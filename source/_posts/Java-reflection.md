---
layout: single
title: "Java Reflection"
date: 2026-04-21 00:00:00 +0700
categories: [Java]
tags: [Java, Java Deserialize, Java Reflection]
---

# Java Reflection là gì
Java Reflection là 1 tính năng trong Java, cho phép truy cập các thông tin của đối tượng (tên Class , các field, các method) và chỉnh sửa các field của đối tượng (kể cả các field private) trong quá trình runtime.

# Cơ chế hoạt động của Reflection
Đầu tiên cần hiểu 2 định nghĩa về `compile time` và `runtime` :
- `compile time` : Là giai đoạn src code được compiler biên dịch thành code mà máy tính có thể thực thi (executable code). Trong Java đó là quá trình biên dịch file `.java` thành file `.class`. Trong `compile time`, chỉ 1 số chức năng biên dịch được thực hiện và code không được đưa vào bộ nhớ để chạy mà chỉ hoạt động dưới dạng văn bản, chẳng hạn như kiểm tra lỗi.

- `runtime` : Là giai đoạn code trên đĩa (disk) được đưa vào bộ nhớ và thực thi.

Ví dụ về 2 định nghĩa trên:

<picture>
  <img src="https://dungnhvhust.github.io/images/r01.png" data-src-ignore>
</picture>

Khi syntax ở dòng 7 bị sai thì compile sẽ bắt lỗi ở đây:

<picture>
  <img src="https://dungnhvhust.github.io/images/r02.png" data-src-ignore>
</picture>
Còn khi dùng phép chia cho 0 thì sẽ phát hiện bởi runtime.

<picture>
  <img src="https://dungnhvhust.github.io/images/r03.png" data-src-ignore>
</picture>

Giờ đến ví dụ chỉnh sửa private property của class bằng Java Reflection:
```java
public class Dog {
    public String name;
    private int id = 99;

    public void Speak(){
        System.out.println("This dog is " + name + " and has id : " + id);
    }

    public Dog(String name){
        this.name = name;
    }
}

```


```java
package org.example;

import java.lang.reflect.Field;

public class Main {
    public static void main(String[] args) throws NoSuchFieldException,IllegalAccessException {
        System.out.println("Hello and welcome!");

        Dog dog = new Dog("Cun");
        dog.Speak();

        // Get the class of the dog
        Class<?> dogClass = dog.getClass();

        // Get the field that want to access (even if it's private)
        Field privateField = dogClass.getDeclaredField("id");

        // Make the private field accessible
        privateField.setAccessible(true);

        // Set new value for the private field in the instance
        privateField.set(dog,1);

        // Get the update value of the private field from the instance
        int fieldValue = (int) privateField.get(dog);

        System.out.println("Updated Private Field Value: " + fieldValue);
        dog.Speak();
    }
}
```
Output:
```text
Hello and welcome!
This dog is Cun and has id : 99
Updated Private Field Value: 1
This dog is Cun and has id : 1

Process finished with exit code 0
```

Hình dung hệ thống sẽ phân cấp như sau:

<picture>
  <img src="https://dungnhvhust.github.io/images/r04.png" data-src-ignore>
</picture>

Các class được dùng trong Reflection được nằm trong `package java.lang.reflect`

## Object
Class Object là class gốc trong hệ thống phân lớp các class.

Mọi class đều là con của class Object,hay có thể nói class Object là class cha của toàn bộ các class.

## Class
Class là class được cung cấp bởi package `java.lang.Class`

Một instance của class Class đại diện cho toàn bộ các kiểu dữ liệu trong Java, bao gồm các kiểu dữ liệu cơ bản (boolean, byte, char, short, int, long), void, array, class, interface, enumeration, annotation.

Class không có public constructor. Thay vào đó object của Class được tạo ra tự động bởi JVM trong quả trình tải class.

Khi sử dụng java reflection thì việc đầu tiên thường phải làm đó là có được một đối tượng kiểu Class, từ các đối tượng kiểu Class chúng ta có thể lấy được các thông tin về:

- Class Name
- Class Modifies (public, private, synchronized etc.)
- Package Info
- Superclass
- Implemented Interfaces
- Constructors
- Methods
- Fields
- Annotations

Có 3 cách để lấy instance của class:

- 1. Sử dụng các biến static class trong class:
```java
Class cls = dog.class; // class là 1 biến static của class Dog
```
- 2. Nếu có object của 1 class thì có thể sử dụng method `getClass()`
```java
Dog s = new Dog("Hello");
Class<?> cls = s.getClass();
```
- 3. Nếu biết toàn bộ tên của class thì có thể sử dụng `Class.forName()`
```java
Class<?> dogClass = Class.forName("org.example.Dog");
```
Khi đã có được Class Object rồi thì ta sẽ dễ dàng có được thông tin các trường của class với các method được viết sẵn:
```java
Class<?> pugClass = Class.forName("org.example.Pug");

Field pugGetField = pugClass.getField("name"); // Lấy 1 trường public (bao gồm cả trường của class cha)

Field pugGetDeclareField = pugClass.getDeclaredField("name"); // Lấy 1 trường public (không bao gồm trường của class cha)
        
Field[] pugGetFields = pugClass.getFields(); // Lấy tất cả fields (bao gồm cả field của class cha)
        
Field[] pugGetDeclareFields = pugClass.getDeclaredFields(); // Lấy tất cả fields (ko bao gồm field của class cha)
```
Sử dụng phương thức `get()` để lấy giá trị của field.

## Method
### Lấy method
Để truy xuất và gọi các method của class thì chúng ta lại có các phương thức có sẵn của Class object

`Method getMethod(name, Class object của type param)` : lấy public method với tên của nó được truyền vào của class và class cha

`Method getDeclaredMethod(name, Class object của type param)` : lấy method (cả public và private) với tên của nó được truyền vào của class không bao gồm class cha

`Method[] getMethods()` : lấy tất cả public method của class gồm cả của class cha

`Method[] getDeclaredMethods()` : lấy tất cả method của class

Ví dụ:
```java
class Student extends Person{
    public int getScore(String type){
        return 99;
    }
    private int getGrade(int year){
        return 1;
    }
}
class Person{

    public String getName(){
        return "Person";
    }
}
```
```java
Class stdClass = Student.class;

System.out.println(stdClass.getMethod("getScore", String.class));

System.out.println(stdClass.getMethod("getName"));

System.out.println(stdClass.getDeclaredMethod("getGrade", int.class));
```

### Gọi method
Bình thường chúng ta sẽ gọi method như thế này

```java
String s = "hello world";
String r = s.substring(6);
//output: world
```
Đối với reflection sử dụng hàm `invoke(object, param)`

```java
import java.lang.Class;
import java.lang.reflect.*;

public class Main {
    public static void main(String[] args) throws  Exception{
        String s = "Hello world";
        Method m = String.class.getMethod("substring", int.class);
        String r = (String) m.invoke(s,6);
        System.out.println(r);
    }
}
```
Đối với các method khai báo với private thì phải sử dụng thêm `setAccessible()`

### Tính đa hình
Câu hỏi đặt ra là nếu class con override một method của class cha thì khi sử dụng reflection để truy xuất method, method nào sẽ được gọi? Method của class cha hay của class con.

```java
import java.lang.Class;
import java.lang.reflect.*;

public class Main {
    public static void main(String[] args) throws  Exception{
       Method h = Person.class.getMethod("hello");
       h.invoke(new Student());

    }
}
class Person{
    public void hello(){
        System.out.println("Person:hello");
    }
}
class Student extends Person{
    public void hello(){
        System.out.println("Student:hello");
    }
}


// Output
// Student:hello
```
Tùy vào object được truyền vào hàm `invoke()` và vẫn sẽ tuân theo flow của tính đa hình, đó là method của class con sẽ override method của class cha.

Đoạn code trên tương đương với:
```java
Person p = new Student();
p.hello();
```
### Truy xuất thông tin các hàm khởi tạo
Bình thường chúng ta có thể khởi tạo một đối tượng bằng cách:
```java
Person p = new Person();
```
Nếu muốn khởi tạo một đối tượng với Reflection thì:
```java
Person p = Person.class.newInstance();
```
Nhưng điểm hạn chế của newInstance() là chúng ta không thể khởi tạo đối tượng có tham số truyền vào.

Đừng lo vì Java Reflection đã tiếp tục cung cấp cho chúng ta Constructor class object với các method có sẵn để lấy được các hàm khởi tạo của class
```java
import java.lang.Class;
import java.lang.reflect.*;

public class Main {
    public static void main(String[] args) throws  Exception{
        Constructor<?> cons = Dog.class.getConstructor(String.class, int.class);
        Dog dog = (Dog) cons.newInstance("Cún", 3);
        System.out.println(dog.name + " - " + dog.age);
    }
}
```
```java
getConstructor(Class...);
// lấy một public Constructor 
getDeclaredConstructor(Class...)
// lấy một constructor của class (có thể public hoặc private, protected)
getConstructors()
// lấy tất cả public constructor của class
getDeclaredConstructors()
// Lấy tất cả không chừa cái constructor nào
```
### Lấy những thông tin về tính kế thừa của class

Để có được class cha của class hiện tại sử dụng hàm `getSupperClass()`

```java
import java.lang.Class;
import java.lang.reflect.*;

public class Main {
   public static void main(String[] args) throws  Exception{
       Class i = Integer.class;
       Class n = i.getSuperclass();
       System.out.println(n);
    }
}
// Output
// class java.lang.Number
```
Để có được list interface của class sử dụng `getInterfaces()`
```java
import java.lang.Class;
import java.lang.reflect.*;

public class Main {
   public static void main(String[] args) throws  Exception{
       Class i = Integer.class;
       Class[] interfaces = i.getInterfaces();
       for (Class is : interfaces){
            System.out.println(is);
       }

    }
}
// Output:
// interface java.lang.Comparable
// interface java.lang.constant.Constable
// interface java.lang.constant.ConstantDesc
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