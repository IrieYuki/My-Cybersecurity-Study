# PHP2Shell 原理：用自己的 C 实验看懂

> 目的：不看别人的 writeup，用 100 行 C 把两个 CVE 的机制自己跑出来。
> 实验目录：`labs/php2shell/`，一键运行 `bash run.sh`
> 漏洞事实来源：PHP 安全公告 GHSA-w8hw-w9fx-j79w / GHSA-6wmf-4rv5-p3rp（2026-10-21），Wiz Research、Calif、OpenAI Codex Security 联合披露。

## 目录

1. [你只需要先懂的 5 个 C 概念](#1-你只需要先懂的-5-个-c-概念)
2. [实验地图](#2-实验地图)
3. [实验①：longjmp 跳栈 = 618 的原理](#3-实验longjmp-跳栈--618-的原理)
4. [实验②：堆复用 = 619 的原理](#4-实验堆复用--619-的原理)
5. [实验③：补丁到底改了什么](#5-实验补丁到底改了什么)
6. [实验④：让机器告诉你这是 UAF](#6-实验让机器告诉你这是-uaf)
7. [实验⑤⑥：PHP 侧的旁证](#7-实验php-侧的旁证)
8. [C 概念 ↔ PHP 机制对照表](#8-c-概念--php-机制对照表)
9. [验收题](#9-验收题)

## 1. 你只需要先懂的 5 个 C 概念

| 概念 | 一句话 | 在本实验里的角色 |
|---|---|---|
| 指针 | 一个存**地址**的数字；`p->field` 是「地址 p 处的 field」 | `g_state` 就是指向请求内存的指针 |
| `malloc` / `free` | 向系统借一块内存 / 还回去。`free` 只归还，**不清零、不通知任何还攥着地址的人** | `free(g_request)` 之后 `g_state` 变成野指针 |
| 野指针（dangling pointer） | 还握着一个已经 `free` 掉的地址。读它=读到别人的数据或乱码 | 实验①的 `'\x06'`、实验②的 `ATTACKER-FORGED` |
| `setjmp` / `longjmp` | 在 A 点拍照（`setjmp`），之后在任何深处 `longjmp` 回 A 点。**中间那些函数的返回路径、清理代码全部被跳过** | PHP 处理 OOM 的老做法 |
| 常驻 worker | 一个进程连续处理几千个请求，进程内的全局变量不会因为「请求结束」而自动消失 | 两个请求为什么能互相污染 |

只要这五条成立，PHP2Shell 就不再神秘了。

## 2. 实验地图

| 实验 | 文件 | 对应内容 |
|---|---|---|
| ① | `php2shell_sim buggy` | CVE-2026-109618：OOM 用 longjmp 跳栈，跳过清理 |
| ② | `php2shell_sim reuse` | CVE-2026-109619：全局状态指向已释放的请求内存 → UAF |
| ③ | `php2shell_sim fixed` | 官方补丁思路：soft OOM + 先 reset 再 free |
| ④ | `sim_asan buggy` | AddressSanitizer 判定为 heap-use-after-free，并指出三行代码 |
| ⑤ | `oom.php` | PHP 真的会「跳过正常路径但执行 shutdown」 |
| ⑥ | `amp.php` | 一个请求的内存成本是线上字节的 3–5 倍 |

程序模拟的是一个**常驻 worker 连续处理 3 个请求**，三个请求里的第 1 个会「内存耗尽」。

## 3. 实验①：longjmp 跳栈 = 618 的原理

### 真实输出（`./php2shell_sim buggy`）

```text
--- 请求 1 ---
[req 1] consumer: 全局状态是干净的，没读到任何残留
[req 1] producer: g_state 指向本请求内存 'PHPSESSID=user1-SECRET'
  PHP Fatal error:  Allowed memory size exhausted (tried to allocate 200 bytes: multipart 头太多)
  -> longjmp(): 直接跳回顶层，中间所有代码(含清理)全部不执行
  shutdown: free(请求堆) —— 但没有 g_state = NULL
--- 请求 2 ---
[req 2] consumer: 初始化之前读到旧 g_state -> '\x06'
[req 2] producer: g_state 指向本请求内存 'PHPSESSID=user2-SECRET'
```

### 逐行解读

1. 请求 1 起来，把「本次请求内存里的 session 串」的地址存进全局 `g_state`（这就是 advisory 说的 **producer**：把请求级状态发布到跨请求可见的位置）。
2. 解析 multipart 时内存超了 `memory_limit`，`emalloc` 里的 `longjmp` 直接跳回顶层——**注意它的栈帧没有再返回**，所以 `request_start` 之后本该执行的清理、reset 一行都没跑。
3. 跳到顶层后执行 `request_shutdown_leaky()`：`free(请求堆)` 把整块内存还给了系统，**但 `g_state` 还是那个旧地址**。
4. 请求 2 在「正常初始化之前」就先跑了 `early_consumer`（对应 619 里的 INI 诊断、`session.upload_progress` 这些**早于请求初始化**的操作），于是读到了已释放内存。

**为什么打印出来是 `'\x06'` 而不是 `user1-SECRET`？**
因为 macOS 的 `free()` 会把这块内存的前 8/16 字节写成堆管理器的元数据（下一个空闲块的指针等），原来的字符串被覆盖了。**这恰好说明它读的是「别人的内存」，而不是自己的数据**——这是一个诚实的证据，不是实验没成功。

> 这一点很重要：真实的漏洞利用里，攻击者不知道会读到什么，所以会出现「跑几千次才中一次」（CVSS 里的 `AC:H`）。中一次的方式有两种：读到**别人**的密码/token（信息泄露，Heartbleed 式），或者读到**自己精心放置的数据**（下个实验）。

## 4. 实验②：堆复用 = 619 的原理

### 真实输出（`./php2shell_sim reuse`）

```text
  shutdown: free(请求堆) —— 但没有 g_state = NULL
  攻击者 malloc 拿到 0x1033f5bf0，刚释放的块在 0x1033f5bf0 —— 同一块，堆被复用
--- 请求 2 ---
[req 2] consumer: 初始化之前读到旧 g_state -> 'PHPSESSID=ATTACKER-FORGED'
```

### 逐行解读

`free` 之后有谁再 `malloc` 同样大小，分配器**极大概率把刚还回来的那块原样给你**（这里地址完全一致，实测输出为证）。攻击者只要让这一步落到受控数据上，`g_state` 这个「野指针」就指向了攻击者写的内容。

在真实的 PHP 里，这一步被利用的方式是：用 attaker 提供的字节**伪造 C 结构体**（`zval`、字符串 `zend_string`、跳转用的函数指针），PHP 随后把这个指针当合法对象用 → 程序流被劫持 → `system()`。

所以 619 的官方描述里那句话就通了：

> A strategically crafted heap layout can produce full remote code execution.

「strategically crafted heap layout」= 让攻击者数据的 `malloc` 正好落在 victim 指针还指着的那块内存上。不是玄学，就是你刚才看到的地址相等。

## 5. 实验③：补丁到底改了什么

### 真实输出（`./php2shell_sim fixed`）

```text
  PHP Fatal error:  Allowed memory size exhausted (tried to allocate 200 bytes: multipart 头太多)
  -> 补丁后(soft OOM): 优雅失败，走正常返回路径，清理照做
  shutdown: g_state = NULL，然后再 free(请求堆) -> 没有野指针
--- 请求 2 ---
[req 2] consumer: 全局状态是干净的，没读到任何残留
```

两处改动，对应官方公告的两句话：

| 改动 | 官方原文 | 效果 |
|---|---|---|
| 不再用 `longjmp` 处理 OOM，改成延迟的优雅 soft OOM | "The patch removes `longjmp()` for OOM" | 跳栈不再发生，栈上的清理代码能跑完 |
| 请求结束**先 reset 全局状态再释放请求内存** | "resets this wider state because it must not survive into operations that precede normal initialization" | 野指针不存在，第二个请求读不到任何东西 |

关键理解：**补丁不是去堵那三种 multipart 打法，而是去修「失败时的状态记账」这个通用模式**。所以它能同时覆盖 618 和 619 的多条路径。

## 6. 实验④：让机器告诉你这是 UAF

编译时加 `-fsanitize=address`，`buggy` 立刻被抓住：

```text
==93147==ERROR: AddressSanitizer: heap-use-after-free on address 0x6040000004d0
READ of size 2 at 0x6040000004d0 thread T0
    #2 in early_consumer php2shell_sim.c:70
freed by thread T0 here:
    #1 in request_shutdown_leaky php2shell_sim.c:78
previously allocated by thread T0 here:
    #1 in emalloc php2shell_sim.c:48
    #2 in request_start php2shell_sim.c:56
```

三段调用栈从下往上读，就是 619 的完整链路：

```
emalloc → request_start        （分配 + 发布 producer）
request_shutdown_leaky         （free，但没 reset）
early_consumer                 （在初始化之前读 → UAF）
```

这就是为什么漏洞报告里的「producer / consumer」两个词值得记：**谁发布、谁消费，中间断在哪一环，决定这条链能不能打通。**

## 7. 实验⑤⑥：PHP 侧的旁证

### ⑤ OOM 时正常路径整段被跳过（`php -d memory_limit=64M oom.php`）

```text
1) 开始分配 200MB（memory_limit 只有 64M）
PHP Fatal error:  Allowed memory size of 67108864 bytes exhausted (tried to allocate 209715232 bytes) in .../oom.php on line 11
[request_shutdown] 我还在执行 —— PHP 的请求收尾阶段仍然会跑
[退出码 255]
```

三个事实，全部实测：

1. `str_repeat` 后面的代码没执行；
2. **`finally` 块也没有执行**——`finally` 只保证「异常」情况，内存耗尽不是异常，是直接中止；
3. `register_shutdown_function` 注册的回调**照样执行**——这就是 PHP 的「request shutdown」阶段，也是 buggy 模型里那个「在非法状态上做收尾」的地方。

一句话：**PHP 里 `memory_limit` 触顶时，你的清理代码是靠不住的，只有 shutdown 里的代码会跑。**

### ⑥ 一个请求的真实内存成本（`php -d memory_limit=1G amp.php`）

```text
扁平 header x 20000        线上   440000 B  →  PHP 内存   2269984 B   放大  5.2 倍
扁平 POST 字段 x 20000   线上   480000 B  →  PHP 内存   2109984 B   放大  4.4 倍
嵌套 f[x][y] x 20000       线上   640000 B  →  PHP 内存   1950776 B   放大  3.0 倍
```

结论要按实测说，不要按传言说：

- **放大 3–5 倍是稳定的**，所以 `post_max_size=8M` 的请求可以轻松吃掉 25–40MB 的 `memory_limit`；把字段/头堆到几十万条，128M 就不够用了。
- **「嵌套字段名倍数更高」这个说法我没测出来**（3.0 倍，反而最低）。原因：PHP 的数组是哈希表，每条记录的固定开销占了主导，嵌套层数不是主要成本。真正的放大器是**条目数量本身**。
- 官方 advisory 说的也是「量」而不是「倍数」：头**数量**不受限、空文件控件不计入 `max_file_uploads` 但照旧建元数据、嵌套名让数组工作翻倍——**没有任何一条限制「总共能生成多少个数组条目」**。这才是 618 那三种打法的共同点。

## 8. C 概念 ↔ PHP 机制对照表

| C 实验里的东西 | 真实 PHP 里对应的东西 |
|---|---|
| `struct request` + `malloc` | 请求堆（request heap / Zend allocator arena），请求结束时整块释放 |
| `g_state` | worker 里跨请求存活的全局状态：错误状态、session 状态、对象状态、扩展状态 |
| `emalloc` 里的 `longjmp` | PHP 的 `zend_bailout`（OOM 的老处理方式） |
| `request_start()` 里的 `g_state = ...` | producer：某个操作把请求级状态发布到全局 |
| `early_consumer()` | consumer：`fatal_error_backtraces` 的诊断、`session.upload_progress`、INI 诊断等**早于请求初始化**的操作 |
| `request_shutdown_leaky()` | 有 bug 的请求收尾：释放了请求内存，却没重置全局状态 |
| 第 1 个请求 OOM、第 2 个请求读野指针 | 两个请求落在**同一个 worker** 上（这也是为什么要跑几千次：得撞上同一个 worker + 堆布局合适） |
| Apache mod_php 无条件调 shutdown | 我的模型里 `setjmp` 落点无条件调 `request_shutdown_leaky()`，就是照 mod_php 的行为写的 |

## 9. 验收题

1. 实验①里请求 2 读到的是 `'\x06'`，实验②里读到的是 `ATTACKER-FORGED`。这两次读的是**同一块**已释放内存，为什么内容不一样？哪个更接近「信息泄露」、哪个更接近「RCE」？
2. 如果我把 `g_state = NULL;` 从 `request_shutdown_clean()` 里删掉、只保留 soft OOM，实验③会退化成什么样？自己动手去掉这两行跑一次，把输出贴出来。
3. 为什么这漏洞在 PHP-FPM 上比 Apache mod_php 难打？用「mod_php 无条件调 shutdown / FPM 启动失败就杀掉 child」这句话解释。
4. 你自己那台机器上 PHP 是 8.5.11，brew 里已经有 8.5.12。除了 `brew upgrade php`，还要做哪一件事才算真的「修好了」？（提示：worker 里跑的是已经加载进内存的旧代码）
