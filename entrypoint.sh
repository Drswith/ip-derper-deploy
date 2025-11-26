#!/bin/bash
set -e

# 1. 如果证书不存在，生成自签名证书
if [ ! -f "${DERP_CERTS}/cert.pem" ] || [ ! -f "${DERP_CERTS}/key.pem" ]; then
    echo "Generating self-signed certificate for host: $DERP_HOST"
    bash /app/build-cert.sh "$DERP_HOST" "$DERP_CERTS" /app/san.conf
fi

# 2. 构建 derper 参数
DERPER_ARGS=(
    --hostname="$DERP_HOST"
    --certmode=manual
    --certdir="$DERP_CERTS"
    --stun="$DERP_STUN"
    --a="$DERP_ADDR"
    --http-port="$DERP_HTTP_PORT"
    --verify-clients="$DERP_VERIFY_CLIENTS"
)

# 3. 如果用户传入了自定义参数（如 docker run ... -- --port=8080），则覆盖默认参数
#    否则使用默认参数
if [ $# -gt 0 ]; then
    # 用户指定了命令，直接使用（需确保 cert 已存在）
    exec "$@"
else
    # 使用默认参数启动 derper
    exec /app/derper "${DERPER_ARGS[@]}"
fi