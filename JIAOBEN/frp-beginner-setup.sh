#!/bin/bash

# FRP 新手一键配置脚本

echo "🚀 FRP 新手配置向导"
echo "=================="

# 获取用户输入
read -p "请输入您的阿里云服务器IP: " SERVER_IP
read -p "请输入您的域名 (如: yourdomain.com): " DOMAIN
read -p "设置一个安全令牌 (建议8位以上): " TOKEN

# 创建目录
mkdir -p /volume1/YC/services/frp-beginner

# 生成服务端配置
cat > /volume1/YC/services/frp-beginner/frps.ini << EOF
[common]
bind_port = 7000
vhost_http_port = 80
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin123
token = $TOKEN
log_level = info
log_file = ./frps.log
EOF

# 生成客户端配置
cat > /volume1/YC/services/frp-beginner/frpc.ini << EOF
[common]
server_addr = $SERVER_IP
server_port = 7000
token = $TOKEN
log_level = info
log_file = ./frpc.log

[web]
type = http
local_ip = 192.168.3.45
local_port = 80
custom_domains = yc.$DOMAIN

[gitlab]
type = http
local_ip = 192.168.3.45
local_port = 8080
custom_domains = gitlab.$DOMAIN

[ai]
type = http
local_ip = 192.168.3.45
local_port = 3000
custom_domains = ai.$DOMAIN

[code]
type = http
local_ip = 192.168.3.45
local_port = 8443
custom_domains = code.$DOMAIN
EOF

# 生成 Docker Compose
cat > /volume1/YC/services/frp-beginner/docker-compose.yml << EOF
version: '3.8'

services:
  frpc:
    image: snowdreamtech/frpc:latest
    container_name: frp-client
    volumes:
      - ./frpc.ini:/etc/frp/frpc.ini
      - ./logs:/var/log/frp
    restart: unless-stopped
    command: frpc -c /etc/frp/frpc.ini
EOF

# 生成阿里云部署命令
cat > /volume1/YC/services/frp-beginner/deploy-server.sh << 'DEPLOY_EOF'
#!/bin/bash

# 在阿里云服务器上执行以下命令

echo "📥 下载 FRP..."
wget https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_amd64.tar.gz
tar -xzf frp_0.52.3_linux_amd64.tar.gz
cd frp_0.52.3_linux_amd64

echo "📝 上传配置文件..."
# 将本地的 frps.ini 上传到服务器

echo "🚀 启动 FRP 服务端..."
nohup ./frps -c frps.ini > frps.log 2>&1 &

echo "🔥 配置防火墙..."
# CentOS/RHEL
firewall-cmd --permanent --add-port=7000/tcp
firewall-cmd --permanent --add-port=7500/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

# Ubuntu/Debian
# ufw allow 7000/tcp
# ufw allow 7500/tcp
# ufw allow 80/tcp

echo "✅ 部署完成！"
echo "🌐 管理面板: http://$SERVER_IP:7500"
DEPLOY_EOF

chmod +x /volume1/YC/services/frp-beginner/deploy-server.sh

echo ""
echo "✅ FRP 配置文件生成完成！"
echo ""
echo "📁 配置目录: /volume1/YC/services/frp-beginner/"
echo ""
echo "🔧 下一步操作："
echo "1. 将 frps.ini 上传到阿里云服务器"
echo "2. 在阿里云服务器执行 deploy-server.sh"
echo "3. 配置域名解析指向 $SERVER_IP"
echo "4. 在本地启动客户端: cd /volume1/YC/services/frp-beginner && docker-compose up -d"
echo ""
echo "🌐 完成后访问地址："
echo "• 主控制台: http://yc.$DOMAIN"
echo "• GitLab: http://gitlab.$DOMAIN"
echo "• AI 服务: http://ai.$DOMAIN"
echo "• Code Server: http://code.$DOMAIN"
echo "• FRP 管理: http://$SERVER_IP:7500 (用户名: admin, 密码: admin123)"
