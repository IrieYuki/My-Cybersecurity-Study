/*
 * php2shell_sim.c —— 用一段 C 演示 PHP2Shell 的两个机制（只是模拟，不是 exploit）
 *
 *   CVE-2026-109618  OOM 时用 longjmp 跳栈，跳过状态清理
 *   CVE-2026-109619  worker 常驻，全局状态指向已释放的请求内存 → use-after-free
 *
 * 全程没有 HTTP、没有堆布局利用、不执行任何命令，只为了看清「机制」。
 *
 * 编译:  clang -Wall -O0 -g -o php2shell_sim php2shell_sim.c
 * 运行:  ./php2shell_sim buggy    # 有 bug 的旧版行为
 *        ./php2shell_sim reuse    # buggy + 用攻击者数据占住刚释放的内存
 *        ./php2shell_sim fixed    # 补丁后：优雅失败 + 先 reset 再 free
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>

#define SESSION_LEN 48

/* 一个请求的整块内存。请求结束时整块被 free —— 这正是「请求堆」 */
struct request {
    char session_id[SESSION_LEN];
};

static jmp_buf bailout;          /* 相当于 PHP 的 zend_bailout 跳板          */
static char   *g_state = NULL;   /* worker 里跨请求存活的全局状态(error/session) */
static struct request *g_request = NULL;
static size_t  g_used  = 0;      /* 本请求已用内存                            */
static size_t  g_limit = 120;    /* 相当于 php.ini 的 memory_limit             */
static int     g_buggy = 1;
static int     g_reuse = 0;

/* ---------------------------------------------------------------- 内存分配 */
static void *emalloc(size_t n, const char *what)
{
    if (g_used + n > g_limit) {
        printf("  PHP Fatal error:  Allowed memory size exhausted "
               "(tried to allocate %zu bytes: %s)\n", n, what);
        if (g_buggy) {
            printf("  -> longjmp(): 直接跳回顶层，中间所有代码(含清理)全部不执行\n");
            longjmp(bailout, 1);
        }
        printf("  -> 补丁后(soft OOM): 优雅失败，走正常返回路径，清理照做\n");
        return NULL;
    }
    g_used += n;
    void *p = malloc(n);
    if (p == NULL) { perror("malloc"); exit(1); }
    return p;
}

/* ------------------------------------------------------------ 请求生命周期 */
static void request_start(int id)
{
    g_request = emalloc(sizeof *g_request, "request heap");
    snprintf(g_request->session_id, SESSION_LEN, "PHPSESSID=user%d-SECRET", id);
    /* producer：把「请求内存里的一块」发布到跨请求存活的全局状态 */
    g_state = g_request->session_id;
    printf("[req %d] producer: g_state 指向本请求内存 '%s'\n", id, g_state);
}

/* 正常初始化之前就跑的操作（相当于 619 里的 consumer：INI 诊断 / upload progress） */
static void early_consumer(int id)
{
    if (g_state == NULL) {
        printf("[req %d] consumer: 全局状态是干净的，没读到任何残留\n", id);
        return;
    }
    printf("[req %d] consumer: 初始化之前读到旧 g_state -> '%s'\n", id, g_state);
}

/* 有 bug 的 request shutdown：只 free 请求堆，忘了把 g_state 置 NULL */
static void request_shutdown_leaky(void)
{
    struct request *freed_at = g_request;
    printf("  shutdown: free(请求堆) —— 但没有 g_state = NULL\n");
    free(g_request);
    g_request = NULL;

    if (g_reuse) {
        /* 堆复用：攻击者让下一次分配落到刚释放的那块内存上 */
        struct request *attacker = malloc(sizeof *attacker);
        snprintf(attacker->session_id, SESSION_LEN, "PHPSESSID=ATTACKER-FORGED");
        printf("  攻击者 malloc 拿到 %p，刚释放的块在 %p —— %s\n",
               (void *)attacker, (void *)freed_at,
               (void *)attacker == (void *)freed_at ? "同一块，堆被复用" : "不是同一块(本次运气不好)");
        /* 故意不 free attacker：模拟释放后仍有人握着引用 */
    }
}

/* 补丁后的 shutdown：先 reset 全局状态，再 free 请求堆 */
static void request_shutdown_clean(void)
{
    printf("  shutdown: g_state = NULL，然后再 free(请求堆) -> 没有野指针\n");
    g_state = NULL;
    free(g_request);
    g_request = NULL;
}

static void handle_request(int id)
{
    printf("--- 请求 %d ---\n", id);
    g_used = 0;                   /* 每个请求有自己的内存预算 */
    early_consumer(id);           /* 这一步在「正常初始化」之前 */

    if (setjmp(bailout) != 0) {
        /* longjmp 落点 = PHP 的 request_shutdown。
           Apache mod_php 即使请求启动失败也会执行这里；FPM 则直接杀掉 child */
        request_shutdown_leaky();
        return;
    }

    request_start(id);
    size_t body = (id == 1) ? 200 : 20;   /* 只有请求 1 的 multipart 特别大 */
    if (emalloc(body, (id == 1) ? "multipart 头太多" : "普通请求体") == NULL) {
        request_shutdown_clean();          /* 补丁后：优雅失败也要先 reset */
        return;
    }
    request_shutdown_clean();
}

int main(int argc, char **argv)
{
    const char *mode = (argc > 1) ? argv[1] : "buggy";
    g_buggy = (strcmp(mode, "fixed") != 0);
    g_reuse = (strcmp(mode, "reuse") == 0);

    printf("=== 模式: %s（一个常驻进程连续处理 3 个请求）===\n\n", mode);
    for (int id = 1; id <= 3; id++)
        handle_request(id);
    printf("\n=== 结束 ===\n");
    return 0;
}
