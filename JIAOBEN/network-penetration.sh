#!/bin/bash

# YYC 开发环境内网穿透配置脚本

ROOT_DIR="/volume1/YC"
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

# 显示穿透方案选择
show_penetration_options() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    🌐 YC 内网穿透解决方案
    =====================
EOF
    echo -e "${NC}"
    echo ""
    echo "请选择内网穿透方案："
    echo ""
    echo "1. 🚀 frp (推荐) - 高性能、稳定可靠"
    echo "2. 🔗 ngrok - 简单易用、快速部署"
    echo "3. ⚡ nps - 轻量级、功能丰富"
    echo "4. 🌟 ZeroTier - P2P组网、安全性高"
    echo "5. 🔧 Tailscale - 现代化VPN、零配置"
    echo "6. 🏠 自建方案 - 完全自主控制"
    echo "7. 📋 查看方案对比"
    echo "0. ❌ 退出"
    echo ""
}

# 显示方案对比
show_comparison() {
    echo ""
    log_highlight "内网穿透方案对比"
    echo "=================="
    echo ""
    echo "| 方案      | 免费额度    | 稳定性 | 速度   | 安全性 | 配置难度 |"
    echo "|-----------|-------------|--------|--------|--------|----------|"
    echo "| frp       | 无限制      | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐   | ⭐⭐⭐     |"
    echo "| ngrok     | 1个隧道     | ⭐⭐⭐⭐   | ⭐⭐⭐⭐   | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐   |"
    echo "| nps       | 无限制      | ⭐⭐⭐⭐   | ⭐⭐⭐⭐   | ⭐⭐⭐     | ⭐⭐⭐     |"
    echo "| ZeroTier  | 25设备      | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐   |"
    echo "| Tailscale | 20设备      | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐   |"
    echo "| 自建方案  | 无限制      | ⭐⭐⭐     | ⭐⭐⭐⭐   | ⭐⭐⭐⭐⭐ | ⭐⭐       |"
    echo ""
    echo "💡 推荐选择："
    echo "• 个人开发: Tailscale 或 ZeroTier"
    echo "• 团队协作: frp 或 ngrok"
    echo "• 企业使用: 自建方案"
    echo ""
    read -p "按回车键返回..."
}

# 配置 frp
setup_frp() {
    log_step "配置 frp 内网穿透..."
    
    mkdir -p "$ROOT_DIR/services/frp"
    
    # 创建 frp 客户端配置
    cat > "$ROOT_DIR/services/frp/frpc.ini" << 'EOF'
[common]
server_addr = YOUR_SERVER_IP
server_port = 7000
token = YOUR_TOKEN

[yc-web]
type = http
local_ip = 192.168.3.45
local_port = 80
custom_domains = yc.yourdomain.com

[yc-gitlab]
type = http
local_ip = 192.168.3.45
local_port = 8080
custom_domains = gitlab.yourdomain.com

[yc-ai]
type = http
local_ip = 192.168.3.45
local_port = 3000
custom_domains = ai.yourdomain.com

[yc-code]
type = http
local_ip = 192.168.3.45
local_port = 8443
custom_domains = code.yourdomain.com

[yc-monitor]
type = http
local_ip = 192.168.3.45
local_port = 3002
custom_domains = monitor.yourdomain.com

[yc-ssh]
type = tcp
local_ip = 192.168.3.45
local_port = 22
remote_port = 6000
EOF

    # 创建 frp 服务端配置（用于自建服务器）
    cat > "$ROOT_DIR/services/frp/frps.ini" << 'EOF'
[common]
bind_port = 7000
token = YOUR_TOKEN
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin123

# HTTP 服务配置
vhost_http_port = 80
vhost_https_port = 443

# 日志配置
log_file = ./frps.log
log_level = info
log_max_days = 3
EOF

    # 创建 Docker Compose 配置
    cat > "$ROOT_DIR/services/frp/docker-compose.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  frpc:
    image: snowdreamtech/frpc:latest
    container_name: yc-frpc
    volumes:
      - ./frpc.ini:/etc/frp/frpc.ini
    command: frpc -c /etc/frp/frpc.ini
    networks:
      - yc-dev-network
    restart: unless-stopped
    depends_on:
      - nginx

  # 如果需要自建 frp 服务端
  frps:
    image: snowdreamtech/frps:latest
    container_name: yc-frps
    ports:
      - "7000:7000"
      - "7500:7500"
      - "80:80"
      - "443:443"
    volumes:
      - ./frps.ini:/etc/frp/frps.ini
    command: frps -c /etc/frp/frps.ini
    restart: unless-stopped
    profiles:
      - server
EOF

    # 创建配置脚本
    cat > "$ROOT_DIR/services/frp/configure.sh" << 'EOF'
#!/bin/bash

echo "🔧 配置 frp 内网穿透"
echo "==================="

read -p "请输入 frp 服务器地址: " SERVER_ADDR
read -p "请输入 frp 服务器端口 (默认7000): " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-7000}
read -p "请输入认证令牌: " TOKEN
read -p "请输入您的域名 (如: yourdomain.com): " DOMAIN

# 更新配置文件
sed -i "s/YOUR_SERVER_IP/$SERVER_ADDR/g" frpc.ini
sed -i "s/7000/$SERVER_PORT/g" frpc.ini
sed -i "s/YOUR_TOKEN/$TOKEN/g" frpc.ini
sed -i "s/yourdomain.com/$DOMAIN/g" frpc.ini

echo "✅ frp 配置完成！"
echo ""
echo "🌐 访问地址："
echo "• 主控制台: http://yc.$DOMAIN"
echo "• GitLab: http://gitlab.$DOMAIN"
echo "• AI 服务: http://ai.$DOMAIN"
echo "• Code Server: http://code.$DOMAIN"
echo "• 监控面板: http://monitor.$DOMAIN"
echo ""
echo "🚀 启动命令: docker-compose up -d frpc"
EOF

    chmod +x "$ROOT_DIR/services/frp/configure.sh"
    
    log_success "frp 配置文件创建完成"
    echo "📁 配置目录: $ROOT_DIR/services/frp/"
    echo "🔧 运行配置: cd $ROOT_DIR/services/frp && ./configure.sh"
}

# 配置 ngrok
setup_ngrok() {
    log_step "配置 ngrok 内网穿透..."
    
    mkdir -p "$ROOT_DIR/services/ngrok"
    
    # 创建 ngrok 配置
    cat > "$ROOT_DIR/services/ngrok/ngrok.yml" << 'EOF'
version: "2"
authtoken: YOUR_NGROK_TOKEN

tunnels:
  yc-web:
    proto: http
    addr: 192.168.3.45:80
    subdomain: yc-dev
    
  yc-gitlab:
    proto: http
    addr: 192.168.3.45:8080
    subdomain: yc-gitlab
    
  yc-ai:
    proto: http
    addr: 192.168.3.45:3000
    subdomain: yc-ai
    
  yc-code:
    proto: http
    addr: 192.168.3.45:8443
    subdomain: yc-code
    
  yc-ssh:
    proto: tcp
    addr: 192.168.3.45:22
EOF

    # 创建 Docker 配置
    cat > "$ROOT_DIR/services/ngrok/docker-compose.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  ngrok:
    image: ngrok/ngrok:latest
    container_name: yc-ngrok
    volumes:
      - ./ngrok.yml:/etc/ngrok.yml
    command: start --all --config /etc/ngrok.yml
    ports:
      - "4040:4040"  # ngrok web interface
    networks:
      - yc-dev-network
    restart: unless-stopped
EOF

    # 创建配置脚本
    cat > "$ROOT_DIR/services/ngrok/configure.sh" << 'EOF'
#!/bin/bash

echo "🔗 配置 ngrok 内网穿透"
echo "====================="

echo "1. 访问 https://ngrok.com 注册账户"
echo "2. 获取您的 authtoken"
echo ""
read -p "请输入您的 ngrok authtoken: " TOKEN

# 更新配置文件
sed -i "s/YOUR_NGROK_TOKEN/$TOKEN/g" ngrok.yml

echo "✅ ngrok 配置完成！"
echo ""
echo "🌐 访问地址："
echo "• 主控制台: https://yc-dev.ngrok.io"
echo "• GitLab: https://yc-gitlab.ngrok.io"
echo "• AI 服务: https://yc-ai.ngrok.io"
echo "• Code Server: https://yc-code.ngrok.io"
echo "• ngrok 管理: http://localhost:4040"
echo ""
echo "🚀 启动命令: docker-compose up -d"
EOF

    chmod +x "$ROOT_DIR/services/ngrok/configure.sh"
    
    log_success "ngrok 配置文件创建完成"
    echo "📁 配置目录: $ROOT_DIR/services/ngrok/"
    echo "🔧 运行配置: cd $ROOT_DIR/services/ngrok && ./configure.sh"
}

# 配置 ZeroTier
setup_zerotier() {
    log_step "配置 ZeroTier 组网..."
    
    mkdir -p "$ROOT_DIR/services/zerotier"
    
    # 创建 ZeroTier 配置
    cat > "$ROOT_DIR/services/zerotier/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  zerotier:
    image: zyclonedx/zerotier:latest
    container_name: yc-zerotier
    devices:
      - /dev/net/tun
    network_mode: host
    volumes:
      - /var/lib/zerotier-one:/var/lib/zerotier-one
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    restart: unless-stopped
    environment:
      - ZEROTIER_ONE_LOCAL_PHYS=eth0
      - ZEROTIER_ONE_USE_IPTABLES_NFT=false
EOF

    # 创建配置脚本
    cat > "$ROOT_DIR/services/zerotier/configure.sh" << 'EOF'
#!/bin/bash

echo "🌟 配置 ZeroTier 组网"
echo "==================="

echo "1. 访问 https://my.zerotier.com 注册账户"
echo "2. 创建一个新的网络"
echo "3. 获取网络ID"
echo ""
read -p "请输入您的 ZeroTier 网络ID: " NETWORK_ID

# 启动 ZeroTier
docker-compose up -d

# 等待服务启动
sleep 5

# 加入网络
docker exec yc-zerotier zerotier-cli join $NETWORK_ID

# 获取节点ID
NODE_ID=$(docker exec yc-zerotier zerotier-cli info | cut -d' ' -f3)

echo "✅ ZeroTier 配置完成！"
echo ""
echo "📋 重要信息："
echo "• 网络ID: $NETWORK_ID"
echo "• 节点ID: $NODE_ID"
echo ""
echo "🔧 下一步操作："
echo "1. 访问 https://my.zerotier.com"
echo "2. 进入您的网络管理页面"
echo "3. 在 Members 中找到节点 $NODE_ID"
echo "4. 勾选 Auth 授权该节点"
echo "5. 记录分配的虚拟IP地址"
echo ""
echo "🌐 完成后可通过虚拟IP访问服务"
EOF

    chmod +x "$ROOT_DIR/services/zerotier/configure.sh"
    
    log_success "ZeroTier 配置文件创建完成"
    echo "📁 配置目录: $ROOT_DIR/services/zerotier/"
    echo "🔧 运行配置: cd $ROOT_DIR/services/zerotier && ./configure.sh"
}

# 配置 Tailscale
setup_tailscale() {
    log_step "配置 Tailscale VPN..."
    
    mkdir -p "$ROOT_DIR/services/tailscale"
    
    # 创建 Tailscale 配置
    cat > "$ROOT_DIR/services/tailscale/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  tailscale:
    image: tailscale/tailscale:latest
    container_name: yc-tailscale
    hostname: yc-nas
    environment:
      - TS_AUTHKEY=${TS_AUTHKEY}
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_USERSPACE=false
    volumes:
      - /var/lib/tailscale:/var/lib/tailscale
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    restart: unless-stopped
    network_mode: host
EOF

    # 创建配置脚本
    cat > "$ROOT_DIR/services/tailscale/configure.sh" << 'EOF'
#!/bin/bash

echo "🔧 配置 Tailscale VPN"
echo "==================="

echo "1. 访问 https://tailscale.com 注册账户"
echo "2. 进入 Settings > Keys"
echo "3. 生成一个 Auth Key"
echo ""
read -p "请输入您的 Tailscale Auth Key: " AUTH_KEY

# 创建环境变量文件
cat > .env << ENV_EOF
TS_AUTHKEY=$AUTH_KEY
ENV_EOF

# 启动 Tailscale
docker-compose up -d

# 等待连接
echo "⏳ 等待 Tailscale 连接..."
sleep 10

# 获取状态
docker exec yc-tailscale tailscale status

echo "✅ Tailscale 配置完成！"
echo ""
echo "🌐 访问方式："
echo "1. 在其他设备上安装 Tailscale"
echo "2. 使用相同账户登录"
echo "3. 通过 Tailscale IP 访问服务"
echo ""
echo "🔧 管理命令："
echo "• 查看状态: docker exec yc-tailscale tailscale status"
echo "• 查看IP: docker exec yc-tailscale tailscale ip"
echo "• 退出网络: docker exec yc-tailscale tailscale logout"
EOF

    chmod +x "$ROOT_DIR/services/tailscale/configure.sh"
    
    log_success "Tailscale 配置文件创建完成"
    echo "📁 配置目录: $ROOT_DIR/services/tailscale/"
    echo "🔧 运行配置: cd $ROOT_DIR/services/tailscale && ./configure.sh"
}

# 配置自建方案
setup_custom() {
    log_step "配置自建内网穿透方案..."
    
    mkdir -p "$ROOT_DIR/services/custom-tunnel"
    
    # 创建基于 SSH 的简单穿透
    cat > "$ROOT_DIR/services/custom-tunnel/ssh-tunnel.sh" << 'EOF'
#!/bin/bash

# SSH 隧道穿透脚本

SERVER_IP="YOUR_SERVER_IP"
SERVER_USER="YOUR_USERNAME"
SSH_KEY="$HOME/.ssh/id_rsa"

echo "🔗 建立 SSH 隧道..."

# 创建多个端口转发
ssh -N -R 8080:192.168.3.45:80 \
    -R 8081:192.168.3.45:8080 \
    -R 8082:192.168.3.45:3000 \
    -R 8083:192.168.3.45:8443 \
    -R 8084:192.168.3.45:3002 \
    -i $SSH_KEY \
    $SERVER_USER@$SERVER_IP
EOF

    # 创建 WireGuard VPN 配置
    cat > "$ROOT_DIR/services/custom-tunnel/wireguard.conf" << 'EOF'
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = YOUR_SERVER_PUBLIC_KEY
Endpoint = YOUR_SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    # 创建 Docker 配置
    cat > "$ROOT_DIR/services/custom-tunnel/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  # WireGuard VPN
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
      - ./wireguard.conf:/config/wg0.conf
      - /lib/modules:/lib/modules
    ports:
      - "51820:51820/udp"
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
    profiles:
      - wireguard

  # 简单的 HTTP 代理
  http-proxy:
    image: nginx:alpine
    container_name: yc-http-proxy
    ports:
      - "8080:80"
    volumes:
      - ./nginx-proxy.conf:/etc/nginx/nginx.conf
    restart: unless-stopped
    profiles:
      - proxy
EOF

    # 创建 Nginx 代理配置
    cat > "$ROOT_DIR/services/custom-tunnel/nginx-proxy.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream yc_backend {
        server 192.168.3.45:80;
    }
    
    upstream yc_gitlab {
        server 192.168.3.45:8080;
    }
    
    upstream yc_ai {
        server 192.168.3.45:3000;
    }
    
    server {
        listen 80;
        server_name _;
        
        location / {
            proxy_pass http://yc_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        location /gitlab/ {
            proxy_pass http://yc_gitlab/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        location /ai/ {
            proxy_pass http://yc_ai/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

    chmod +x "$ROOT_DIR/services/custom-tunnel/ssh-tunnel.sh"
    
    log_success "自建方案配置文件创建完成"
    echo "📁 配置目录: $ROOT_DIR/services/custom-tunnel/"
    echo "🔧 SSH隧道: 修改 ssh-tunnel.sh 中的服务器信息"
    echo "🔧 WireGuard: 修改 wireguard.conf 中的密钥信息"
}

# 创建统一管理脚本
create_tunnel_manager() {
    log_step "创建内网穿透管理器..."
    
    cat > "$ROOT_DIR/development/scripts/tunnel-manager.sh" << 'EOF'
#!/bin/bash

# 内网穿透管理器

ROOT_DIR="/volume1/YC"

show_menu() {
    echo "🌐 YC 内网穿透管理器"
    echo "==================="
    echo "1. 启动 frp 客户端"
    echo "2. 启动 ngrok"
    echo "3. 启动 ZeroTier"
    echo "4. 启动 Tailscale"
    echo "5. 启动自建隧道"
    echo "6. 查看隧道状态"
    echo "7. 停止所有隧道"
    echo "8. 查看访问地址"
    echo "0. 退出"
    echo "==================="
}

start_frp() {
    echo "🚀 启动 frp 客户端..."
    cd "$ROOT_DIR/services/frp"
    docker-compose up -d frpc
    echo "✅ frp 客户端已启动"
}

start_ngrok() {
    echo "🔗 启动 ngrok..."
    cd "$ROOT_DIR/services/ngrok"
    docker-compose up -d
    echo "✅ ngrok 已启动"
    echo "🌐 管理界面: http://localhost:4040"
}

start_zerotier() {
    echo "🌟 启动 ZeroTier..."
    cd "$ROOT_DIR/services/zerotier"
    docker-compose up -d
    echo "✅ ZeroTier 已启动"
}

start_tailscale() {
    echo "🔧 启动 Tailscale..."
    cd "$ROOT_DIR/services/tailscale"
    docker-compose up -d
    echo "✅ Tailscale 已启动"
}

start_custom() {
    echo "🏠 启动自建隧道..."
    cd "$ROOT_DIR/services/custom-tunnel"
    echo "请选择隧道类型："
    echo "1. SSH 隧道"
    echo "2. WireGuard VPN"
    echo "3. HTTP 代理"
    read -p "选择 (1-3): " choice
    
    case $choice in
        1) ./ssh-tunnel.sh & ;;
        2) docker-compose --profile wireguard up -d ;;
        3) docker-compose --profile proxy up -d ;;
    esac
    echo "✅ 自建隧道已启动"
}

show_status() {
    echo "📊 隧道状态："
    echo "============="
    
    # 检查各种隧道服务
    services=("yc-frpc" "yc-ngrok" "yc-zerotier" "yc-tailscale" "yc-wireguard" "yc-http-proxy")
    
    for service in "${services[@]}"; do
        if docker ps | grep -q "$service"; then
            echo "✅ $service - 运行中"
        else
            echo "❌ $service - 未运行"
        fi
    done
    
    # 检查 SSH 隧道
    if pgrep -f "ssh.*192.168.3.45" > /dev/null; then
        echo "✅ SSH隧道 - 运行中"
    else
        echo "❌ SSH隧道 - 未运行"
    fi
}

stop_all() {
    echo "⏹️ 停止所有隧道..."
    
    # 停止 Docker 服务
    docker stop yc-frpc yc-ngrok yc-zerotier yc-tailscale yc-wireguard yc-http-proxy 2>/dev/null
    
    # 停止 SSH 隧道
    pkill -f "ssh.*1192.168.3.45
    
    echo "✅ 所有隧道已停止"
}

show_access_urls() {
    echo "🌐 访问地址："
    echo "============"
    
    if docker ps | grep -q "yc-frpc"; then
        echo "📡 frp 访问地址："
        echo "  • 主控制台: http://yc.yourdomain.com"
        echo "  • GitLab: http://gitlab.yourdomain.com"
        echo "  • AI 服务: http://ai.yourdomain.com"
        echo ""
    fi
    
    if docker ps | grep -q "yc-ngrok"; then
        echo "🔗 ngrok 访问地址："
        echo "  • 主控制台: https://yc-dev.ngrok.io"
        echo "  • GitLab: https://yc-gitlab.ngrok.io"
        echo "  • AI 服务: https://yc-ai.ngrok.io"
        echo "  • 管理界面: http://localhost:4040"
        echo ""
    fi
    
    if docker ps | grep -q "yc-zerotier"; then
        ZEROTIER_IP=$(docker exec yc-zerotier ip addr show zt0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
        if [ -n "$ZEROTIER_IP" ]; then
            echo "🌟 ZeroTier 访问地址："
            echo "  • 虚拟IP: $ZEROTIER_IP"
            echo "  • 主控制台: http://$ZEROTIER_IP"
            echo ""
        fi
    fi
    
    if docker ps | grep -q "yc-tailscale"; then
        TAILSCALE_IP=$(docker exec yc-tailscale tailscale ip 2>/dev/null | head -1)
        if [ -n "$TAILSCALE_IP" ]; then
            echo "🔧 Tailscale 访问地址："
            echo "  • Tailscale IP: $TAILSCALE_IP"
            echo "  • 主控制台: http://$TAILSCALE_IP"
            echo ""
        fi
    fi
}

# 主循环
while true; do
    show_menu
    read -p "请选择操作 (0-8): " choice
    
    case $choice in
        1) start_frp ;;
        2) start_ngrok ;;
        3) start_zerotier ;;
        4) start_tailscale ;;
        5) start_custom ;;
        6) show_status ;;
        7) stop_all ;;
        8) show_access_urls ;;
        0) echo "👋 再见！"; exit 0 ;;
        *) echo "❌ 无效选择，请重新输入" ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
    clear
done
EOF

    chmod +x "$ROOT_DIR/development/scripts/tunnel-manager.sh"
    
    log_success "内网穿透管理器创建完成"
}

# 主函数
main() {
    while true; do
        show_penetration_options
        read -p "请选择方案 (0-7): " choice
        
        case $choice in
            1) setup_frp ;;
            2) setup_ngrok ;;
            3) setup_nps ;;
            4) setup_zerotier ;;
            5) setup_tailscale ;;
            6) setup_custom ;;
            7) show_comparison; continue ;;
            0) echo "👋 配置已取消"; exit 0 ;;
            *) echo "❌ 无效选择，请重新输入"; continue ;;
        esac
        
        break
    done
    
    create_tunnel_manager
    
    echo ""
    log_success "内网穿透配置完成！"
    echo ""
    echo "🛠️ 管理工具: $ROOT_DIR/development/scripts/tunnel-manager.sh"
    echo ""
    read -p "是否立即启动隧道管理器？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$ROOT_DIR/development/scripts/tunnel-manager.sh"
    fi
}

# 执行主函数
main "$@"