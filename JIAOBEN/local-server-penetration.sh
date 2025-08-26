#!/bin/bash

# 本地服务器内网穿透解决方案
# 针对有阿里云公网IP的场景

ROOT_DIR="/volume2/YC"  # 使用SSD存储配置
ALIYUN_IP="YOUR_ALIYUN_IP"
NAS_IP="192.168.3.45"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[信息]${NC} $1"; }
log_success() { echo -e "${GREEN}[成功]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
log_error() { echo -e "${RED}[错误]${NC} $1"; }
log_step() { echo -e "${PURPLE}[步骤]${NC} $1"; }
log_highlight() { echo -e "${CYAN}[重点]${NC} $1"; }

# 显示方案选择
show_penetration_solutions() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    🌐 本地服务器穿透方案
    ====================
    
    您有阿里云服务器公网IP，推荐以下方案：
EOF
    echo -e "${NC}"
    echo ""
    echo "1. 🚀 反向代理 + SSL (推荐)"
    echo "   • Nginx 反向代理"
    echo "   • Let's Encrypt SSL 证书"
    echo "   • 阿里云 CDN 加速"
    echo ""
    echo "2. 🔗 SSH 隧道 + Nginx"
    echo "   • SSH 端口转发"
    echo "   • Nginx 负载均衡"
    echo "   • 自动重连机制"
    echo ""
    echo "3. 🛡️ WireGuard VPN (高安全)"
    echo "   • 点对点加密"
    echo "   • 高性能传输"
    echo "   • 移动端支持"
    echo ""
    echo "4. 📊 方案对比分析"
    echo "0. ❌ 退出"
    echo ""
}

# 方案1: 反向代理 + SSL
setup_reverse_proxy() {
    log_step "配置反向代理 + SSL 方案..."
    
    mkdir -p "$ROOT_DIR/config/penetration/reverse-proxy"
    
    # 获取用户配置
    read -p "请输入您的阿里云服务器IP: " ALIYUN_IP
    read -p "请输入您的域名 (如: yourdomain.com): " DOMAIN
    
    # 创建阿里云服务器配置脚本
    cat > "$ROOT_DIR/config/penetration/reverse-proxy/aliyun-setup.sh" << 'ALIYUN_EOF'
#!/bin/bash

# 在阿里云服务器上执行此脚本

DOMAIN="DOMAIN_PLACEHOLDER"
NAS_IP="192.168.3.45"

echo "🚀 配置阿里云反向代理服务器..."

# 1. 安装必要软件
echo "📦 安装软件包..."
if command -v yum &> /dev/null; then
    # CentOS/RHEL
    yum update -y
    yum install -y nginx certbot python3-certbot-nginx
elif command -v apt &> /dev/null; then
    # Ubuntu/Debian
    apt update -y
    apt install -y nginx certbot python3-certbot-nginx
fi

# 2. 配置防火墙
echo "🔥 配置防火墙..."
if command -v firewall-cmd &> /dev/null; then
    # CentOS/RHEL
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --permanent --add-port=3000/tcp
    firewall-cmd --reload
elif command -v ufw &> /dev/null; then
    # Ubuntu/Debian
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8080/tcp
    ufw allow 3000/tcp
    ufw --force enable
fi

# 3. 创建 Nginx 配置
echo "⚙️ 配置 Nginx..."
cat > /etc/nginx/conf.d/yc-proxy.conf << 'NGINX_EOF'
# YC 开发环境反向代理配置

upstream yc_main {
    server NAS_IP_PLACEHOLDER:80;
    keepalive 32;
}

upstream yc_gitlab {
    server NAS_IP_PLACEHOLDER:8080;
    keepalive 32;
}

upstream yc_ai {
    server NAS_IP_PLACEHOLDER:3000;
    keepalive 32;
}

upstream yc_code {
    server NAS_IP_PLACEHOLDER:8443;
    keepalive 32;
}

upstream yc_monitor {
    server NAS_IP_PLACEHOLDER:3002;
    keepalive 32;
}

# 主站点
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER;
    
    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;
    
    # SSL 配置 (Let's Encrypt 会自动添加)
    
    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # 主控制台
    location / {
        proxy_pass http://yc_main;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}

# GitLab 子域名
server {
    listen 80;
    server_name gitlab.DOMAIN_PLACEHOLDER;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name gitlab.DOMAIN_PLACEHOLDER;
    
    location / {
        proxy_pass http://yc_gitlab;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffering off;
    }
}

# AI 服务子域名
server {
    listen 80;
    server_name ai.DOMAIN_PLACEHOLDER;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ai.DOMAIN_PLACEHOLDER;
    
    location / {
        proxy_pass http://yc_ai;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 300s;  # AI 响应可能较慢
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# Code Server 子域名
server {
    listen 80;
    server_name code.DOMAIN_PLACEHOLDER;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name code.DOMAIN_PLACEHOLDER;
    
    location / {
        proxy_pass http://yc_code;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 支持 (VS Code 需要)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}

# 监控面板子域名
server {
    listen 80;
    server_name monitor.DOMAIN_PLACEHOLDER;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name monitor.DOMAIN_PLACEHOLDER;
    
    location / {
        proxy_pass http://yc_monitor;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF

# 替换占位符
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" /etc/nginx/conf.d/yc-proxy.conf
sed -i "s/NAS_IP_PLACEHOLDER/$NAS_IP/g" /etc/nginx/conf.d/yc-proxy.conf

# 4. 测试 Nginx 配置
echo "🧪 测试 Nginx 配置..."
nginx -t

# 5. 启动 Nginx
echo "🚀 启动 Nginx..."
systemctl enable nginx
systemctl start nginx

# 6. 获取 SSL 证书
echo "🔒 获取 SSL 证书..."
certbot --nginx -d $DOMAIN -d gitlab.$DOMAIN -d ai.$DOMAIN -d code.$DOMAIN -d monitor.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

# 7. 设置证书自动更新
echo "🔄 设置证书自动更新..."
echo "0 3 * * * certbot renew --quiet" | crontab -

echo "✅ 阿里云反向代理配置完成！"
echo ""
echo "🌐 访问地址："
echo "• 主控制台: https://$DOMAIN"
echo "• GitLab: https://gitlab.$DOMAIN"
echo "• AI 服务: https://ai.$DOMAIN"
echo "• Code Server: https://code.$DOMAIN"
echo "• 监控面板: https://monitor.$DOMAIN"
ALIYUN_EOF

    # 替换占位符
    sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$ROOT_DIR/config/penetration/reverse-proxy/aliyun-setup.sh"
    
    # 创建本地配置脚本
    cat > "$ROOT_DIR/config/penetration/reverse-proxy/local-setup.sh" << 'LOCAL_EOF'
#!/bin/bash

# 本地 NAS 配置脚本

echo "🏠 配置本地 NAS..."

# 1. 更新 Nginx 配置以支持反向代理
cat > /volume2/YC/config/nginx/conf.d/proxy-support.conf << 'PROXY_EOF'
# 反向代理支持配置

# 真实IP获取
set_real_ip_from 0.0.0.0/0;
real_ip_header X-Forwarded-For;
real_ip_recursive on;

# 代理缓存
proxy_cache_path /volume2/YC/cache/nginx levels=1:2 keys_zone=proxy_cache:10m max_size=1g inactive=60m;

# 上游健康检查
upstream_conf {
    zone upstream_dynamic 64k;
}
PROXY_EOF

# 2. 重启 Nginx
docker restart yc-nginx

# 3. 配置防火墙 (如果有)
echo "🔥 配置本地防火墙..."
# 这里可以添加 iptables 规则

echo "✅ 本地 NAS 配置完成！"
LOCAL_EOF

    chmod +x "$ROOT_DIR/config/penetration/reverse-proxy/aliyun-setup.sh"
    chmod +x "$ROOT_DIR/config/penetration/reverse-proxy/local-setup.sh"
    
    # 创建域名解析说明
    cat > "$ROOT_DIR/config/penetration/reverse-proxy/dns-setup.md" << DNS_EOF
# 域名解析配置

## 1. 添加 A 记录

在您的域名管理面板添加以下 A 记录：

\`\`\`
$DOMAIN           A    $ALIYUN_IP
gitlab.$DOMAIN    A    $ALIYUN_IP
ai.$DOMAIN        A    $ALIYUN_IP
code.$DOMAIN      A    $ALIYUN_IP
monitor.$DOMAIN   A    $ALIYUN_IP
\`\`\`

## 2. 等待 DNS 生效

DNS 解析通常需要 10 分钟到 24 小时生效。

## 3. 验证解析

\`\`\`bash
nslookup $DOMAIN
ping $DOMAIN
\`\`\`

## 4. 阿里云 CDN 配置 (可选)

1. 登录阿里云控制台
2. 进入 CDN 服务
3. 添加域名加速
4. 源站设置为您的服务器 IP
5. 配置 HTTPS 证书
DNS_EOF

    log_success "反向代理方案配置完成"
    echo "📁 配置目录: $ROOT_DIR/config/penetration/reverse-proxy/"
    echo "🔧 下一步:"
    echo "1. 配置域名解析"
    echo "2. 在阿里云服务器执行: aliyun-setup.sh"
    echo "3. 在本地 NAS 执行: local-setup.sh"
}

# 方案2: SSH 隧道 + Nginx
setup_ssh_tunnel() {
    log_step "配置 SSH 隧道方案..."
    
    mkdir -p "$ROOT_DIR/config/penetration/ssh-tunnel"
    
    read -p "请输入阿里云服务器IP: " ALIYUN_IP
    read -p "请输入阿里云服务器用户名: " ALIYUN_USER
    
    # 创建 SSH 隧道脚本
    cat > "$ROOT_DIR/config/penetration/ssh-tunnel/create-tunnel.sh" << 'SSH_EOF'
#!/bin/bash

# SSH 隧道创建脚本

ALIYUN_IP="ALIYUN_IP_PLACEHOLDER"
ALIYUN_USER="ALIYUN_USER_PLACEHOLDER"
SSH_KEY="/volume2/YC/config/ssh/id_rsa"

echo "🔗 创建 SSH 隧道到阿里云服务器..."

# 检查 SSH 密钥
if [ ! -f "$SSH_KEY" ]; then
    echo "🔑 生成 SSH 密钥..."
    mkdir -p "$(dirname "$SSH_KEY")"
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N ""
    
    echo "📋 请将以下公钥添加到阿里云服务器的 ~/.ssh/authorized_keys:"
    cat "${SSH_KEY}.pub"
    echo ""
    read -p "按回车键继续..."
fi

# 创建隧道
echo "🚇 建立 SSH 隧道..."

# 使用 autossh 确保连接稳定
if ! command -v autossh &> /dev/null; then
    echo "📦 安装 autossh..."
    # 这里需要根据系统安装 autossh
fi

# 创建多个端口转发
autossh -M 20000 -N -f \
    -o "ServerAliveInterval=30" \
    -o "ServerAliveCountMax=3" \
    -o "StrictHostKeyChecking=no" \
    -i "$SSH_KEY" \
    -R 8080:192.168.3.45:80 \
    -R 8081:192.168.3.45:8080 \
    -R 8082:192.168.3.45:3000 \
    -R 8083:192.168.3.45:8443 \
    -R 8084:192.168.3.45:3002 \
    -R 8085:192.168.3.45:9000 \
    "$ALIYUN_USER@$ALIYUN_IP"

if [ $? -eq 0 ]; then
    echo "✅ SSH 隧道创建成功！"
    echo ""
    echo "🌐 访问地址："
    echo "• 主控制台: http://$ALIYUN_IP:8080"
    echo "• GitLab: http://$ALIYUN_IP:8081"
    echo "• AI 服务: http://$ALIYUN_IP:8082"
    echo "• Code Server: http://$ALIYUN_IP:8083"
    echo "• 监控面板: http://$ALIYUN_IP:8084"
    echo "• 容器管理: http://$ALIYUN_IP:8085"
else
    echo "❌ SSH 隧道创建失败"
    exit 1
fi
SSH_EOF

    # 替换占位符
    sed -i "s/ALIYUN_IP_PLACEHOLDER/$ALIYUN_IP/g" "$ROOT_DIR/config/penetration/ssh-tunnel/create-tunnel.sh"
    sed -i "s/ALIYUN_USER_PLACEHOLDER/$ALIYUN_USER/g" "$ROOT_DIR/config/penetration/ssh-tunnel/create-tunnel.sh"
    
    # 创建隧道监控脚本
    cat > "$ROOT_DIR/config/penetration/ssh-tunnel/monitor-tunnel.sh" << 'MONITOR_EOF'
#!/bin/bash

# SSH 隧道监控脚本

ALIYUN_IP="ALIYUN_IP_PLACEHOLDER"
ALIYUN_USER="ALIYUN_USER_PLACEHOLDER"

check_tunnel() {
    echo "🔍 检查 SSH 隧道状态..."
    
    # 检查 autossh 进程
    if pgrep -f "autossh.*$ALIYUN_IP" > /dev/null; then
        echo "✅ SSH 隧道运行中"
        
        # 测试连接
        if curl -s --connect-timeout 5 "http://$ALIYUN_IP:8080" > /dev/null; then
            echo "✅ 隧道连接正常"
        else
            echo "⚠️ 隧道连接异常，尝试重启..."
            restart_tunnel
        fi
    else
        echo "❌ SSH 隧道未运行，启动隧道..."
        /volume2/YC/config/penetration/ssh-tunnel/create-tunnel.sh
    fi
}

restart_tunnel() {
    echo "🔄 重启 SSH 隧道..."
    
    # 停止现有隧道
    pkill -f "autossh.*$ALIYUN_IP"
    sleep 5
    
    # 重新创建隧道
    /volume2/YC/config/penetration/ssh-tunnel/create-tunnel.sh
}

show_status() {
    echo "📊 SSH 隧道状态报告"
    echo "==================="
    echo "时间: $(date)"
    echo ""
    
    # 进程状态
    if pgrep -f "autossh.*$ALIYUN_IP" > /dev/null; then
        echo "🔗 隧道状态: 运行中"
        echo "📈 进程ID: $(pgrep -f "autossh.*$ALIYUN_IP")"
    else
        echo "🔗 隧道状态: 未运行"
    fi
    
    # 连接测试
    echo ""
    echo "🌐 连接测试:"
    services=("8080:主控制台" "8081:GitLab" "8082:AI服务" "8083:Code Server" "8084:监控面板")
    
    for service in "${services[@]}"; do
        IFS=':' read -r port name <<< "$service"
        if curl -s --connect-timeout 3 "http://$ALIYUN_IP:$port" > /dev/null; then
            echo "✅ $name (端口 $port) - 可访问"
        else
            echo "❌ $name (端口 $port) - 不可访问"
        fi
    done
}

case "$1" in
    "check")
        check_tunnel
        ;;
    "restart")
        restart_tunnel
        ;;
    "status")
        show_status
        ;;
    "stop")
        echo "⏹️ 停止 SSH 隧道..."
        pkill -f "autossh.*$ALIYUN_IP"
        echo "✅ SSH 隧道已停止"
        ;;
    *)
        echo "🔗 SSH 隧道管理工具"
        echo "=================="
        echo "用法: $0 {check|restart|status|stop}"
        echo ""
        echo "命令说明:"
        echo "  check   - 检查并自动修复隧道"
        echo "  restart - 重启隧道"
        echo "  status  - 显示详细状态"
        echo "  stop    - 停止隧道"
        ;;
esac
MONITOR_EOF

    # 替换占位符
    sed -i "s/ALIYUN_IP_PLACEHOLDER/$ALIYUN_IP/g" "$ROOT_DIR/config/penetration/ssh-tunnel/monitor-tunnel.sh"
    sed -i "s/ALIYUN_USER_PLACEHOLDER/$ALIYUN_USER/g" "$ROOT_DIR/config/penetration/ssh-tunnel/monitor-tunnel.sh"
    
    chmod +x "$ROOT_DIR/config/penetration/ssh-tunnel/create-tunnel.sh"
    chmod +x "$ROOT_DIR/config/penetration/ssh-tunnel/monitor-tunnel.sh"
    
    # 创建阿里云服务器 Nginx 配置
    cat > "$ROOT_DIR/config/penetration/ssh-tunnel/aliyun-nginx.conf" << 'ALIYUN_NGINX_EOF'
# 阿里云服务器 Nginx 配置
# 将此配置添加到 /etc/nginx/conf.d/yc-tunnel.conf

upstream yc_main {
    server 127.0.0.1:8080;
}

upstream yc_gitlab {
    server 127.0.0.1:8081;
}

upstream yc_ai {
    server 127.0.0.1:8082;
}

upstream yc_code {
    server 127.0.0.1:8083;
}

upstream yc_monitor {
    server 127.0.0.1:8084;
}

server {
    listen 80 default_server;
    server_name _;
    
    # 主控制台
    location / {
        proxy_pass http://yc_main;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # GitLab
    location /gitlab/ {
        proxy_pass http://yc_gitlab/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # AI 服务
    location /ai/ {
        proxy_pass http://yc_ai/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Code Server
    location /code/ {
        proxy_pass http://yc_code/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # 监控面板
    location /monitor/ {
        proxy_pass http://yc_monitor/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
ALIYUN_NGINX_EOF

    # 创建自动启动脚本
    cat > "$ROOT_DIR/config/penetration/ssh-tunnel/auto-start.sh" << 'AUTO_EOF'
#!/bin/bash

# SSH 隧道自动启动脚本

# 添加到 crontab
echo "⏰ 设置自动启动..."

# 备份当前 crontab
crontab -l > /tmp/current_cron 2>/dev/null || touch /tmp/current_cron

# 添加监控任务
cat >> /tmp/current_cron << 'CRON_EOF'
# SSH 隧道自动监控
*/5 * * * * /volume2/YC/config/penetration/ssh-tunnel/monitor-tunnel.sh check >> /volume1/YC/archives/logs/tunnel.log 2>&1
@reboot sleep 60 && /volume2/YC/config/penetration/ssh-tunnel/create-tunnel.sh
CRON_EOF

# 安装新的 crontab
crontab /tmp/current_cron
rm /tmp/current_cron

echo "✅ 自动启动配置完成"
echo "🔄 隧道将每5分钟检查一次"
echo "🚀 系统重启后自动建立隧道"
AUTO_EOF

    chmod +x "$ROOT_DIR/config/penetration/ssh-tunnel/auto-start.sh"
    
    log_success "SSH 隧道方案配置完成"
    echo "📁 配置目录: $ROOT_DIR/config/penetration/ssh-tunnel/"
    echo "🔧 下一步:"
    echo "1. 执行 create-tunnel.sh 创建隧道"
    echo "2. 在阿里云服务器配置 Nginx"
    echo "3. 执行 auto-start.sh 设置自动启动"
}

# 方案3: WireGuard VPN
setup_wireguard_vpn() {
    log_step "配置 WireGuard VPN 方案..."
    
    mkdir -p "$ROOT_DIR/config/penetration/wireguard"
    
    read -p "请输入阿里云服务器IP: " ALIYUN_IP
    
    # 生成密钥
    PRIVATE_KEY=$(wg genkey)
    PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)
    SERVER_PRIVATE_KEY=$(wg genkey)
    SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)
    
    # 创建客户端配置
    cat > "$ROOT_DIR/config/penetration/wireguard/wg0.conf" << WG_CLIENT_EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $ALIYUN_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
WG_CLIENT_EOF

    # 创建服务端配置
    cat > "$ROOT_DIR/config/penetration/wireguard/server-wg0.conf" << WG_SERVER_EOF
# 在阿里云服务器上使用此配置
# 路径: /etc/wireguard/wg0.conf

[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $PUBLIC_KEY
AllowedIPs = 10.0.0.2/32
WG_SERVER_EOF

    # 创建 Docker Compose 配置
    cat > "$ROOT_DIR/config/penetration/wireguard/docker-compose.yml" << 'WG_DOCKER_EOF'
version: '3.8'

services:
  wireguard:
    image: linuxserver/wireguard:latest
    container_name: yc-wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
    volumes:
      - ./wg0.conf:/config/wg0.conf
      - /lib/modules:/lib/modules
    ports:
      - "51820:51820/udp"
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
WG_DOCKER_EOF

    # 创建阿里云服务器安装脚本
    cat > "$ROOT_DIR/config/penetration/wireguard/aliyun-install.sh" << 'WG_INSTALL_EOF'
#!/bin/bash

# 在阿里云服务器上执行此脚本

echo "🛡️ 安装 WireGuard VPN 服务器..."

# 1. 安装 WireGuard
if command -v yum &> /dev/null; then
    # CentOS/RHEL
    yum install -y epel-release
    yum install -y wireguard-tools
elif command -v apt &> /dev/null; then
    # Ubuntu/Debian
    apt update
    apt install -y wireguard
fi

# 2. 启用 IP 转发
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# 3. 配置防火墙
if command -v firewall-cmd &> /dev/null; then
    # CentOS/RHEL
    firewall-cmd --permanent --add-port=51820/udp
    firewall-cmd --permanent --add-masquerade
    firewall-cmd --reload
elif command -v ufw &> /dev/null; then
    # Ubuntu/Debian
    ufw allow 51820/udp
    ufw --force enable
fi

# 4. 复制配置文件
echo "📝 请将 server-wg0.conf 内容复制到 /etc/wireguard/wg0.conf"
echo "然后执行以下命令启动 WireGuard:"
echo ""
echo "systemctl enable wg-quick@wg0"
echo "systemctl start wg-quick@wg0"
echo ""
echo "🔍 检查状态:"
echo "systemctl status wg-quick@wg0"
echo "wg show"
WG_INSTALL_EOF

    chmod +x "$ROOT_DIR/config/penetration/wireguard/aliyun-install.sh"
    
    # 创建连接脚本
    cat > "$ROOT_DIR/config/penetration/wireguard/connect.sh" << 'WG_CONNECT_EOF'
#!/bin/bash

# WireGuard 连接管理脚本

case "$1" in
    "start")
        echo "🚀 启动 WireGuard VPN..."
        docker-compose up -d
        sleep 5
        echo "✅ WireGuard 已启动"
        echo "🌐 VPN IP: 10.0.0.2"
        ;;
    "stop")
        echo "⏹️ 停止 WireGuard VPN..."
        docker-compose down
        echo "✅ WireGuard 已停止"
        ;;
    "status")
        echo "📊 WireGuard 状态:"
        if docker ps | grep -q yc-wireguard; then
            echo "✅ WireGuard 运行中"
            docker exec yc-wireguard wg show 2>/dev/null || echo "无法获取详细状态"
        else
            echo "❌ WireGuard 未运行"
        fi
        ;;
    "test")
        echo "🧪 测试 VPN 连接..."
        if ping -c 3 10.0.0.1 > /dev/null; then
            echo "✅ VPN 连接正常"
        else
            echo "❌ VPN 连接失败"
        fi
        ;;
    *)
        echo "🛡️ WireGuard VPN 管理工具"
        echo "========================"
        echo "用法: $0 {start|stop|status|test}"
        echo ""
        echo "命令说明:"
        echo "  start  - 启动 VPN"
        echo "  stop   - 停止 VPN"
        echo "  status - 查看状态"
        echo "  test   - 测试连接"
        ;;
esac
WG_CONNECT_EOF

    chmod +x "$ROOT_DIR/config/penetration/wireguard/connect.sh"
    
    # 保存密钥信息
    cat > "$ROOT_DIR/config/penetration/wireguard/keys.txt" << KEY_EOF
WireGuard 密钥信息
================

客户端 (NAS):
Private Key: $PRIVATE_KEY
Public Key: $PUBLIC_KEY

服务端 (阿里云):
Private Key: $SERVER_PRIVATE_KEY
Public Key: $SERVER_PUBLIC_KEY

网络配置:
服务端 IP: 10.0.0.1/24
客户端 IP: 10.0.0.2/24
监听端口: 51820/udp
KEY_EOF

    log_success "WireGuard VPN 方案配置完成"
    echo "📁 配置目录: $ROOT_DIR/config/penetration/wireguard/"
    echo "🔧 下一步:"
    echo "1. 在阿里云服务器执行 aliyun-install.sh"
    echo "2. 配置服务端 WireGuard"
    echo "3. 执行 connect.sh start 启动客户端"
}

# 方案对比分析
show_comparison_analysis() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    📊 内网穿透方案对比分析
    ========================
EOF
    echo -e "${NC}"
    echo ""
    
    echo "| 方案 | 性能 | 稳定性 | 安全性 | 配置难度 | 维护成本 | 推荐指数 |"
    echo "|------|------|--------|--------|----------|----------|----------|"
    echo "| 反向代理+SSL | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |"
    echo "| SSH隧道+Nginx | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |"
    echo "| WireGuard VPN | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |"
    echo ""
    
    echo -e "${GREEN}🚀 方案1: 反向代理 + SSL (推荐)${NC}"
    echo "优势:"
    echo "• 性能最佳，直接代理无额外开销"
    echo "• 支持多域名，访问地址友好"
    echo "• 自动 HTTPS，安全性高"
    echo "• 支持 CDN 加速"
    echo ""
    echo "劣势:"
    echo "• 需要域名和 SSL 证书"
    echo "• 配置相对复杂"
    echo ""
    
    echo -e "${BLUE}🔗 方案2: SSH 隧道 + Nginx${NC}"
    echo "优势:"
    echo "• 配置简单，快速部署"
    echo "• 无需域名，使用 IP 访问"
    echo "• 自动重连机制"
    echo ""
    echo "劣势:"
    echo "• 性能略低于直接代理"
    echo "• 依赖 SSH 连接稳定性"
    echo "• 端口访问不够友好"
    echo ""
    
    echo -e "${PURPLE}🛡️ 方案3: WireGuard VPN${NC}"
    echo "优势:"
    echo "• 安全性最高，端到端加密"
    echo "• 性能优秀，现代化协议"
    echo "• 支持移动端"
    echo ""
    echo "劣势:"
    echo "• 需要客户端软件"
    echo "• 配置相对复杂"
    echo "• 不适合公开访问"
    echo ""
    
    echo -e "${YELLOW}💡 选择建议：${NC}"
    echo "• 🏢 企业/团队使用: 反向代理 + SSL"
    echo "• 🚀 快速测试: SSH 隧道"
    echo "• 🔒 高安全要求: WireGuard VPN"
    echo "• 👥 多人协作: 反向代理 + SSL"
    echo "• 📱 移动办公: WireGuard VPN"
    echo ""
    
    read -p "按回车键返回主菜单..."
}

# 创建统一管理脚本
create_penetration_manager() {
    log_step "创建内网穿透管理器..."
    
    cat > "$ROOT_DIR/config/scripts/local-server-manager.sh" << 'MANAGER_EOF'
#!/bin/bash

# 本地服务器内网穿透管理器

ROOT_DIR="/volume2/YC"

show_menu() {
    echo "🌐 本地服务器穿透管理器"
    echo "======================"
    echo "1. 启动反向代理方案"
    echo "2. 启动 SSH 隧道方案"
    echo "3. 启动 WireGuard VPN"
    echo "4. 查看连接状态"
    echo "5. 测试外网访问"
    echo "6. 查看访问日志"
    echo "7. 重启穿透服务"
    echo "8. 停止所有穿透"
    echo "9. 性能监控"
    echo "0. 退出"
    echo "======================"
}

start_reverse_proxy() {
    echo "🚀 启动反向代理方案..."
    
    if [ -f "$ROOT_DIR/config/penetration/reverse-proxy/local-setup.sh" ]; then
        "$ROOT_DIR/config/penetration/reverse-proxy/local-setup.sh"
        echo "✅ 反向代理方案已启动"
        echo "🌐 请确保阿里云服务器已配置完成"
    else
        echo "❌ 反向代理配置不存在，请先运行配置脚本"
    fi
}

start_ssh_tunnel() {
    echo "🔗 启动 SSH 隧道方案..."
    
    if [ -f "$ROOT_DIR/config/penetration/ssh-tunnel/create-tunnel.sh" ]; then
        "$ROOT_DIR/config/penetration/ssh-tunnel/create-tunnel.sh"
        echo "✅ SSH 隧道已启动"
    else
        echo "❌ SSH 隧道配置不存在，请先运行配置脚本"
    fi
}

start_wireguard() {
    echo "🛡️ 启动 WireGuard VPN..."
    
    if [ -f "$ROOT_DIR/config/penetration/wireguard/connect.sh" ]; then
        "$ROOT_DIR/config/penetration/wireguard/connect.sh" start
        echo "✅ WireGuard VPN 已启动"
    else
        echo "❌ WireGuard 配置不存在，请先运行配置脚本"
    fi
}

show_status() {
    echo "📊 穿透连接状态："
    echo "================"
    
    # 检查反向代理
    if docker ps | grep -q yc-nginx; then
        echo "✅ Nginx 反向代理 - 运行中"
    else
        echo "❌ Nginx 反向代理 - 未运行"
    fi
    
    # 检查 SSH 隧道
    if pgrep -f "autossh.*" > /dev/null; then
        echo "✅ SSH 隧道 - 运行中"
    else
        echo "❌ SSH 隧道 - 未运行"
    fi
    
    # 检查 WireGuard
    if docker ps | grep -q yc-wireguard; then
        echo "✅ WireGuard VPN - 运行中"
    else
        echo "❌ WireGuard VPN - 未运行"
    fi
}

test_external_access() {
    echo "🧪 测试外网访问..."
    
    read -p "请输入要测试的外网地址 (如: https://yourdomain.com): " TEST_URL
    
    if curl -s --connect-timeout 10 "$TEST_URL" > /dev/null; then
        echo "✅ 外网访问正常"
        
        # 测试响应时间
        RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" "$TEST_URL")
        echo "⏱️ 响应时间: ${RESPONSE_TIME}s"
    else
        echo "❌ 外网访问失败"
        echo "💡 请检查:"
        echo "  1. 穿透服务是否正常运行"
        echo "  2. 阿里云服务器配置是否正确"
        echo "  3. 域名解析是否生效"
        echo "  4. 防火墙设置是否正确"
    fi
}

show_access_logs() {
    echo "📋 访问日志："
    echo "============"
    
    # Nginx 访问日志
    if [ -f "/volume2/YC/logs/nginx/access.log" ]; then
        echo "🌐 Nginx 访问日志 (最近10条):"
        tail -10 /volume2/YC/logs/nginx/access.log
    fi
    
    # SSH 隧道日志
    if [ -f "/volume1/YC/archives/logs/tunnel.log" ]; then
        echo ""
        echo "🔗 SSH 隧道日志 (最近10条):"
        tail -10 /volume1/YC/archives/logs/tunnel.log
    fi
}

restart_services() {
    echo "🔄 重启穿透服务..."
    
    # 重启 Nginx
    docker restart yc-nginx 2>/dev/null
    
    # 重启 SSH 隧道
    if [ -f "$ROOT_DIR/config/penetration/ssh-tunnel/monitor-tunnel.sh" ]; then
        "$ROOT_DIR/config/penetration/ssh-tunnel/monitor-tunnel.sh" restart
    fi
    
    # 重启 WireGuard
    if [ -f "$ROOT_DIR/config/penetration/wireguard/connect.sh" ]; then
        "$ROOT_DIR/config/penetration/wireguard/connect.sh" stop
        sleep 3
        "$ROOT_DIR/config/penetration/wireguard/connect.sh" start
    fi
    
    echo "✅ 穿透服务重启完成"
}

stop_all() {
    echo "⏹️ 停止所有穿透服务..."
    
    # 停止 SSH 隧道
    pkill -f "autossh"
    
    # 停止 WireGuard
    if [ -f "$ROOT_DIR/config/penetration/wireguard/connect.sh" ]; then
        "$ROOT_DIR/config/penetration/wireguard/connect.sh" stop
    fi
    
    echo "✅ 所有穿透服务已停止"
}

show_performance() {
    echo "📈 性能监控："
    echo "============"
    
    # 网络连接数
    echo "🌐 网络连接数:"
    netstat -an | grep ESTABLISHED | wc -l
    
    # 带宽使用
    echo ""
    echo "📊 网络接口状态:"
    cat /proc/net/dev | grep -E "(eth0|ens|enp)" | head -3
    
    # 系统负载
    echo ""
    echo "⚡ 系统负载:"
    uptime
}

# 主循环
while true; do
    show_menu
    read -p "请选择操作 (0-9): " choice
    
    case $choice in
        1) start_reverse_proxy ;;
        2) start_ssh_tunnel ;;
        3) start_wireguard ;;
        4) show_status ;;
        5) test_external_access ;;
        6) show_access_logs ;;
        7) restart_services ;;
        8) stop_all ;;
        9) show_performance ;;
        0) echo "👋 再见！"; exit 0 ;;
        *) echo "❌ 无效选择，请重新输入" ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
    clear
done
MANAGER_EOF

    chmod +x "$ROOT_DIR/config/scripts/local-server-manager.sh"
    
    log_success "内网穿透管理器创建完成"
}

# 主函数
main() {
    while true; do
        show_penetration_solutions
        read -p "请选择方案 (0-4): " choice
        
        case $choice in
            1) setup_reverse_proxy ;;
            2) setup_ssh_tunnel ;;
            3) setup_wireguard_vpn ;;
            4) show_comparison_analysis; continue ;;
            0) echo "👋 配置已取消"; exit 0 ;;
            *) echo "❌ 无效选择，请重新输入"; continue ;;
        esac
        
        break
    done
    
    create_penetration_manager
    
    echo ""
    log_success "本地服务器穿透配置完成！"
    echo ""
    echo "🛠️ 管理工具: $ROOT_DIR/config/scripts/local-server-manager.sh"
    echo ""
    echo "📋 配置总结："
    echo "• 配置文件已生成到对应目录"
    echo "• 请按照说明配置阿里云服务器"
    echo "• 使用管理工具启动和监控服务"
    echo ""
    
    read -p "是否立即启动穿透管理器？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$ROOT_DIR/config/scripts/local-server-manager.sh"
    fi
}

# 执行主函数
main "$@"
