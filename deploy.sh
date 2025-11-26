#!/bin/bash

# Tailscale DERP 中继服务器一键部署脚本（无 Docker 版）
# 说明：
# - 直接从 GitHub Release 下载已构建的 derper 二进制
# - 进行 SHA256 校验验证
# - 安装并配置为 systemd 服务运行
# - 配合 Tailscale 登录与首选项设置

set -euo pipefail

LOG_FILE="/var/log/derper-deploy.log"
mkdir -p "$(dirname "$LOG_FILE")" || true

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(ts) [INFO] $*" | tee -a "$LOG_FILE"; }
warn() { echo "$(ts) [WARN] $*" | tee -a "$LOG_FILE"; }
err() { echo "$(ts) [ERROR] $*" | tee -a "$LOG_FILE"; }

trap 'err "发生错误，查看日志: $LOG_FILE"' ERR

echo "========================================="
echo "Tailscale DERP中继服务器一键部署脚本（无 Docker）"
echo "========================================="
echo ""

# 1) 基础环境校验
if [ "$EUID" -ne 0 ]; then
  err "请以 root 或使用 sudo 运行此脚本"
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  err "错误: 此脚本仅支持使用 apt 包管理器的系统（如 Ubuntu/Debian）"
  exit 1
fi
log "系统检查通过: 检测到 apt 包管理器"

# 获取当前用户（用于设置工作目录与权限）
if [ -z "${SUDO_USER:-}" ]; then
  CURRENT_USER=$(whoami)
else
  CURRENT_USER=$SUDO_USER
fi
USER_HOME=$(eval echo ~$CURRENT_USER)

echo ""
echo ">>> 配置信息收集"
echo ""

# 2) 配置输入
read -p "请输入 DERP 服务端口 (默认 52625): " DERP_PORT < /dev/tty
DERP_PORT=${DERP_PORT:-52625}

read -p "请输入 HTTP 端口 (默认 80): " HTTP_PORT < /dev/tty
HTTP_PORT=${HTTP_PORT:-80}

read -p "请输入主机名或 IP 地址 (默认 127.0.0.1): " DERP_HOST < /dev/tty
DERP_HOST=${DERP_HOST:-127.0.0.1}

read -p "请输入证书目录 (默认 /opt/derper/certs): " DERP_CERTS < /dev/tty
DERP_CERTS=${DERP_CERTS:-/opt/derper/certs}

read -p "是否启用 STUN 服务? (y/n, 默认 y): " STUN_ENABLED < /dev/tty
STUN_ENABLED=${STUN_ENABLED:-y}

read -p "是否启用客户端验证? (y/n, 默认 y): " CLIENT_VERIFY < /dev/tty
CLIENT_VERIFY=${CLIENT_VERIFY:-y}

read -p "是否禁用 Tailscale 防火墙规则 (netfilter)? (阿里云必须禁用) (y/n, 默认 n): " DISABLE_NETFILTER < /dev/tty
DISABLE_NETFILTER=${DISABLE_NETFILTER:-n}

read -p "是否禁用 Magic DNS 修改 /etc/resolv.conf? (阿里云必须禁用) (y/n, 默认 n): " DISABLE_MAGIC_DNS < /dev/tty
DISABLE_MAGIC_DNS=${DISABLE_MAGIC_DNS:-n}

read -p "是否接受其他节点的子网路由 (accept-routes)? (y/n, 默认 y): " ACCEPT_ROUTES < /dev/tty
ACCEPT_ROUTES=${ACCEPT_ROUTES:-y}

read -p "是否设置为出口节点 (advertise-exit-node)? (y/n, 默认 n): " ADVERTISE_EXIT_NODE < /dev/tty
ADVERTISE_EXIT_NODE=${ADVERTISE_EXIT_NODE:-n}

read -p "广告子网路由 (例如 192.168.0.0/24，留空不广告): " ADVERTISE_ROUTES < /dev/tty

read -p "安装目录 (用于存放文件，默认 /opt/derper): " INSTALL_DIR < /dev/tty
INSTALL_DIR=${INSTALL_DIR:-/opt/derper}

# 3) 布尔值转换
if [[ "$STUN_ENABLED" == "y" || "$STUN_ENABLED" == "Y" ]]; then DERP_STUN="true"; else DERP_STUN="false"; fi
if [[ "$CLIENT_VERIFY" == "y" || "$CLIENT_VERIFY" == "Y" ]]; then DERP_VERIFY_CLIENTS="true"; else DERP_VERIFY_CLIENTS="false"; fi
if [[ "$DISABLE_NETFILTER" == "y" || "$DISABLE_NETFILTER" == "Y" ]]; then NETFILTER_MODE="off"; else NETFILTER_MODE="on"; fi
if [[ "$DISABLE_MAGIC_DNS" == "y" || "$DISABLE_MAGIC_DNS" == "Y" ]]; then TS_ACCEPT_DNS="false"; else TS_ACCEPT_DNS="true"; fi
if [[ "$ACCEPT_ROUTES" == "y" || "$ACCEPT_ROUTES" == "Y" ]]; then TS_ACCEPT_ROUTES="true"; else TS_ACCEPT_ROUTES="false"; fi
if [[ "$ADVERTISE_EXIT_NODE" == "y" || "$ADVERTISE_EXIT_NODE" == "Y" ]]; then TS_ADVERTISE_EXIT_NODE="true"; else TS_ADVERTISE_EXIT_NODE="false"; fi

echo ""
echo "========================================="
echo "开始部署流程"
echo "========================================="

# 4) 安装常用依赖
log "安装必需工具: curl tar openssl"
apt-get update -y
apt-get install -y curl tar openssl

# 5) 安装并登录 Tailscale
echo ""
echo ">>> 安装并登录 Tailscale"
echo ""
log "安装 Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

log "启动 Tailscale 登录过程..."
tailscale login
echo ""
echo "请在浏览器中打开上面显示的 URL 完成登录授权"
echo "登录成功后，tailscale login 命令会自动返回"

log "检查 Tailscale 状态..."
MAX_WAIT=600
WAIT_COUNT=0
while ! tailscale status >/dev/null 2>&1; do
  if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    warn "等待 Tailscale 登录超时，请手动检查 Tailscale 状态"
    break
  fi
  log "等待 Tailscale 服务启动..."
  sleep 5
  WAIT_COUNT=$((WAIT_COUNT + 5))
done

if tailscale status >/dev/null 2>&1; then
  log "Tailscale 已成功启动并登录"
else
  warn "Tailscale 登录可能未完成，请手动运行 'tailscale login' 完成登录"
fi

TS_UP_FLAGS=""
TS_UP_FLAGS="$TS_UP_FLAGS --netfilter-mode=$NETFILTER_MODE"
if [ "$TS_ACCEPT_DNS" = "true" ]; then TS_UP_FLAGS="$TS_UP_FLAGS --accept-dns=true"; else TS_UP_FLAGS="$TS_UP_FLAGS --accept-dns=false"; fi
if [ "$TS_ACCEPT_ROUTES" = "true" ]; then TS_UP_FLAGS="$TS_UP_FLAGS --accept-routes=true"; else TS_UP_FLAGS="$TS_UP_FLAGS --accept-routes=false"; fi
if [ "$TS_ADVERTISE_EXIT_NODE" = "true" ]; then TS_UP_FLAGS="$TS_UP_FLAGS --advertise-exit-node"; fi
if [ -n "$ADVERTISE_ROUTES" ]; then TS_UP_FLAGS="$TS_UP_FLAGS --advertise-routes=$ADVERTISE_ROUTES"; fi
log "应用 Tailscale 首选项: $TS_UP_FLAGS"
tailscale up $TS_UP_FLAGS || true

if [ "$NETFILTER_MODE" = "off" ]; then
  echo ""
  echo ">>> 禁用 Tailscale 防火墙规则 (netfilter)"
  if command -v iptables >/dev/null 2>&1; then
    if iptables -C INPUT -j ts-input >/dev/null 2>&1; then iptables -D INPUT -j ts-input || true; fi
    if iptables -C FORWARD -j ts-forward >/dev/null 2>&1; then iptables -D FORWARD -j ts-forward || true; fi
    iptables -F ts-input || true; iptables -X ts-input || true
    iptables -F ts-forward || true; iptables -X ts-forward || true
  fi
  if command -v ip6tables >/dev/null 2>&1; then
    if ip6tables -C INPUT -j ts-input >/dev/null 2>&1; then ip6tables -D INPUT -j ts-input || true; fi
    if ip6tables -C FORWARD -j ts-forward >/dev/null 2>&1; then ip6tables -D FORWARD -j ts-forward || true; fi
    ip6tables -F ts-input || true; ip6tables -X ts-input || true
    ip6tables -F ts-forward || true; ip6tables -X ts-forward || true
  fi
fi

echo ""
echo ">>> 下载并安装 derper 二进制"
echo ""

# 6) 解析架构与 Release 信息
arch_raw=$(uname -m)
case "$arch_raw" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  arm64) ARCH="arm64" ;;
  *) err "不支持的架构: $arch_raw (仅支持 x86_64/aarch64)"; exit 1 ;;
esac

GITHUB_OWNER=${GITHUB_OWNER:-"Drswith"}
GITHUB_REPO=${GITHUB_REPO:-"ip-derper-deploy"}
API_URL="https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/releases/latest"

log "查询 GitHub 最新 Release: $API_URL"
release_json=$(curl -fsSL "$API_URL")
tag_name=$(echo "$release_json" | grep -E '"tag_name"' | head -n1 | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')
if [ -z "$tag_name" ]; then
  err "无法获取最新 Release 标签"
  exit 1
fi
log "最新 Release 标签: $tag_name"

# tag 形如 derper-1.90.8，提取版本原始号
version_raw=${tag_name#derper-}
ASSET_TAR="derper_${version_raw}_linux_${ARCH}.tar.gz"
ASSET_SUMS="derper_${version_raw}_SHA256SUMS.txt"

# Release 下载地址（无需 API 转换，直接拼接）
BASE_DL="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/download/$tag_name"
URL_TAR="$BASE_DL/$ASSET_TAR"
URL_SUMS="$BASE_DL/$ASSET_SUMS"
log "准备下载: $URL_TAR"
log "校验文件: $URL_SUMS"

WORK_DIR="$INSTALL_DIR"
mkdir -p "$WORK_DIR" "$DERP_CERTS"
chown $CURRENT_USER:$CURRENT_USER "$WORK_DIR" || true

pushd "$WORK_DIR" >/dev/null
  curl -fSL "$URL_TAR" -o "$ASSET_TAR"
  curl -fSL "$URL_SUMS" -o "$ASSET_SUMS"
  log "下载完成，开始校验..."
  if grep -F "$ASSET_TAR" "$ASSET_SUMS" | sha256sum -c -; then
    log "校验通过"
  else
    err "校验失败，终止部署"
    exit 1
  fi
  tar -xzf "$ASSET_TAR"
  # 解压后应包含单个二进制 derper
  if [ ! -f "derper" ]; then
    err "解压后未找到 derper 二进制"
    exit 1
  fi
  # 备份旧版本并安装到 /usr/local/bin
  if command -v derper >/dev/null 2>&1; then
    cp "$(command -v derper)" derper.bak || true
    log "已备份旧版本: derper.bak"
  fi
  install -m 0755 derper /usr/local/bin/derper
popd >/dev/null

# 7) 自签名证书（若不存在）
if [ ! -f "$DERP_CERTS/cert.pem" ] || [ ! -f "$DERP_CERTS/key.pem" ]; then
  log "生成自签名证书: $DERP_HOST -> $DERP_CERTS"
  openssl req -x509 -nodes -days 730 -newkey rsa:2048 \
    -keyout "$DERP_CERTS/key.pem" -out "$DERP_CERTS/cert.pem" \
    -subj "/CN=$DERP_HOST" \
    -addext "subjectAltName=DNS:$DERP_HOST,IP:$DERP_HOST" || {
      err "证书生成失败"; exit 1; }
fi

# 8) 创建 systemd 服务
SERVICE_FILE="/etc/systemd/system/derper.service"
log "创建 systemd 服务: $SERVICE_FILE"
cat > "$SERVICE_FILE" <<SERVICE
[Unit]
Description=Tailscale DERP Relay (derper)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/derper \
  --hostname="$DERP_HOST" \
  --certmode=manual \
  --certdir="$DERP_CERTS" \
  --stun="$DERP_STUN" \
  --a=":$DERP_PORT" \
  --http-port="$HTTP_PORT" \
  --verify-clients="$DERP_VERIFY_CLIENTS"
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable derper
systemctl restart derper

# 验证服务是否正常启动，如失败尝试回滚二进制
if ! systemctl is-active --quiet derper; then
  warn "derper 服务启动失败，尝试回滚到旧版本"
  if [ -f "$WORK_DIR/derper.bak" ]; then
    install -m 0755 "$WORK_DIR/derper.bak" /usr/local/bin/derper
    systemctl restart derper || true
    if systemctl is-active --quiet derper; then
      log "回滚成功，服务已恢复运行"
    else
      err "回滚后服务仍未启动，请检查日志: journalctl -u derper"
    fi
  else
    err "没有可用的旧版本备份，无法回滚"
  fi
fi

# 9) 输出部署信息
echo ""
echo "========================================="
echo "DERP 服务已启动"
echo "服务配置信息:"
echo "  - DERP 服务端口: $DERP_PORT"
echo "  - HTTP 端口: $HTTP_PORT"
echo "  - 主机名: $DERP_HOST"
echo "  - 证书目录: $DERP_CERTS"
echo "  - STUN 服务: $DERP_STUN"
echo "  - 客户端验证: $DERP_VERIFY_CLIENTS"
if [ "$NETFILTER_MODE" = "off" ]; then echo "  - 已禁用 Tailscale 防火墙 (netfilter)"; fi
echo "  - DNS 管理: $TS_ACCEPT_DNS"
echo "  - 接受子网路由: $TS_ACCEPT_ROUTES"
echo "  - 出口节点: $TS_ADVERTISE_EXIT_NODE"
if [ -n "$ADVERTISE_ROUTES" ]; then echo "  - 广告子网路由: $ADVERTISE_ROUTES"; fi
echo "工作目录: $WORK_DIR"
echo ""
echo "验证服务状态:"
echo "1. Tailscale 状态: tailscale status"
echo "2. DERP 服务状态: systemctl status derper"
echo "3. DERP 服务日志: journalctl -u derper -f"
echo ""
echo "防火墙设置（如适用）:"
echo "请确保服务器防火墙已开放以下端口："
echo "  - TCP 端口: $DERP_PORT (DERP 服务端口)"
echo "  - TCP 端口: $HTTP_PORT (HTTP 端口)"
echo "  - UDP 端口: 3478 (STUN 服务端口)"
echo "========================================="
