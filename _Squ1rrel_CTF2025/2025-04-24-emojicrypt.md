---
layout: default
title: "emojicrypt"
date: 2025-04-24 16:00:00 +0700
tags: [CTF, Squ1rrelCTF 2025]
---
# emojicrypt - web
> Tên: emojicrypt
> Description: Passwords can be more secure. We’re taking the first step.
> Có source code

## Phân tích
Có 2 chức năng : 
1. Register: Khi register sẽ không biết password.
2. Login: Chỉ cần login được sẽ lấy được flag.

Phân tích source code:
```python
EMOJIS = ['🌀', '🌁', '🌂', '🌐', '🌱', '🍀', '🍁', '🍂', '🍄', '🍅', '🎁', '🎒', '🎓', '🎵', '😀', '😁', '😂', '😕', '😶', '😩', '😗']
NUMBERS = '0123456789'

def register():
    email = request.form.get('email')
    username = request.form.get('username')

    if not email or not username:
        return "Missing email or username", 400
    salt = generate_salt()
    random_password = ''.join(random.choice(NUMBERS) for _ in range(32))
    password_hash = bcrypt.hashpw((salt + random_password).encode("utf-8"), bcrypt.gensalt()).decode('utf-8')

    # TODO: email the password to the user. oopsies!
```
```python
def generate_salt():
    return 'aa'.join(random.choices(EMOJIS, k=12))

```
`EMOJIS` có 21 emoji.
`random.choices(..., k=12)` → chọn random 12 emoji.
Rồi ghép lại bằng chuỗi `'aa'` (tức `emoji1` + `'aa'` + `emoji2` + `'aa'` + ...)
Mỗi emoji trong UTF-8 thường có độ dài 4 byte,ghép với chuỗi `'aa' `   nghĩa là độ dài salt là: 
`4x12 + 2x11 = 70 byte` 

```python
random_password = ''.join(random.choice(NUMBERS) for _ in range(32)) 
```  
Password có độ dài 32 byte,được random từ `NUMBERS`

```python 
password_hash = bcrypt.hashpw((salt + random_password).encode("utf-8"), bcrypt.gensalt()).decode('utf-8')
```
Ghép `salt + password` → rồi `.encode("utf-8")` → ra 1 chuỗi byte
Bỏ vào `bcrypt.hashpw(...)` để hash

📉 Nhưng vấn đề chết người ở đây là: **BCRYPT chỉ dùng 72 byte** đầu tiên
Phần nào vượt quá 72 byte → bị bỏ luôn
→ Dẫn đến khả năng 2 password khác nhau vẫn hash ra cùng giá trị nếu phần khác nằm sau byte 72

```python
if salt and hash and bcrypt.checkpw((salt + password).encode("utf-8"), hash.encode("utf-8")):
        return os.environ.get("FLAG")
```
Do đó thực chất phần password được ghép với satl và hash chỉ có độ dài 2 byte → Có thể brute force được.
## Exploit
Sử dụng Intruder của Burpsuite để brute force password chạy từ 00 đến 99:
![](http://note.bksec.vn/pad/uploads/2733ce62-5662-4a54-88d8-d81fa2a7975c.png)

Lấy flag:
![](http://note.bksec.vn/pad/uploads/04906970-c949-4953-9cf9-80ef03eb3593.png)

>Flag: squ1rrel{turns_out_the_emojis_werent_that_useful_after_all}