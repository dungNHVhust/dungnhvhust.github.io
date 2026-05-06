---
layout: single
title: "Bypass Talsec FreeRASP"
date: 2026-05-06 10:00:00 +0700
categories: [Mobile]
tags: [Mobile, Android, Talsec ]
---

# Tổng quan
Một real case (maybe đơn giản) mình được ông anh ném cho vọc.

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

## Bypass Anti-Frida

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

## Bypass check root

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

## Bypass SSL Pinning

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