#!/bin/bash

# Tailscale DERP中继服务器一键部署脚本
# 仅支持Ubuntu系统

set -e  # 遇到错误时退出

echo "========================================="
echo "Tailscale DERP中继服务器一键部署脚本"
echo "========================================="
echo ""

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户或使用sudo运行此脚本"
  exit 1
fi

# 检查系统是否支持apt包管理器
if ! command -v apt-get >/dev/null 2>&1; then
  echo "错误: 此脚本仅支持使用apt包管理器的系统（如Ubuntu、Debian等）"
  echo "当前系统不支持apt-get命令，脚本将退出"
  exit 1
fi

echo "系统检查通过: 检测到apt包管理器"
echo ""

# 获取当前用户（用于设置工作目录）
if [ -z "$SUDO_USER" ]; then
  CURRENT_USER=$(whoami)
else
  CURRENT_USER=$SUDO_USER
fi

# 获取用户主目录
USER_HOME=$(eval echo ~$CURRENT_USER)

echo ""
echo ">>> 配置信息收集"
echo ""

# 获取用户输入
read -p "请输入DERP服务端口 (默认33445): " DERP_PORT
DERP_PORT=${DERP_PORT:-33445}

read -p "请输入HTTP端口 (默认80): " HTTP_PORT
HTTP_PORT=${HTTP_PORT:-80}

read -p "请输入主机名或IP地址 (默认127.0.0.1): " DERP_HOST
DERP_HOST=${DERP_HOST:-127.0.0.1}

read -p "请输入证书目录 (默认/app/certs): " DERP_CERTS
DERP_CERTS=${DERP_CERTS:-/app/certs}

read -p "是否启用STUN服务? (y/n, 默认y): " STUN_ENABLED
STUN_ENABLED=${STUN_ENABLED:-y}

read -p "是否启用客户端验证? (y/n, 默认y): " CLIENT_VERIFY
CLIENT_VERIFY=${CLIENT_VERIFY:-y}

read -p "请选择镜像源 (1: 南大镜像源, 2: 默认源) [默认1]: " IMAGE_SOURCE
IMAGE_SOURCE=${IMAGE_SOURCE:-1}

# 根据选择设置镜像（默认使用南大镜像源）
if [ "$IMAGE_SOURCE" = "2" ]; then
  DERPER_IMAGE="ghcr.io/yangchuansheng/ip_derper:latest"
  echo ""
  echo "使用默认镜像源: $DERPER_IMAGE"
else
  DERPER_IMAGE="ghcr.nju.edu.cn/yangchuansheng/ip_derper:latest"
  echo ""
  echo "使用南大镜像源: $DERPER_IMAGE (默认)"
fi

# 转换STUN_ENABLED和CLIENT_VERIFY为布尔值
if [[ "$STUN_ENABLED" == "y" || "$STUN_ENABLED" == "Y" ]]; then
  DERP_STUN="true"
else
  DERP_STUN="false"
fi

if [[ "$CLIENT_VERIFY" == "y" || "$CLIENT_VERIFY" == "Y" ]]; then
  DERP_VERIFY_CLIENTS="true"
else
  DERP_VERIFY_CLIENTS="false"
fi

echo ""
echo "========================================="
echo "开始部署流程"
echo "========================================="

# 检查Docker是否已安装
echo ""
echo ">>> 检查Docker安装状态"
echo ""
DOCKER_INSTALLED=false
if command -v docker >/dev/null 2>&1; then
  DOCKER_VERSION=$(docker --version 2>/dev/null || echo "unknown")
  echo "检测到Docker已安装: $DOCKER_VERSION"
  DOCKER_INSTALLED=true
else
  echo "未检测到Docker，将执行安装流程"
fi

# 安装Docker（仅Ubuntu）
install_docker() {
  echo "为Ubuntu系统安装Docker..."
  # Step 1: 安装必要的一些系统工具
  echo ""
  echo ">>> Step 1: 安装必要的一些系统工具"
  echo ""
  echo "正在更新系统并安装必要工具..."
  apt-get update
  echo "-----------------------------------------"
  apt-get install -y ca-certificates curl gnupg
  echo "-----------------------------------------"
  echo "Step 1 完成"
  echo ""

  # Step 2: 信任 Docker 的 GPG 公钥
  echo ""
  echo ">>> Step 2: 信任 Docker 的 GPG 公钥"
  echo ""
  echo "正在添加Docker GPG密钥..."
  install -m 0755 -d /etc/apt/keyrings
  echo "-----------------------------------------"
  curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "-----------------------------------------"
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "-----------------------------------------"
  echo "Step 2 完成"
  echo ""

  # Step 3: 写入软件源信息
  echo ""
  echo ">>> Step 3: 写入软件源信息"
  echo ""
  echo "正在添加Docker软件源..."
  echo "-----------------------------------------"
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  echo "-----------------------------------------"
  echo "Step 3 完成"
  echo ""

  # Step 4: 安装Docker
  echo ""
  echo ">>> Step 4: 安装Docker"
  echo ""
  echo "正在安装Docker..."
  apt-get update
  echo "-----------------------------------------"
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo "-----------------------------------------"
  echo "Step 4 完成"
  echo ""
}

# 如果Docker未安装，则执行安装步骤
if [ "$DOCKER_INSTALLED" = false ]; then
  install_docker
else
  echo ""
  echo ">>> 跳过Docker安装步骤"
  echo "Docker已安装，跳过安装流程"
  echo ""
fi

# Step 5: 安装并登录Tailscale
echo ""
echo ">>> Step 5: 安装并登录Tailscale"
echo ""
echo "正在安装Tailscale..."
echo "-----------------------------------------"
curl -fsSL https://tailscale.com/install.sh | sh
echo "-----------------------------------------"

echo ""
echo "========================================="
echo "Tailscale已安装完成，现在开始登录..."
echo "========================================="
echo ""

# 执行tailscale登录并等待完成
echo "正在启动Tailscale登录过程..."
echo "-----------------------------------------"
tailscale login
echo "-----------------------------------------"

echo ""
echo "请在浏览器中打开上面显示的URL完成登录授权"
echo "登录成功后，tailscale login命令会自动返回"
echo ""

# 等待tailscale准备就绪
echo "正在检查Tailscale状态..."
MAX_WAIT=600  # 最大等待时间（秒）
WAIT_COUNT=0

while ! tailscale status >/dev/null 2>&1; do
  if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo "等待Tailscale登录超时，请手动检查Tailscale状态"
    break
  fi
  
  echo "等待Tailscale服务启动..."
  sleep 5
  WAIT_COUNT=$((WAIT_COUNT + 5))
done

if tailscale status >/dev/null 2>&1; then
  echo ""
  echo "Tailscale已成功启动并登录"
else
  echo ""
  echo "Tailscale登录可能未完成，请手动运行 'tailscale login' 完成登录"
fi

echo ""
echo "Step 5 完成"
echo ""

# Step 6: 拉取DERPER镜像
echo ""
echo ">>> Step 6: 拉取DERPER镜像"
echo ""
echo "正在拉取DERPER镜像: $DERPER_IMAGE"
echo "-----------------------------------------"
sudo -u $CURRENT_USER docker pull $DERPER_IMAGE
echo "-----------------------------------------"
echo "Step 6 完成"
echo ""

# Step 7: 创建docker-compose.yml文件
echo ""
echo ">>> Step 7: 创建docker-compose.yml文件"
echo ""
echo "正在创建docker-compose.yml文件..."

# 创建工作目录（使用用户目录）
WORK_DIR="$USER_HOME/derper"
echo ""
echo "使用工作目录: $WORK_DIR"

# 创建工作目录并设置权限
mkdir -p $WORK_DIR
chown $CURRENT_USER:$CURRENT_USER $WORK_DIR

cd $WORK_DIR

# 创建docker-compose.yml文件
cat > docker-compose.yml << EOF
version: '3.8'

services:
  derper:
    image: $DERPER_IMAGE
    container_name: derper
    restart: always
    ports:
      - "$DERP_PORT:$DERP_PORT" # DERP端口
      - "$HTTP_PORT:$HTTP_PORT" # HTTP端口
      - "3478:3478/udp" # STUN端口
    volumes:
      - /var/run/tailscale/tailscaled.sock:/var/run/tailscale/tailscaled.sock
      - ./certs:$DERP_CERTS
    environment:
      - DERP_ADDR=:$DERP_PORT
      - DERP_HTTP_PORT=$HTTP_PORT
      - DERP_HOST=$DERP_HOST
      - DERP_CERTS=$DERP_CERTS
      - DERP_STUN=$DERP_STUN
      - DERP_VERIFY_CLIENTS=$DERP_VERIFY_CLIENTS
EOF

# 设置文件权限
chown $CURRENT_USER:$CURRENT_USER docker-compose.yml

echo ""
echo "docker-compose.yml文件已创建在 $WORK_DIR/docker-compose.yml"
echo "Step 7 完成"
echo ""

# Step 8: 启动服务
echo ""
echo ">>> Step 8: 启动服务"
echo ""
echo "正在启动DERP服务..."
cd $WORK_DIR
echo "-----------------------------------------"
# 使用当前用户运行docker compose命令
sudo -u $CURRENT_USER docker compose up -d
echo "-----------------------------------------"
echo "Step 8 完成"
echo ""

echo ""
echo "========================================="
echo "DERP服务已启动"
echo "服务配置信息:"
echo "  - DERP服务端口: $DERP_PORT"
echo "  - HTTP端口: $HTTP_PORT"
echo "  - 主机名: $DERP_HOST"
echo "  - 证书目录: $DERP_CERTS"
echo "  - STUN服务: $DERP_STUN"
echo "  - 客户端验证: $DERP_VERIFY_CLIENTS"
echo "工作目录: $WORK_DIR"
echo ""
echo "验证服务状态:"
echo "1. Tailscale状态: tailscale status"
echo "2. DERP服务日志: docker logs derper"
echo ""
echo "防火墙设置（如适用）:"
echo "请确保服务器防火墙已开放以下端口："
echo "  - TCP端口: $DERP_PORT (DERP服务端口)"
echo "  - TCP端口: $HTTP_PORT (HTTP端口)"
echo "  - UDP端口: 3478 (STUN服务端口)"
echo "========================================="
echo ""