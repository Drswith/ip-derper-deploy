#!/bin/bash

GITHUB_GIT_URL=${GITHUB_GIT_URL:-"https://github.com"}
REPO_URL="${GITHUB_GIT_URL%/}/tailscale/tailscale.git"
if [ -t 1 ] && [ -z "$NO_COLOR" ]; then
  RED=$'\033[31m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  RED=""; YELLOW=""; CYAN=""; GREEN=""; RESET=""
fi
log() { local level="$1"; shift; local color=""; case "$level" in INFO) color="$CYAN";; WARN) color="$YELLOW";; ERROR) color="$RED";; OK) color="$GREEN";; esac; printf "%s %b[%s]%b %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$color" "$level" "$RESET" "$*"; }
log INFO "开始获取 Tailscale 版本列表..."
latest_url=$(curl -sL -o /dev/null -w '%{url_effective}' "https://github.com/tailscale/tailscale/releases/latest")
latest_version=${latest_url##*/}
if command -v git >/dev/null 2>&1; then
  tags=$(git ls-remote --tags "$REPO_URL" 2>/dev/null | awk -F'/' '{print $NF}' | sed 's/\^{}//' | sort -V)
  latest_versions=$(echo "$tags" | tail -n 10)
  if [ -z "$latest_versions" ]; then
    latest_versions="$latest_version"
    log WARN "无法获取标签列表，已仅显示最新版本"
  fi
  if [ -z "$latest_version" ]; then
    latest_version=$(echo "$tags" | tail -n 1)
  fi
else
  latest_versions="$latest_version"
fi

log INFO "最近的 10个 Tailscale 版本"
printf "%s\n" "$latest_versions"
log INFO "最新的 Tailscale 版本: $latest_version"

DEST_DIR="tailscale-$latest_version"
if command -v git >/dev/null 2>&1; then
  rm -rf "$DEST_DIR"
  log INFO "开始克隆 $REPO_URL@$latest_version 到 $DEST_DIR..."
  if ! git -c advice.detachedHead=false clone --depth 1 --single-branch --branch "$latest_version" --filter=blob:none --quiet "$REPO_URL" "$DEST_DIR"; then
    log WARN "git 克隆失败，回退为压缩包下载"
    curl -sSL "https://codeload.github.com/tailscale/tailscale/tar.gz/$latest_version" -o "tailscale-$latest_version.tar.gz"
    tar -xzf "tailscale-$latest_version.tar.gz"
    log OK "已下载并解压 tailscale-$latest_version.tar.gz"
  else
    log OK "克隆完成: $DEST_DIR"
  fi
else
  log WARN "未检测到 git，使用压缩包下载"
  curl -sSL "https://codeload.github.com/tailscale/tailscale/tar.gz/$latest_version" -o "tailscale-$latest_version.tar.gz"
  tar -xzf "tailscale-$latest_version.tar.gz"
  log OK "已下载并解压 tailscale-$latest_version.tar.gz"
fi
