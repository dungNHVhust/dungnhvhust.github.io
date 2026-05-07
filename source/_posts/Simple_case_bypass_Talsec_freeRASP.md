---
layout: single
title: "Bypass Talsec FreeRASP"
date: 2026-05-06 10:00:00 +0700
categories: [Mobile]
tags: [Mobile, Android, Talsec ]
---
#
## Case 1
Một vài real case (maybe đơn giản) mình được ông anh ném cho vọc.

Ban đầu khi cài đặt và mở app trên con android đã ẩn root và bật sẵn `frida-server` thì bị văng app sau 30s.
Do khá tự tin về khả năng ẩn root, ẩn unlock botloader , ẩn usb debug trên máy của mình nên khả năng chỉ có thể là `frida` đã bị detech.

Thử tắt `frida-server` đi và thử lại thì không còn bị văng app nữa nên chắc chắn app có detech frida.

Decompile với JADX nhận thấy đây là 1 app Flutter.

<picture>
  <img src="https://dungnhvhust.github.io/images/adr14.png" data-src-ignore>
</picture>

Và đã được obfuscate

<picture>
  <img src="https://dungnhvhust.github.io/images/adr15.png" data-src-ignore>
</picture>

Search thử 1 số keyword, phát hiện ở đây đã sử dụng [Talsec RASP](https://github.com/talsec), cụ thể là `freeRASP`

<picture>
  <img src="https://dungnhvhust.github.io/images/adr16.png" data-src-ignore>
</picture>


Khi list function thấy các JNI export:

- `Java_com_aheaditec_talsec_1security_security_Natives_e`
- `Java_com_aheaditec_talsec_1security_security_Natives_f`
- `Java_com_aheaditec_talsec_1security_security_Natives_g`
- `Java_com_aheaditec_talsec_1security_security_Natives_a`

Cùng với namespace `com.aheaditec.talsec_security`, có thể xác nhận đây là thư viện Talsec.


Đầu tiên thử sử dụng các [script](https://codeshare.frida.re/@muhammadhikmahhusnuzon/bypass-talsec-rasp-and-root-detection/) bypass Talsec RASP sẵn nhưng không được cơm cháo gì. Ok fine.Bắt buộc phải nhảy vào rev.

Sau 1 hồi trace theo keyword `X509Certificate` nhưng không thấy đoạn code nào liên quan đến việc triển khai SSL Pinning, quay lại kiểm tra các lib.

Có 1 số lib khả nghi ở đây :

- `libsecurity.so` : là thư viện Talsec Security dùng cho RASP: anti-Frida, root detection, threat checks.
- `libpolarssl.so` : Chưa có thông tin.

### Bypass Anti-Frida

Bắt đầu với `libsecurity.so`. Sử dụng `IDA Pro` ~~và 100% Claude~~ để rev lib này, tìm thấy cách app detech Frida:

- `afld()` @ `0x5bc4` : mở `/proc/self/maps`, đọc từng dòng bằng `fgets` , tìm substring `"frida"` bằng `strstr` . Nếu trong memory map có module / path chứa chữ `frida` thì coi như bị instrumentation.

- `ifpip()` @ `0x5910` : mở `/proc/self/maps`,parse các memory region có quyền `r-x`, quét trực tiếp vùng nhớ thực thi và tìm chuỗi `LIBFRIDA`.

- `ifsl()` @ `0x5b24` : tạo socket rồi connect tới `127.0.0.1:27042` (Port mặc định của Frida), nếu connect được thì kết luận đang có Frida server hoạt động.

Ok đã tìm thấy hàm detech frida, tiến hành hook vào để bypass:

- Hook `strstr` : Nếu needle chứa `frida` trả `NULL`

- Hook `connect`: Nếu app thử connect `127.0.0.1:27042` ép fail
- Hook các hàm `afld()`,`ifpip()`,`ifsl()` để return 2.

```js
var libc = Process.findModuleByName("libc.so");
// Hook strstr - hide "frida" string
if (libc) {
  var strstrExport = libc.findExportByName("strstr");
  if (strstrExport) {
    Interceptor.attach(strstrExport, {
      onEnter: function (args) {
        this.needle = args[1].readUtf8String();
      },
      onLeave: function (retval) {
        if (this.needle && this.needle.toLowerCase().indexOf("frida") !== -1) {
          retval.replace(ptr(0));
        }
      },
    });
    console.log("[+] Hooked strstr (frida string hiding)");
  }
  // Hook connect - block port 27042
  var connectExport = libc.findExportByName("connect");
  if (connectExport) {
    Interceptor.attach(connectExport, {
      onEnter: function (args) {
        this.block = false;
        var addrPtr = args[1];
        var addrLen = args[2].toInt32();
        if (addrLen >= 16) {
          var family = addrPtr.readU16();
          if (family === 2) {
            var port = (addrPtr.add(2).readU8() << 8) | addrPtr.add(3).readU8();
            if (port === 27042) {
              console.log("[+] Blocked connect() to 127.0.0.1:" + port);
              this.block = true;
            }
          }
        }
      },
      onLeave: function (retval) {
        if (this.block) retval.replace(-1);
      },
    });
    console.log("[+] Hooked connect (port 27042 blocking)");
  }
}

// Hook afld/ifpip/ifsl in libsecurity.so
function hookSecurityModule() {
  var mod = Process.findModuleByName("libsecurity.so");
  if (mod) {
    console.log("[+] Found libsecurity.so @ " + mod.base);

    Interceptor.attach(mod.base.add(0x5bc4), {
      // afld
      onLeave: function (retval) {
        if (retval.toInt32() === 1) {
          console.log("[+] afld(): blocked frida in /proc/self/maps");
          retval.replace(2);
        }
      },
    });
    Interceptor.attach(mod.base.add(0x5910), {
      // ifpip
      onLeave: function (retval) {
        if (retval.toInt32() === 1) {
          console.log("[+] ifpip(): blocked LIBFRIDA scan");
          retval.replace(2);
        }
      },
    });
    Interceptor.attach(mod.base.add(0x5b24), {
      // ifsl
      onLeave: function (retval) {
        if (retval.toInt32() === 1) {
          console.log("[+] ifsl(): blocked port 27042 detection");
          retval.replace(2);
        }
      },
    });
    console.log("[+] Native anti-Frida hooks installed");
  } else {
    setTimeout(hookSecurityModule, 100);
  }
}
```

Thử hook script này và test, lúc này không bị văng app nữa.

```
Spawning com.samsung.xxxx.xxxx...
[.] Starting Talsec Bypass Script...
Spawned com.samsung.xxxx.xxxx. Resuming main thread!
[Remote::com.samsung.xxxx.xxxx ]-> [+] Hooked strstr (frida string hiding)
[+] Hooked connect (port 27042 blocking)
[+] Found libsecurity.so @ 0x7012243000
[+] Native anti-Frida hooks installed
[+] Blocked connect() to 127.0.0.1:27042
```

### Bypass check root

Cũng ở `libsecurity.so`, app có 1 số cơ chế để check root:

- Tìm `su` trong PATH : đọc biến môi trường `PATH` ,thử ghép từng directory với `/su`, nếu tồn tại thì báo root.

- Đọc `/proc/self/mounts`,tìm string `magisk`, tìm `core/mirror`, tìm `core/img` để phát hiện Magisk / root environment.

- Quét `/system/app` , so tên package trong danh sách APK decode sẵn, tìm app root manager / suspicious app.

- Tìm file nhị phân root phổ biến :
  Danh sách đã được obfuscate nhưng khi chạy thực tế thấy app kiểm các path kiểu: `/system/app/Superuser.apk`,`/sbin/su`,
  `/system/bin/su`, `/system/xbin/su`,`/data/local/xbin/su`,`/data/local/bin/su`,`/data/local/su`,`/su/bin/su`,`/cache/su`
  ,`/dev/su`,...

```js
try {
  var File = Java.use("java.io.File");
  var suPaths = [
    "/system/app/Superuser.apk",
    "/sbin/su",
    "/system/bin/su",
    "/system/xbin/su",
    "/data/local/xbin/su",
    "/data/local/bin/su",
    "/system/sd/xbin/su",
    "/system/bin/failsafe/su",
    "/data/local/su",
    "/su/bin/su",
    "/su/xbin/su",
    "/su/sbin/su",
    "/system/su",
    "/system/usr/we-need-root/su",
    "/cache/su",
    "/data/su",
    "/dev/su",
  ];
  File.$init.overload("java.lang.String").implementation = function (path) {
    if (suPaths.indexOf(path) > -1) {
      console.log("[+] Bypassing root check for file: " + path);
      return this.$init.call(this, "/nonexistent");
    }
    return this.$init.call(this, path);
  };
} catch (err) {
  console.log("[-] Root detection bypass (File) failed: " + err.message);
}
```

### Bypass SSL Pinning

Sau khi đã bypass anti-frida và check root thành công, cần bypass nốt SSL Pinning để bắt request.

Do khi rev `libsecurity.so` không thấy dấu hiệu gì của việc triển khai SSL Pinning ở đây nên thử rev `libpolarssl.so`,tuy nhiên lib này chỉ chứa crypto/hash, không phải chỗ xử lý TLS chính của app.

Lúc này có 2 khả năng:

1. Flutter engine (`libflutter.so`) dùng BoringSSL
2. native custom TLS library riêng

Đã thử reverse `libflutter.so`:

- có string liên quan `SecurityContext`, `SecureSocket`, `handshake.cc`
- tìm được một số candidate của BoringSSL
- nhưng hook các hàm candidate như `verify_cert_chain`, `ssl_verify_peer_cert` không hề trigger trong runtime

Điều này chứng tỏ app không đi qua luồng TLS mặc định của Flutter cho request thực tế.

Thêm debug log :

- `connect()` để xem app connect đi đâu
- `fopen()` để xem app mở cert/config nào

Trong lúc debug log `fopen()`, thấy:

```
/Users/martinzigrai/Desktop/openssl-curl-android/openssl/build/arm64-v8a/ssl/openssl.cnf
```

Đây là path build machine bị hardcode, cho thấy:

- app nhúng OpenSSL/curl riêng
- không dùng TLS stack mặc định của Flutter cho network chính

Do đó thử ~~Claude~~ rev `libclib.so` và thấy rất nhiều symbol OpenSSL còn nguyên:

- `SSL_CTX_set_verify`
- `SSL_set_verify`
- `SSL_CTX_set_cert_verify_callback`
- `SSL_get_verify_result`
- `SSL_do_handshake`

Đến đây chắc chắn app dùng OpenSSL custom và SSL/TLS pinning và verify chính nằm ở `libclib.so`.

TLS client flow

- `SSL_connect` @ `0x3eeffc`
- gọi tiếp `SSL_do_handshake` @ `0x3eef18`

App triển khai verify từ 3 hàm:

- `SSL_CTX_set_verify` @ `0x3f115c`
- `SSL_set_verify` @ `0x3eeac4`
- `SSL_CTX_set_cert_verify_callback` @ `0x3f1154`

Ta thấy app có 2 cơ chế:

1. set verify mode
2. set callback verify custom

Đây là đúng pattern của app dùng OpenSSL để tự kiểm soát cert verification / pinning.

Sau handshake app hoặc thư viện có thể đọc verify status

- `SSL_get_verify_result` @ `0x3f2108`

Tiến hành hook vào các hàm

- `SSL_CTX_set_verify` : ép mode thành `SSL_VERIFY_NONE` (`0`)

- `SSL_set_verify` : ép mode thành `0`

- `SSL_CTX_set_cert_verify_callback` : thay callback verify bằng callback custom luôn return success

- `SSL_get_verify_result` : nếu return khác `0` thì ép thành `0` (`X509_V_OK`)

- `SSL_do_handshake` : debug xem handshake có thực sự đi qua OpenSSL hay không

Ở đây app dùng raw `OpenSSL/curl` để nói chuyện TLS trực tiếp với server.

Nên ta sẽ rewrite TCP destination từ `18.x.x.x:443` / `18.x.x.x:9243`
thành `172.20.10.2:8080` (Proxy của Burp), nên cần bật invisible proxy trong Burp để bắt được request.

```js
var PROXY_IP = "172.20.10.2";
var PROXY_PORT = 8080;

    function hookClibSSL() {
        var clib = Process.findModuleByName("libclib.so");
        if (!clib) { setTimeout(hookClibSSL, 200); return; }
        console.log("[+] Found libclib.so @ " + clib.base);

        // Hook SSL_CTX_set_verify to disable cert verification
        var SSL_CTX_set_verify = clib.findExportByName("SSL_CTX_set_verify");
        if (SSL_CTX_set_verify) {
            Interceptor.attach(SSL_CTX_set_verify, {
                onEnter: function(args) {
                    // args[0] = ctx, args[1] = mode, args[2] = callback
                    var mode = args[1].toInt32();
                    console.log("[*] SSL_CTX_set_verify(mode=" + mode + ") -> forcing VERIFY_NONE");
                    args[1] = ptr(0); // SSL_VERIFY_NONE = 0
                }
            });
            console.log("[+] Hooked SSL_CTX_set_verify");
        }

        // Hook SSL_set_verify too
        var SSL_set_verify = clib.findExportByName("SSL_set_verify");
        if (SSL_set_verify) {
            Interceptor.attach(SSL_set_verify, {
                onEnter: function(args) {
                    args[1] = ptr(0);
                }
            });
            console.log("[+] Hooked SSL_set_verify");
        }

        // Hook SSL_CTX_set_cert_verify_callback
        var SSL_CTX_set_cert_verify_callback = clib.findExportByName("SSL_CTX_set_cert_verify_callback");
        if (SSL_CTX_set_cert_verify_callback) {
            Interceptor.attach(SSL_CTX_set_cert_verify_callback, {
                onEnter: function(args) {
                    // Replace callback with one that always returns 1 (success)
                    args[1] = new NativeCallback(function(store_ctx, x) {
                        console.log("[+] cert_verify_callback BYPASSED");
                        return 1;
                    }, 'int', ['pointer', 'pointer']);
                }
            });
            console.log("[+] Hooked SSL_CTX_set_cert_verify_callback");
        }

        // Hook SSL_get_verify_result to always return X509_V_OK (0)
        var SSL_get_verify_result = clib.findExportByName("SSL_get_verify_result");
        if (SSL_get_verify_result) {
            Interceptor.attach(SSL_get_verify_result, {
                onLeave: function(retval) {
                    if (retval.toInt32() !== 0) {
                        console.log("[+] SSL_get_verify_result: " + retval + " -> forcing 0 (OK)");
                        retval.replace(ptr(0));
                    }
                }
            });
            console.log("[+] Hooked SSL_get_verify_result");
        }

        // Hook SSL_do_handshake to log handshakes
        var SSL_do_handshake = clib.findExportByName("SSL_do_handshake");
        if (SSL_do_handshake) {
            Interceptor.attach(SSL_do_handshake, {
                onEnter: function() { console.log("[*] SSL_do_handshake called"); },
                onLeave: function(retval) { console.log("[*] SSL_do_handshake result: " + retval); }
            });
            console.log("[+] Hooked SSL_do_handshake");
        }

        console.log("[+] OpenSSL SSL bypass hooks installed");
    }

    // Traffic redirect: redirect connections to proxy
    function hookTrafficRedirect() {
        var realConnect = libc.findExportByName("connect");
        if (realConnect) {
            Interceptor.attach(realConnect, {
                onEnter: function(args) {
                    this.redirect = false;
                    var addrPtr = args[1];
                    var family = addrPtr.readU16();
                    if (family === 2) { // AF_INET
                        var port = (addrPtr.add(2).readU8() << 8) | addrPtr.add(3).readU8();
                        var ip = addrPtr.add(4).readU8() + "." + addrPtr.add(5).readU8() + "." +
                                 addrPtr.add(6).readU8() + "." + addrPtr.add(7).readU8();
                        // Redirect to proxy (skip localhost and port 27042)
                        if (port !== 27042 && ip !== "127.0.0.1") {
                            console.log("[+] Redirecting " + ip + ":" + port + " -> " + PROXY_IP + ":" + PROXY_PORT);
                            addrPtr.add(2).writeU16(((PROXY_PORT & 0xFF) << 8) | ((PROXY_PORT >> 8) & 0xFF));
                            var octets = PROXY_IP.split(".").map(function(o){return parseInt(o);});
                            addrPtr.add(4).writeByteArray(octets);
                            this.redirect = true;
                        }
                    }
                }
            });
            console.log("[+] connect() traffic redirect active");
        }
```

Chạy script

```
PS C:\Users\dungnhv2\Script> frida -H 127.0.0.1 -l .\talsecBypass.js -f com.samsung.xxxx.xxxx
     ____
    / _  |   Frida 17.9.1 - A world-class dynamic instrumentation toolkit
   | (_| |
    > _  |   Commands:
   /_/ |_|       help      -> Displays the help system
   . . . .       object?   -> Display information about 'object'
   . . . .       exit/quit -> Exit
   . . . .
   . . . .   More info at https://frida.re/docs/home/
   . . . .
   . . . .   Connected to 127.0.0.1 (id=socket@127.0.0.1)
Spawning `com.samsung.xxxx.xxxx`...
[.] Starting Talsec Bypass Script...
Spawned `com.samsung.xxxx.xxxx`. Resuming main thread!
[Remote::com.samsung.xxxx.xxxx ]-> [+] Hooked strstr (frida string hiding)
[+] Hooked connect (port 27042 blocking)
[+] connect() traffic redirect active
[+] Bypassing root check for file: /system/app/Superuser.apk
[+] Bypassing root check for file: /system/xbin/su
[+] Bypassing root check for file: /system/app/Superuser.apk
[+] Bypassing root check for file: /system/xbin/su
[+] Bypassing root check for file: /system/app/Superuser.apk
[+] Bypassing root check for file: /system/xbin/su
[+] Bypassing root check for file: /system/app/Superuser.apk
[+] Bypassing root check for file: /system/xbin/su
[+] Found libclib.so @ 0x6df8055000
[+] Hooked SSL_CTX_set_verify
[+] Hooked SSL_set_verify
[+] Hooked SSL_CTX_set_cert_verify_callback
[+] Hooked SSL_get_verify_result
[+] Hooked SSL_do_handshake
[+] OpenSSL SSL bypass hooks installed
[+] Found libsecurity.so @ 0x6f4cdc1000
[+] Native anti-Frida hooks installed
[+] Redirecting 203.246.224.53:80 -> 172.20.10.2:8080
[+] Redirecting 54.80.119.44:9243 -> 172.20.10.2:8080
[*] SSL_CTX_set_verify(mode=1) -> forcing VERIFY_NONE
[*] SSL_do_handshake called
[*] SSL_do_handshake result: 0xffffffff
[+] Redirecting 34.234.143.15:443 -> 172.20.10.2:8080
[*] SSL_CTX_set_verify(mode=0) -> forcing VERIFY_NONE
[*] SSL_do_handshake called
[*] SSL_do_handshake result: 0xffffffff
[+] Redirecting 54.80.119.44:9243 -> 172.20.10.2:8080
[*] SSL_CTX_set_verify(mode=1) -> forcing VERIFY_NONE
[*] SSL_do_handshake called
[*] SSL_do_handshake result: 0xffffffff
[+] Redirecting 203.246.224.53:80 -> 172.20.10.2:8080
[*] SSL_do_handshake called
[*] SSL_do_handshake result: 0x1
[+] SSL_get_verify_result: 0x13 -> forcing 0 (OK)
[+] SSL_get_verify_result: 0x13 -> forcing 0 (OK)
[+] Blocked connect() to 127.0.0.1:27042
[+] Redirecting 18.204.141.221:9243 -> 172.20.10.2:8080
[*] SSL_CTX_set_verify(mode=1) -> forcing VERIFY_NONE
[*] SSL_do_handshake called
```

Bắt được request

<picture>
  <img src="https://dungnhvhust.github.io/images/adr17.png" data-src-ignore>
</picture>



## Case 2
### Bypass ở `libclib.so`
Nhìn tổng quan thì app này cũng tương tự như case 1. Thử sửa lại offset và chạy script của app 1 thì bypass được check frida và check root, app hoạt động bình thường nhưng không bắt được request.

Nhảy vào ~~Claude~~ rev `libclib.so` thì phát hiện app này triển khai SSL khác với app 1.

Qua RE trên `libclib.so`, flow chính là:

- `sub_2575F4` khởi tạo `SSL_CTX`, cấu hình TLS, gọi `SSL_CTX_set_verify(ctx, mode, NULL)`
- `sub_259DD8` thực hiện `SSL_connect` trong loop
- Sau khi handshake thành công, `sub_259DD8` gọi trực tiếp `sub_258204`
- `sub_258204` làm phần verify thực tế:
  - kiểm tra chain
  - kiểm tra OCSP
  - kiểm tra public-key pin
- public-key pin nằm ở `sub_253B58`

`sub_253B58` so sánh public key của peer cert với pin format:

```text
sha256//<base64>
```

Convention trả về của lớp này:
- `0` = success / pin match
- `90` = mismatch

Vì vậy bypass đúng là ép các hàm verify nội bộ này về `0`, không phải `1`.

Tuy nhiên sau khi hook thành công thì chỉ bắt được duy nhất request đến server của talsec :
```
POST /tlpafw HTTP/2
Host: query.atidevs.com
Accept: */*
Authorization: ApiKey Skx2Sjcza0JUWixxxxxxxxxxxxEtVRWRBSURULVdlMm1uQVZabUVTdw==
Sdk-Identifier: com.samsung.xxxx.xxxxxxxxx
Req-Integrity: value=kLunDQYsoX58ixLxxxxxsxzM2fawewNtZgzJ4riQ=;id=atidevs-prod;version=1
Content-Type: application/json
Content-Length: 1654

{"instanceId":"50eaff99-94e0-4f9c-aa7c-32cdbf3f5d00","sdkVersion":"14.0.1","platform":"Android","deviceInfo":{"osVersion":"16","manufacturer":"Google","model":"Pixel 6a"},"deviceId":{"androidId":"c4f93600b0afdf19","mediaDrm":"bf406a95da9ec2f9505d236dfa123f462c33c41ae2ef61fa739661753c7fda33","fingerprintV3":"24fd9f2c3f3f0b55108cacc9edba081b"},"loggingSslPinning":true,"occurence":"2026-05-06T15:06:26.992000+0700","appInfo":{"appIdentifier":"com.samsung.xxxx.xxxxxxxxx","certHash":"TXAXpsr1rblOukuGwXDW9RjGH0aLiVM76am0EUurH7s=","appVersion":"2.0.13","installationSource":"com.android.shell"},"deviceState":{"security":"unlocked","biometrics":"noneEnrolled","hwBackedKeychain":"StrongBox","isAdbEnabled":"true","hasGoogleMobileServices":true,"hasHuaweiMobileServices":false,"selinuxProperties":{"buildSelinuxProperty":"none","selinuxMode":"none","bootSelinuxProperty":"none","selinuxEnforcementFileContent":"error","selinuxEnabledReflect":"true","selinuxEnforcedReflect":"false"},"securityPatch":"2026-03-05"},"sdkState":{"beatExecutionState":"Active","controlExecutionState":"Running - 63"},"checks":{"unofficialStore":{"status":"NOK","timeMs":2},"debug":{"status":"OK","timeMs":1},"simulator":{"status":"OK","timeMs":1403},"privilegedAccess":{"status":"NOK","timeMs":1021},"monitoring":{"status":"OK","timeMs":0},"appIntegrity":{"status":"NOK","timeMs":2929},"hooks":{"status":"NOK","timeMs":361}},"sessionId":"a27255ed-a66f-4cba-9507-9de816b59515","sdkPlatform":"Flutter","sdkIdentifier":"com.samsung.xxxx.xxxxxxxxx","watcherMail":"","incidentReport":{"featureTestingIgnored":{"isHookHoneypotDetectedFeatureTesting2":"true"},"type":"hooks"}}
```
Có thể đây là request tracking trạng thái để gửi về server của Tailsec.

Đến đây sau 1 lúc loay hoay thì mình nghĩ rằng có thể app này triển khai SSL ở chỗ khác nữa, ở `libclib.so` chỉ triển khai SSL của Talsec thôi.

### Bypass libflutter.so

Thử với script vẫn hay dùng với những app triển khai SSL trong `libflutter.so` thì hook thành công và bắt được request.

<picture>
  <img src="https://dungnhvhust.github.io/images/adr18.png" data-src-ignore>
</picture>

Do đó có thể chắc chắn traffic API chính không đi qua `libclib.so` mà đi qua engine Flutter trong `libflutter.so`, dùng `BoringSSL statically linked`.

Điều này dẫn tới hai hệ quả:

1. Không thể hook tìm hàm theo kiểu `findExportByName("SSL_CTX_set_verify")` như với OpenSSL/libcurl
2. Muốn hook phải tìm hàm theo pattern / string / control-flow, không phải theo export name

Vì BoringSSL được compile thẳng vào `libflutter.so` dưới dạng static link và binary release đã strip symbol/không export các hàm SSL nội bộ, nên không còn symbol như `SSL_CTX_set_verify` trong `.dynsym` để `findExportByName()` tìm được; do đó phải lần theo dấu vết còn sót lại như string (`ssl_client`), xref và control-flow để xác định hàm verify cần hook.

Ta sẽ lần theo 2 string:
- string `ssl_client\0`
- string `Socket_CreateConnect\0`

Từ `ssl_client\0`:
- scan trong `.rodata`
- tìm instruction sequence trong `.text` tham chiếu tới string đó
- trace ngược về prologue hàm
- suy ra được hàm `verify_cert_chain`

Ở phía Flutter/BoringSSL, `verify_cert_chain` dùng convention kiểu boolean:
- `0` = fail
- `1` = success

Vì vậy chỉ cần tìm `verify_cert_chain` rồi hook vào `onLeave`,nếu retval là fail (`0`) thì đổi thành success (`1`).

Tương tự với `Socket_CreateConnect`, tìm `Socket_CreateConnect` , từ đó lần tới `GetSockAddr` ,hook `GetSockAddr` để lấy `sockaddr` rồi hook `socket()` để sửa destination IP/port sang Burp.

```
Spawning `com.samsung.xxxx.xxxxxx`...
[.] Starting Bypass Script...
[+] Hooked getenv (curl proxy)
[+] Hooked connect (port 27042 block)
[+] Hooked strstr (frida hiding)
Spawned `com.samsung.xxxx.xxxxxx`. Resuming main thread!
[Remote::com.samsung.xxxx.xxxxxx ]-> [+] Found libflutter.so @ 0x7b8cc7f000
[*] hookFlutter: resolving libc exports
[*] open=0x7f9b72ec40 close=0x7f9b726150 lseek=0x7f9b7891c0 read=0x7f9b788380
[*] libflutter path: /data/app/~~xVjRqFHsfQK-OvLNsWqu5g==/com.samsung.xxxx.xxxxxx-whWYvVQ-YLKbmUDRgSSpeQ==/base.apk!/lib/arm64-v8a/libflutter.so
[*] open(fd) = -1
[*] ELF parse result: rodata_memsz=0x42d654 text_vaddr=0x43d680 text_memsz=0x5a2cd0 relro_vaddr=0x9f0350 relro_memsz=0x63cb0
[*] ELF parsed: rodata=0x42d654 textVaddr=0x43d680 textSize=0x5a2cd0 relroVaddr=0x9f0350 relroSize=0x63cb0
[*] ssl_client string @ 0x7b8ce345b1
[*] Socket_CreateConnect string @ 0x7b8ce3585f
[*] Socket_CreateConnect @ 0x7b8d47c3a0
[*] GetSockAddr @ 0x7b8d482a30
[+] Flutter traffic redirect installed
[*] verify_cert_chain @ 0x7b8d35aef4
[+] Hooked verify_cert_chain (flutter SSL bypass)
[+] Found libsecurity.so @ 0x7b682e9000
[+] Hooked afld @ 0x7b682f191c
[+] Hooked ifpip @ 0x7b682f1668
[+] Hooked ifsl @ 0x7b682f187c
[+] Hooked JNI wrapper @ 0x7b682f19d4 -> Java_com_aheaditec_talsec_1security_security_Natives_e
[+] Hooked JNI wrapper @ 0x7b682f1a24 -> Java_com_aheaditec_talsec_1security_security_Natives_f
[+] Hooked JNI wrapper @ 0x7b682f1a74 -> Java_com_aheaditec_talsec_1security_security_Natives_g
[+] Talsec anti-Frida bypass ready
[+] Found libclib.so @ 0x7b630bd000
[+] Hooked SSL_get_verify_result @ 0x7b634aff08
[+] Hooked X509_verify_cert @ 0x7b6344712c
[*] No symbol for curl verify/pin funcs, falling back to offsets
[+] Hooked curl_verify_callback @ 0x7b63315204
[+] Hooked curl_pin_check @ 0x7b63310b58
[+] SSL bypass ready (libclib.so)
[+] flutter socket redirect -> 172.20.10.2:8080
[+] flutter socket redirect -> 172.20.10.2:8080
[+] flutter socket redirect -> 172.20.10.2:8080
[+] flutter verify_cert_chain bypass
[+] X509_verify_cert -> 1
```

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