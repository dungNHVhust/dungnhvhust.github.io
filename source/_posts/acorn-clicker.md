---
layout: single
title: "acorn clicker"
date: 2025-04-24 16:00:00 +0700
categories: [Squ1rrel-CTF-2025]
tags: [CTF, Web]
---
# acorn clicker - web - very_easy

> Tên : acorn clicker
> Description: Click acorns. Buy squirrels. Profit.
> Có source code

## Phân tích 
Mục tiêu cần tích đủ 999999999999999999 acorn để mua được flag.

Phân tích source code:
```javascript
app.post("/api/click", authenticate, async (req, res) => {
  // increase user balance
  const { username } = req.user;
  const { amount } = req.body;

  if (typeof amount !== "number") {
    return res.status(400).send("Invalid amount");
  }

  if (amount > 10) {
    return res.status(400).send("Invalid amount");
  }

  let bigIntAmount;

  try {
    bigIntAmount = BigInt(amount);
  } catch (err) {
    return res.status(400).send("Invalid amount");
  }

  await db
    .collection("accounts")
    .updateOne({ username }, { $inc: { balance: bigIntAmount } });

  res.json({ earned: amount });
});
```
Ta thấy ở đây Mongodb sử dụng kiểu dữ liệu `BigInt` để lưu số acorn,điểm đặc biệt ở đây là kiểu dữ liệu này ko biểu diễn số âm.
-> Nếu ta làm cho số acorn thành âm thì Mongodb sẽ wrap thành số rất lớn.


## Exploit
Race condition:
Gửi 2 request mua cùng 1 lúc để số acorn thành âm:
Dùng tính năng `Send Group (paralleel)` của Burp Suite:
![](http://note.bksec.vn/pad/uploads/66515082-9c54-48aa-9872-ff5e18b6e3a9.png)
Sau khi send,giá trị acorn âm sẽ được wrap thành rất lớn:
![](http://note.bksec.vn/pad/uploads/c1043e05-5093-4dbb-bce4-176fa6965362.png)
Lấy flag:
![](http://note.bksec.vn/pad/uploads/1a3b490e-7f06-4d01-a6a0-c82bbdd6052e.png)

> Flag: squ1rrel{1nc0rr3ct_d3s3r1al1zat10n?_1n_MY_m0ng0?}


