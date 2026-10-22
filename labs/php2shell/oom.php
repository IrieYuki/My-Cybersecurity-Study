<?php
// oom.php —— 证明 memory_limit 耗尽时「正常路径」被整段跳过，但 shutdown 仍会执行
// 运行: php -d memory_limit=64M oom.php

register_shutdown_function(function () {
    echo "[request_shutdown] 我还在执行 —— PHP 的请求收尾阶段仍然会跑\n";
});

try {
    echo "1) 开始分配 200MB（memory_limit 只有 64M）\n";
    $a = str_repeat('x', 200 * 1024 * 1024);
    echo "2) 这行永远不会打印\n";
} finally {
    echo "[finally] 我执行了吗？\n";
}

echo "[正常路径] 清理代码：这行永远不会打印\n";
