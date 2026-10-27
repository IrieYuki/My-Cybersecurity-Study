# 网络安全学习之路

> 从基础原理到实战进阶的系统学习记录。
> 环境：macOS / Apple Silicon ｜ 方法：原理 → 手工复现 → 脚本自动化 → 笔记沉淀

## 📍 当前位置

**第二阶段 · Web 安全进阶 — SQL 注入进阶（下一项：宽字节注入）**

---

## 学习路线总览

### 第一阶段：安全基础（已完成 ✅）

*目标：建立完整知识框架，能独立完成基础靶场渗透并输出渗透测试报告。*

**环境搭建**
- 攻击机工具链：nmap、sqlmap、gobuster、ffuf、nikto、hydra、netcat（Homebrew）
- Burp Suite（代理/爆破/重放）、Wireshark 抓包
- UTM + Kali Linux（ARM64）虚拟机
- Docker 靶场矩阵：DVWA、sqli-labs、upload-labs、XSS-labs、Pikachu

**网络协议**
- 信息安全 CIA 三要素、OSI / TCP-IP 分层模型
- IP 与端口、TCP 三次握手与四次挥手
- HTTP 请求/响应报文解剖、防火墙原理
- 入侵五阶段、病毒/蠕虫/木马区分
- 实验：curl 解剖 HTTP、nc 自发自收、ping 与 TTL

**Linux 与抓包分析**
- Linux 五类核心命令：文件目录 / 文本处理 / 权限用户 / 进程服务 / 网络包管理
- rwx 权限模型与 sudo 机制
- Wireshark：混杂模式、BPF 过滤器、ARP / ICMP / TCP / HTTP 协议分析
- 实验：抓取 DVWA 登录明文口令并重放，证明"抓包 = 拿到身份"

**信息收集**
- 被动收集：DNS、whois、子域名枚举、Google Hacking、Shodan、备案查询
- 主动收集：ping / arping / fping 主机发现
- Nmap 端口扫描（-sT / -sS / -sV）、服务版本指纹识别

**Burp 与文件上传**
- Burp Suite：Intercept 拦截改包、Repeater 重放、Intruder 爆破
- 弱口令爆破：DVWA Brute Force 模块（Burp + hydra 双路线）
- 文件上传漏洞：前端 JS 校验 / MIME 校验 / 黑名单绕过（upload-labs Pass-01~03）

**四大 Web 漏洞**
- XSS：原理与反射型 / 存储型 / DOM 型三类
- SQL 注入：手工完整流程（sqli-labs Less-1：判断注入点 → order by 探列数 → union 找显示位 → 脱库脱表）
- CSRF：跨站请求伪造原理与 DVWA 实战
- RCE：远程命令执行原理与利用

**综合实战**
- DVWA 完整渗透链：信息收集 → 弱口令 → RCE → 反弹 Shell
- 渗透测试报告撰写（目标 / 收集 / 发现 / 利用 / 修复建议）

### 第二阶段：Web 安全进阶（进行中 🔄）

*目标：从"会用 payload"到"理解原理、能独立挖掘"，每个漏洞配套 Python 自动化脚本。*

**SQL 注入进阶**
- [x] 布尔盲注 —— sqli-labs Less-8：真/假页面差异作信号，二分法自动化脱库
- [x] 时间盲注 —— sqli-labs Less-9：`IF` + `SLEEP` 以响应时间作信号
- [x] 报错盲注 —— sqli-labs Less-5：`updatexml` / `extractvalue` 让数据随报错带出
- [ ] 宽字节注入 —— GBK 编码吞掉转义符 `%5c` 的原理与利用
- [ ] 二次注入 —— 入库转义、出库未过滤的延迟触发
- [ ] 堆叠注入 —— 分号分隔多语句执行
- [ ] SQL 注入到 RCE —— `into outfile` 写 WebShell、日志文件写入

**XSS 进阶**
- [ ] 存储型 XSS 实战利用链
- [ ] WAF 绕过：大小写 / 编码 / 标签变异 / 伪协议

**SSRF / XXE / SSTI**
- [ ] SSRF —— 内网端口探测、`file` 协议读文件、`gopher` 打内网服务
- [ ] XXE —— 外部实体注入读文件、内网探测
- [ ] SSTI —— 服务端模板注入（Jinja2 / Twig）

**反序列化漏洞**
- [ ] PHP 反序列化：魔术方法、POP 调用链入门

**逻辑漏洞**
- [ ] 越权（水平 / 垂直）、支付金额篡改、条件竞争

**代码审计入门**
- [ ] PHP 代码审计：`eval` / `system` / `unserialize` 等危险函数追踪

### 第三阶段：内网渗透（计划中）

- 域环境搭建与域基础概念
- 域内信息收集与横向移动
- Windows / Linux 权限提升
- 权限维持与痕迹清理
- 免杀入门

### 第四阶段：二进制安全与实战输出（长期）

- C 语言与汇编基础
- 栈溢出与 Pwn 入门
- 逆向工具（Ghidra / IDA）入门
- CTF 持续参赛
- 合法众测与漏洞赏金

---

## 笔记

**基础阶段**
- [D0 环境搭建记录](notes/D0-环境搭建记录.md)
- [D1 网络协议地基](notes/D1-网络协议地基.md)
- [D2 Linux 与抓包](notes/D2-Linux与抓包.md)
- [D3 信息收集](notes/D3-信息收集.md)
- [D4 Burp 与文件上传](notes/D4-Burp与文件上传.md)
- [D5 四大 Web 漏洞](notes/D5-四大Web漏洞.md)
- [D6 综合实战](notes/D6-综合实战.md)

**进阶阶段**
- [P1-01 布尔盲注](notes/P1-01-布尔盲注.md)
- [P1-02 时间盲注](notes/P1-02-时间盲注.md)
- [P1-03 报错盲注](notes/P1-03-报错盲注.md)

**补充专题实验**
- [PHP2Shell 原理与模拟实验](notes/PHP2Shell原理与模拟实验.md)

**参考速查**
- [命令行写法与排错](notes/命令行写法与排错.md)

---

## 实验环境

```bash
cd ~/xx/CS/labs
docker compose ps            # 查看靶场状态
docker compose up -d         # 启动全部靶场
open http://127.0.0.1:8081   # DVWA
open http://127.0.0.1:8082   # upload-labs
open http://127.0.0.1:8083   # sqli-labs
open http://127.0.0.1:8084   # xss-labs
open http://127.0.0.1:8085   # pikachu
```

---

## 学习原则

仅在本地靶场、CTF 平台及合法授权范围内进行安全研究，不触碰任何未授权目标。
