#!/bin/bash
# 国庆网安自学 · 环境搭建第二阶段（Homebrew 已装好之后）
# 用法：bash labs/setup-env.sh
# 会依次完成：aria2 → Burp Suite → colima+docker → UTM → 预下载 Wireshark 安装包
# 进度日志：/tmp/setup.log
set -u
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export HOMEBREW_NO_ENV_HINTS=1
export ALL_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897
export HTTP_PROXY=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897

LOG=/tmp/setup.log
: > "$LOG"
step() { echo "" | tee -a "$LOG"; echo "### $* ###" | tee -a "$LOG"; }

# ---------------------------------------------------------------- 1. aria2
step "1/6 安装 aria2（多线程下载器，单线程只有 200KB/s 的站全靠它）"
brew install aria2 2>&1 | tail -5 | tee -a "$LOG"

# ---------------------------------------------------------------- 2. Burp
step "2/6 下载 Burp Suite 社区版（8 线程并发）"
BURP_URL="https://portswigger-cdn.net/burp/releases/download?product=desktop&version=2026.8&type=MacOsArm64"
BURP_SHA="638ff9d9c3026838798f5659904e3e9cba00ee0b26f3d616f93b1967f275d2ce"
rm -f /tmp/burp-suite.dmg
aria2c -x 8 -s 8 -k 1M --file-allocation=none --summary-interval=15 \
  -d /tmp -o burp-suite.dmg "$BURP_URL" 2>&1 | tail -6 | tee -a "$LOG"

if [ "$(shasum -a 256 /tmp/burp-suite.dmg | awk '{print $1}')" = "$BURP_SHA" ]; then
  echo "SHA256 校验通过 ✓" | tee -a "$LOG"
  CACHE="$HOME/Library/Caches/Homebrew/downloads"
  H=$(printf '%s' "$BURP_URL" | shasum -a 256 | awk '{print $1}')
  mkdir -p "$CACHE"
  cp /tmp/burp-suite.dmg "$CACHE/$H--burpsuite_macos_arm64_v2026_8.dmg"
  step "3/6 用缓存安装 Burp Suite（免重复下载）"
  brew install --cask burp-suite 2>&1 | tail -8 | tee -a "$LOG"
else
  echo "SHA256 校验失败，改为让 brew 自己下载" | tee -a "$LOG"
  brew install --cask burp-suite 2>&1 | tail -8 | tee -a "$LOG"
fi

# ---------------------------------------------------------------- 3. colima+docker
step "4/6 安装 colima + docker CLI（免管理员密码、免 Docker Desktop 授权）"
brew install colima docker docker-compose docker-buildx 2>&1 | tail -15 | tee -a "$LOG"

# ---------------------------------------------------------------- 4. UTM
step "5/6 安装 UTM 虚拟机"
brew install --cask utm 2>&1 | tail -8 | tee -a "$LOG"

# ---------------------------------------------------------------- 5. Wireshark 安装包
step "6/6 预下载 Wireshark 安装包（安装需要管理员密码，之后单独执行）"
brew fetch --cask wireshark-app 2>&1 | tail -6 | tee -a "$LOG"

step "全部完成"
echo "--- 结果核对 ---" | tee -a "$LOG"
ls -d "/Applications/Burp Suite.app" /Applications/UTM.app 2>&1 | tee -a "$LOG"
for t in aria2c colima docker docker-compose; do printf "%-15s " "$t" | tee -a "$LOG"; command -v "$t" || echo "缺失" | tee -a "$LOG"; done
ls -1 "$HOME/Library/Caches/Homebrew/downloads" | grep -i wireshark | tee -a "$LOG"
