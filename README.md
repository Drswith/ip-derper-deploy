# ip-derper-deploy
Ubuntu 一键部署 Tailscale DERP 中继服务器脚本

## 使用方法

### 快速部署

#### curl 一键部署
 - 源脚本
```bash
curl -fsSL https://raw.githubusercontent.com/Drswith/ip-derper-deploy/main/deploy.sh | sudo bash
```
 - 镜像加速
```bash
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Drswith/ip-derper-deploy/main/deploy.sh | sudo bash
```
#### wget 一键部署
 - 源脚本
```bash
wget -O deploy.sh https://raw.githubusercontent.com/Drswith/ip-derper-deploy/main/deploy.sh && chmod +x deploy.sh && sudo bash deploy.sh
```
 - 镜像加速
```bash
wget -O deploy.sh https://gh-proxy.com/https://raw.githubusercontent.com/Drswith/ip-derper-deploy/main/deploy.sh && chmod +x deploy.sh && sudo bash deploy.sh
```

### 系统要求
- Ubuntu 系统（支持 apt 包管理器）
- root 权限或 sudo 权限
- 网络连接正常

### 前置准备
- 打开服务器所属的防火墙，允许脚本配置的端口和协议通行
  - DERP 服务端口 默认 52625（TCP）
  - HTTP 端口 默认 80 （TCP）
  - STUN 端口 默认 3478、41641 （UDP）

- 使用阿里云 Web 控制台连接服务器时，因内网 IP 段可能与 Tailscale IP 段冲突，配置中途可能失去响应。
  - 解决方法：使用其他 SSH 工具连接到服务器执行脚本配置即可。

### 权限说明
- 脚本会安装软件包、写入 `/usr/local/bin` 和 `/etc/systemd/system`，需要 root 权限。
- 若看到“请以 root 或使用 sudo 运行此脚本”，请按以上命令使用 `sudo` 执行。

### 部署流程
脚本将自动完成以下步骤：
1. 系统环境检查（root 权限、apt 包管理器）
2. 收集配置信息（端口、主机名、证书目录等）
3. 安装并登录 Tailscale
4. 从 GitHub Release 下载 derper 构建产物并进行 SHA256 校验
5. 安装二进制到 `/usr/local/bin`，配置为 systemd 服务
6. 启动 DERP 服务并输出日志与状态信息

## 参考文档
https://blog.sleepstars.net/archives/ji-yu-docker-compose

https://sspai.com/post/89200

https://zhuanlan.zhihu.com/p/638910565

## 参考仓库
https://github.com/yangchuansheng/ip_derper
