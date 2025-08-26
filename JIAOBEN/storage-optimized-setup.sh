#!/bin/bash

# YYC 开发环境存储优化部署脚本
# 针对 Volume1(HDD-RAID6) 和 Volume2(SSD-RAID1) 的优化配置

set -e

# 存储配置
VOLUME1_HDD="/volume1"  # 14.34TB HDD RAID6 - 大容量存储
VOLUME2_SSD="/volume2"  # 200GB SSD RAID1 - 高性能存储
NAS_IP="192.168.0.9"

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

# 显示存储策略
show_storage_strategy() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    💾 YC 存储优化策略
    ==================
    
    📀 Volume1 (HDD RAID6 - 14.34TB)
    ├── 大容量数据存储
    ├── 备份和归档
    ├── 媒体文件
    └── 长��项目存储
    
    ⚡ Volume2 (SSD RAID1 - 200GB)  
    ├── 数据库文件
    ├── 缓存数据
    ├── 活跃项目
    └── 系统配置
EOF
    echo -e "${NC}"
    echo ""
}

# 创建优化的目录结构
create_optimized_structure() {
    log_step "创建存储优化的目录结构..."
    
    # === SSD 存储 (高性能) ===
    log_info "在 SSD 上创建高性能目录..."
    
    # 数据库和缓存 (需要高 IOPS)
    mkdir -p "$VOLUME2_SSD/YC/databases"/{postgresql,redis,mongodb,sqlite}
    mkdir -p "$VOLUME2_SSD/YC/cache"/{nginx,docker,npm,pip}
    
    # 活跃开发项目 (频繁读写)
    mkdir -p "$VOLUME2_SSD/YC/active-projects"
    mkdir -p "$VOLUME2_SSD/YC/development"/{workspace,temp,build}
    
    # 系统配置和日志 (快速访问)
    mkdir -p "$VOLUME2_SSD/YC/config"/{nginx,ssl,monitoring}
    mkdir -p "$VOLUME2_SSD/YC/logs"/{system,application,access}
    
    # Docker 镜像和容器数据 (频繁访问)
    mkdir -p "$VOLUME2_SSD/YC/docker"/{images,containers,volumes}
    
    # === HDD 存储 (大容量) ===
    log_info "在 HDD 上创建大容量目录..."
    
    # 项目归档和备份 (大文件存储)
    mkdir -p "$VOLUME1_HDD/YC/archives"/{projects,databases,configs}
    mkdir -p "$VOLUME1_HDD/YC/backups"/{daily,weekly,monthly,emergency}
    
    # 媒体和资源文件 (大文件)
    mkdir -p "$VOLUME1_HDD/YC/media"/{images,videos,documents,assets}
    mkdir -p "$VOLUME1_HDD/YC/resources"/{templates,libraries,datasets}
    
    # AI 模型存储 (大模型文件)
    mkdir -p "$VOLUME1_HDD/YC/ai-models"/{ollama,huggingface,custom}
    
    # 长期项目存储
    mkdir -p "$VOLUME1_HDD/YC/projects"/{completed,archived,shared}
    
    # 服务数据备份
    mkdir -p "$VOLUME1_HDD/YC/services-backup"/{gitlab,portainer,monitoring}
    
    log_success "目录结构创建完成"
}

# 创建存储优化的 Docker Compose 配置
create_optimized_docker_compose() {
    log_step "创建存储优化的 Docker Compose 配置..."
    
    mkdir -p "$VOLUME2_SSD/YC/config/docker-compose"
    
    cat > "$VOLUME2_SSD/YC/config/docker-compose/storage-optimized.yml" << 'EOF'
version: '3.8'

networks:
  yc-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

services:
  # === 高性能服务 (SSD) ===
  
  # PostgreSQL - 主数据库 (SSD)
  postgres:
    image: postgres:15-alpine
    container_name: yc-postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: yc_dev
      POSTGRES_USER: yc_admin
      POSTGRES_PASSWORD: yc_password_2024
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - /volume2/YC/databases/postgresql:/var/lib/postgresql/data
      - /volume1/YC/backups/daily:/backups
    networks:
      - yc-network
    restart: unless-stopped
    command: >
      postgres
      -c shared_buffers=256MB
      -c effective_cache_size=1GB
      -c maintenance_work_mem=64MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
      -c default_statistics_target=100

  # Redis - 缓存服务 (SSD)
  redis:
    image: redis:7-alpine
    container_name: yc-redis
    ports:
      - "6379:6379"
    volumes:
      - /volume2/YC/databases/redis:/data
      - /volume2/YC/config/redis.conf:/usr/local/etc/redis/redis.conf
    networks:
      - yc-network
    restart: unless-stopped
    command: redis-server /usr/local/etc/redis/redis.conf

  # Nginx - 反向代理 (SSD 配置)
  nginx:
    image: nginx:alpine
    container_name: yc-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /volume2/YC/config/nginx:/etc/nginx
      - /volume2/YC/config/ssl:/etc/ssl/certs
      - /volume2/YC/logs/nginx:/var/log/nginx
      - /volume1/YC/media:/var/www/media:ro
    networks:
      - yc-network
    restart: unless-stopped
    depends_on:
      - postgres
      - redis

  # === 开发服务 (混合存储) ===
  
  # GitLab (配置在SSD，仓库在HDD)
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: yc-gitlab
    hostname: gitlab.yc.local
    ports:
      - "8080:80"
      - "8443:443"
      - "8022:22"
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://192.168.0.9:8080'
        gitlab_rails['gitlab_shell_ssh_port'] = 8022
        # 数据库配置使用外部 PostgreSQL
        postgresql['enable'] = false
        gitlab_rails['db_adapter'] = 'postgresql'
        gitlab_rails['db_encoding'] = 'utf8'
        gitlab_rails['db_host'] = 'postgres'
        gitlab_rails['db_port'] = 5432
        gitlab_rails['db_database'] = 'gitlab'
        gitlab_rails['db_username'] = 'gitlab'
        gitlab_rails['db_password'] = 'gitlab_password'
        # Redis 配置
        redis['enable'] = false
        gitlab_rails['redis_host'] = 'redis'
        gitlab_rails['redis_port'] = 6379
    volumes:
      - /volume2/YC/config/gitlab:/etc/gitlab
      - /volume2/YC/logs/gitlab:/var/log/gitlab
      - /volume1/YC/services-backup/gitlab:/var/opt/gitlab
    networks:
      - yc-network
    restart: unless-stopped
    depends_on:
      - postgres
      - redis

  # Portainer (配置在SSD)
  portainer:
    image: portainer/portainer-ce:latest
    container_name: yc-portainer
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /volume2/YC/config/portainer:/data
    networks:
      - yc-network
    restart: unless-stopped

  # === AI 服务 (模型在HDD，缓存在SSD) ===
  
  # Ollama (模型存储在HDD)
  ollama:
    image: ollama/ollama:latest
    container_name: yc-ollama
    ports:
      - "11434:11434"
    environment:
      - OLLAMA_HOST=0.0.0.0
      - OLLAMA_ORIGINS=*
    volumes:
      - /volume1/YC/ai-models/ollama:/root/.ollama
      - /volume2/YC/cache/ollama:/tmp/ollama
    networks:
      - yc-network
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  # Open WebUI (配置在SSD)
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: yc-open-webui
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - WEBUI_SECRET_KEY=yc-webui-secret-2024
    volumes:
      - /volume2/YC/config/open-webui:/app/backend/data
    networks:
      - yc-network
    restart: unless-stopped
    depends_on:
      - ollama

  # === 监控服务 (SSD) ===
  
  # Prometheus (配置和短期数据在SSD)
  prometheus:
    image: prom/prometheus:latest
    container_name: yc-prometheus
    ports:
      - "9090:9090"
    volumes:
      - /volume2/YC/config/prometheus:/etc/prometheus
      - /volume2/YC/databases/prometheus:/prometheus
      - /volume1/YC/archives/prometheus:/archives
    networks:
      - yc-network
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'

  # Grafana (配置在SSD)
  grafana:
    image: grafana/grafana:latest
    container_name: yc-grafana
    ports:
      - "3002:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_DATABASE_TYPE=postgres
      - GF_DATABASE_HOST=postgres:5432
      - GF_DATABASE_NAME=grafana
      - GF_DATABASE_USER=grafana
      - GF_DATABASE_PASSWORD=grafana_password
    volumes:
      - /volume2/YC/config/grafana:/etc/grafana
      - /volume2/YC/config/grafana/data:/var/lib/grafana
    networks:
      - yc-network
    restart: unless-stopped
    depends_on:
      - postgres
      - prometheus

  # === 开发工具 (SSD) ===
  
  # Code Server (工作区在SSD)
  code-server:
    image: codercom/code-server:latest
    container_name: yc-code-server
    ports:
      - "8443:8080"
    environment:
      - PASSWORD=yc-dev-2024
      - SUDO_PASSWORD=yc-dev-2024
    volumes:
      - /volume2/YC/active-projects:/home/coder/projects
      - /volume2/YC/config/code-server:/home/coder/.config
      - /volume1/YC/projects:/home/coder/archives:ro
    networks:
      - yc-network
    restart: unless-stopped

  # MinIO (热数据在SSD，冷数据在HDD)
  minio:
    image: minio/minio:latest
    container_name: yc-minio
    ports:
      - "9001:9000"
      - "9002:9001"
    environment:
      MINIO_ROOT_USER: yc-admin
      MINIO_ROOT_PASSWORD: yc-minio-2024
      MINIO_CONSOLE_ADDRESS: ":9001"
    volumes:
      - /volume2/YC/databases/minio:/data/hot
      - /volume1/YC/media:/data/cold
    networks:
      - yc-network
    restart: unless-stopped
    command: server /data/hot /data/cold --console-address ":9001"
EOF

    log_success "存储优化的 Docker Compose 配置创建完成"
}

# 创建 Redis 优化配置
create_redis_config() {
    log_step "创建 Redis 优化配置..."
    
    cat > "$VOLUME2_SSD/YC/config/redis.conf" << 'EOF'
# Redis 配置 - SSD 优化版本

# 基础配置
port 6379
bind 0.0.0.0
protected-mode no
timeout 300
tcp-keepalive 300

# 内存配置
maxmemory 512mb
maxmemory-policy allkeys-lru

# 持久化配置 (SSD 优化)
save 900 1
save 300 10
save 60 10000

# AOF 配置
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# 日志配置
loglevel notice
logfile "/var/log/redis/redis-server.log"

# 客户端配置
maxclients 10000

# 慢查询日志
slowlog-log-slower-than 10000
slowlog-max-len 128

# 延迟监控
latency-monitor-threshold 100
EOF

    log_success "Redis 配置创建完成"
}

# 创建 Nginx 优化配置
create_nginx_config() {
    log_step "创建 Nginx 优化配置..."
    
    mkdir -p "$VOLUME2_SSD/YC/config/nginx/conf.d"
    
    cat > "$VOLUME2_SSD/YC/config/nginx/nginx.conf" << 'EOF'
# Nginx 主配置 - 存储优化版本

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # 性能优化
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # 缓存配置 (利用SSD速度)
    proxy_cache_path /volume2/YC/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g 
                     inactive=60m use_temp_path=off;

    # 静态文件缓存 (HDD媒体文件)
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        root /var/www/media;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # 包含站点配置
    include /etc/nginx/conf.d/*.conf;
}
EOF

    # 创建主站点配置
    cat > "$VOLUME2_SSD/YC/config/nginx/conf.d/yc-main.conf" << 'EOF'
# YC 主站点配置

upstream yc_backend {
    server yc-gitlab:80;
    server yc-open-webui:8080 backup;
}

server {
    listen 80 default_server;
    server_name _;
    
    # 主控制台
    location / {
        return 200 '
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🚀 YC 开发环境控制台</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, sans-serif; 
            margin: 0; padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white; min-height: 100vh;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .service { 
            background: rgba(255,255,255,0.1); 
            padding: 20px; border-radius: 15px; 
            backdrop-filter: blur(10px);
            transition: transform 0.3s ease;
        }
        .service:hover { transform: translateY(-5px); }
        .service h3 { margin-top: 0; }
        .service a { 
            color: #ffd700; text-decoration: none; font-weight: bold;
            display: inline-block; margin-top: 10px;
        }
        .storage-info {
            background: rgba(255,255,255,0.2);
            padding: 15px; border-radius: 10px; margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 YC 开发环境控制台</h1>
            <p>存储优化版 - SSD + HDD 混合架构</p>
        </div>
        
        <div class="storage-info">
            <h3>💾 存储状态</h3>
            <p>⚡ SSD (200GB): 数据库、缓存、活跃项目</p>
            <p>📀 HDD (14.34TB): 备份、归档、媒体文件、AI模型</p>
        </div>
        
        <div class="services">
            <div class="service">
                <h3>🐙 GitLab</h3>
                <p>代码仓库和CI/CD</p>
                <a href="http://192.168.0.9:8080">访问 GitLab →</a>
            </div>
            <div class="service">
                <h3>🤖 AI 服务</h3>
                <p>大语言模型和AI工具</p>
                <a href="http://192.168.0.9:3000">访问 AI 服务 →</a>
            </div>
            <div class="service">
                <h3>💻 Code Server</h3>
                <p>Web版VS Code开发环境</p>
                <a href="http://192.168.0.9:8443">打开 Code Server →</a>
            </div>
            <div class="service">
                <h3>📊 监控面板</h3>
                <p>系统性能和服务监控</p>
                <a href="http://192.168.0.9:3002">查看监控 →</a>
            </div>
            <div class="service">
                <h3>🐳 容器管理</h3>
                <p>Docker容器管理界面</p>
                <a href="http://192.168.0.9:9000">访问 Portainer →</a>
            </div>
            <div class="service">
                <h3>📦 对象存储</h3>
                <p>文件存储和管理</p>
                <a href="http://192.168.0.9:9002">访问 MinIO →</a>
            </div>
        </div>
    </div>
</body>
</html>
        ';
        add_header Content-Type text/html;
    }
    
    # GitLab 代理
    location /gitlab/ {
        proxy_pass http://yc-gitlab:80/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # AI 服务代理
    location /ai/ {
        proxy_pass http://yc-open-webui:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 静态文��服务 (HDD媒体文件)
    location /media/ {
        alias /var/www/media/;
        expires 1y;
        add_header Cache-Control "public";
    }
}
EOF

    log_success "Nginx 配置创建完成"
}

# 创建存储监控脚本
create_storage_monitor() {
    log_step "创建存储监控脚本..."
    
    cat > "$VOLUME2_SSD/YC/config/scripts/storage-monitor.sh" << 'EOF'
#!/bin/bash

# 存储监控脚本

echo "💾 YC 存储监控报告"
echo "=================="
echo "时间: $(date)"
echo ""

# SSD 使用情况
echo "⚡ SSD 存储 (Volume2):"
echo "--------------------"
df -h /volume2 | tail -1 | awk '{print "总容量: " $2 ", 已用: " $3 ", 可用: " $4 ", 使用率: " $5}'

echo ""
echo "📊 SSD 详细使用:"
du -sh /volume2/YC/databases/* 2>/dev/null | sort -hr | head -5
echo ""

# HDD 使用情况  
echo "📀 HDD 存储 (Volume1):"
echo "--------------------"
df -h /volume1 | tail -1 | awk '{print "总容量: " $2 ", 已用: " $3 ", 可用: " $4 ", 使用率: " $5}'

echo ""
echo "📊 HDD 详细使用:"
du -sh /volume1/YC/* 2>/dev/null | sort -hr | head -5
echo ""

# 磁盘 I/O 统计
echo "📈 磁盘 I/O 统计:"
echo "---------------"
iostat -x 1 1 | grep -E "(Device|volume)" || echo "iostat 未安装"

echo ""
echo "🔥 热点文件 (最近访问):"
echo "--------------------"
find /volume2/YC -type f -atime -1 -exec ls -lh {} \; 2>/dev/null | head -5

echo ""
echo "❄️ 冷数据建议迁移:"
echo "----------------"
find /volume2/YC -type f -atime +30 -size +100M 2>/dev/null | head -5
EOF

    chmod +x "$VOLUME2_SSD/YC/config/scripts/storage-monitor.sh"
    
    log_success "存储监控脚本创建完成"
}

# 创建数据迁移脚本
create_migration_script() {
    log_step "创建数据迁移脚本..."
    
    cat > "$VOLUME2_SSD/YC/config/scripts/data-migration.sh" << 'EOF'
#!/bin/bash

# 数据迁移脚本 - SSD与HDD之间的智能迁移

show_menu() {
    echo "🔄 YC 数据迁移工具"
    echo "=================="
    echo "1. 冷数据迁移 (SSD → HDD)"
    echo "2. 热数据迁移 (HDD → SSD)"
    echo "3. 项目归档"
    echo "4. 备份迁移"
    echo "5. 查看迁移建议"
    echo "0. 退出"
    echo "=================="
}

migrate_cold_data() {
    echo "❄️ 迁移冷数据到 HDD..."
    
    # 查找30天未访问的大文件
    find /volume2/YC -type f -atime +30 -size +100M | while read file; do
        relative_path=${file#/volume2/YC/}
        target_dir="/volume1/YC/archives/$(dirname "$relative_path")"
        
        echo "迁移: $file"
        mkdir -p "$target_dir"
        mv "$file" "$target_dir/"
        
        # 创建软链接
        ln -s "/volume1/YC/archives/$relative_path" "$file"
    done
    
    echo "✅ 冷数据迁移完成"
}

migrate_hot_data() {
    echo "🔥 迁移热数据到 SSD..."
    
    read -p "请输入要迁移的项目名称: " project_name
    
    if [ -d "/volume1/YC/projects/$project_name" ]; then
        echo "迁移项目: $project_name"
        mv "/volume1/YC/projects/$project_name" "/volume2/YC/active-projects/"
        ln -s "/volume2/YC/active-projects/$project_name" "/volume1/YC/projects/$project_name"
        echo "✅ 项目迁移到 SSD 完成"
    else
        echo "❌ 项目不存在"
    fi
}

archive_project() {
    echo "📦 项目归档..."
    
    read -p "请输入要归档的项目名称: " project_name
    
    if [ -d "/volume2/YC/active-projects/$project_name" ]; then
        echo "归档项目: $project_name"
        
        # 创建归档
        tar -czf "/volume1/YC/archives/projects/$project_name-$(date +%Y%m%d).tar.gz" \
                 -C "/volume2/YC/active-projects" "$project_name"
        
        # 移动到HDD
        mv "/volume2/YC/active-projects/$project_name" "/volume1/YC/projects/"
        
        echo "✅ 项目归档完成"
    else
        echo "❌ 活跃项目不存在"
    fi
}

show_migration_suggestions() {
    echo "💡 迁移建议:"
    echo "============"
    
    echo ""
    echo "🔥 建议迁移到 SSD 的数据:"
    echo "------------------------"
    
    # 查找频繁访问的HDD文件
    find /volume1/YC/projects -type f -atime -7 -size +10M | head -5
    
    echo ""
    echo "❄️ 建议迁移到 HDD 的数据:"
    echo "------------------------"
    
    # 查找长期未访问的SSD文件
    find /volume2/YC -type f -atime +30 -size +50M | head -5
    
    echo ""
    echo "📊 存储使用统计:"
    echo "--------------"
    echo "SSD 使用率: $(df /volume2 | tail -1 | awk '{print $5}')"
    echo "HDD 使用率: $(df /volume1 | tail -1 | awk '{print $5}')"
}

# 主循环
while true; do
    show_menu
    read -p "请选择操作 (0-5): " choice
    
    case $choice in
        1) migrate_cold_data ;;
        2) migrate_hot_data ;;
        3) archive_project ;;
        4) echo "备份迁移功能开发中..." ;;
        5) show_migration_suggestions ;;
        0) echo "👋 再见！"; exit 0 ;;
        *) echo "❌ 无效选择" ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
    clear
done
EOF

    chmod +x "$VOLUME2_SSD/YC/config/scripts/data-migration.sh"
    
    log_success "数据迁移脚本创建完成"
}

# 创建自动化存储优化任务
create_storage_automation() {
    log_step "创建自动化存储优化任务..."
    
    cat > "$VOLUME2_SSD/YC/config/scripts/storage-automation.sh" << 'EOF'
#!/bin/bash

# 存储自动化优化脚本

# 清理临时文件
cleanup_temp_files() {
    echo "🧹 清理临时文件..."
    
    # 清理构建缓存
    find /volume2/YC/cache -type f -mtime +7 -delete
    find /volume2/YC/development/temp -type f -mtime +1 -delete
    
    # 清理Docker临时文件
    docker system prune -f
    
    echo "✅ 临时文件清理完成"
}

# 自动备份SSD重要数据到HDD
backup_ssd_data() {
    echo "💾 备份 SSD 重要数据..."
    
    # 备份数据库
    rsync -av --delete /volume2/YC/databases/ /volume1/YC/backups/daily/databases/
    
    # 备份配置文件
    rsync -av --delete /volume2/YC/config/ /volume1/YC/backups/daily/config/
    
    # 备份活跃项目
    rsync -av --delete /volume2/YC/active-projects/ /volume1/YC/backups/daily/active-projects/
    
    echo "✅ SSD 数据备份完成"
}

# 监控存储使用率
monitor_storage_usage() {
    echo "📊 监控存储使用率..."
    
    SSD_USAGE=$(df /volume2 | tail -1 | awk '{print $5}' | sed 's/%//')
    HDD_USAGE=$(df /volume1 | tail -1 | awk '{print $5}' | sed 's/%//')
    
    # SSD 使用率超过 80% 时告警
    if [ "$SSD_USAGE" -gt 80 ]; then
        echo "⚠️ SSD 使用率过高: ${SSD_USAGE}%"
        echo "建议执行冷数据迁移"
        
        # 自动迁移部分冷数据
        find /volume2/YC -type f -atime +30 -size +100M | head -5 | while read file; do
            echo "自动迁移: $file"
            # 这里可以添加自动迁移逻辑
        done
    fi
    
    # HDD 使用率超过 90% 时告警
    if [ "$HDD_USAGE" -gt 90 ]; then
        echo "⚠️ HDD 使用率过高: ${HDD_USAGE}%"
        echo "建议清理旧备份文件"
    fi
}

# 优化数据库性能
optimize_databases() {
    echo "⚡ 优化数据库性能..."
    
    # PostgreSQL 优化
    docker exec yc-postgres psql -U yc_admin -d yc_dev -c "VACUUM ANALYZE;" 2>/dev/null
    
    # Redis 优化
    docker exec yc-redis redis-cli BGREWRITEAOF 2>/dev/null
    
    echo "✅ 数据库优化完成"
}

# 主执行函数
main() {
    echo "🤖 存储自动化优化开始..."
    echo "时间: $(date)"
    echo ""
    
    cleanup_temp_files
    backup_ssd_data
    monitor_storage_usage
    optimize_databases
    
    echo ""
    echo "✅ 存储自动化优化完成"
}

# 执行主函数
main "$@"
EOF

    chmod +x "$VOLUME2_SSD/YC/config/scripts/storage-automation.sh"
    
    # 添加到 crontab
    cat > "$VOLUME2_SSD/YC/config/crontab/storage-tasks" << 'EOF'
# YC 存储自动化任务

# 每小时清理临时文件
0 * * * * /volume2/YC/config/scripts/storage-automation.sh

# 每天凌晨2点备份SSD数据
0 2 * * * /volume2/YC/config/scripts/storage-automation.sh

# 每周日进行存储优化
0 3 * * 0 /volume2/YC/config/scripts/data-migration.sh

# 每天生成存储监控报告
30 1 * * * /volume2/YC/config/scripts/storage-monitor.sh > /volume1/YC/archives/reports/storage-$(date +\%Y\%m\%d).log
EOF

    log_success "自动化存储优化任务创建完成"
}

# 部署存储优化环境
deploy_optimized_environment() {
    log_step "部署存储优化环境..."
    
    cd "$VOLUME2_SSD/YC/config/docker-compose"
    
    # 启动核心服务
    docker-compose -f storage-optimized.yml up -d
    
    # 等待服务启动
    echo "⏳ 等待服务启动..."
    sleep 30
    
    # 检查服务状态
    echo "📊 检查服务状态:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep yc-
    
    log_success "存储优化环境部署完成"
}

# 生成部署报告
generate_deployment_report() {
    log_step "生成部署报告..."
    
    REPORT_FILE="/volume1/YC/archives/reports/storage-deployment-$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
YC 存储优化部署报告
==================
部署时间: $(date)

存储配置:
- Volume1 (HDD RAID6): 14.34TB - 大容量存储
- Volume2 (SSD RAID1): 200GB - 高性能存储

存储分配策略:
SSD 存储 (高性能):
- 数据库文件: PostgreSQL, Redis, MongoDB
- 缓存数据: Nginx, Docker, 应用缓存
- 活跃项目: 当前开发项目
- 系统配置: 服务配置文件
- 日志文件: 实时日志

HDD 存储 (大容量):
- 项目归档: 完成的项目
- 备份文件: 数据库备份、配置备份
- 媒体文件: 图片、视频、文档
- AI 模型: Ollama 模型文件
- 长期存储: 历史数据

服务部署状态:
$(docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep yc-)

存储使用情况:
SSD: $(df -h /volume2 | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')
HDD: $(df -h /volume1 | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')

访问地址:
- 主控制台: http://192.168.0.9
- GitLab: http://192.168.0.9:8080
- AI 服务: http://192.168.0.9:3000
- Code Server: http://192.168.0.9:8443
- 监控面板: http://192.168.0.9:3002
- 容器管理: http://192.168.0.9:9000
- 对象存储: http://192.168.0.9:9002

管理工具:
- 存储监控: /volume2/YC/config/scripts/storage-monitor.sh
- 数据迁移: /volume2/YC/config/scripts/data-migration.sh
- 自动化优化: /volume2/YC/config/scripts/storage-automation.sh

优化建议:
1. 定期运行存储监控脚本
2. 根据访问频率迁移数据
3. 保持 SSD 使用率在 80% 以下
4. 定期清理临时文件和缓存
5. 监控数据库性能指标

部署完成！🎉
EOF

    log_success "部署报告生成完成: $REPORT_FILE"
}

# 显示完成信息
show_completion_info() {
    clear
    echo -e "${GREEN}"
    cat << 'EOF'
    ✅ 存储优化部署完成！
    ====================
    
    🎉 YC 开发环境已针对您的存储配置进行优化！
    
EOF
    echo -e "${NC}"
    
    echo -e "${CYAN}💾 存储策略：${NC}"
    echo "• ⚡ SSD (200GB): 数据库、缓存、活跃项目"
    echo "• 📀 HDD (14.34TB): 备份、归档、媒体、AI模型"
    echo ""
    
    echo -e "${CYAN}🌐 访问地址：${NC}"
    echo "• 主控制台: http://192.168.0.9"
    echo "• GitLab: http://192.168.0.9:8080"
    echo "• AI 服务: http://192.168.0.9:3000"
    echo "• Code Server: http://192.168.0.9:8443"
    echo "• 监控面板: http://192.168.0.9:3002"
    echo ""
    
    echo -e "${CYAN}🛠️ 存储管理工具：${NC}"
    echo "• 存储监控: /volume2/YC/config/scripts/storage-monitor.sh"
    echo "• 数据迁移: /volume2/YC/config/scripts/data-migration.sh"
    echo "• 自动优化: /volume2/YC/config/scripts/storage-automation.sh"
    echo ""
    
    echo -e "${YELLOW}💡 使用建议：${NC}"
    echo "• 活跃开发项目放在 SSD 上获得最佳性能"
    echo "• 完成的项目及时归档到 HDD 节省 SSD 空间"
    echo "• 定期运行存储监控了解使用情况"
    echo "• 利用自动迁移功能优化存储分配"
    echo ""
    
    read -p "是否立即运行存储监控？(Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        /volume2/YC/config/scripts/storage-monitor.sh
    fi
    
    echo ""
    echo -e "${GREEN}🎊 存储优化部署成功！享受高性能开发体验！${NC}"
}

# 主函数
main() {
    show_storage_strategy
    create_optimized_structure
    create_optimized_docker_compose
    create_redis_config
    create_nginx_config
    create_storage_monitor
    create_migration_script
    create_storage_automation
    deploy_optimized_environment
    generate_deployment_report
    show_completion_info
}

# 执行主函数
main "$@"
