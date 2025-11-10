# ip-derper-deploy
ubuntu 一键部署 tailscale derp中继服务器脚本

## 使用方法

### 快速部署
```bash
# curl 一键部署命令
curl -fsSL https://raw.githubusercontent.com/Drswith/ip-derper-deploy/main/deploy.sh | bash
```
```bash
# curl 镜像加速
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Drswith/ip-derper-deploy/main/deploy.sh | bash
```

```bash
# wget 一键部署命令
wget -O deploy.sh https://raw.githubusercontent.com/Drswith/ip-derper-deploy/main/deploy.sh && chmod +x deploy.sh && ./deploy.sh
```
```bash
# wget 镜像加速
wget -O deploy.sh https://gh-proxy.com/https://raw.githubusercontent.com/Drswith/ip-derper-deploy/main/deploy.sh && chmod +x deploy.sh && ./deploy.sh
```

### 系统要求
- Ubuntu 系统（支持 apt 包管理器）
- root 权限或 sudo 权限
- 网络连接正常

### 前置准备
- 打开服务器所属的防火墙，允许脚本配置的端口和协议通行
  - DERP服务端口 默认 33445、33446 （tcp）
  - HTTP端口 默认 80 （tcp）
  - STUN端口 默认 3478、41641 （udp）

- 警告：使用阿里云web控制台连接服务器时由于内网服务IP段与tailscale使用的IP网段冲突，会配置到中途失去响应。
  - 解决方法：使用其他ssh工具连接到服务器执行脚本配置即可。

### 部署流程
脚本将自动完成以下步骤：
1. 系统环境检查（root权限、apt包管理器）
2. 收集配置信息（端口、主机名、证书目录等）
3. 安装 Docker（如未安装）
4. 安装并登录 Tailscale
5. 拉取 DERPER 镜像
6. 创建 docker-compose.yml 配置文件
7. 启动 DERP 服务

## 参考文档
https://blog.sleepstars.net/archives/ji-yu-docker-compose
https://sspai.com/post/89200
https://zhuanlan.zhihu.com/p/638910565

## 参考仓库
https://github.com/yangchuansheng/ip_derper