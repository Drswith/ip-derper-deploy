FROM golang:latest AS builder

WORKDIR /app
ARG TAILSCALE_DIR=tailscale-*/
ADD ${TAILSCALE_DIR} /app/tailscale

# build modified derper
RUN cd /app/tailscale/cmd/derper && \
    CGO_ENABLED=0 /usr/local/go/bin/go build -buildvcs=false -ldflags "-s -w" -o /app/derper && \
    cd /app && \
    rm -rf /app/tailscale

FROM ubuntu:20.04
WORKDIR /app

ARG VERSION=dev

# ========= CONFIG =========
# - derper args
ENV DERP_ADDR :443
ENV DERP_HTTP_PORT 80
ENV DERP_HOST=127.0.0.1
ENV DERP_CERTS=/app/certs/
ENV DERP_STUN=true
ENV DERP_VERIFY_CLIENTS=false
# ==========================

# apt
RUN apt-get update && \
    apt-get install -y openssl curl

# 复制脚本和证书生成工具
COPY build-cert.sh /app/
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh /app/build-cert.sh

# 从 builder 阶段复制二进制
COPY --from=builder /app/derper /app/derper

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]
# 默认无参数，由 entrypoint.sh 决定是否使用默认值
CMD []
