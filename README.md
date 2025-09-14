# ip-derper-deploy
ubuntu 一键部署 tailscale derp中继服务器脚本

## 使用方法

### 快速部署
```bash
# curl 一键部署命令
curl -fsSL https://raw.githubusercontent.com/Drswith/ip-derper-deploy/main/deploy.sh | bash

# wget 一键部署命令
wget -O deploy.sh https://raw.githubusercontent.com/Drswith/ip-derper-deploy/main/deploy.sh && chmod +x deploy.sh && ./deploy.sh
```

### 系统要求
- Ubuntu 系统（支持 apt 包管理器）
- root 权限或 sudo 权限
- 网络连接正常

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