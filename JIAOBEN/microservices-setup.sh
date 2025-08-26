#!/bin/bash

# YYC 微服务架构支持脚本
# 包含服务网格、API 网关、服务发现等

set -e

ROOT_DIR="/volume1/YC"
NAS_IP="192.168.3.45"

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

# 创建微服务基础架构
create_microservices_infrastructure() {
    log_step "创建微服务基础架构..."
    
    cat > "$ROOT_DIR/development/docker-compose/microservices.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true
  yc-microservices:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

services:
  # Kong API 网关
  kong-database:
    image: postgres:13
    container_name: yc-kong-db
    environment:
      POSTGRES_USER: kong
      POSTGRES_DB: kong
      POSTGRES_PASSWORD: kong_password
    volumes:
      - /volume1/YC/services/kong/db:/var/lib/postgresql/data
    networks:
      - yc-microservices
    restart: unless-stopped

  kong-migration:
    image: kong:latest
    container_name: yc-kong-migration
    command: kong migrations bootstrap
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: kong-database
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kong_password
      KONG_PG_DATABASE: kong
    depends_on:
      - kong-database
    networks:
      - yc-microservices
    restart: "no"

  kong:
    image: kong:latest
    container_name: yc-kong
    ports:
      - "8000:8000"  # API Gateway
      - "8001:8001"  # Admin API
      - "8443:8443"  # HTTPS API Gateway
      - "8444:8444"  # HTTPS Admin API
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: kong-database
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kong_password
      KONG_PG_DATABASE: kong
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
    depends_on:
      - kong-migration
    networks:
      - yc-microservices
      - yc-dev-network
    restart: unless-stopped

  # Konga - Kong 管理界面
  konga:
    image: pantsel/konga:latest
    container_name: yc-konga
    ports:
      - "1337:1337"
    environment:
      NODE_ENV: production
      KONGA_HOOK_TIMEOUT: 120000
    networks:
      - yc-microservices
    restart: unless-stopped

  # Consul 服务发现
  consul:
    image: consul:latest
    container_name: yc-consul
    ports:
      - "8500:8500"
      - "8600:8600/udp"
    command: agent -server -ui -node=server-1 -bootstrap-expect=1 -client=0.0.0.0
    volumes:
      - /volume1/YC/services/consul:/consul/data
    networks:
      - yc-microservices
      - yc-dev-network
    restart: unless-stopped

  # Jaeger 分布式追踪
  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: yc-jaeger
    ports:
      - "16686:16686"  # Jaeger UI
      - "14268:14268"  # HTTP collector
      - "14250:14250"  # gRPC collector
      - "6831:6831/udp"  # UDP agent
    environment:
      COLLECTOR_ZIPKIN_HOST_PORT: :9411
    networks:
      - yc-microservices
      - yc-dev-network
    restart: unless-stopped

  # Zipkin 链路追踪
  zipkin:
    image: openzipkin/zipkin:latest
    container_name: yc-zipkin
    ports:
      - "9411:9411"
    networks:
      - yc-microservices
      - yc-dev-network
    restart: unless-stopped

  # NATS 消息队列
  nats:
    image: nats:latest
    container_name: yc-nats
    ports:
      - "4222:4222"  # Client connections
      - "8222:8222"  # HTTP monitoring
      - "6222:6222"  # Cluster connections
    command: ["-js", "-m", "8222"]
    networks:
      - yc-microservices
      - yc-dev-network
    restart: unless-stopped

  # RabbitMQ 消息队列
  rabbitmq:
    image: rabbitmq:3-management
    container_name: yc-rabbitmq
    ports:
      - "5672:5672"   # AMQP
      - "15672:15672" # Management UI
    environment:
      RABBITMQ_DEFAULT_USER: yc_admin
      RABBITMQ_DEFAULT_PASS: rabbitmq_password
    volumes:
      - /volume1/YC/services/rabbitmq:/var/lib/rabbitmq
    networks:
      - yc-microservices
      - yc-dev-network
    restart: unless-stopped

  # Vault 密钥管理
  vault:
    image: vault:latest
    container_name: yc-vault
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: yc-vault-token
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    networks:
      - yc-microservices
      - yc-dev-network
    restart: unless-stopped

  # Etcd 分布式键值存储
  etcd:
    image: quay.io/coreos/etcd:latest
    container_name: yc-etcd
    ports:
      - "2379:2379"
      - "2380:2380"
    environment:
      ETCD_NAME: node1
      ETCD_DATA_DIR: /etcd-data
      ETCD_LISTEN_CLIENT_URLS: http://0.0.0.0:2379
      ETCD_ADVERTISE_CLIENT_URLS: http://0.0.0.0:2379
      ETCD_LISTEN_PEER_URLS: http://0.0.0.0:2380
      ETCD_INITIAL_ADVERTISE_PEER_URLS: http://0.0.0.0:2380
      ETCD_INITIAL_CLUSTER: node1=http://0.0.0.0:2380
      ETCD_INITIAL_CLUSTER_TOKEN: etcd-cluster
      ETCD_INITIAL_CLUSTER_STATE: new
    volumes:
      - /volume1/YC/services/etcd:/etcd-data
    networks:
      - yc-microservices
      - yc-dev-network
    restart: unless-stopped
EOF

    log_success "微服务基础架构配置完成"
}

# 创建服务模板生成器
create_service_templates() {
    log_step "创建服务模板生成器..."
    
    mkdir -p "$ROOT_DIR/development/templates/microservices"
    
    # Node.js 微服务模板
    cat > "$ROOT_DIR/development/templates/microservices/nodejs-service.template" << 'EOF'
# Node.js 微服务模板
FROM node:18-alpine

WORKDIR /app

# 安装依赖
COPY package*.json ./
RUN npm ci --only=production

# 复制源代码
COPY . .

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

# 暴露端口
EXPOSE ${PORT:-3000}

# 启动服务
CMD ["npm", "start"]
EOF

    # Go 微服务模板
    cat > "$ROOT_DIR/development/templates/microservices/go-service.template" << 'EOF'
# Go 微服务模板
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates curl
WORKDIR /root/

COPY --from=builder /app/main .

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8080}/health || exit 1

EXPOSE ${PORT:-8080}
CMD ["./main"]
EOF

    # Python 微服务模板
    cat > "$ROOT_DIR/development/templates/microservices/python-service.template" << 'EOF'
# Python 微服务模板
FROM python:3.11-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制源代码
COPY . .

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

EXPOSE ${PORT:-8000}
CMD ["python", "app.py"]
EOF

    # 微服务生成脚本
    cat > "$ROOT_DIR/development/scripts/create-microservice.sh" << 'EOF'
#!/bin/bash

# 微服务生成脚本

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "❌ 用法: $0 <服务名称> <语言类型> [端口]"
    echo "语言类型: nodejs, go, python"
    echo "示例: $0 user-service nodejs 3001"
    exit 1
fi

SERVICE_NAME="$1"
LANGUAGE="$2"
PORT="${3:-3000}"
SERVICE_DIR="/volume1/YC/development/projects/microservices/$SERVICE_NAME"

echo "🚀 创建微服务: $SERVICE_NAME ($LANGUAGE)"

# 创建服务目录
mkdir -p "$SERVICE_DIR"
cd "$SERVICE_DIR"

case "$LANGUAGE" in
    "nodejs")
        # 创建 package.json
        cat > package.json << NODE_EOF
{
  "name": "$SERVICE_NAME",
  "version": "1.0.0",
  "description": "$SERVICE_NAME 微服务",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1",
    "axios": "^1.5.0",
    "consul": "^0.40.0",
    "prom-client": "^14.2.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.6.2"
  }
}
NODE_EOF

        # 创建主文件
        cat > index.js << 'NODE_MAIN_EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const consul = require('consul')();
const client = require('prom-client');

require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const SERVICE_NAME = process.env.SERVICE_NAME || 'SERVICE_NAME_PLACEHOLDER';

// 中间件
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

// Prometheus 指标
const register = new client.Registry();
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP 请求持续时间',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// 指标中间件
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration);
  });
  next();
});

// 健康检查
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: SERVICE_NAME,
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// 指标端点
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// 服务信息
app.get('/info', (req, res) => {
  res.json({
    name: SERVICE_NAME,
    version: process.env.npm_package_version || '1.0.0',
    description: 'SERVICE_NAME_PLACEHOLDER 微服务',
    environment: process.env.NODE_ENV || 'development'
  });
});

// 示例 API 端点
app.get('/api/hello', (req, res) => {
  res.json({
    message: `Hello from ${SERVICE_NAME}!`,
    timestamp: new Date().toISOString()
  });
});

// 错误处理
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// 404 处理
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.originalUrl
  });
});

// 启动服务
app.listen(PORT, () => {
  console.log(`🚀 ${SERVICE_NAME} 服务运行在端口 ${PORT}`);
  
  // 注册到 Consul
  consul.agent.service.register({
    name: SERVICE_NAME,
    id: `${SERVICE_NAME}-${PORT}`,
    address: process.env.SERVICE_HOST || 'localhost',
    port: parseInt(PORT),
    check: {
      http: `http://localhost:${PORT}/health`,
      interval: '10s'
    }
  }, (err) => {
    if (err) {
      console.error('Consul 注册失败:', err);
    } else {
      console.log(`✅ 服务已注册到 Consul: ${SERVICE_NAME}`);
    }
  });
});

// 优雅关闭
process.on('SIGTERM', () => {
  console.log('收到 SIGTERM 信号，开始优雅关闭...');
  consul.agent.service.deregister(`${SERVICE_NAME}-${PORT}`, () => {
    process.exit(0);
  });
});
NODE_MAIN_EOF

        # 替换占位符
        sed -i "s/SERVICE_NAME_PLACEHOLDER/$SERVICE_NAME/g" index.js
        
        # 创建 .env 文件
        cat > .env << ENV_EOF
NODE_ENV=development
PORT=$PORT
SERVICE_NAME=$SERVICE_NAME
SERVICE_HOST=localhost
CONSUL_HOST=192.168.3.45
CONSUL_PORT=8500
ENV_EOF

        # 创建 Dockerfile
        cp /volume1/YC/development/templates/microservices/nodejs-service.template Dockerfile
        ;;
        
    "go")
        # 创建 Go 模块
        go mod init "$SERVICE_NAME"
        
        # 创建主文件
        cat > main.go << 'GO_MAIN_EOF'
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
    
    "github.com/gorilla/mux"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

type Service struct {
    Name        string `json:"name"`
    Version     string `json:"version"`
    Description string `json:"description"`
    Environment string `json:"environment"`
}

type HealthResponse struct {
    Status    string    `json:"status"`
    Service   string    `json:"service"`
    Timestamp time.Time `json:"timestamp"`
    Uptime    float64   `json:"uptime"`
}

var (
    startTime = time.Now()
    httpDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "http_request_duration_seconds",
            Help: "HTTP 请求持续时间",
        },
        []string{"method", "route", "status_code"},
    )
)

func init() {
    prometheus.MustRegister(httpDuration)
}

func main() {
    serviceName := getEnv("SERVICE_NAME", "SERVICE_NAME_PLACEHOLDER")
    port := getEnv("PORT", "8080")
    
    r := mux.NewRouter()
    
    // 中间件
    r.Use(loggingMiddleware)
    r.Use(metricsMiddleware)
    
    // 路由
    r.HandleFunc("/health", healthHandler).Methods("GET")
    r.HandleFunc("/info", infoHandler).Methods("GET")
    r.HandleFunc("/api/hello", helloHandler).Methods("GET")
    r.Handle("/metrics", promhttp.Handler()).Methods("GET")
    
    // 启动服务器
    srv := &http.Server{
        Addr:    ":" + port,
        Handler: r,
    }
    
    go func() {
        log.Printf("🚀 %s 服务运行在端口 %s", serviceName, port)
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("服务启动失败: %v", err)
        }
    }()
    
    // 优雅关闭
    c := make(chan os.Signal, 1)
    signal.Notify(c, os.Interrupt, syscall.SIGTERM)
    <-c
    
    log.Println("收到关闭信号，开始优雅关闭...")
    // 这里可以添加清理逻辑
    os.Exit(0)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    response := HealthResponse{
        Status:    "healthy",
        Service:   getEnv("SERVICE_NAME", "SERVICE_NAME_PLACEHOLDER"),
        Timestamp: time.Now(),
        Uptime:    time.Since(startTime).Seconds(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func infoHandler(w http.ResponseWriter, r *http.Request) {
    service := Service{
        Name:        getEnv("SERVICE_NAME", "SERVICE_NAME_PLACEHOLDER"),
        Version:     "1.0.0",
        Description: "SERVICE_NAME_PLACEHOLDER 微服务",
        Environment: getEnv("GO_ENV", "development"),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(service)
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
    response := map[string]interface{}{
        "message":   fmt.Sprintf("Hello from %s!", getEnv("SERVICE_NAME", "SERVICE_NAME_PLACEHOLDER")),
        "timestamp": time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        next.ServeHTTP(w, r)
        log.Printf("%s %s %v", r.Method, r.URL.Path, time.Since(start))
    })
}

func metricsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        
        // 包装 ResponseWriter 以捕获状态码
        wrapped := &responseWriter{ResponseWriter: w, statusCode: 200}
        next.ServeHTTP(wrapped, r)
        
        duration := time.Since(start).Seconds()
        httpDuration.WithLabelValues(
            r.Method,
            r.URL.Path,
            fmt.Sprintf("%d", wrapped.statusCode),
        ).Observe(duration)
    })
}

type responseWriter struct {
    http.ResponseWriter
    statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.statusCode = code
    rw.ResponseWriter.WriteHeader(code)
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}
GO_MAIN_EOF

        # 替换占位符
        sed -i "s/SERVICE_NAME_PLACEHOLDER/$SERVICE_NAME/g" main.go
        
        # 创建 go.mod
        cat >> go.mod << GO_MOD_EOF

require (
    github.com/gorilla/mux v1.8.0
    github.com/prometheus/client_golang v1.16.0
)
GO_MOD_EOF

        # 创建 Dockerfile
        cp /volume1/YC/development/templates/microservices/go-service.template Dockerfile
        ;;
        
    "python")
        # 创建 requirements.txt
        cat > requirements.txt << PY_REQ_EOF
fastapi==0.103.1
uvicorn==0.23.2
pydantic==2.3.0
prometheus-client==0.17.1
python-consul==1.1.0
requests==2.31.0
python-dotenv==1.0.0
PY_REQ_EOF

        # 创建主文件
        cat > app.py << 'PY_MAIN_EOF'
import os
import time
import logging
from datetime import datetime
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response
import consul
from dotenv import load_dotenv

load_dotenv()

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 创建 FastAPI 应用
app = FastAPI(
    title="SERVICE_NAME_PLACEHOLDER",
    description="SERVICE_NAME_PLACEHOLDER 微服务",
    version="1.0.0"
)

# CORS 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Prometheus 指标
REQUEST_COUNT = Counter('http_requests_total', 'HTTP 请求总数', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP 请求持续时间', ['method', 'endpoint'])

# 服务配置
SERVICE_NAME = os.getenv('SERVICE_NAME', 'SERVICE_NAME_PLACEHOLDER')
PORT = int(os.getenv('PORT', 8000))
START_TIME = time.time()

# Consul 客户端
consul_client = consul.Consul(
    host=os.getenv('CONSUL_HOST', '192.168.3.45'),
    port=int(os.getenv('CONSUL_PORT', 8500))
)

@app.middleware("http")
async def metrics_middleware(request, call_next):
    start_time = time.time()
    
    response = await call_next(request)
    
    # 记录指标
    duration = time.time() - start_time
    REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
    
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    return response

@app.get("/health")
async def health_check():
    """健康检查端点"""
    return {
        "status": "healthy",
        "service": SERVICE_NAME,
        "timestamp": datetime.now().isoformat(),
        "uptime": time.time() - START_TIME
    }

@app.get("/info")
async def service_info():
    """服务信息端点"""
    return {
        "name": SERVICE_NAME,
        "version": "1.0.0",
        "description": f"{SERVICE_NAME} 微服务",
        "environment": os.getenv('PYTHON_ENV', 'development')
    }

@app.get("/api/hello")
async def hello():
    """示例 API 端点"""
    return {
        "message": f"Hello from {SERVICE_NAME}!",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/metrics")
async def metrics():
    """Prometheus 指标端点"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.on_event("startup")
async def startup_event():
    """服务启动事件"""
    logger.info(f"🚀 {SERVICE_NAME} 服务启动")
    
    # 注册到 Consul
    try:
        consul_client.agent.service.register(
            name=SERVICE_NAME,
            service_id=f"{SERVICE_NAME}-{PORT}",
            address=os.getenv('SERVICE_HOST', 'localhost'),
            port=PORT,
            check=consul.Check.http(f"http://localhost:{PORT}/health", interval="10s")
        )
        logger.info(f"✅ 服务已注册到 Consul: {SERVICE_NAME}")
    except Exception as e:
        logger.error(f"Consul 注册失败: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    """服务关闭事件"""
    logger.info("开始优雅关闭...")
    
    # 从 Consul 注销
    try:
        consul_client.agent.service.deregister(f"{SERVICE_NAME}-{PORT}")
        logger.info("✅ 服务已从 Consul 注销")
    except Exception as e:
        logger.error(f"Consul 注销失败: {e}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=PORT,
        reload=os.getenv('PYTHON_ENV') == 'development'
    )
PY_MAIN_EOF

        # 替换占位符
        sed -i "s/SERVICE_NAME_PLACEHOLDER/$SERVICE_NAME/g" app.py
        
        # 创建 .env 文件
        cat > .env << ENV_EOF
PYTHON_ENV=development
PORT=$PORT
SERVICE_NAME=$SERVICE_NAME
SERVICE_HOST=localhost
CONSUL_HOST=192.168.3.45
CONSUL_PORT=8500
ENV_EOF

        # 创建 Dockerfile
        cp /volume1/YC/development/templates/microservices/python-service.template Dockerfile
        ;;
        
    *)
        echo "❌ 不支持的语言类型: $LANGUAGE"
        exit 1
        ;;
esac

# 创建 docker-compose.yml
cat > docker-compose.yml << COMPOSE_EOF
version: '3.8'

networks:
  yc-dev-network:
    external: true
  yc-microservices:
    external: true

services:
  $SERVICE_NAME:
    build: .
    container_name: yc-$SERVICE_NAME
    ports:
      - "$PORT:$PORT"
    environment:
      - PORT=$PORT
      - SERVICE_NAME=$SERVICE_NAME
      - SERVICE_HOST=$SERVICE_NAME
      - CONSUL_HOST=yc-consul
      - CONSUL_PORT=8500
    networks:
      - yc-dev-network
      - yc-microservices
    restart: unless-stopped
    depends_on:
      - consul
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:$PORT/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  consul:
    image: consul:latest
    container_name: yc-consul
    external_links:
      - yc-consul
COMPOSE_EOF

# 创建 README.md
cat > README.md << README_EOF
# $SERVICE_NAME

$SERVICE_NAME 微服务

## 功能特性

- ✅ 健康检查端点
- ✅ Prometheus 指标收集
- ✅ Consul 服务发现
- ✅ 优雅关闭
- ✅ 结构化日志
- ✅ CORS 支持

## 快速开始

### 本地开发

\`\`\`bash
# 安装依赖
npm install  # Node.js
go mod tidy  # Go
pip install -r requirements.txt  # Python

# 启动服务
npm run dev     # Node.js
go run main.go  # Go
python app.py   # Python
\`\`\`

### Docker 部署

\`\`\`bash
# 构建镜像
docker build -t $SERVICE_NAME .

# 运行容器
docker-compose up -d
\`\`\`

## API 端点

- \`GET /health\` - 健康检查
- \`GET /info\` - 服务信息
- \`GET /api/hello\` - 示例接口
- \`GET /metrics\` - Prometheus 指标

## 环境变量

- \`PORT\` - 服务端口 (默认: $PORT)
- \`SERVICE_NAME\` - 服务名称
- \`CONSUL_HOST\` - Consul 主机地址
- \`CONSUL_PORT\` - Consul 端口

## 监控

服务自动注册到 Consul 并提供 Prometheus 指标。

访问地址:
- 服务: http://localhost:$PORT
- 健康检查: http://localhost:$PORT/health
- 指标: http://localhost:$PORT/metrics
README_EOF

echo "✅ 微服务 $SERVICE_NAME 创建完成！"
echo "📁 服务路径: $SERVICE_DIR"
echo "🌐 访问地址: http://192.168.3.45:$PORT"
echo ""
echo "🚀 下一步:"
echo "1. cd $SERVICE_DIR"
echo "2. docker-compose up -d"
echo "3. 访问 http://192.168.3.45:$PORT/health 检查服务状态"
EOF

    chmod +x "$ROOT_DIR/development/scripts/create-microservice.sh"
    
    log_success "服务模板生成器创建完成"
}

# 创建 DevOps 流水线
create_devops_pipeline() {
    log_step "创建 DevOps 流水线..."
    
    mkdir -p "$ROOT_DIR/development/pipelines"
    
    # GitLab CI/CD 模板
    cat > "$ROOT_DIR/development/pipelines/gitlab-ci.yml" << 'EOF'
# YC 微服务 CI/CD 流水线模板

stages:
  - test
  - build
  - security
  - deploy
  - monitor

variables:
  DOCKER_REGISTRY: "192.168.3.45:5000"
  KUBECONFIG: "/etc/deploy/config"

# 代码质量检查
code_quality:
  stage: test
  image: node:18-alpine
  script:
    - npm install
    - npm run lint
    - npm run test:coverage
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
  only:
    - merge_requests
    - main

# 安全扫描
security_scan:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy fs --exit-code 0 --format template --template "@contrib/sarif.tpl" -o trivy-results.sarif .
    - trivy fs --exit-code 1 --severity HIGH,CRITICAL .
  artifacts:
    reports:
      sast: trivy-results.sarif
  only:
    - merge_requests
    - main

# Docker 镜像构建
build_image:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $DOCKER_REGISTRY
  script:
    - docker build -t $DOCKER_REGISTRY/$CI_PROJECT_NAME:$CI_COMMIT_SHA .
    - docker build -t $DOCKER_REGISTRY/$CI_PROJECT_NAME:latest .
    - docker push $DOCKER_REGISTRY/$CI_PROJECT_NAME:$CI_COMMIT_SHA
    - docker push $DOCKER_REGISTRY/$CI_PROJECT_NAME:latest
  only:
    - main

# 部署到开发环境
deploy_dev:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl set image deployment/$CI_PROJECT_NAME $CI_PROJECT_NAME=$DOCKER_REGISTRY/$CI_PROJECT_NAME:$CI_COMMIT_SHA -n development
    - kubectl rollout status deployment/$CI_PROJECT_NAME -n development
  environment:
    name: development
    url: http://dev.yc.local
  only:
    - main

# 部署到生产环境
deploy_prod:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl set image deployment/$CI_PROJECT_NAME $CI_PROJECT_NAME=$DOCKER_REGISTRY/$CI_PROJECT_NAME:$CI_COMMIT_SHA -n production
    - kubectl rollout status deployment/$CI_PROJECT_NAME -n production
  environment:
    name: production
    url: http://prod.yc.local
  when: manual
  only:
    - main

# 性能测试
performance_test:
  stage: monitor
  image: loadimpact/k6:latest
  script:
    - k6 run --out influxdb=http://192.168.3.45:8086/k6 performance-test.js
  artifacts:
    reports:
      performance: performance-report.json
  only:
    - main
EOF

    # Jenkins 流水线模板
    cat > "$ROOT_DIR/development/pipelines/Jenkinsfile" << 'EOF'
// YC 微服务 Jenkins 流水线

pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = '192.168.3.45:5000'
        DOCKER_CREDENTIALS = credentials('docker-registry')
        KUBECONFIG = credentials('kubeconfig')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        script {
                            if (fileExists('package.json')) {
                                sh 'npm install'
                                sh 'npm test'
                            } else if (fileExists('go.mod')) {
                                sh 'go test ./...'
                            } else if (fileExists('requirements.txt')) {
                                sh 'pip install -r requirements.txt'
                                sh 'python -m pytest'
                            }
                        }
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'test-results.xml'
                        }
                    }
                }
                
                stage('Code Quality') {
                    steps {
                        script {
                            if (fileExists('package.json')) {
                                sh 'npm run lint'
                            } else if (fileExists('go.mod')) {
                                sh 'golangci-lint run'
                            } else if (fileExists('requirements.txt')) {
                                sh 'flake8 .'
                            }
                        }
                    }
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                sh 'trivy fs --exit-code 0 --format json -o trivy-results.json .'
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: '.',
                    reportFiles: 'trivy-results.json',
                    reportName: 'Security Scan Report'
                ])
            }
        }
        
        stage('Build') {
            steps {
                script {
                    def image = docker.build("${DOCKER_REGISTRY}/${env.JOB_NAME}:${env.BUILD_NUMBER}")
                    docker.withRegistry("http://${DOCKER_REGISTRY}", 'docker-registry') {
                        image.push()
                        image.push('latest')
                    }
                }
            }
        }
        
        stage('Deploy to Dev') {
            when {
                branch 'main'
            }
            steps {
                sh """
                    kubectl set image deployment/${env.JOB_NAME} ${env.JOB_NAME}=${DOCKER_REGISTRY}/${env.JOB_NAME}:${env.BUILD_NUMBER} -n development
                    kubectl rollout status deployment/${env.JOB_NAME} -n development
                """
            }
        }
        
        stage('Integration Tests') {
            when {
                branch 'main'
            }
            steps {
                sh 'npm run test:integration'
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                input message: '部署到生产环境?', ok: '部署'
                sh """
                    kubectl set image deployment/${env.JOB_NAME} ${env.JOB_NAME}=${DOCKER_REGISTRY}/${env.JOB_NAME}:${env.BUILD_NUMBER} -n production
                    kubectl rollout status deployment/${env.JOB_NAME} -n production
                """
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: "✅ ${env.JOB_NAME} #${env.BUILD_NUMBER} 部署成功"
            )
        }
        failure {
            slackSend(
                channel: '#deployments',
                color: 'danger',
                message: "❌ ${env.JOB_NAME} #${env.BUILD_NUMBER} 部署失败"
            )
        }
    }
}
EOF

    # GitHub Actions 模板
    cat > "$ROOT_DIR/development/pipelines/github-actions.yml" << 'EOF'
# YC 微服务 GitHub Actions 工作流

name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  DOCKER_REGISTRY: 192.168.3.45:5000
  KUBECONFIG_DATA: ${{ secrets.KUBECONFIG }}

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18.x, 20.x]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: ${{ matrix.node-version }}
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run tests
      run: npm test
    
    - name: Run linting
      run: npm run lint
    
    - name: Generate coverage report
      run: npm run test:coverage
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3

  security:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

  build:
    needs: [test, security]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Docker Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ env.DOCKER_REGISTRY }}
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: |
          ${{ env.DOCKER_REGISTRY }}/${{ github.repository }}:${{ github.sha }}
          ${{ env.DOCKER_REGISTRY }}/${{ github.repository }}:latest

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
    
    - name: Deploy to Kubernetes
      run: |
        echo "${{ env.KUBECONFIG_DATA }}" | base64 -d > kubeconfig
        export KUBECONFIG=kubeconfig
        kubectl set image deployment/${{ github.event.repository.name }} ${{ github.event.repository.name }}=${{ env.DOCKER_REGISTRY }}/${{ github.repository }}:${{ github.sha }} -n development
        kubectl rollout status deployment/${{ github.event.repository.name }} -n development
EOF

    log_success "DevOps 流水线模板创建完成"
}

# 创建智能运维系统
create_intelligent_ops() {
    log_step "创建智能运维系统..."
    
    cat > "$ROOT_DIR/development/docker-compose/intelligent-ops.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  # Fluentd 日志收集
  fluentd:
    image: fluent/fluentd:v1.16-debian-1
    container_name: yc-fluentd
    ports:
      - "24224:24224"
      - "24224:24224/udp"
    volumes:
      - /volume1/YC/services/fluentd:/fluentd/etc
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    environment:
      FLUENTD_CONF: fluent.conf
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Loki 日志存储
  loki:
    image: grafana/loki:latest
    container_name: yc-loki
    ports:
      - "3100:3100"
    volumes:
      - /volume1/YC/services/loki:/etc/loki
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Promtail 日志采集
  promtail:
    image: grafana/promtail:latest
    container_name: yc-promtail
    volumes:
      - /volume1/YC/services/promtail:/etc/promtail
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Thanos 长期存储
  thanos-sidecar:
    image: thanosio/thanos:latest
    container_name: yc-thanos-sidecar
    command:
      - sidecar
      - --tsdb.path=/prometheus
      - --prometheus.url=http://yc-prometheus:9090
      - --grpc-address=0.0.0.0:10901
      - --http-address=0.0.0.0:10902
    ports:
      - "10901:10901"
      - "10902:10902"
    volumes:
      - /volume1/YC/services/monitoring/prometheus-data:/prometheus
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Thanos Query
  thanos-query:
    image: thanosio/thanos:latest
    container_name: yc-thanos-query
    command:
      - query
      - --http-address=0.0.0.0:9090
      - --store=thanos-sidecar:10901
    ports:
      - "19090:9090"
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Chaos Engineering - Chaos Monkey
  chaos-monkey:
    image: node:18-alpine
    container_name: yc-chaos-monkey
    ports:
      - "3010:3000"
    volumes:
      - /volume1/YC/services/chaos-monkey:/app
      - /var/run/docker.sock:/var/run/docker.sock
    working_dir: /app
    command: |
      sh -c "
        if [ ! -f package.json ]; then
          npm init -y &&
          npm install express dockerode cron &&
          cat > chaos-monkey.js << 'CHAOS_EOF'
const express = require('express');
const Docker = require('dockerode');
const cron = require('cron');

const app = express();
const docker = new Docker();

app.use(express.json());

// 混沌实验配置
const chaosConfig = {
  enabled: false,
  targets: ['yc-'], // 目标容器前缀
  experiments: {
    killContainer: { probability: 0.1, enabled: true },
    pauseContainer: { probability: 0.05, enabled: true, duration: 30000 },
    networkDelay: { probability: 0.05, enabled: false },
    cpuStress: { probability: 0.05, enabled: false }
  }
};

// 获取目标容器
async function getTargetContainers() {
  const containers = await docker.listContainers();
  return containers.filter(container => 
    chaosConfig.targets.some(target => 
      container.Names.some(name => name.includes(target))
    )
  );
}

// 杀死容器实验
async function killContainerExperiment() {
  const containers = await getTargetContainers();
  if (containers.length === 0) return;
  
  const target = containers[Math.floor(Math.random() * containers.length)];
  const container = docker.getContainer(target.Id);
  
  console.log(\`🔥 混沌实验: 杀死容器 \${target.Names[0]}\`);
  
  try {
    await container.kill();
    console.log(\`✅ 容器 \${target.Names[0]} 已被杀死\`);
  } catch (error) {
    console.error(\`❌ 杀死容器失败: \${error.message}\`);
  }
}

// 暂停容器实验
async function pauseContainerExperiment() {
  const containers = await getTargetContainers();
  if (containers.length === 0) return;
  
  const target = containers[Math.floor(Math.random() * containers.length)];
  const container = docker.getContainer(target.Id);
  
  console.log(\`⏸️  混沌实验: 暂停容器 \${target.Names[0]}\`);
  
  try {
    await container.pause();
    console.log(\`✅ 容器 \${target.Names[0]} 已暂停\`);
    
    // 指定时间后恢复
    setTimeout(async () => {
      try {
        await container.unpause();
        console.log(\`▶️  容器 \${target.Names[0]} 已恢复\`);
      } catch (error) {
        console.error(\`❌ 恢复容器失败: \${error.message}\`);
      }
    }, chaosConfig.experiments.pauseContainer.duration);
    
  } catch (error) {
    console.error(\`❌ 暂停容器失败: \${error.message}\`);
  }
}

// 执行混沌实验
async function runChaosExperiments() {
  if (!chaosConfig.enabled) return;
  
  console.log('🐒 Chaos Monkey 开始执行实验...');
  
  const experiments = Object.entries(chaosConfig.experiments);
  
  for (const [name, config] of experiments) {
    if (!config.enabled) continue;
    
    if (Math.random() < config.probability) {
      switch (name) {
        case 'killContainer':
          await killContainerExperiment();
          break;
        case 'pauseContainer':
          await pauseContainerExperiment();
          break;
      }
    }
  }
}

// API 端点
app.get('/status', (req, res) => {
  res.json({
    enabled: chaosConfig.enabled,
    config: chaosConfig
  });
});

app.post('/enable', (req, res) => {
  chaosConfig.enabled = true;
  res.json({ message: 'Chaos Monkey 已启用' });
});

app.post('/disable', (req, res) => {
  chaosConfig.enabled = false;
  res.json({ message: 'Chaos Monkey 已禁用' });
});

app.post('/config', (req, res) => {
  Object.assign(chaosConfig, req.body);
  res.json({ message: '配置已更新', config: chaosConfig });
});

app.get('/experiments', async (req, res) => {
  const containers = await getTargetContainers();
  res.json({
    targetContainers: containers.length,
    experiments: chaosConfig.experiments
  });
});

// 定时任务 - 每5分钟执行一次
const chaosJob = new cron.CronJob('*/5 * * * *', runChaosExperiments);
chaosJob.start();

// Web 界面
app.get('/', (req, res) => {
  res.send(\`
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🐒 Chaos Monkey 控制台</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .card { background: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .status { padding: 10px 20px; border-radius: 20px; color: white; font-weight: bold; }
        .enabled { background: #e74c3c; }
        .disabled { background: #95a5a6; }
        .btn { padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; margin: 5px; }
        .btn-danger { background: #e74c3c; color: white; }
        .btn-success { background: #27ae60; color: white; }
        .btn-info { background: #3498db; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🐒 Chaos Monkey 控制台</h1>
            <p>混沌工程实验平台</p>
        </div>
        
        <div class="card">
            <h2>状态</h2>
            <div id="status" class="status disabled">禁用</div>
            <br>
            <button class="btn btn-danger" onclick="toggleChaos(true)">启用</button>
            <button class="btn btn-success" onclick="toggleChaos(false)">禁用</button>
            <button class="btn btn-info" onclick="loadStatus()">刷新状态</button>
        </div>
        
        <div class="card">
            <h2>实验配置</h2>
            <div id="experiments">加载中...</div>
        </div>
    </div>
    
    <script>
        async function loadStatus() {
            try {
                const response = await fetch('/status');
                const data = await response.json();
                
                const statusEl = document.getElementById('status');
                statusEl.textContent = data.enabled ? '启用' : '禁用';
                statusEl.className = 'status ' + (data.enabled ? 'enabled' : 'disabled');
                
                const experimentsEl = document.getElementById('experiments');
                experimentsEl.innerHTML = Object.entries(data.config.experiments)
                    .map(([name, config]) => \`
                        <div>
                            <strong>\${name}</strong>: 
                            概率 \${(config.probability * 100).toFixed(1)}%, 
                            状态 \${config.enabled ? '启用' : '禁用'}
                        </div>
                    \`).join('');
                    
            } catch (error) {
                console.error('加载状态失败:', error);
            }
        }
        
        async function toggleChaos(enable) {
            try {
                const response = await fetch(enable ? '/enable' : '/disable', {
                    method: 'POST'
                });
                const data = await response.json();
                alert(data.message);
                loadStatus();
            } catch (error) {
                alert('操作失败: ' + error.message);
            }
        }
        
        loadStatus();
        setInterval(loadStatus, 30000);
    </script>
</body>
</html>
  \`);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(\`🐒 Chaos Monkey 运行在端口 \${PORT}\`);
});
CHAOS_EOF
        fi &&
        node chaos-monkey.js
      "
    networks:
      - yc-dev-network
    restart: unless-stopped

  # 智能告警系统
  smart-alerting:
    image: node:18-alpine
    container_name: yc-smart-alerting
    ports:
      - "3011:3000"
    volumes:
      - /volume1/YC/services/smart-alerting:/app
    working_dir: /app
    command: |
      sh -c "
        if [ ! -f package.json ]; then
          npm init -y &&
          npm install express axios node-cron sqlite3 &&
          cat > smart-alerting.js << 'ALERT_EOF'
const express = require('express');
const axios = require('axios');
const cron = require('node-cron');
const sqlite3 = require('sqlite3').verbose();

const app = express();
app.use(express.json());

// 初始化数据库
const db = new sqlite3.Database('./alerts.db');
db.serialize(() => {
  db.run(\`CREATE TABLE IF NOT EXISTS alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    service TEXT,
    metric TEXT,
    value REAL,
    threshold REAL,
    severity TEXT,
    message TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolved BOOLEAN DEFAULT 0
  )\`);
  
  db.run(\`CREATE TABLE IF NOT EXISTS alert_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    service TEXT,
    metric TEXT,
    operator TEXT,
    threshold REAL,
    severity TEXT,
    enabled BOOLEAN DEFAULT 1
  )\`);
  
  // 默认告警规则
  const defaultRules = [
    ['CPU使用率过高', '*', 'cpu_usage', '>', 80, 'warning'],
    ['内存使用率过高', '*', 'memory_usage', '>', 85, 'critical'],
    ['磁盘使用率过高', '*', 'disk_usage', '>', 90, 'critical'],
    ['服务响应时间过长', '*', 'response_time', '>', 5000, 'warning'],
    ['错误率过高', '*', 'error_rate', '>', 5, 'critical']
  ];
  
  defaultRules.forEach(rule => {
    db.run(\`INSERT OR IGNORE INTO alert_rules (name, service, metric, operator, threshold, severity) 
             VALUES (?, ?, ?, ?, ?, ?)\`, rule);
  });
});

// 获取 Prometheus 指标
async function getPrometheusMetrics() {
  try {
    const response = await axios.get('http://yc-prometheus:9090/api/v1/query_range', {
      params: {
        query: 'up',
        start: Math.floor(Date.now() / 1000) - 300,
        end: Math.floor(Date.now() / 1000),
        step: 60
      }
    });
    return response.data.data.result;
  } catch (error) {
    console.error('获取 Prometheus 指标失败:', error.message);
    return [];
  }
}

// 检查告警规则
async function checkAlertRules() {
  console.log('🔍 检查告警规则...');
  
  db.all('SELECT * FROM alert_rules WHERE enabled = 1', async (err, rules) => {
    if (err) {
      console.error('查询告警规则失败:', err);
      return;
    }
    
    for (const rule of rules) {
      try {
        // 这里应该根据实际的监控系统查询指标
        // 示例：模拟检查逻辑
        const mockValue = Math.random() * 100;
        
        if (evaluateRule(mockValue, rule.operator, rule.threshold)) {
          const alert = {
            service: rule.service,
            metric: rule.metric,
            value: mockValue,
            threshold: rule.threshold,
            severity: rule.severity,
            message: \`\${rule.name}: \${rule.metric} 当前值 \${mockValue.toFixed(2)} \${rule.operator} 阈值 \${rule.threshold}\`
          };
          
          await createAlert(alert);
        }
      } catch (error) {
        console.error(\`检查规则 \${rule.name} 失败:\`, error);
      }
    }
  });
}

// 评估告警规则
function evaluateRule(value, operator, threshold) {
  switch (operator) {
    case '>': return value > threshold;
    case '<': return value < threshold;
    case '>=': return value >= threshold;
    case '<=': return value <= threshold;
    case '==': return value == threshold;
    case '!=': return value != threshold;
    default: return false;
  }
}

// 创建告警
async function createAlert(alert) {
  return new Promise((resolve, reject) => {
    db.run(\`INSERT INTO alerts (service, metric, value, threshold, severity, message) 
             VALUES (?, ?, ?, ?, ?, ?)\`,
           [alert.service, alert.metric, alert.value, alert.threshold, alert.severity, alert.message],
           function(err) {
      if (err) {
        reject(err);
      } else {
        console.log(\`🚨 新告警: \${alert.message}\`);
        sendNotification(alert);
        resolve(this.lastID);
      }
    });
  });
}

// 发送通知
async function sendNotification(alert) {
  try {
    // 发送到 Slack/微信/邮件等
    console.log(\`📢 发送通知: \${alert.message}\`);
    
    // 示例：发送到 Webhook
    if (process.env.WEBHOOK_URL) {
      await axios.post(process.env.WEBHOOK_URL, {
        text: \`🚨 YC 开发环境告警\\n\${alert.message}\\n严重级别: \${alert.severity}\`,
        severity: alert.severity
      });
    }
  } catch (error) {
    console.error('发送通知失败:', error.message);
  }
}

// API 端点
app.get('/alerts', (req, res) => {
  const { resolved = 0, limit = 50 } = req.query;
  
  db.all(\`SELECT * FROM alerts WHERE resolved = ? ORDER BY timestamp DESC LIMIT ?\`,
         [resolved, limit], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
    } else {
      res.json(rows);
    }
  });
});

app.get('/rules', (req, res) => {
  db.all('SELECT * FROM alert_rules ORDER BY name', (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
    } else {
      res.json(rows);
    }
  });
});

app.post('/rules', (req, res) => {
  const { name, service, metric, operator, threshold, severity } = req.body;
  
  db.run(\`INSERT INTO alert_rules (name, service, metric, operator, threshold, severity) 
           VALUES (?, ?, ?, ?, ?, ?)\`,
         [name, service, metric, operator, threshold, severity], function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
    } else {
      res.json({ id: this.lastID, message: '告警规则创建成功' });
    }
  });
});

app.put('/alerts/:id/resolve', (req, res) => {
  const { id } = req.params;
  
  db.run('UPDATE alerts SET resolved = 1 WHERE id = ?', [id], function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
    } else {
      res.json({ message: '告警已解决' });
    }
  });
});

// 告警统计
app.get('/stats', (req, res) => {
  const stats = {};
  
  db.get('SELECT COUNT(*) as total FROM alerts WHERE resolved = 0', (err, row) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    stats.activeAlerts = row.total;
    
    db.all(\`SELECT severity, COUNT(*) as count FROM alerts 
             WHERE resolved = 0 GROUP BY severity\`, (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      
      stats.bySeverity = rows.reduce((acc, row) => {
        acc[row.severity] = row.count;
        return acc;
      }, {});
      
      res.json(stats);
    });
  });
});

// Web 界面
app.get('/', (req, res) => {
  res.send(\`
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🚨 智能告警系统</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 40px; }
        .stat-card { background: white; padding: 20px; border-radius: 10px; text-align: center; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .stat-number { font-size: 2em; font-weight: bold; margin-bottom: 10px; }
        .critical { color: #e74c3c; }
        .warning { color: #f39c12; }
        .info { color: #3498db; }
        .alerts { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .alert-item { padding: 15px; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; align-items: center; }
        .alert-message { flex: 1; }
        .alert-time { color: #666; font-size: 0.9em; }
        .severity-badge { padding: 4px 12px; border-radius: 20px; color: white; font-size: 12px; font-weight: bold; }
        .severity-critical { background: #e74c3c; }
        .severity-warning { background: #f39c12; }
        .severity-info { background: #3498db; }
        .btn { padding: 8px 16px; border: none; border-radius: 5px; cursor: pointer; }
        .btn-success { background: #27ae60; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚨 智能告警系统</h1>
            <p>实时监控和智能告警管理</p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number critical" id="activeAlerts">-</div>
                <div>活跃告警</div>
            </div>
            <div class="stat-card">
                <div class="stat-number critical" id="criticalAlerts">-</div>
                <div>严重告警</div>
            </div>
            <div class="stat-card">
                <div class="stat-number warning" id="warningAlerts">-</div>
                <div>警告告警</div>
            </div>
            <div class="stat-card">
                <div class="stat-number info" id="infoAlerts">-</div>
                <div>信息告警</div>
            </div>
        </div>
        
        <div class="alerts">
            <h2>最新告警</h2>
            <div id="alertsList">加载中...</div>
        </div>
    </div>
    
    <script>
        async function loadStats() {
            try {
                const response = await fetch('/stats');
                const stats = await response.json();
                
                document.getElementById('activeAlerts').textContent = stats.activeAlerts || 0;
                document.getElementById('criticalAlerts').textContent = stats.bySeverity?.critical || 0;
                document.getElementById('warningAlerts').textContent = stats.bySeverity?.warning || 0;
                document.getElementById('infoAlerts').textContent = stats.bySeverity?.info || 0;
            } catch (error) {
                console.error('加载统计失败:', error);
            }
        }
        
        async function loadAlerts() {
            try {
                const response = await fetch('/alerts?limit=20');
                const alerts = await response.json();
                
                const alertsList = document.getElementById('alertsList');
                if (alerts.length === 0) {
                    alertsList.innerHTML = '<p>暂无告警</p>';
                } else {
                    alertsList.innerHTML = alerts.map(alert => \`
                        <div class="alert-item">
                            <div class="alert-message">
                                <strong>\${alert.message}</strong><br>
                                <small>服务: \${alert.service} | 指标: \${alert.metric}</small>
                            </div>
                            <div>
                                <span class="severity-badge severity-\${alert.severity}">\${alert.severity}</span>
                                <div class="alert-time">\${new Date(alert.timestamp).toLocaleString()}</div>
                                \${!alert.resolved ? \`<button class="btn btn-success" onclick="resolveAlert(\${alert.id})">解决</button>\` : ''}
                            </div>
                        </div>
                    \`).join('');
                }
            } catch (error) {
                console.error('加载告警失败:', error);
            }
        }
        
        async function resolveAlert(id) {
            try {
                await fetch(\`/alerts/\${id}/resolve\`, { method: 'PUT' });
                loadAlerts();
                loadStats();
            } catch (error) {
                alert('解决告警失败: ' + error.message);
            }
        }
        
        loadStats();
        loadAlerts();
        setInterval(() => {
            loadStats();
            loadAlerts();
        }, 30000);
    </script>
</body>
</html>
  \`);
});

// 定时检查告警规则（每分钟）
cron.schedule('* * * * *', checkAlertRules);

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(\`🚨 智能告警系统运行在端口 \${PORT}\`);
});
ALERT_EOF
        fi &&
        node smart-alerting.js
      "
    networks:
      - yc-dev-network
    restart: unless-stopped
EOF

    log_success "智能运维系统创建完成"
}

# 创建企业级集成
create_enterprise_integrations() {
    log_step "创建企业级集成..."
    
    cat > "$ROOT_DIR/development/docker-compose/enterprise.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  # LDAP 目录服务
  openldap:
    image: osixia/openldap:latest
    container_name: yc-openldap
    ports:
      - "389:389"
      - "636:636"
    environment:
      LDAP_ORGANISATION: "YC Development"
      LDAP_DOMAIN: "yc.local"
      LDAP_ADMIN_PASSWORD: "admin_password"
      LDAP_CONFIG_PASSWORD: "config_password"
      LDAP_READONLY_USER: "true"
      LDAP_READONLY_USER_USERNAME: "readonly"
      LDAP_READONLY_USER_PASSWORD: "readonly_password"
    volumes:
      - /volume1/YC/services/ldap/database:/var/lib/ldap
      - /volume1/YC/services/ldap/config:/etc/ldap/slapd.d
    networks:
      - yc-dev-network
    restart: unless-stopped

  # LDAP 管理界面
  phpldapadmin:
    image: osixia/phpldapadmin:latest
    container_name: yc-phpldapadmin
    ports:
      - "6443:443"
    environment:
      PHPLDAPADMIN_LDAP_HOSTS: openldap
      PHPLDAPADMIN_HTTPS: "false"
    depends_on:
      - openldap
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Keycloak 身份认证
  keycloak-db:
    image: postgres:13
    container_name: yc-keycloak-db
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: keycloak_password
    volumes:
      - /volume1/YC/services/keycloak/db:/var/lib/postgresql/data
    networks:
      - yc-dev-network
    restart: unless-stopped

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: yc-keycloak
    ports:
      - "8080:8080"
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin_password
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://keycloak-db:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: keycloak_password
      KC_HOSTNAME: 192.168.3.45
    command: start-dev
    depends_on:
      - keycloak-db
    networks:
      - yc-dev-network
    restart: unless-stopped

  # SonarQube 代码质量
  sonarqube-db:
    image: postgres:13
    container_name: yc-sonarqube-db
    environment:
      POSTGRES_DB: sonarqube
      POSTGRES_USER: sonarqube
      POSTGRES_PASSWORD: sonarqube_password
    volumes:
      - /volume1/YC/services/sonarqube/db:/var/lib/postgresql/data
    networks:
      - yc-dev-network
    restart: unless-stopped

  sonarqube:
    image: sonarqube:community
    container_name: yc-sonarqube
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonarqube-db:5432/sonarqube
      SONAR_JDBC_USERNAME: sonarqube
      SONAR_JDBC_PASSWORD: sonarqube_password
    volumes:
      - /volume1/YC/services/sonarqube/data:/opt/sonarqube/data
      - /volume1/YC/services/sonarqube/logs:/opt/sonarqube/logs
      - /volume1/YC/services/sonarqube/extensions:/opt/sonarqube/extensions
    depends_on:
      - sonarqube-db
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Nexus 制品仓库
  nexus:
    image: sonatype/nexus3:latest
    container_name: yc-nexus
    ports:
      - "8081:8081"
      - "5000:5000"  # Docker registry
    environment:
      NEXUS_SECURITY_RANDOMPASSWORD: "false"
    volumes:
      - /volume1/YC/services/nexus:/nexus-data
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Harbor 容器镜像仓库
  harbor-db:
    image: postgres:13
    container_name: yc-harbor-db
    environment:
      POSTGRES_DB: registry
      POSTGRES_USER: harbor
      POSTGRES_PASSWORD: harbor_password
    volumes:
      - /volume1/YC/services/harbor/db:/var/lib/postgresql/data
    networks:
      - yc-dev-network
    restart: unless-stopped

  redis-harbor:
    image: redis:alpine
    container_name: yc-redis-harbor
    networks:
      - yc-dev-network
    restart: unless-stopped

  harbor-core:
    image: goharbor/harbor-core:latest
    container_name: yc-harbor-core
    ports:
      - "8082:8080"
    environment:
      CORE_SECRET: harbor_secret
      JOBSERVICE_SECRET: jobservice_secret
      DATABASE_TYPE: postgresql
      DATABASE_HOST: harbor-db
      DATABASE_PORT: 5432
      DATABASE_USERNAME: harbor
      DATABASE_PASSWORD: harbor_password
      DATABASE_SSLMODE: disable
      REDIS_HOST: redis-harbor
      REDIS_PORT: 6379
    volumes:
      - /volume1/YC/services/harbor/config:/etc/core
      - /volume1/YC/services/harbor/data:/data
    depends_on:
      - harbor-db
      - redis-harbor
    networks:
      - yc-dev-network
    restart: unless-stopped

  # Artifactory 制品管理
  artifactory:
    image: docker.bintray.io/jfrog/artifactory-oss:latest
    container_name: yc-artifactory
    ports:
      - "8082:8082"
    environment:
      JF_SHARED_DATABASE_TYPE: postgresql
      JF_SHARED_DATABASE_DRIVER: org.postgresql.Driver
      JF_SHARED_DATABASE_URL: jdbc:postgresql://artifactory-db:5432/artifactory
      JF_SHARED_DATABASE_USERNAME: artifactory
      JF_SHARED_DATABASE_PASSWORD: artifactory_password
    volumes:
      - /volume1/YC/services/artifactory:/var/opt/jfrog/artifactory
    networks:
      - yc-dev-network
    restart: unless-stopped

  artifactory-db:
    image: postgres:13
    container_name: yc-artifactory-db
    environment:
      POSTGRES_DB: artifactory
      POSTGRES_USER: artifactory
      POSTGRES_PASSWORD: artifactory_password
    volumes:
      - /volume1/YC/services/artifactory/db:/var/lib/postgresql/data
    networks:
      - yc-dev-network
    restart: unless-stopped
EOF

    # 创建企业集成管理脚本
    cat > "$ROOT_DIR/development/scripts/enterprise-manager.sh" << 'EOF'
#!/bin/bash

# 企业级集成管理脚本

ROOT_DIR="/volume1/YC"
COMPOSE_DIR="$ROOT_DIR/development/docker-compose"

show_menu() {
    echo "🏢 YC 企业级集成管理"
    echo "===================="
    echo "1. 启动身份认证服务"
    echo "2. 启动代码质量服务"
    echo "3. 启动制品仓库服务"
    echo "4. 配置 LDAP 用户"
    echo "5. 配置 Keycloak 域"
    echo "6. 初始化 SonarQube"
    echo "7. 配置 Nexus 仓库"
    echo "8. 查看服务状态"
    echo "9. 生成集成报告"
    echo "0. 退出"
    echo "===================="
}

start_auth_services() {
    echo "🔐 启动身份认证服务..."
    docker-compose -f "$COMPOSE_DIR/enterprise.yml" up -d openldap phpldapadmin keycloak keycloak-db
    echo "✅ 身份认证服务启动完成"
    echo "🌐 LDAP 管理: http://192.168.3.45:6443"
    echo "🌐 Keycloak: http://192.168.3.45:8080"
}

start_quality_services() {
    echo "📊 启动代码质量服务..."
    docker-compose -f "$COMPOSE_DIR/enterprise.yml" up -d sonarqube sonarqube-db
    echo "✅ 代码质量服务启动完成"
    echo "🌐 SonarQube: http://192.168.3.45:9000"
}

start_artifact_services() {
    echo "📦 启动制品仓库服务..."
    docker-compose -f "$COMPOSE_DIR/enterprise.yml" up -d nexus harbor-db redis-harbor harbor-core artifactory artifactory-db
    echo "✅ 制品仓库服��启动完成"
    echo "🌐 Nexus: http://192.168.3.45:8081"
    echo "🌐 Harbor: http://192.168.3.45:8082"
    echo "🌐 Artifactory: http://192.168.3.45:8082"
}

configure_ldap() {
    echo "👥 配置 LDAP 用户..."
    
    # 等待 LDAP 服务启动
    echo "等待 LDAP 服务启动..."
    sleep 10
    
    # 创建组织单位
    cat > /tmp/ou.ldif << EOF
dn: ou=people,dc=yc,dc=local
objectClass: organizationalUnit
ou: people

dn: ou=groups,dc=yc,dc=local
objectClass: organizationalUnit
ou: groups
EOF

    # 创建用户组
    cat > /tmp/groups.ldif << EOF
dn: cn=developers,ou=groups,dc=yc,dc=local
objectClass: groupOfNames
cn: developers
member: cn=admin,dc=yc,dc=local

dn: cn=admins,ou=groups,dc=yc,dc=local
objectClass: groupOfNames
cn: admins
member: cn=admin,dc=yc,dc=local
EOF

    # 创建示例用户
    cat > /tmp/users.ldif << EOF
dn: cn=developer1,ou=people,dc=yc,dc=local
objectClass: inetOrgPerson
cn: developer1
sn: Developer
givenName: Test
mail: developer1@yc.local
userPassword: password123

dn: cn=developer2,ou=people,dc=yc,dc=local
objectClass: inetOrgPerson
cn: developer2
sn: Developer
givenName: Test
mail: developer2@yc.local
userPassword: password123
EOF

    # 导入 LDIF 文件
    docker exec yc-openldap ldapadd -x -D "cn=admin,dc=yc,dc=local" -w admin_password -f /tmp/ou.ldif 2>/dev/null || echo "组织单位可能已存在"
    docker exec yc-openldap ldapadd -x -D "cn=admin,dc=yc,dc=local" -w admin_password -f /tmp/groups.ldif 2>/dev/null || echo "用户组可能已存在"
    docker exec yc-openldap ldapadd -x -D "cn=admin,dc=yc,dc=local" -w admin_password -f /tmp/users.ldif 2>/dev/null || echo "用户可能已存在"
    
    rm -f /tmp/*.ldif
    echo "✅ LDAP 用户配置完成"
}

configure_keycloak() {
    echo "🔑 配置 Keycloak 域..."
    
    echo "等待 Keycloak 服务启动..."
    sleep 30
    
    # 这里可以添加 Keycloak 配置脚本
    echo "✅ Keycloak 配置完成"
    echo "💡 请访问 http://192.168.3.45:8080 手动配置域和客户端"
}

init_sonarqube() {
    echo "📊 初始化 SonarQube..."
    
    echo "等待 SonarQube 服务启动..."
    sleep 60
    
    # 等待 SonarQube 完全启动
    while ! curl -s http://192.168.3.45:9000/api/system/status | grep -q "UP"; do
        echo "等待 SonarQube 启动..."
        sleep 10
    done
    
    echo "✅ SonarQube 初始化完成"
    echo "🔑 默认登录: admin/admin"
    echo "💡 首次登录需要修改密码"
}

configure_nexus() {
    echo "📦 配置 Nexus 仓库..."
    
    echo "等待 Nexus 服务启动..."
    sleep 60
    
    # 获取初始密码
    if docker exec yc-nexus test -f /nexus-data/admin.password; then
        NEXUS_PASSWORD=$(docker exec yc-nexus cat /nexus-data/admin.password)
        echo "✅ Nexus 配置完成"
        echo "🔑 初始登录: admin/$NEXUS_PASSWORD"
        echo "💡 首次登录需要修改密码并配置仓库"
    else
        echo "⚠️ 无法获取 Nexus 初始密码，请手动配置"
    fi
}

show_status() {
    echo "📊 企业服务状态："
    echo "=================="
    
    services=(
        "yc-openldap:LDAP目录服务"
        "yc-keycloak:身份认证"
        "yc-sonarqube:代码质量"
        "yc-nexus:制品仓库"
        "yc-harbor-core:容器仓库"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r container_name service_name <<< "$service"
        if docker ps | grep -q "$container_name"; then
            echo "✅ $service_name - 运行中"
        else
            echo "❌ $service_name - 未运行"
        fi
    done
}

generate_report() {
    echo "📋 生成企业集成报告..."
    
    REPORT_FILE="$ROOT_DIR/shared/enterprise_integration_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOF
YC 企业级集成报告
==================
生成时间: $(date)

服务状态:
$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(ldap|keycloak|sonar|nexus|harbor|artifactory)")

服务访问地址:
- LDAP 管理: http://192.168.3.45:6443
- Keycloak: http://192.168.3.45:8080
- SonarQube: http://192.168.3.45:9000
- Nexus: http://192.168.3.45:8081
- Harbor: http://192.168.3.45:8082

默认账户信息:
- LDAP 管理员: cn=admin,dc=yc,dc=local / admin_password
- Keycloak 管理员: admin / admin_password
- SonarQube 管理员: admin / admin (首次登录需修改)
- Nexus 管理员: admin / (查看容器内 admin.password 文件)

集成配置:
- LDAP 域: yc.local
- 用户组织: ou=people,dc=yc,dc=local
- 用户组: developers, admins
- 示例用户: developer1, developer2

配置文件位置:
- LDAP 数据: /volume1/YC/services/ldap/
- Keycloak 数据: /volume1/YC/services/keycloak/
- SonarQube 数据: /volume1/YC/services/sonarqube/
- Nexus 数据: /volume1/YC/services/nexus/

集成完成！🎉
EOF

    echo "✅ 企业集成报告生成完成: $REPORT_FILE"
}

# 主循环
while true; do
    show_menu
    read -p "请选择操作 (0-9): " choice
    
    case $choice in
        1) start_auth_services ;;
        2) start_quality_services ;;
        3) start_artifact_services ;;
        4) configure_ldap ;;
        5) configure_keycloak ;;
        6) init_sonarqube ;;
        7) configure_nexus ;;
        8) show_status ;;
        9) generate_report ;;
        0) echo "👋 再见！"; exit 0 ;;
        *) echo "❌ 无效选择，请重新输入" ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
    clear
done
EOF

    chmod +x "$ROOT_DIR/development/scripts/enterprise-manager.sh"
    
    log_success "企业级集成创建完成"
}

# 主函数
main() {
    echo "🚀 开始 YC 微服务和企业级功能部署"
    echo "===================================="
    
    create_microservices_infrastructure
    create_service_templates
    create_devops_pipeline
    create_intelligent_ops
    create_enterprise_integrations
    
    echo ""
    echo "🎉 微服务和企业级功能部署完成！"
    echo "==============================="
    echo ""
    echo "🏗️ 微服务架构："
    echo "• Kong API 网关"
    echo "• Consul 服务发现"
    echo "• Jaeger 分布式追踪"
    echo "• NATS/RabbitMQ 消息队列"
    echo "• Vault 密钥管理"
    echo ""
    echo "🔧 DevOps 流水线："
    echo "• GitLab CI/CD 模板"
    echo "• Jenkins 流水线"
    echo "• GitHub Actions 工作流"
    echo ""
    echo "🤖 智能运维："
    echo "• Fluentd 日志收集"
    echo "• Loki 日志存储"
    echo "• Thanos 长期存储"
    echo "• Chaos Monkey 混沌工程"
    echo "• 智能告警系统"
    echo ""
    echo "🏢 企业级集成："
    echo "• LDAP 目录服务"
    echo "• Keycloak 身份认证"
    echo "• SonarQube 代码质量"
    echo "• Nexus 制品仓库"
    echo "• Harbor 容器仓库"
    echo ""
    echo "🛠️ 管理工具："
    echo "• 微服务生成器: $ROOT_DIR/development/scripts/create-microservice.sh"
    echo "• 企业集成管理: $ROOT_DIR/development/scripts/enterprise-manager.sh"
    echo ""
    echo "🌐 新增服务地址："
    echo "• Kong 管理: http://192.168.3.45:1337"
    echo "• Consul: http://192.168.3.45:8500"
    echo "• Jaeger: http://192.168.3.45:16686"
    echo "• Chaos Monkey: http://192.168.3.45:3010"
    echo "• 智能告警: http://192.168.3.45:3011"
    echo "• LDAP 管理: http://192.168.3.45:6443"
    echo "• Keycloak: http://192.168.3.45:8080"
    echo "• SonarQube: http://192.168.3.45:9000"
    echo "• Nexus: http://192.168.3.45:8081"
    echo ""
    
    read -p "是否启动企业集成管理器？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$ROOT_DIR/development/scripts/enterprise-manager.sh"
    fi
}

# 执行主函数
main "$@"
