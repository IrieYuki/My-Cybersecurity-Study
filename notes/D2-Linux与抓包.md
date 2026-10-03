# D2 Linux 核心操作与抓包分析（导师讲义）

> 日期：2026-10-03 ｜ 对应大纲 Day 2 ｜ 主线：Linux 命令 → 抓包原理 → 抓出明文口令
> 今天的产出：**一条能从抓包文件里直接读出登录口令的命令 + 一次"重放"验证**（都在第六节）
> ⚠️ 今天开始你的 Kali 和 Mac 都能用来做实验；抓包文件我们在 `.gitignore` 里排除了（里面有明文凭据，永不入库）

## 目录

1. [一 Linux 命令：按用途分成五类记](#一-linux-命令按用途分成五类记)
2. [二 权限：rwx 与 sudo](#二-权限rwx-与-sudo)
3. [三 抓包原理：网卡 混杂模式 BPF](#三-抓包原理网卡-混杂模式-bpf)
4. [四 三件套与过滤器速查](#四-三件套与过滤器速查)
5. [五 协议分析实战](#五-协议分析实战)
6. [六 实验：抓出 DVWA 的明文口令并重放](#六-实验抓出-dvwa-的明文口令并重放)
7. [七 中间人攻击为什么能成立](#七-中间人攻击为什么能成立)
8. [八 高频面试问答](#八-高频面试问答)

---

## 一 Linux 命令：按用途分成五类记

不要背"50 个命令"，要背**分类**。每类记住 3–5 个就够用，剩下的现查。

### 1. 文件与目录

| 命令 | 作用 | 靶场/渗透场景 |
|---|---|---|
| `pwd` / `cd` | 我在哪 / 切目录 | 基本 |
| `ls -la` | 列出（含隐藏文件+详细属性） | 藏文件、看权限 |
| `tree` | 树状展示 | 看网站目录结构 |
| `cp` / `mv` / `rm -rf` | 复制/移动/删除 | 部署 payload |
| `find / -name "*.conf" 2>/dev/null` | 全盘找文件 | **找配置文件里的密码** |
| `file x` | 判断文件类型 | 识别 webshell/二进制 |
| `stat x` | 详细时间戳 | 溯源 |

### 2. 文本处理（渗透最常用）

| 命令 | 作用 |
|---|---|
| `cat` / `less` / `head -20` / `tail -f` | 看内容 / 分页 / 前 N 行 / 实时追日志 |
| `grep -rn "password" .` | 递归搜索关键词（**挖源码第一招**） |
| `cut -d: -f1` / `awk -F: '{print $1}'` | 按分隔符取列（处理 `/etc/passwd` 那种） |
| `sort` / `uniq -c` / `wc -l` | 排序 / 去重计数 / 数行数 |
| `sed` / `tr` | 批量替换 / 字符转换 |
| `diff` | 对比两个文件差异 |

> **管道 `|` 是 Linux 的灵魂**：`命令A | 命令B` 把 A 的输出当 B 的输入。今天的实验就是 `tshark … | xxd -r -p`。
> 其他管子：`>` 覆盖写入 / `>>` 追加 / `2>&1` 把错误也并进输出 / `&&` 前一条成功才执行后一条 / `;` 顺序执行 / `$(命令)` 把命令结果嵌进来。

### 3. 权限与用户

`chmod` / `chown` / `chgrp` / `id` / `whoami` / `groups` / `sudo` / `su` / `passwd` / `umask` / `visudo`

### 4. 进程与服务

| 命令 | 作用 |
|---|---|
| `ps aux` / `ps -ef` | 列出所有进程 |
| `top` / `htop` | 实时看资源 |
| `kill -9 PID` / `pkill 名字` | 杀进程 |
| `&` / `nohup cmd &` | 后台跑 / 挂断也不停 |
| `systemctl status/start/stop/enable 服务` | 服务管理（**`enable` = 开机自启**） |
| `journalctl -u 服务 -n 50` | 看服务日志 |

### 5. 网络与包管理

| 命令 | 作用 | Mac 上的差异 |
|---|---|---|
| `ip a` / `ip r` | 看网卡 / 看路由 | Mac 用 `ifconfig` / `netstat -rn` |
| `ss -tulnp` | 看本机监听的端口和进程 | Mac 用 `lsof -iTCP -sTCP:LISTEN` |
| `ping` / `curl` / `wget` | 连通性 / 发请求 / 下载 | 一样 |
| `dig` / `nslookup` / `whois` | DNS 与域名信息（**Day 3 主力**） | 一样 |
| `nc` / `ssh` / `scp` | 瑞士军刀 / 远程登录 / 传文件 | 一样 |
| `tcpdump` / `tshark` | 抓包（今天重点） | tcpdump 需 sudo，tshark 已配好免 sudo |
| `apt update` / `apt install` / `dpkg -l` / `dpkg -L 包` | 装包 / 列已装 / 列包内文件 | Mac 用 `brew` |

### 附：Windows 核心命令对照（课时 17 的内容，面试也会问）

| Windows | Linux | 说明 |
|---|---|---|
| `ipconfig /all` | `ip a` | 网络配置 |
| `netstat -ano` | `ss -tulnp` | 端口与进程（Ano 记法：**a**ll/**n**umeric/**o**wner） |
| `tasklist` / `taskkill /PID x /F` | `ps aux` / `kill -9` | 进程 |
| `type x.txt` / `dir` | `cat` / `ls` | 看文件 / 列表 |
| `findstr "密码" *.txt` | `grep` | 搜索文本 |
| `whoami` / `net user` / `net localgroup administrators` | `id` / `groups` | 身份与用户组 |
| `systeminfo` | `uname -a` `cat /etc/os-release` | 系统版本 |
| `sc query` / `reg query` | `systemctl` / 看配置文件 | 服务/注册表 |

---

## 二 权限：rwx 与 sudo

**看懂 `ls -l` 这一行**：

```
-rwxr-xr-x  1 kali kali  1234 Oct 3 14:00  script.sh
│└┬┘└┬┘└┬┘  │  │    │
│ │  │  │   │  │    └── 文件大小、时间
│ │  │  │   │  └─────── 属组
│ │  │  │   └────────── 属主
│ │  │  └────────────── 其他人（other）的权限
│ │  └───────────────── 属组成员（group）的权限
│ └──────────────────── 属主（owner）的权限
└────────────────────── 文件类型：- 普通文件 / d 目录 / l 链接
```

- **r=4、w=2、x=1** → `rwx` = 7、`rw-` = 6、`r-x` = 5、`---` = 0 ⇒ `chmod 755`、`chmod +x`
- **目录上的 r 和 x 含义不同**：`r` 是"能否列出文件名"，`x` 是"能否进入/穿过这个目录"（这是很多"明明有权限却进不去"的原因）
- **三个特殊权限位**（了解即可）：**SUID**（`-rwsr-xr-x`，以**文件所有者**身份执行 —— 提权最经典的跳板）、SGID、Sticky Bit（`/tmp` 那个 `t`）

**为什么渗透里重要**：你通过 Web 漏洞拿到的 shell，身份通常是 `www-data` 这种**低权限**用户：能读网站目录，但读不了 `/etc/shadow`、装不了服务。想进一步就得分"提权"（Day 7 之后的内容）。所以"当前身份是谁"（`id` / `whoami`）是拿到 shell 后的第一个动作。

---

## 三 抓包原理：网卡 混杂模式 BPF

**数据包到达网卡后，谁会看到它？**

1. 网卡默认只把"**发给我的**"和"广播的"帧交给操作系统，其他帧在硬件/驱动层就被丢掉
2. **混杂模式（promiscuous mode）**：让网卡把经过它的**所有**帧都交给系统 —— 这是嗅探的物理前提
3. 但**交换机**只把帧转发到目标端口。所以：**你在自己电脑上开混杂模式，通常看不到别人的流量** —— 除非
   - 你在**同一个广播域**且做了 **ARP 欺骗 / MAC 泛洪**（让流量绕道经过你）
   - 或者流量本来就经过你（你是网关、代理、路由器，或所在网络用的是集线器）

**那为什么今天的实验能抓到？** 因为目标就在**本机**：浏览器访问 `127.0.0.1:8081`，Docker 把容器端口映射到 Mac 的 8081，数据包走的是**回环接口 `lo0`**。回环上的流量全部属于本机，所以直接就能看到 —— 这也解释了为什么过滤器里要写 `-i lo0`（Day 1 抓包同理）。

**BPF（Berkeley Packet Filter）**：抓包的过滤机制。"捕获过滤器"（dumpcap 的 `-f`、tcpdump 的表达式）在**内核层**就把不要的包丢掉，省内存省磁盘；Wireshark 的"显示过滤器"是**抓完再筛**。两者语法不同，别混用。

---

## 四 三件套与过滤器速查

| 工具 | 定位 | 什么时候用 |
|---|---|---|
| `dumpcap` | 只负责抓，权限要求最低 | 长时间抓包（最安全，不给它分析功能） |
| `tshark` | 命令行分析 | SSH 远程环境、脚本、**一条命令直接出答案** |
| `Wireshark` | 图形界面 | 看懂协议细节、Follow Stream、肉眼比对 |

> macOS 上我已经把 `tshark` / `dumpcap` 等软链到 `/opt/homebrew/bin`，直接能用，**不需要 sudo**（因为装了 ChmodBPF）。

**命令行常用**：

```bash
dumpcap -D                                       # 列出所有网卡（lo0 / en0 / bridge100…）
dumpcap -i lo0 -f "tcp port 8081" -w out.pcapng  # 抓：接口 + 捕获过滤器 + 存文件（Ctrl+C 停）
tshark -r out.pcapng                             # 读文件、逐包打印
tshark -r out.pcapng -Y 'http.request' -T fields -e ip.src -e http.host -e http.request.uri
capinfos out.pcapng                              # 看这个抓包文件的基本信息（包数、时长）
```

**Wireshark 显示过滤器速查（今天要背下来的部分）**：

| 过滤器 | 含义 |
|---|---|
| `http` / `http.request` / `http.response` | 只看 HTTP 请求/响应 |
| `http.request.method == "POST"` | 只看 POST（**登录、上传都在这里**） |
| `ip.addr == 192.168.64.2` | 与某 IP 通信的包（src/dst 都算） |
| `ip.src == 127.0.0.1 && tcp.port == 8081` | 组合条件（`&&` 与、`\|\|` 或、`!` 非） |
| `tcp.flags.syn == 1` | 只看握手包 |
| `tcp.flags.reset == 1` | 看 RST（连接被拒/被打断） |
| `tcp.stream eq 0` | 只看第 0 条 TCP 流（配合右键 → Follow → TCP Stream） |
| `icmp` / `arp` / `dns` | 按协议过滤 |
| `http contains "password"` | 内容里含某关键词 |
| 右键 → **Follow → HTTP/TCP Stream** | **把一次完整对话拼出来看**（新手最该用的功能） |

---

## 五 协议分析实战

### 5.1 ARP：把 IP 翻译成 MAC

- 作用：同一局域网内，知道对方 IP 但不知道 MAC，就发**广播**问"谁是 192.168.64.1？" → 对方**单播**回答自己的 MAC
- 缓存：`arp -a`（Windows/Linux/Mac 都有）
- **为什么能被骗**：ARP **无状态、不认证** —— 谁都可能抢先回答"我是网关"。攻击者只要持续发送伪造应答，就能把流量引到自己这里（**ARP 欺骗**，第七节展开）
- 在 Wireshark 里：`arp`，看 `Who has …? Tell …`（请求）与 `<ip> is at <mac>`（应答）

### 5.2 ICMP：ping 和 traceroute 的真身

- ping = ICMP `echo request` / `echo reply`
- Day 1 看到的 TTL 就在 **IP 头**里；traceroute 靠"逐级递增 TTL + 读路由器回的 ICMP 超时报文"工作
- 过滤器：`icmp`，展开 IP 头找 `Time to live`

### 5.3 TCP 三次握手在 Wireshark 里长什么样

过滤 `tcp.flags.syn == 1`，你会看到（今天的真实抓包）：

```
tcp.stream  ip.src        tcp.dstport  tcp.flags.str
0           127.0.0.1     8081         ··········S·        ← 客户端 SYN（S）
0           127.0.0.1     52743        ········A··S·        ← 服务端 SYN+ACK（A 表示 ACK 位、S 表示 SYN 位）
```

- 前两行就是**握手的前两步**；第三步（客户端 ACK）过滤 `syn==1` 看不到，改用 `tcp.stream eq 0` 看全流
- 在 Wireshark 里点开任一包 → 展开 **TCP** 层，能看到 `Flags`、**相对序号（Sequence/Acknowledgment number）**、`Window size` 等 —— 这就是 Day 1 讲的 seq/ack 机制的实物
- 顺带看 `Window size`（流量控制）和 `MSS/Options`（协商参数）

### 5.4 HTTP 为什么能被看光

HTTP/1.1 是**纯文本协议**：请求行、头、正文全是人能直接读的字符。所以只要流量经过你，`Hello` 内容和口令就都在明面上。
（HTTPS 就是把 HTTP 装进 TLS 加密隧道里 —— 抓包只能看到"访问了哪个域名（SNI/证书）"，看不到内容。这是第七节的伏笔。）

---

## 六 实验：抓出 DVWA 的明文口令并重放

> 前提：DVWA 的数据库已经初始化（我替你跑了 `setup.php` 的等效操作 —— 之前登录失败就是因为**数据库还没建表**）。
> 现在可用账号：`admin / password`（浏览器登录会自动带上 CSRF token，不用你管）

### 实验 1 抓一次登录

**终端 1**（保持运行，抓包）：

```bash
dumpcap -i lo0 -f "tcp port 8081" -w ~/xx/CS/captures/dvwa-login.pcapng
```

然后**去浏览器**打开 http://127.0.0.1:8081 ，用 `admin` / `password` 登录。登录成功后回到**终端 1 按 `Ctrl+C`** 停止抓包。

### 实验 2 一条命令读出请求体（今天的主角）

**终端 2**：

```bash
# ① 先确认抓到了 POST
tshark -r ~/xx/CS/captures/dvwa-login.pcapng -Y 'http.request.method=="POST"' -T fields -e http.host -e http.request.uri

# ② 直接取正文 —— 你会看到一长串十六进制（不是明文！）
tshark -r ~/xx/CS/captures/dvwa-login.pcapng -Y 'http.request.method=="POST"' -T fields -e http.file_data

# ③ 转回明文：管道接 xxd
tshark -r ~/xx/CS/captures/dvwa-login.pcapng -Y 'http.request.method=="POST"' -T fields -e http.file_data | xxd -r -p

# ④ 顺便把 Cookie 一起看（会话身份就在这）
tshark -r ~/xx/CS/captures/dvwa-login.pcapng -Y 'http.request.method=="POST"' -T fields -e http.cookie
```

**我的实测输出（照抄当时的真实结果）**：

```
① 127.0.0.1:8081    /login.php
② 757365726e616d653d61646d696e2670617373776f72643d70617373776f7264264c6f67696e3d4c6f67696e…
③ username=admin&password=password&Login=Login&user_token=…
④ PHPSESSID=mfdpfr71o02sk0ojp8nger51e1; security=low
```

**要点**：
- `http.file_data` 输出的是**十六进制**，所以要 `| xxd -r -p` 还原（`p` = plain dump）。这一步卡住过很多人。
- **口令是明文**：因为 HTTP 不加密，且 DVWA 只在**服务端**做 md5（客户端发的是原始密码）
- 图形界面里等价操作：点那个 POST 包 → 右键 → **Follow → HTTP Stream**，能直接看到完整对话

### 实验 3 重放：证明"抓包 = 拿到身份"

抓到 Cookie 就等于拿到登录态。用命令行模拟一次完整登录（DVWA 登录页有 CSRF token，所以要两步）：

> ⚠️ **常见坑**：如果你直接 `curl -d "username=admin&password=password&Login=Login"`（不带 `user_token`）会得到 `302 → Location: login.php`（跳回登录页），**这不是密码错，是缺 CSRF token**。DVWA 的 `login.php` 里 `checkToken()` 是无条件执行的——浏览器登录时自动带上了隐藏字段 `user_token`，所以浏览器能登、裸 curl 不能。**所以必须两步**：先 GET 登录页拿到 token 和 PHPSESSID，再带着 token POST。

```bash
rm -f /tmp/dvwa.txt
TOK=$(curl -s -c /tmp/dvwa.txt http://127.0.0.1:8081/login.php | grep -oE "user_token' value='[a-f0-9]+'" | head -1 | cut -d"'" -f3)

curl -s -i -b /tmp/dvwa.txt -c /tmp/dvwa.txt -b "security=low" \
  -d "username=admin&password=password&Login=Login&user_token=$TOK" \
  http://127.0.0.1:8081/login.php | head -5

curl -s -b /tmp/dvwa.txt -b "security=low" http://127.0.0.1:8081/index.php | grep -o "You have logged in as '[a-z0-9]*'"
```

**我的实测输出**：

```
HTTP/1.1 302 Found
Location: index.php
You have logged in as 'admin'
```

**这一步的意义**：你没有打开浏览器，只用几条命令行就完成了登录 —— 说明"登录"这件事的本质就是"发一个带凭据的 HTTP 请求"。攻击者拿到抓包里的凭据/Cookie 后，做的就是这件事（**重放攻击**）。

### 附赠发现：数据库里的口令长什么样

顺手看一眼 DVWA 的 users 表：

```bash
docker exec lab-dvwa mysql -uroot -pp@ssw0rd -e "select user,password from dvwa.users;"
```

```
admin     5f4dcc3b5aa765d61d8327deb882cf99
gordonb   e99a18c428cb38d5f260853678922e03
1337      8d3533d75ae2c3966d7e0d4fcc69216b
```

**验证一下它们是什么**（你自己跑）：

```bash
printf '%s' "password" | md5      # → 5f4dcc3b5aa765d61d8327deb882cf99  ← admin 的
printf '%s' "abc123"   | md5
printf '%s' "charley"  | md5
```

**结论**：口令在数据库里是 **MD5 哈希**（无盐）。这意味着：一旦你通过 SQL 注入拿到这张表，就能**离线**用 hashcat/john 把明文算出来 —— 这就是 Day 4–6 里"注入拿哈希 → 破解 → 登录后台"的完整链条。今天先记住这个伏笔。

---

## 七 中间人攻击为什么能成立

**MITM（中间人）的三个条件**：

1. **你在通信路径上** —— 同一广播域（配 ARP 欺骗）、或控制了网关/路由器/Wi-Fi 热点/代理
2. **受害者无法发现你** —— ARP 无认证，或伪造证书被信任
3. **数据本身没被保护** —— 明文协议（HTTP/FTP/Telnet）直接可读；加密协议则需要额外手段

**攻击者能做到什么**：

| 层次 | 能力 | 例子 |
|---|---|---|
| 被动 | 只看不改 | 抓明文口令、Cookie、邮箱内容 |
| 主动 | 改包/注入/重放 | 把网页里的下载链接改成木马、篡改响应内容、重放凭据 |

**防御手段**（也是面试常问）：
- **HTTPS**（传输加密 + 证书校验）—— 这是最有效的一层，能防"看"和"改"
- 但要注意：**HTTPS 防不住"证书被信任的中间人"**（企业内网装的根证书、钓鱼自签证书），也**不隐藏你访问了哪个域名**（SNI/证书明文）
- ARP 层面：**动态 ARP 检测（DAI）**、静态 ARP 绑定、交换机端口安全
- 应用层面：**HSTS 强制 HTTPS**、**Cookie 加 `Secure`/`HttpOnly`**、短会话 + 二次验证

**和今天实验的关系**：我们没做 ARP 欺骗（那是主动攻击，且需要授权环境），但因为流量本来就流过本机，效果等价 —— 你今天就亲眼看到了"明文协议在中间人面前等于裸奔"。

---

## 八 高频面试问答

**Q：混杂模式是什么？开了就能看到别人的流量吗？**
混杂模式让网卡把经过的**所有**帧都交给系统，而不是只收发给自己的。但现代网络用交换机，帧只发到目标端口，所以**开了也不一定看得到别人的流量** —— 还需要 ARP 欺骗/MAC 泛洪，或位于流量必经路径（网关、代理、集线器）。

**Q：抓包能解密 HTTPS 吗？**
不能直接解。TLS 保证机密性，抓包只能看到 SNI/证书/流量大小和时间特征。要看内容只能：① 中间人 + 让客户端信任你的证书；② 有服务器的私钥（如 `SSLKEYLOGFILE` 或 RSA 密钥）配置 Wireshark 解密。

**Q：BPF 捕获过滤器和 Wireshark 显示过滤器有什么区别？**
捕获过滤器在**内核层丢弃**不要的包（省资源，语法如 `tcp port 8081`）；显示过滤器是**抓完再筛**（语法如 `tcp.port == 8081`）。语法不能混用。

**Q：怎么判断端口是"关闭"还是"被防火墙挡了"？**
关闭：目标会回 **RST**（Wireshark 里 `tcp.flags.reset == 1`）；被防火墙丢弃：**没有任何回应、客户端超时**（nmap 里就是 `filtered`）。

**Q：抓到一次 HTTP 登录，能拿到什么？**
请求行（方法/路径）、Host、User-Agent、**Cookie（会话身份）**、**请求体里的用户名口令**、响应里的 Set-Cookie 和页面内容。**只要凭据/会话还能用，就能重放登录**。

**Q：Linux 怎么查端口占用？**
`ss -tulnp`（-t TCP、-u UDP、-l 监听、-n 数字、-p 显示进程）；Mac 上是 `lsof -iTCP -sTCP:LISTEN`。

**Q：拿到 Web shell 后第一步做什么？**
确认身份与权限（`id`、`whoami`）、看系统信息（`uname -a`、`/etc/os-release`）、看能不能出网、再考虑提权/横移 —— 也就是回到"信息收集"。

**Q：ARP 欺骗为什么能成功？怎么防？**
ARP 无状态、无认证，主机收到"某 IP 对应的 MAC"就更新缓存、不校验。防御：DAI、静态 ARP 绑定、端口安全、以及把敏感流量放进 HTTPS。

---

## 今日结论（一句话）

**网络世界里"没人拦着"是默认状态**：明文协议在中间人面前等于裸奔，一条 `tshark … | xxd -r -p` 就能从流量里读出登录口令。所以后面所有攻击的起点，都是"先把自己放到流量经过的位置，再决定看还是改"。

---

## 验收（三道题，10/3 实测通关）

**题 1 抓包原理**：`-i lo0` 抓本机回环流量（DVWA 在本机），`en0` 是物理 Wi-Fi。✅ 抓不到室友流量——但**主因不是"Wi-Fi 加密"，而是 AP/交换机按 MAC 投递**：你的网卡收不到发给别人的单播帧（开放 Wi-Fi 也一样）。要抓得靠 **ARP 欺骗**（Day 3）。

**题 2 CSRF token**：先 GET 拿 token + 会话，再带 token POST，服务器才认；裸 POST 缺 token 被拒。✅ 精度纠一个：DVWA 的 `session_token` 是**每会话生成一次**（非一次性）；登录页**无条件校验**，其它页面（XSS/SQLi 表单）才按安全等级开关。

**题 3 会话/重放**：服务器靠 Cookie 里的 `PHPSESSID` 找服务器端 Session 存储（`logged_in=true` + `username=admin`）。✅ "Cookie 是钥匙串，身份信息在服务器手里"——点透 Session 本质。

**遗留待讲（Day 3）**：ARP 欺骗 / 中间人原理——为什么"按 MAC 投递"能被骗过去。

