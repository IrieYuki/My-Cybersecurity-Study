<?php
// amp.php —— 量化「线上的字节数」和「PHP 内存里的字节数」差多少倍
// 这就是 CVE-2026-109618 里「一个 post_max_size 之内的请求把 memory_limit 撑爆」的根据
// 运行: php -d memory_limit=1G amp.php

const N = 20000;   // 字段数 / 头数

function measure(string $label, callable $build, int $wireBytes): void
{
    $before = memory_get_usage();
    $data   = $build();
    $mem    = memory_get_usage() - $before;
    printf("%-28s 线上 %8d B  →  PHP 内存 %9d B   放大 %4.1f 倍\n",
           $label, $wireBytes, $mem, $mem / $wireBytes);
    unset($data);
}

// ① 扁平 http 头：每条线上约 22 字节
measure('扁平 header x ' . N,
    fn() => array_combine(
        array_map(fn($i) => "x-pad-header-$i", range(1, N)),
        array_fill(1, N, 'v')
    ),
    N * 22);

// ② 扁平 POST 字段：每条线上约 24 字节
measure('扁平 POST 字段 x ' . N,
    fn() => array_combine(
        array_map(fn($i) => "field$i", range(1, N)),
        array_fill(1, N, 'v')
    ),
    N * 24);

// ③ 嵌套字段名 f1[x][y]：每个字段自己一条三级链，PHP 要为每层建数组
function nested(int $n): array
{
    $root = [];
    for ($i = 0; $i < $n; $i++) {
        $root["f$i"] = ['x' => ['y' => 'v']];
    }
    return $root;
}
measure('嵌套 f[x][y] x ' . N, fn() => nested(N), N * 32);

echo "\n峰值内存: " . round(memory_get_peak_usage() / 1048576, 1) . " MB\n";
