# 网络安全自学 · 国庆 7 天冲刺

目标：通过校网络安全学习协会招新。时间：2026-10-01 ～ 10-07。环境：macOS / Apple M5（arm64）。

**GitHub**：https://github.com/IrieYuki/My-Cybersecurity-Study （公开，改完就 push 并核实远端）

**学习大纲（先看这个）**：[`网络安全自学大纲-国庆7天.md`](网络安全自学大纲-国庆7天.md)
**环境搭建记录（含全部踩坑）**：[`notes/D0-环境搭建记录.md`](notes/D0-环境搭建记录.md)

---

## 进度表

| 阶段 | 日期 | 主题 | 产出 | 状态 |
|---|---|---|---|---|
| D0 | 9/29–9/30 | 环境搭建 | 工具链 + 5 靶场 + Kali VM | ✅ |
| D1 | 9/30 | 网络协议地基 | [D1 讲义](notes/D1-网络协议地基.md) | ✅ |
| D2 | 10/3 | Linux 命令 + 抓包分析 | [D2 讲义](notes/D2-Linux与抓包.md) + 从抓包里读出明文口令 | 🔄 进行中 |
| D3 | 10/4 | 信息收集（被动 + 主动） | 一页信息收集报告 | ☐ |
| D4 | 10/5 | Web 基础 + Burp + 弱口令 + **文件上传** | 上传绕过 ↔ 防御 对照表 | ☐ |
| D5 | 10/6 | XSS + SQLi + CSRF + RCE | 漏洞四件套卡片 | ☐ |
| D6 | 10/7 | 综合实战 + 招新材料 | 渗透报告 + 自我介绍稿 | ☐ |

> ⚠️ **排期调整（10/3 定）**：假期已过 2 天，原 Day4（Web 基础/Burp/弱口令）与 Day5（文件上传）**合并** ——
> Burp 本来就是在文件上传靶场里练最有效，分开学反而重复。其余不变，5 天覆盖原 6 天内容。
> 若某天实验想多花时间，优先牺牲最后的报告，**Day4（上传）和 Day5（注入/XSS）的靶场不能省**。

## 目录

```
├── 网络安全自学大纲-国庆7天.md   # 总纲：取舍、日程、验收标准
├── notes/                        # 每日笔记（每条命令附真实输出）
├── labs/                         # 靶场编排 + 环境脚本
│   ├── docker-compose.yml        # 5 个靶场一键起
│   ├── docker-daemon.json        # 国内镜像加速配置
│   └── setup-env.sh              # 环境搭建复现脚本
├── reports/                      # 信息收集报告、渗透测试报告（招新材料）
├── ctf/                          # CTF 刷题记录
├── captures/                     # 抓包样本（不入库）
└── iso/                          # Kali 安装镜像（不入库，3.7 GB）
```

## 常用命令

```bash
# —— 靶场 ——
cd ~/xx/网络安全/labs
docker compose ps            # 看状态
docker compose up -d         # 启动全部靶场
docker compose down          # 全部停止并删除
open http://127.0.0.1:8081   # DVWA（先 Create/Reset Database，安全级别选 low）
open http://127.0.0.1:8082   # upload-labs  8083 sqli-labs  8084 xss-labs  8085 pikachu

# —— 抓包（Wireshark 装了 ChmodBPF，普通用户即可抓，不用 sudo）——
dumpcap -i lo0 -a duration:10 -w captures/$(date +%m%d-%H%M).pcapng   # 抓本机容器流量用 lo0
dumpcap -D                   # 列出网卡
/Applications/Wireshark.app/Contents/MacOS/tshark -r captures/xxx.pcapng -Y "http.request"

# —— 容器/虚拟机 ——
colima status                # 容器引擎状态
colima stop / colima start   # 引擎开关
docker exec -it lab-dvwa bash
```

## 红线

只打**本地靶场**和 CTF 平台。不扫学校内网、不碰任何未授权目标、不用本机扫描公网网段。
