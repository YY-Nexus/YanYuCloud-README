#!/bin/bash

# YYC 高级配置脚本 - 第二阶段部署
# 包含性能优化、安全配置、开发工具集成

set -e

# 配置变量
ROOT_DIR="/volume1/YC"
NAS_IP="192.168.3.9"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[信息]${NC} $1"; }
log_success() { echo -e "${GREEN}[成功]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
log_error() { echo -e "${RED}[错误]${NC} $1"; }
log_step() { echo -e "${PURPLE}[步骤]${NC} $1"; }

# 创建高级服务配置
create_advanced_services() {
    log_step "创建高级服务配置..."
    
    # 创建 v0 开发环境配置
    cat > "$ROOT_DIR/development/docker-compose/v0-dev.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  # v0 开发环境 - Next.js 专用
  v0-nextjs:
    image: node:18-alpine
    container_name: yc-v0-nextjs
    ports:
      - "3100:3000"
      - "3101:3001"
    volumes:
      - /volume1/YC/development/projects/v0-projects:/workspace
      - /volume1/YC/development/scripts/v0-tools:/tools
    working_dir: /workspace
    environment:
      - NODE_ENV=development
      - NEXT_TELEMETRY_DISABLED=1
      - CHOKIDAR_USEPOLLING=true
    command: |
      sh -c "
        apk add --no-cache git curl &&
        npm install -g @vercel/cli create-next-app &&
        tail -f /dev/null
      "
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Code Server (VS Code Web 版)
  code-server:
    image: codercom/code-server:latest
    container_name: yc-code-server
    ports:
      - "8443:8080"
    volumes:
      - /volume1/YC/development/projects:/home/coder/projects
      - /volume1/YC/services/code-server:/home/coder/.config
    environment:
      - PASSWORD=yc-dev-2024
      - SUDO_PASSWORD=yc-dev-2024
    command: |
      --bind-addr 0.0.0.0:8080
      --user-data-dir /home/coder/.config
      --auth password
      --disable-telemetry
      /home/coder/projects
    networks:
      - yc-dev-network
    restart: unless-stopped

  # MinIO 对象存储
  minio:
    image: minio/minio:latest
    container_name: yc-minio
    ports:
      - "9001:9000"
      - "9002:9001"
    volumes:
      - /volume1/YC/services/minio/data:/data
      - /volume1/YC/services/minio/config:/root/.minio
    environment:
      MINIO_ROOT_USER: yc-admin
      MINIO_ROOT_PASSWORD: yc-minio-2024
      MINIO_CONSOLE_ADDRESS: ":9001"
    command: server /data --console-address ":9001"
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Elasticsearch (日志搜索)
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: yc-elasticsearch
    ports:
      - "9200:9200"
    volumes:
      - /volume1/YC/services/elasticsearch:/usr/share/elasticsearch/data
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Kibana (日志可视化)
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: yc-kibana
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Jenkins CI/CD
  jenkins:
    image: jenkins/jenkins:lts
    container_name: yc-jenkins
    ports:
      - "8081:8080"
      - "50000:50000"
    volumes:
      - /volume1/YC/services/jenkins:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JENKINS_OPTS=--httpPort=8080
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Grafana 监控面板
  grafana:
    image: grafana/grafana:latest
    container_name: yc-grafana
    ports:
      - "3002:3000"
    volumes:
      - /volume1/YC/services/grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_SMTP_ENABLED=true
      - GF_SMTP_HOST=0379.email:587
      - GF_SMTP_USER=admin@0379.email
      - GF_SMTP_PASSWORD=your-password
      - GF_SMTP_FROM_ADDRESS=admin@0379.email
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Traefik 反向代理 (高级版)
  traefik:
    image: traefik:v3.0
    container_name: yc-traefik
    ports:
      - "8080:8080"  # Traefik 仪表板
      - "80:80"      # HTTP
      - "443:443"    # HTTPS
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /volume1/YC/services/traefik:/etc/traefik
    command:
      - --api.dashboard=true
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
    networks:
      - yc-dev-network
    restart: unless-stopped
EOF

    log_success "高级服务配置创建完成"
}

# 创建 v0 专用工具
create_v0_tools() {
    log_step "创建 v0 开发工具..."
    
    mkdir -p "$ROOT_DIR/development/scripts/v0-tools"
    mkdir -p "$ROOT_DIR/development/projects/v0-projects"
    
    # v0 项目快速创建工具
    cat > "$ROOT_DIR/development/scripts/v0-tools/create-v0-project.sh" << 'EOF'
#!/bin/bash

# v0 项目快速创建工具

if [ -z "$1" ]; then
    echo "❌ 请指定项目名称"
    echo "用法: $0 <项目名称> [模板类型]"
    echo "模板类型: dashboard, landing, ecommerce, blog, saas"
    exit 1
fi

PROJECT_NAME="$1"
TEMPLATE="${2:-dashboard}"
PROJECT_DIR="/workspace/$PROJECT_NAME"

echo "🚀 创建 v0 项目: $PROJECT_NAME (模板: $TEMPLATE)"

# 进入容器执行
docker exec -it yc-v0-nextjs sh -c "
    cd /workspace &&
    npx create-next-app@latest $PROJECT_NAME --typescript --tailwind --eslint --app --src-dir --import-alias '@/*' &&
    cd $PROJECT_NAME &&
    
    # 安装常用依赖
    npm install @radix-ui/react-icons @radix-ui/react-slot class-variance-authority clsx tailwind-merge lucide-react &&
    npm install -D @types/node &&
    
    # 创建基础组件结构
    mkdir -p src/components/ui &&
    mkdir -p src/lib &&
    
    # 创建 utils 文件
    cat > src/lib/utils.ts << 'UTILS_EOF'
import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
UTILS_EOF

    # 根据模板类型创建不同的初始页面
    case '$TEMPLATE' in
        'dashboard')
            cat > src/app/page.tsx << 'PAGE_EOF'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

export default function Dashboard() {
  return (
    <div className='min-h-screen bg-gray-50 p-8'>
      <div className='max-w-7xl mx-auto'>
        <h1 className='text-3xl font-bold mb-8'>仪表板</h1>
        <div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6'>
          <Card>
            <CardHeader>
              <CardTitle>总用户数</CardTitle>
              <CardDescription>本月新增用户</CardDescription>
            </CardHeader>
            <CardContent>
              <div className='text-2xl font-bold'>1,234</div>
              <p className='text-xs text-muted-foreground'>+20.1% 较上月</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>收入</CardTitle>
              <CardDescription>本月总收入</CardDescription>
            </CardHeader>
            <CardContent>
              <div className='text-2xl font-bold'>¥45,231</div>
              <p className='text-xs text-muted-foreground'>+15.3% 较上月</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>订单数</CardTitle>
              <CardDescription>本月完成订单</CardDescription>
            </CardHeader>
            <CardContent>
              <div className='text-2xl font-bold'>573</div>
              <p className='text-xs text-muted-foreground'>+8.2% 较上月</p>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
PAGE_EOF
            ;;
        'landing')
            cat > src/app/page.tsx << 'PAGE_EOF'
export default function Landing() {
  return (
    <div className='min-h-screen'>
      {/* Hero Section */}
      <section className='bg-gradient-to-r from-blue-600 to-purple-600 text-white py-20'>
        <div className='max-w-7xl mx-auto px-4 text-center'>
          <h1 className='text-5xl font-bold mb-6'>欢迎来到我们的平台</h1>
          <p className='text-xl mb-8'>构建下一代应用程序的最佳选择</p>
          <button className='bg-white text-blue-600 px-8 py-3 rounded-lg font-semibold hover:bg-gray-100 transition-colors'>
            立即开始
          </button>
        </div>
      </section>
      
      {/* Features Section */}
      <section className='py-20'>
        <div className='max-w-7xl mx-auto px-4'>
          <h2 className='text-3xl font-bold text-center mb-12'>核心功能</h2>
          <div className='grid grid-cols-1 md:grid-cols-3 gap-8'>
            <div className='text-center'>
              <div className='bg-blue-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4'>
                <span className='text-2xl'>🚀</span>
              </div>
              <h3 className='text-xl font-semibold mb-2'>快速部署</h3>
              <p className='text-gray-600'>一键部署，快速上线您的应用</p>
            </div>
            <div className='text-center'>
              <div className='bg-green-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4'>
                <span className='text-2xl'>🔒</span>
              </div>
              <h3 className='text-xl font-semibold mb-2'>安全可靠</h3>
              <p className='text-gray-600'>企业级安全保障，数据安全无忧</p>
            </div>
            <div className='text-center'>
              <div className='bg-purple-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4'>
                <span className='text-2xl'>📊</span>
              </div>
              <h3 className='text-xl font-semibold mb-2'>数据分析</h3>
              <p className='text-gray-600'>实时数据分析，助力业务决策</p>
            </div>
          </div>
        </div>
      </section>
    </div>
  )
}
PAGE_EOF
            ;;
    esac
    
    echo '✅ v0 项目创建完成！'
    echo '📁 项目路径: $PROJECT_DIR'
    echo '🌐 开发服务器: npm run dev'
"

echo "✅ v0 项目 $PROJECT_NAME 创建完成"
echo "🔗 访问地址: http://192.168.3.9:3100"
EOF

    chmod +x "$ROOT_DIR/development/scripts/v0-tools/create-v0-project.sh"
    
    # v0 组件库管理工具
    cat > "$ROOT_DIR/development/scripts/v0-tools/manage-components.sh" << 'EOF'
#!/bin/bash

# v0 组件库管理工具

COMPONENTS_DIR="/workspace/shared-components"

case "$1" in
    "init")
        echo "🎨 初始化共享组件库..."
        docker exec -it yc-v0-nextjs sh -c "
            mkdir -p $COMPONENTS_DIR/ui &&
            mkdir -p $COMPONENTS_DIR/layouts &&
            mkdir -p $COMPONENTS_DIR/forms &&
            
            # 创建基础 Button 组件
            cat > $COMPONENTS_DIR/ui/button.tsx << 'BUTTON_EOF'
import * as React from 'react'
import { Slot } from '@radix-ui/react-slot'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button'
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    )
  }
)
Button.displayName = 'Button'

export { Button, buttonVariants }
BUTTON_EOF
        "
        echo "✅ 共享组件库初始化完成"
        ;;
    "list")
        echo "📋 可用组件列表："
        docker exec -it yc-v0-nextjs find $COMPONENTS_DIR -name "*.tsx" -type f
        ;;
    "add")
        if [ -z "$2" ]; then
            echo "❌ 请指定组件名称"
            exit 1
        fi
        echo "➕ 添加组件: $2"
        # 这里可以添加从 shadcn/ui 或其他源添加组件的逻辑
        ;;
    *)
        echo "🎨 v0 组件库管理工具"
        echo "用法: $0 {init|list|add} [组件名称]"
        ;;
esac
EOF

    chmod +x "$ROOT_DIR/development/scripts/v0-tools/manage-components.sh"
    
    log_success "v0 开发工具创建完成"
}

# 创建 AI 模型负载均衡配置
create_ai_load_balancer() {
    log_step "创建 AI 模型负载均衡配置..."
    
    cat > "$ROOT_DIR/development/docker-compose/ai-services.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  # AI 网关服务
  ai-gateway:
    image: nginx:alpine
    container_name: yc-ai-gateway
    ports:
      - "11435:80"
    volumes:
      - /volume1/YC/services/ai-gateway/nginx.conf:/etc/nginx/nginx.conf
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Ollama 主实例 (NAS)
  ollama-primary:
    image: ollama/ollama:latest
    container_name: yc-ollama-primary
    ports:
      - "11434:11434"
    volumes:
      - /volume1/YC/ai-models/ollama-primary:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0
      - OLLAMA_ORIGINS=*
    networks:
      - yc-dev-network
    restart: unless-stopped

  # AI 模型管理面板
  ai-dashboard:
    image: node:18-alpine
    container_name: yc-ai-dashboard
    ports:
      - "3003:3000"
    volumes:
      - /volume1/YC/development/ai-dashboard:/app
    working_dir: /app
    command: |
      sh -c "
        if [ ! -f package.json ]; then
          npm init -y &&
          npm install express cors axios &&
          cat > server.js << 'SERVER_EOF'
const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// AI 服务状态检查
app.get('/api/status', async (req, res) => {
  try {
    const services = [
      { name: 'NAS Ollama', url: 'http://yc-ollama-primary:11434/api/tags' },
      // 可以添加更多 AI 服务
    ];
    
    const results = await Promise.allSettled(
      services.map(async service => {
        const response = await axios.get(service.url, { timeout: 5000 });
        return { ...service, status: 'online', models: response.data.models || [] };
      })
    );
    
    res.json(results.map((result, index) => 
      result.status === 'fulfilled' 
        ? result.value 
        : { ...services[index], status: 'offline', error: result.reason.message }
    ));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 模型使用统计
app.get('/api/stats', (req, res) => {
  // 这里可以添加模型使用统计逻辑
  res.json({
    totalRequests: 1234,
    activeModels: 5,
    avgResponseTime: '2.3s'
  });
});

// 创建简单的 HTML 界面
app.get('/', (req, res) => {
  res.send(\`
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>YC AI 模型管理面板</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .service { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .status-online { color: #28a745; }
        .status-offline { color: #dc3545; }
        .models { margin-top: 10px; }
        .model { background: #f8f9fa; padding: 5px 10px; margin: 5px 0; border-radius: 4px; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 YC AI 模型管理面板</h1>
            <p>实时监控 AI 服务状态和模型使用情况</p>
        </div>
        <div id="services" class="services">
            <div>加载中...</div>
        </div>
    </div>
    
    <script>
        async function loadStatus() {
            try {
                const response = await fetch('/api/status');
                const services = await response.json();
                
                const container = document.getElementById('services');
                container.innerHTML = services.map(service => \`
                    <div class="service">
                        <h3>\${service.name}</h3>
                        <p class="status-\${service.status}">状态: \${service.status === 'online' ? '在线' : '离线'}</p>
                        \${service.models ? \`
                            <div class="models">
                                <strong>可用模型 (\${service.models.length}):</strong>
                                \${service.models.map(model => \`
                                    <div class="model">\${model.name} - \${(model.size/1024/1024/1024).toFixed(1)}GB</div>
                                \`).join('')}
                            </div>
                        \` : ''}
                        \${service.error ? \`<p style="color: red;">错误: \${service.error}</p>\` : ''}
                    </div>
                \`).join('');
            } catch (error) {
                document.getElementById('services').innerHTML = '<div>加载失败: ' + error.message + '</div>';
            }
        }
        
        loadStatus();
        setInterval(loadStatus, 30000); // 每30秒刷新
    </script>
</body>
</html>
  \`);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(\`AI 管理面板运行在端口 \${PORT}\`);
});
SERVER_EOF
        fi &&
        node server.js
      "
    networks:
      - yc-dev-network
    restart: unless-stopped
EOF

    # 创建 AI 网关 Nginx 配置
    mkdir -p "$ROOT_DIR/services/ai-gateway"
    cat > "$ROOT_DIR/services/ai-gateway/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream ollama_backend {
        server yc-ollama-primary:11434;
        # 可以添加更多后端服务器
        # server mac-ollama:11434 backup;
        # server imac-ollama:11434 backup;
    }
    
    server {
        listen 80;
        
        location /api/ {
            proxy_pass http://ollama_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # 增加超时时间，适应大模型响应
            proxy_read_timeout 300s;
            proxy_connect_timeout 10s;
            proxy_send_timeout 300s;
        }
        
        location / {
            return 200 'YC AI Gateway - 负载均衡运行中';
            add_header Content-Type text/plain;
        }
    }
}
EOF

    log_success "AI 模型负载均衡配置完成"
}

# 创建性能监控配置
create_monitoring_stack() {
    log_step "创建性能监控配置..."
    
    cat > "$ROOT_DIR/development/docker-compose/monitoring.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  # Prometheus 监控
  prometheus:
    image: prom/prometheus:latest
    container_name: yc-prometheus
    ports:
      - "9090:9090"
    volumes:
      - /volume1/YC/services/monitoring/prometheus:/etc/prometheus
      - /volume1/YC/services/monitoring/prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Node Exporter (系统监控)
  node-exporter:
    image: prom/node-exporter:latest
    container_name: yc-node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - yc-dev-network
    restart: unless-stopped

  # cAdvisor (容器监控)
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: yc-cadvisor
    ports:
      - "8082:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - yc-dev-network
    restart: unless-stopped

  # AlertManager (告警管理)
  alertmanager:
    image: prom/alertmanager:latest
    container_name: yc-alertmanager
    ports:
      - "9093:9093"
    volumes:
      - /volume1/YC/services/monitoring/alertmanager:/etc/alertmanager
    networks:
      - yc-dev-network
    restart: unless-stopped
EOF

    # 创建 Prometheus 配置
    mkdir -p "$ROOT_DIR/services/monitoring/prometheus"
    cat > "$ROOT_DIR/services/monitoring/prometheus/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'ollama'
    static_configs:
      - targets: ['yc-ollama-primary:11434']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'nginx'
    static_configs:
      - targets: ['yc-nginx:80']
EOF

    # 创建告警规则
    cat > "$ROOT_DIR/services/monitoring/prometheus/alert_rules.yml" << 'EOF'
groups:
  - name: yc-alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU 使用率过高"
          description: "实例 {{ $labels.instance }} CPU 使用率超过 80%"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "内存使用率过高"
          description: "实例 {{ $labels.instance }} 内存使用率超过 85%"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "磁盘空间不足"
          description: "实例 {{ $labels.instance }} 磁盘空间少于 10%"

      - alert: OllamaServiceDown
        expr: up{job="ollama"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Ollama 服务离线"
          description: "Ollama AI 服务已离线超过 1 分钟"
EOF

    log_success "性能监控配置完成"
}

# 创建开发环境管理脚本
create_dev_management() {
    log_step "创建开发环境管理脚本..."
    
    cat > "$ROOT_DIR/development/scripts/dev-manager.sh" << 'EOF'
#!/bin/bash

# YC 开发环境管理器

ROOT_DIR="/volume1/YC"
COMPOSE_DIR="$ROOT_DIR/development/docker-compose"

show_menu() {
    echo "🚀 YC 开发环境管理器"
    echo "======================="
    echo "1. 启动核心服务"
    echo "2. 启动 v0 开发环境"
    echo "3. 启动 AI 服务"
    echo "4. 启动监控服务"
    echo "5. 查看服务状态"
    echo "6. 查看服务日志"
    echo "7. 重启所有服务"
    echo "8. 停止所有服务"
    echo "9. 系统资源使用情况"
    echo "10. 创建新项目"
    echo "0. 退出"
    echo "======================="
}

start_core_services() {
    echo "🚀 启动核心服务..."
    docker-compose -f "$COMPOSE_DIR/docker-compose.yml" up -d
    echo "✅ 核心服务启动完成"
}

start_v0_services() {
    echo "🎨 启动 v0 开发环境..."
    docker-compose -f "$COMPOSE_DIR/v0-dev.yml" up -d
    echo "✅ v0 开发环境启动完成"
    echo "🌐 Code Server: http://192.168.3.9:8443"
    echo "🌐 v0 开发服务器: http://192.168.3.9:3100"
}

start_ai_services() {
    echo "🤖 启动 AI 服务..."
    docker-compose -f "$COMPOSE_DIR/ai-services.yml" up -d
    echo "✅ AI 服务启动完成"
    echo "🌐 AI 管理面板: http://192.168.3.9:3003"
    echo "🌐 AI 网关: http://192.168.3.9:11435"
}

start_monitoring() {
    echo "📊 启动监控服务..."
    docker-compose -f "$COMPOSE_DIR/monitoring.yml" up -d
    echo "✅ 监控服务启动完成"
    echo "🌐 Prometheus: http://192.168.3.9:9090"
    echo "🌐 Grafana: http://192.168.3.9:3002"
}

show_status() {
    echo "📊 服务状态："
    echo "=============="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep yc-
}

show_logs() {
    echo "请选择要查看日志的服务："
    docker ps --format "{{.Names}}" | grep yc- | nl
    read -p "输入服务编号: " service_num
    service_name=$(docker ps --format "{{.Names}}" | grep yc- | sed -n "${service_num}p")
    if [ -n "$service_name" ]; then
        echo "📋 查看 $service_name 日志 (Ctrl+C 退出)："
        docker logs -f "$service_name"
    else
        echo "❌ 无效的服务编号"
    fi
}

restart_all() {
    echo "🔄 重启所有服务..."
    docker-compose -f "$COMPOSE_DIR/docker-compose.yml" restart
    docker-compose -f "$COMPOSE_DIR/v0-dev.yml" restart
    docker-compose -f "$COMPOSE_DIR/ai-services.yml" restart
    docker-compose -f "$COMPOSE_DIR/monitoring.yml" restart
    echo "✅ 所有服务重启完成"
}

stop_all() {
    echo "⏹️ 停止所有服务..."
    docker-compose -f "$COMPOSE_DIR/docker-compose.yml" down
    docker-compose -f "$COMPOSE_DIR/v0-dev.yml" down
    docker-compose -f "$COMPOSE_DIR/ai-services.yml" down
    docker-compose -f "$COMPOSE_DIR/monitoring.yml" down
    echo "✅ 所有服务已停止"
}

show_resources() {
    echo "💻 系统资源使用情况："
    echo "===================="
    echo "CPU 使用率："
    top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4"%"}'
    echo ""
    echo "内存使用情况："
    free -h
    echo ""
    echo "磁盘使用情况："
    df -h | grep -E "^/dev/"
    echo ""
    echo "Docker 容器资源使用："
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -10
}

create_project() {
    echo "🚀 创建新项目"
    echo "============="
    read -p "项目名称: " project_name
    echo "选择项目类型："
    echo "1. Next.js (推荐用于 v0)"
    echo "2. React"
    echo "3. Vue"
    echo "4. Node.js"
    read -p "选择 (1-4): " project_type
    
    case $project_type in
        1) template="nextjs" ;;
        2) template="react" ;;
        3) template="vue" ;;
        4) template="node" ;;
        *) echo "❌ 无效选择"; return ;;
    esac
    
    "$ROOT_DIR/development/scripts/init-project.sh" "$project_name" "$template"
}

# 主循环
while true; do
    show_menu
    read -p "请选择操作 (0-10): " choice
    
    case $choice in
        1) start_core_services ;;
        2) start_v0_services ;;
        3) start_ai_services ;;
        4) start_monitoring ;;
        5) show_status ;;
        6) show_logs ;;
        7) restart_all ;;
        8) stop_all ;;
        9) show_resources ;;
        10) create_project ;;
        0) echo "👋 再见！"; exit 0 ;;
        *) echo "❌ 无效选择，请重新输入" ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
    clear
done
EOF

    chmod +x "$ROOT_DIR/development/scripts/dev-manager.sh"
    
    log_success "开发环境管理脚本创建完成"
}

# 创建自动化部署脚本
create_deployment_automation() {
    log_step "创建自动化部署脚本..."
    
    cat > "$ROOT_DIR/development/scripts/auto-deploy.sh" << 'EOF'
#!/bin/bash

# 自动化部署脚本

if [ -z "$1" ]; then
    echo "❌ 请指定项目路径"
    echo "用法: $0 <项目路径> [环境]"
    echo "环境: dev, staging, prod"
    exit 1
fi

PROJECT_PATH="$1"
ENVIRONMENT="${2:-dev}"
PROJECT_NAME=$(basename "$PROJECT_PATH")

echo "🚀 开始部署项目: $PROJECT_NAME"
echo "📁 项目路径: $PROJECT_PATH"
echo "🌍 部署环境: $ENVIRONMENT"

# 检查项目是否存在
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ 项目路径不存在: $PROJECT_PATH"
    exit 1
fi

cd "$PROJECT_PATH"

# 检查是否是 Next.js 项目
if [ -f "next.config.js" ] || [ -f "next.config.mjs" ]; then
    echo "📦 检测到 Next.js 项目"
    
    # 安装依赖
    echo "📥 安装依赖..."
    npm install
    
    # 构建项目
    echo "🔨 构建项目..."
    npm run build
    
    # 创建 Docker 镜像
    echo "🐳 创建 Docker 镜像..."
    cat > Dockerfile << 'DOCKERFILE_EOF'
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

CMD ["node", "server.js"]
DOCKERFILE_EOF

    # 构建镜像
    docker build -t "yc-$PROJECT_NAME:$ENVIRONMENT" .
    
    # 创建部署配置
    cat > "docker-compose.deploy.yml" << DEPLOY_EOF
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  $PROJECT_NAME:
    image: yc-$PROJECT_NAME:$ENVIRONMENT
    container_name: yc-$PROJECT_NAME-$ENVIRONMENT
    ports:
      - "0:3000"  # 自动分配端口
    environment:
      - NODE_ENV=$ENVIRONMENT
    networks:
      - yc-dev-network
    restart: unless-stopped
DEPLOY_EOF

    # 部署服务
    echo "🚀 部署服务..."
    docker-compose -f docker-compose.deploy.yml up -d
    
    # 获取分配的端口
    PORT=$(docker port "yc-$PROJECT_NAME-$ENVIRONMENT" 3000 | cut -d: -f2)
    
    echo "✅ 部署完成！"
    echo "🌐 访问地址: http://192.168.3.9:$PORT"
    
elif [ -f "package.json" ]; then
    echo "📦 检测到 Node.js 项目"
    # 处理其他 Node.js 项目的部署逻辑
    
else
    echo "❌ 不支持的项目类型"
    exit 1
fi

echo "📊 部署信息已保存到部署日志"
echo "$(date): 项目 $PROJECT_NAME 部署到 $ENVIRONMENT 环境，端口 $PORT" >> /volume1/YC/shared/deployment.log
EOF

    chmod +x "$ROOT_DIR/development/scripts/auto-deploy.sh"
    
    log_success "自动化部署脚本创建完成"
}

# 主函数
main() {
    echo "🚀 开始高级配置部署"
    echo "===================="
    
    create_advanced_services
    create_v0_tools
    create_ai_load_balancer
    create_monitoring_stack
    create_dev_management
    create_deployment_automation
    
    echo ""
    echo "🎉 高级配置部署完成！"
    echo "===================="
    echo ""
    echo "📋 新增功能："
    echo "• v0 专用开发环境"
    echo "• Code Server (Web VS Code)"
    echo "• AI 模型负载均衡"
    echo "• 完整监控栈"
    echo "• 自动化部署"
    echo "• 统一管理界面"
    echo ""
    echo "🛠️ 管理工具："
    echo "• 开发环境管理器: $ROOT_DIR/development/scripts/dev-manager.sh"
    echo "• v0 项目创建: $ROOT_DIR/development/scripts/v0-tools/create-v0-project.sh"
    echo "• 自动部署: $ROOT_DIR/development/scripts/auto-deploy.sh"
    echo ""
    echo "🌐 新增服务地址："
    echo "• 🌐 Code Server: http://192.168.3.9:8443"
    echo "• 🌐 v0 开发服务器: http://192.168.3.9:3100"
    echo "• 🌐 AI 管理面板: http://192.168.3.9:3003"
    echo "• 🌐 AI 网关: http://192.168.3.9:11435"
    echo "• 🌐 Prometheus: http://192.168.3.9:9090"
    echo "• 🌐 MinIO: http://192.168.3.9:9002"
    echo "• 🌐 Jenkins: http://192.168.3.9:8081"
    echo ""
    
    read -p "是否启动开发环境管理器？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$ROOT_DIR/development/scripts/dev-manager.sh"
    fi
}

# 执行主函数
main "$@"
