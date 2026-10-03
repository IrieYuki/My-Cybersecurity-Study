#!/usr/bin/env bash
# Day2 实验2+3：抓包提取明文口令 + 登录重放
# 用法：bash scripts/dvwa-demo.sh
set -u
cd "$(dirname "$0")/.."
CAP=captures/dvwa-login.pcapng
BASE=http://127.0.0.1:8081

echo "======== 实验2：从抓包文件提取信息 ========"
echo "--- ① POST 的目标（host + 路径）---"
tshark -r "$CAP" -Y 'http.request.method=="POST"' -T fields -e http.host -e http.request.uri
echo
echo "--- ② POST 正文原始字节（十六进制）---"
tshark -r "$CAP" -Y 'http.request.method=="POST"' -T fields -e http.file_data
echo
echo "--- ③ 转明文：被抓走的密码 ---"
tshark -r "$CAP" -Y 'http.request.method=="POST"' -T fields -e http.file_data | xxd -r -p
echo
echo "--- ④ 会话 Cookie（登录态就在这）---"
tshark -r "$CAP" -Y 'http.request.method=="POST"' -T fields -e http.cookie
echo
echo "======== 实验3：重放登录 ========"
COOKIE=$(mktemp)
trap 'rm -f "$COOKIE"' EXIT

# ① 先 GET 登录页，拿 CSRF token + 会话
TOK=$(curl -s -c "$COOKIE" "$BASE/login.php" | grep -oE "user_token' value='[a-f0-9]+'" | head -1 | cut -d"'" -f3)
echo "① 拿到 CSRF token: $TOK"

# ② 带 token 登录
echo "② 登录 POST 的响应头："
curl -s -i -b "$COOKIE" -c "$COOKIE" -b "security=low" \
  -d "username=admin&password=password&Login=Login&user_token=$TOK" \
  "$BASE/login.php" | grep -iE '^HTTP|^Location'

# ③ 用同一会话访问首页，验证登录态
echo "③ 访问首页，验证登录态："
curl -s -b "$COOKIE" -b "security=low" "$BASE/index.php" | grep -o "You have logged in as '[a-z0-9]*'"
