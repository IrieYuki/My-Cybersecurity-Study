#!/usr/bin/env bash
# PHP2Shell 机制模拟 —— 一键跑完六个实验
# 用法: bash run.sh
set -u
cd "$(dirname "$0")"

echo "========== ① 旧版行为（OOM + longjmp 跳过清理）=========="
clang -Wall -O0 -g -o php2shell_sim php2shell_sim.c
./php2shell_sim buggy

echo
echo "========== ② 堆复用：攻击者的数据被当成合法 session =========="
./php2shell_sim reuse

echo
echo "========== ③ 补丁后：优雅失败 + 先 reset 再 free =========="
./php2shell_sim fixed

echo
echo "========== ④ ASan 指出真正的 bug 在哪一行 =========="
clang -fsanitize=address -g -O0 -o sim_asan php2shell_sim.c
./sim_asan buggy 2>&1 | head -14

echo
echo "========== ⑤ PHP: memory_limit 耗尽时正常路径被整段跳过 =========="
php -d memory_limit=64M oom.php || true

echo
echo "========== ⑥ PHP: 线上字节数 vs 内存字节数 =========="
php -d memory_limit=1G amp.php
