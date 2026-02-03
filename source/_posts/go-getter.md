---
layout: single
title: "go-getter"
date: 2025-04-24 16:00:00 +0700
categories: [Squ1rrel-CTF-2025]
tags: [CTF, Web]
---
# [web] go-getter - web

>Tên : go-getter
>Description : There's a joke to be made here about Python eating the GOpher. I'll cook on it and get back to you.
>Có source code

## Phân tích
Target có 2 service viết bằng Go và Python.

Phân tích source code:
Go:
```Go
// Handler for executing actions
func executeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Invalid request method", http.StatusMethodNotAllowed)
		return
	}

	// Read JSON body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Failed to read request body", http.StatusBadRequest)
		return
	}

	// Parse JSON
	var requestData RequestData
	if err := json.Unmarshal(body, &requestData); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Process action
	switch requestData.Action {
	case "getgopher":
		resp, err := http.Post("http://python-service:8081/execute", "application/json", bytes.NewBuffer(body))
		if err != nil {
			log.Printf("Failed to reach Python API: %v", err)
			http.Error(w, "Failed to reach Python API", http.StatusInternalServerError)
			return
		}
		defer resp.Body.Close()

		// Forward response from Python API back to the client
		responseBody, _ := io.ReadAll(resp.Body)
		w.WriteHeader(resp.StatusCode)
		w.Write(responseBody)
	case "getflag":
		w.Write([]byte("Access denied: You are not an admin."))
	default:
		http.Error(w, "Invalid action", http.StatusBadRequest)
	}
}
```
Python:
```python
@app.route('/execute', methods=['POST'])
def execute():
    # Ensure request has JSON
    if not request.is_json:
        return jsonify({"error": "Invalid JSON"}), 400

    data = request.get_json()
    
    # Check if action key exists
    if 'action' not in data:
        return jsonify({"error": "Missing 'action' key"}), 400

    # Process action
    if data['action'] == "getgopher":
        # choose random gopher
        gopher = random.choice(GO_HAMSTER_IMAGES)
        return jsonify(gopher)
    elif data['action'] == "getflag":
        return jsonify({"flag": os.getenv("FLAG")})
    else:
        return jsonify({"error": "Invalid action"}), 400

```
Mục tiêu là để Go hiểu action là `getgopher` còn Python hiểu là `getflag`.
### Phân tích cách parse JSON của Go và Python
Go:
```go 
type RequestData struct {
  Action string `json:"action"`
}

json.Unmarshal(body, &requestData)
switch requestData.Action {
  case "getgopher":
    // Cho forward sang Python
  case "getflag":
    w.Write([]byte("Access denied"))
}
```
Cách Go parse JSON  : 

1.  Go `json.Unmarshal()` sẽ lấy giá trị cuối cùng khi gặp key trùng lặp.

2. Go `encoding/json` **không phân biệt chữ hoa/thường** khi match `JSON key` với `struct field tag`.

Python (Flask) :
```python
data = request.get_json()
if data['action'] == 'getflag':
    return {"flag": FLAG}
elif data['action'] == 'getgopher':
    # random gopher

```
Python parse JSON thành dictionary “y chang” key :
1. Python `json.loads()` / `request.get_json()` sẽ giữ hết các key đúng như trong JSON.

2. Khi code Python viết `data['action']`, nó chỉ quan tâm key `"action"` (nhỏ) nếu nó tồn tại.
## Exploit

Payload: 
```JSON
{
  "action": "getflag",
  "Action": "getgopher"
}
```

![](http://note.bksec.vn/pad/uploads/c9299169-c0bb-41fd-b059-50b6acd86dc8.png)


>Flag: squ1rrel{p4rs3r?_1_h4rd1y_kn0w_3r!}