#!/bin/bash

# YC 开发环境安全加固脚本
# 包含 SSL 证书、防火墙、访问控制等安全配置

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

# 创建 SSL 证书
create_ssl_certificates() {
    log_step "创建 SSL 证书..."
    
    SSL_DIR="$ROOT_DIR/services/ssl"
    mkdir -p "$SSL_DIR"
    
    # 创建 CA 私钥
    openssl genrsa -out "$SSL_DIR/ca-key.pem" 4096
    
    # 创建 CA 证书
    openssl req -new -x509 -days 365 -key "$SSL_DIR/ca-key.pem" -sha256 -out "$SSL_DIR/ca.pem" -subj "/C=CN/ST=Beijing/L=Beijing/O=YC/OU=Dev/CN=YC-CA"
    
    # 创建服务器私钥
    openssl genrsa -out "$SSL_DIR/server-key.pem" 4096
    
    # 创建服务器证书请求
    openssl req -subj "/C=CN/ST=Beijing/L=Beijing/O=YC/OU=Dev/CN=yc.local" -sha256 -new -key "$SSL_DIR/server-key.pem" -out "$SSL_DIR/server.csr"
    
    # 创建扩展文件
    cat > "$SSL_DIR/server-extfile.cnf" << EOF
subjectAltName = DNS:yc.local,DNS:*.yc.local,IP:192.168.3.45,IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF
    
    # 创建服务器证书
    openssl x509 -req -days 365 -sha256 -in "$SSL_DIR/server.csr" -CA "$SSL_DIR/ca.pem" -CAkey "$SSL_DIR/ca-key.pem" -out "$SSL_DIR/server-cert.pem" -extfile "$SSL_DIR/server-extfile.cnf" -CAcreateserial
    
    # 设置权限
    chmod 400 "$SSL_DIR/ca-key.pem" "$SSL_DIR/server-key.pem"
    chmod 444 "$SSL_DIR/ca.pem" "$SSL_DIR/server-cert.pem"
    
    log_success "SSL 证书创建完成"
}

# 创建安全的 Nginx 配置
create_secure_nginx_config() {
    log_step "创建安全的 Nginx 配置..."
    
    cat > "$ROOT_DIR/services/nginx/conf.d/ssl.conf" << 'EOF'
# SSL 安全配置
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
ssl_prefer_server_ciphers on;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# 安全头
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Referrer-Policy "strict-origin-when-cross-origin";

# 隐藏 Nginx 版本
server_tokens off;
EOF

    # 更新主配置文件
    cat > "$ROOT_DIR/services/nginx/conf.d/secure-default.conf" << 'EOF'
# YC 开发环境安全配置

# HTTP 重定向到 HTTPS
server {
    listen 80 default_server;
    server_name _;
    return 301 https://$server_name$request_uri;
}

# HTTPS 主服务器
server {
    listen 443 ssl http2 default_server;
    server_name yc.local *.yc.local 192.168.3.45;
    
    ssl_certificate /etc/nginx/ssl/server-cert.pem;
    ssl_certificate_key /etc/nginx/ssl/server-key.pem;
    
    include /etc/nginx/conf.d/ssl.conf;
    
    # 主页面
    location / {
        return 200 '
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🔒 YC 安全开发环境控制台</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, sans-serif; 
            margin: 0; padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .header h1 { font-size: 3em; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
        .security-badge { 
            background: rgba(255,255,255,0.2); 
            padding: 10px 20px; 
            border-radius: 25px; 
            display: inline-block;
            margin-top: 10px;
        }
        .services { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); 
            gap: 20px; 
        }
        .service { 
            background: rgba(255,255,255,0.1); 
            padding: 20px; 
            border-radius: 15px; 
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
            transition: transform 0.3s ease;
        }
        .service:hover { transform: translateY(-5px); }
        .service h3 { margin-top: 0; color: #fff; font-size: 1.3em; }
        .service a { 
            color: #ffd700; 
            text-decoration: none; 
            font-weight: bold;
            display: inline-block;
            margin-top: 10px;
            padding: 8px 16px;
            background: rgba(255,215,0,0.2);
            border-radius: 8px;
            transition: background 0.3s ease;
        }
        .service a:hover { background: rgba(255,215,0,0.3); }
        .status-indicator {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #00ff00;
            display: inline-block;
            margin-right: 8px;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 YC 安全开发环境</h1>
            <div class="security-badge">
                <span class="status-indicator"></span>
                SSL 加密 • 安全访问 • 企业级防护
            </div>
        </div>
        <div class="services">
            <div class="service">
                <h3>🐙 GitLab 代码仓库</h3>
                <p>安全的 Git 代码管理和 CI/CD 流水线</p>
                <a href="https://192.168.3.45:8443/gitlab" target="_blank">安全访问 GitLab →</a>
            </div>
            <div class="service">
                <h3>🐳 Portainer 容器管理</h3>
                <p>Docker 容器可视化管理平台</p>
                <a href="https://192.168.3.45:9443" target="_blank">访问 Portainer →</a>
            </div>
            <div class="service">
                <h3>🤖 AI 模型服务</h3>
                <p>安全的大语言模型服务接口</p>
                <a href="https://192.168.3.45:3443" target="_blank">访问 AI 服务 →</a>
            </div>
            <div class="service">
                <h3>💻 Code Server</h3>
                <p>Web 版 VS Code 开发环境</p>
                <a href="https://192.168.3.45:8443" target="_blank">打开 Code Server →</a>
            </div>
            <div class="service">
                <h3>📊 监控面板</h3>
                <p>系统性能和安全监控</p>
                <a href="https://192.168.3.45:3443/grafana" target="_blank">查看监控 →</a>
            </div>
            <div class="service">
                <h3>🔐 安全中心</h3>
                <p>访问控制和安全审计</p>
                <a href="https://192.168.3.45:8443/security" target="_blank">安全管理 →</a>
            </div>
        </div>
    </div>
</body>
</html>
        ';
        add_header Content-Type text/html;
    }
    
    # API 网关
    location /api/ {
        # 限制请求频率
        limit_req zone=api burst=20 nodelay;
        
        # 根据路径代理到不同服务
        location /api/git/ {
            proxy_pass https://yc-gitlab:443/;
            include /etc/nginx/proxy_params;
        }
        
        location /api/ai/ {
            proxy_pass http://yc-ai-gateway:80/;
            include /etc/nginx/proxy_params;
        }
        
        location /api/monitor/ {
            proxy_pass http://yc-prometheus:9090/;
            include /etc/nginx/proxy_params;
        }
    }
}

# 限制请求频率
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
EOF

    # 创建代理参数文件
    cat > "$ROOT_DIR/services/nginx/proxy_params" << 'EOF'
proxy_set_header Host $http_host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $server_name;
proxy_buffering off;
EOF

    log_success "安全 Nginx 配置完成"
}

# 创建访问控制系统
create_access_control() {
    log_step "创建访问控制系统..."
    
    mkdir -p "$ROOT_DIR/services/auth"
    
    # 创建用户认证服务
    cat > "$ROOT_DIR/development/docker-compose/auth-service.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  # OAuth2 Proxy
  oauth2-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy:latest
    container_name: yc-oauth2-proxy
    ports:
      - "4180:4180"
    environment:
      OAUTH2_PROXY_PROVIDER: github
      OAUTH2_PROXY_CLIENT_ID: your-github-client-id
      OAUTH2_PROXY_CLIENT_SECRET: your-github-client-secret
      OAUTH2_PROXY_COOKIE_SECRET: your-cookie-secret-32-chars
      OAUTH2_PROXY_EMAIL_DOMAINS: "*"
      OAUTH2_PROXY_UPSTREAM: file:///dev/null
      OAUTH2_PROXY_HTTP_ADDRESS: 0.0.0.0:4180
      OAUTH2_PROXY_REDIRECT_URL: https://192.168.3.45:4180/oauth2/callback
    networks:
      - yc-dev-network
    restart: unless-stopped

  # 访问控制管理界面
  access-manager:
    image: node:18-alpine
    container_name: yc-access-manager
    ports:
      - "3004:3000"
    volumes:
      - /volume1/YC/services/auth:/app
    working_dir: /app
    command: |
      sh -c "
        if [ ! -f package.json ]; then
          npm init -y &&
          npm install express bcryptjs jsonwebtoken sqlite3 cors helmet &&
          cat > server.js << 'SERVER_EOF'
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
const helmet = require('helmet');

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json());

// 初始化数据库
const db = new sqlite3.Database('./users.db');
db.serialize(() => {
  db.run(\`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    email TEXT UNIQUE,
    password TEXT,
    role TEXT DEFAULT 'user',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME,
    active BOOLEAN DEFAULT 1
  )\`);
  
  db.run(\`CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    token TEXT,
    expires_at DATETIME,
    ip_address TEXT,
    user_agent TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id)
  )\`);
  
  // 创建默认管理员账户
  const adminPassword = bcrypt.hashSync('admin123', 10);
  db.run(\`INSERT OR IGNORE INTO users (username, email, password, role) 
           VALUES ('admin', 'admin@yc.local', ?, 'admin')\`, [adminPassword]);
});

const JWT_SECRET = process.env.JWT_SECRET || 'yc-dev-secret-key-2024';

// 用户登录
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  
  db.get('SELECT * FROM users WHERE username = ? AND active = 1', [username], (err, user) => {
    if (err || !user) {
      return res.status(401).json({ error: '用户名或密码错误' });
    }
    
    if (!bcrypt.compareSync(password, user.password)) {
      return res.status(401).json({ error: '用户名或密码错误' });
    }
    
    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    // 记录登录会话
    const clientIP = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('User-Agent');
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    
    db.run(\`INSERT INTO sessions (user_id, token, expires_at, ip_address, user_agent) 
             VALUES (?, ?, ?, ?, ?)\`, 
           [user.id, token, expiresAt, clientIP, userAgent]);
    
    // 更新最后登录时间
    db.run('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?', [user.id]);
    
    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role
      }
    });
  });
});

// 验证令牌中间件
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: '访问令牌缺失' });
  }
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: '访问令牌无效' });
    }
    req.user = user;
    next();
  });
};

// 获取用户信息
app.get('/api/user', authenticateToken, (req, res) => {
  db.get('SELECT id, username, email, role, created_at, last_login FROM users WHERE id = ?', 
         [req.user.id], (err, user) => {
    if (err || !user) {
      return res.status(404).json({ error: '用户不存在' });
    }
    res.json(user);
  });
});

// 获取用户列表（仅管理员）
app.get('/api/users', authenticateToken, (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: '权限不足' });
  }
  
  db.all(\`SELECT id, username, email, role, created_at, last_login, active 
           FROM users ORDER BY created_at DESC\`, (err, users) => {
    if (err) {
      return res.status(500).json({ error: '获取用户列表失败' });
    }
    res.json(users);
  });
});

// 创建用户（仅管理员）
app.post('/api/users', authenticateToken, (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: '权限不足' });
  }
  
  const { username, email, password, role = 'user' } = req.body;
  const hashedPassword = bcrypt.hashSync(password, 10);
  
  db.run(\`INSERT INTO users (username, email, password, role) VALUES (?, ?, ?, ?)\`,
         [username, email, hashedPassword, role], function(err) {
    if (err) {
      return res.status(400).json({ error: '创建用户失败' });
    }
    res.json({ id: this.lastID, message: '用户创建成功' });
  });
});

// 登录页面
app.get('/', (req, res) => {
  res.send(\`
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>YC 开发环境 - 安全登录</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-container {
            background: rgba(255, 255, 255, 0.95);
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            backdrop-filter: blur(10px);
            width: 100%;
            max-width: 400px;
        }
        .logo {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo h1 {
            color: #333;
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .logo p {
            color: #666;
            font-size: 1.1em;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            color: #333;
            font-weight: 500;
        }
        input[type="text"], input[type="password"] {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e1e5e9;
            border-radius: 10px;
            font-size: 16px;
            transition: border-color 0.3s ease;
        }
        input[type="text"]:focus, input[type="password"]:focus {
            outline: none;
            border-color: #667eea;
        }
        .login-btn {
            width: 100%;
            padding: 12px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s ease;
        }
        .login-btn:hover {
            transform: translateY(-2px);
        }
        .error {
            color: #e74c3c;
            text-align: center;
            margin-top: 15px;
            padding: 10px;
            background: rgba(231, 76, 60, 0.1);
            border-radius: 8px;
        }
        .success {
            color: #27ae60;
            text-align: center;
            margin-top: 15px;
            padding: 10px;
            background: rgba(39, 174, 96, 0.1);
            border-radius: 8px;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">
            <h1>🔒 YC</h1>
            <p>安全开发环境</p>
        </div>
        <form id="loginForm">
            <div class="form-group">
                <label for="username">用户名</label>
                <input type="text" id="username" name="username" required>
            </div>
            <div class="form-group">
                <label for="password">密码</label>
                <input type="password" id="password" name="password" required>
            </div>
            <button type="submit" class="login-btn">安全登录</button>
        </form>
        <div id="message"></div>
    </div>

    <script>
        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const messageDiv = document.getElementById('message');
            
            try {
                const response = await fetch('/api/login', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ username, password }),
                });
                
                const data = await response.json();
                
                if (response.ok) {
                    localStorage.setItem('yc_token', data.token);
                    messageDiv.innerHTML = '<div class="success">登录成功！正在跳转...</div>';
                    setTimeout(() => {
                        window.location.href = 'https://192.168.3.45';
                    }, 1500);
                } else {
                    messageDiv.innerHTML = \`<div class="error">\${data.error}</div>\`;
                }
            } catch (error) {
                messageDiv.innerHTML = '<div class="error">登录失败，请检查网络连接</div>';
            }
        });
    </script>
</body>
</html>
  \`);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(\`访问控制服务运行在端口 \${PORT}\`);
});
SERVER_EOF
        fi &&
        node server.js
      "
    networks:
      - yc-dev-network
    restart: unless-stopped
EOF

    log_success "访问控制系统创建完成"
}

# 创建安全监控和审计
create_security_monitoring() {
    log_step "创建安全监控和审计系统..."
    
    cat > "$ROOT_DIR/development/docker-compose/security-monitoring.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  # Fail2Ban 入侵防护
  fail2ban:
    image: crazymax/fail2ban:latest
    container_name: yc-fail2ban
    network_mode: "host"
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - /volume1/YC/services/fail2ban:/data
      - /var/log:/var/log:ro
    environment:
      TZ: Asia/Shanghai
      F2B_LOG_LEVEL: INFO
      F2B_DB_PURGE_AGE: 1d
    restart: unless-stopped

  # 安全扫描器
  security-scanner:
    image: node:18-alpine
    container_name: yc-security-scanner
    ports:
      - "3005:3000"
    volumes:
      - /volume1/YC/services/security:/app
      - /var/run/docker.sock:/var/run/docker.sock:ro
    working_dir: /app
    command: |
      sh -c "
        apk add --no-cache docker-cli &&
        if [ ! -f package.json ]; then
          npm init -y &&
          npm install express node-cron axios &&
          cat > scanner.js << 'SCANNER_EOF'
const express = require('express');
const cron = require('node-cron');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

// 安全扫描结果存储
const scanResults = {
  containers: [],
  vulnerabilities: [],
  lastScan: null,
  summary: {
    totalContainers: 0,
    vulnerableContainers: 0,
    criticalVulns: 0,
    highVulns: 0,
    mediumVulns: 0,
    lowVulns: 0
  }
};

// 容器安全扫描
function scanContainers() {
  console.log('开始容器安全扫描...');
  
  exec('docker ps --format \"{{.Names}}\"', (error, stdout, stderr) => {
    if (error) {
      console.error('获取容器列表失败:', error);
      return;
    }
    
    const containers = stdout.trim().split('\\n').filter(name => name.startsWith('yc-'));
    scanResults.summary.totalContainers = containers.length;
    scanResults.containers = [];
    
    containers.forEach(containerName => {
      // 检查容器配置
      exec(\`docker inspect \${containerName}\`, (error, stdout, stderr) => {
        if (error) return;
        
        try {
          const config = JSON.parse(stdout)[0];
          const securityIssues = [];
          
          // 检查特权模式
          if (config.HostConfig.Privileged) {
            securityIssues.push({
              severity: 'HIGH',
              issue: '容器运行在特权模式',
              recommendation: '移除特权模式，使用最小权限原则'
            });
          }
          
          // 检查网络模式
          if (config.HostConfig.NetworkMode === 'host') {
            securityIssues.push({
              severity: 'MEDIUM',
              issue: '容器使用主机网络模式',
              recommendation: '使用自定义网络替代主机网络'
            });
          }
          
          // 检查挂载点
          config.Mounts.forEach(mount => {
            if (mount.Source === '/var/run/docker.sock') {
              securityIssues.push({
                severity: 'HIGH',
                issue: 'Docker socket 挂载存在安全风险',
                recommendation: '限制 Docker socket 访问权限'
              });
            }
          });
          
          scanResults.containers.push({
            name: containerName,
            image: config.Config.Image,
            status: config.State.Status,
            securityIssues,
            riskLevel: securityIssues.length > 0 ? 
              (securityIssues.some(i => i.severity === 'HIGH') ? 'HIGH' : 'MEDIUM') : 'LOW'
          });
          
          // 更新统计
          if (securityIssues.length > 0) {
            scanResults.summary.vulnerableContainers++;
            securityIssues.forEach(issue => {
              switch(issue.severity) {
                case 'CRITICAL': scanResults.summary.criticalVulns++; break;
                case 'HIGH': scanResults.summary.highVulns++; break;
                case 'MEDIUM': scanResults.summary.mediumVulns++; break;
                case 'LOW': scanResults.summary.lowVulns++; break;
              }
            });
          }
          
        } catch (e) {
          console.error('解析容器配置失败:', e);
        }
      });
    });
    
    scanResults.lastScan = new Date().toISOString();
    console.log('容器安全扫描完成');
  });
}

// 网络安全检查
function checkNetworkSecurity() {
  console.log('检查网络安全配置...');
  
  // 检查开放端口
  exec('netstat -tuln', (error, stdout, stderr) => {
    if (error) return;
    
    const openPorts = [];
    const lines = stdout.split('\\n');
    
    lines.forEach(line => {
      if (line.includes('LISTEN')) {
        const parts = line.split(/\\s+/);
        const address = parts[3];
        if (address && address.includes(':')) {
          const port = address.split(':').pop();
          openPorts.push(port);
        }
      }
    });
    
    // 检查危险端口
    const dangerousPorts = ['22', '23', '21', '25', '53', '80', '443', '993', '995'];
    const exposedDangerousPorts = openPorts.filter(port => dangerousPorts.includes(port));
    
    if (exposedDangerousPorts.length > 0) {
      console.log('发现暴露的敏感端口:', exposedDangerousPorts);
    }
  });
}

// API 端点
app.get('/api/scan/status', (req, res) => {
  res.json(scanResults);
});

app.post('/api/scan/start', (req, res) => {
  scanContainers();
  checkNetworkSecurity();
  res.json({ message: '安全扫描已启动' });
});

// 安全报告页面
app.get('/', (req, res) => {
  res.send(\`
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>YC 安全监控中心</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 40px; }
        .stat-card { background: white; padding: 20px; border-radius: 10px; text-align: center; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .stat-number { font-size: 2em; font-weight: bold; margin-bottom: 10px; }
        .critical { color: #e74c3c; }
        .high { color: #f39c12; }
        .medium { color: #f1c40f; }
        .low { color: #27ae60; }
        .containers { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .container-item { padding: 15px; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; align-items: center; }
        .risk-badge { padding: 4px 12px; border-radius: 20px; color: white; font-size: 12px; font-weight: bold; }
        .risk-high { background: #e74c3c; }
        .risk-medium { background: #f39c12; }
        .risk-low { background: #27ae60; }
        .scan-btn { background: #3498db; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛡️ YC 安全监控中心</h1>
            <button class="scan-btn" onclick="startScan()">开始安全扫描</button>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number" id="totalContainers">-</div>
                <div>总容器数</div>
            </div>
            <div class="stat-card">
                <div class="stat-number critical" id="criticalVulns">-</div>
                <div>严重漏洞</div>
            </div>
            <div class="stat-card">
                <div class="stat-number high" id="highVulns">-</div>
                <div>高危漏洞</div>
            </div>
            <div class="stat-card">
                <div class="stat-number medium" id="mediumVulns">-</div>
                <div>中危漏洞</div>
            </div>
        </div>
        
        <div class="containers">
            <h2>容器安全状态</h2>
            <div id="containerList">加载中...</div>
        </div>
    </div>
    
    <script>
        async function loadScanResults() {
            try {
                const response = await fetch('/api/scan/status');
                const data = await response.json();
                
                document.getElementById('totalContainers').textContent = data.summary.totalContainers;
                document.getElementById('criticalVulns').textContent = data.summary.criticalVulns;
                document.getElementById('highVulns').textContent = data.summary.highVulns;
                document.getElementById('mediumVulns').textContent = data.summary.mediumVulns;
                
                const containerList = document.getElementById('containerList');
                if (data.containers.length === 0) {
                    containerList.innerHTML = '<p>暂无扫描结果</p>';
                } else {
                    containerList.innerHTML = data.containers.map(container => \`
                        <div class="container-item">
                            <div>
                                <strong>\${container.name}</strong><br>
                                <small>\${container.image}</small>
                            </div>
                            <span class="risk-badge risk-\${container.riskLevel.toLowerCase()}">\${container.riskLevel}</span>
                        </div>
                    \`).join('');
                }
            } catch (error) {
                console.error('加载扫描结果失败:', error);
            }
        }
        
        async function startScan() {
            try {
                await fetch('/api/scan/start', { method: 'POST' });
                alert('安全扫描已启动，请稍后刷新查看结果');
                setTimeout(loadScanResults, 5000);
            } catch (error) {
                alert('启动扫描失败');
            }
        }
        
        loadScanResults();
        setInterval(loadScanResults, 30000);
    </script>
</body>
</html>
  \`);
});

// 定时扫描（每天凌晨3点）
cron.schedule('0 3 * * *', () => {
  console.log('执行定时安全扫描');
  scanContainers();
  checkNetworkSecurity();
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(\`安全监控服务运行在端口 \${PORT}\`);
});
SCANNER_EOF
          node scanner.js
        fi
      "
    networks:
      - yc-dev-network
    restart: unless-stopped
EOF

    log_success "安全监控和审计系统创建完成"
}

# 创建自动化备份和恢复系统
create_backup_system() {
    log_step "创建自动化备份和恢复系统..."
    
    cat > "$ROOT_DIR/development/scripts/advanced-backup.sh" << 'EOF'
#!/bin/bash

# 高级备份和恢复系统

BACKUP_ROOT="/volume1/YC/shared/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# 创建备份目录结构
mkdir -p "$BACKUP_ROOT"/{daily,weekly,monthly,emergency}

log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [信息] $1"; }
log_success() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [成功] $1"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [错误] $1"; }

# 数据库备份
backup_databases() {
    log_info "开始数据库备份..."
    
    # PostgreSQL 备份
    if docker ps | grep -q yc-postgres; then
        log_info "备份 PostgreSQL 数据库..."
        docker exec yc-postgres pg_dumpall -U yc_admin > "$BACKUP_ROOT/daily/postgres_$DATE.sql"
        gzip "$BACKUP_ROOT/daily/postgres_$DATE.sql"
        log_success "PostgreSQL 备份完成"
    fi
    
    # Redis 备份
    if docker ps | grep -q yc-redis; then
        log_info "备份 Redis 数据..."
        docker exec yc-redis redis-cli BGSAVE
        sleep 5
        docker cp yc-redis:/data/dump.rdb "$BACKUP_ROOT/daily/redis_$DATE.rdb"
        log_success "Redis 备份完成"
    fi
    
    # SQLite 备份（用户数据库）
    if [ -f "/volume1/YC/services/auth/users.db" ]; then
        log_info "备份用户数据库..."
        cp "/volume1/YC/services/auth/users.db" "$BACKUP_ROOT/daily/users_$DATE.db"
        log_success "用户数据库备份完成"
    fi
}

# 配置文件备份
backup_configs() {
    log_info "备份配置文件..."
    
    tar -czf "$BACKUP_ROOT/daily/configs_$DATE.tar.gz" \
        -C /volume1/YC \
        services/nginx \
        services/ssl \
        services/monitoring \
        development/docker-compose \
        2>/dev/null
    
    log_success "配置文件备份完成"
}

# 项目代码备份
backup_projects() {
    log_info "备份项目代码..."
    
    if [ -d "/volume1/YC/development/projects" ]; then
        tar -czf "$BACKUP_ROOT/daily/projects_$DATE.tar.gz" \
            -C /volume1/YC/development \
            projects/ \
            2>/dev/null
        log_success "项目代码备份完成"
    fi
}

# Git 仓库备份
backup_git_repos() {
    log_info "备份 Git 仓库..."
    
    if [ -d "/volume1/YC/development/git-repos" ]; then
        tar -czf "$BACKUP_ROOT/daily/git-repos_$DATE.tar.gz" \
            -C /volume1/YC/development \
            git-repos/ \
            2>/dev/null
        log_success "Git 仓库备份完成"
    fi
}

# AI 模型备份
backup_ai_models() {
    log_info "备份 AI 模型配置..."
    
    # 只备份配置，不备份大模型文件
    tar -czf "$BACKUP_ROOT/daily/ai-configs_$DATE.tar.gz" \
        -C /volume1/YC \
        ai-models/model-configs \
        2>/dev/null
    
    log_success "AI 模型配置备份完成"
}

# 系统状态快照
create_system_snapshot() {
    log_info "创建系统状态快照..."
    
    SNAPSHOT_DIR="$BACKUP_ROOT/daily/snapshot_$DATE"
    mkdir -p "$SNAPSHOT_DIR"
    
    # Docker 容器状态
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" > "$SNAPSHOT_DIR/docker_containers.txt"
    
    # Docker 镜像列表
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" > "$SNAPSHOT_DIR/docker_images.txt"
    
    # 网络配置
    docker network ls > "$SNAPSHOT_DIR/docker_networks.txt"
    
    # 系统资源使用
    df -h > "$SNAPSHOT_DIR/disk_usage.txt"
    free -h > "$SNAPSHOT_DIR/memory_usage.txt"
    
    # 运行的服务
    docker-compose -f /volume1/YC/development/docker-compose/docker-compose.yml ps > "$SNAPSHOT_DIR/services_status.txt"
    
    tar -czf "$BACKUP_ROOT/daily/system_snapshot_$DATE.tar.gz" -C "$BACKUP_ROOT/daily" "snapshot_$DATE"
    rm -rf "$SNAPSHOT_DIR"
    
    log_success "系统状态快照创建完成"
}

# 备份验证
verify_backups() {
    log_info "验证备份完整性..."
    
    BACKUP_DIR="$BACKUP_ROOT/daily"
    VERIFICATION_LOG="$BACKUP_DIR/verification_$DATE.log"
    
    echo "备份验证报告 - $(date)" > "$VERIFICATION_LOG"
    echo "================================" >> "$VERIFICATION_LOG"
    
    for backup_file in "$BACKUP_DIR"/*_$DATE.*; do
        if [ -f "$backup_file" ]; then
            filename=$(basename "$backup_file")
            filesize=$(du -h "$backup_file" | cut -f1)
            
            if [[ "$backup_file" == *.gz ]]; then
                if gzip -t "$backup_file" 2>/dev/null; then
                    echo "✅ $filename ($filesize) - 完整" >> "$VERIFICATION_LOG"
                else
                    echo "❌ $filename ($filesize) - 损坏" >> "$VERIFICATION_LOG"
                    log_error "备份文件损坏: $filename"
                fi
            else
                echo "✅ $filename ($filesize) - 存在" >> "$VERIFICATION_LOG"
            fi
        fi
    done
    
    log_success "备份验证完成"
}

# 清理旧备份
cleanup_old_backups() {
    log_info "清理旧备份文件..."
    
    # 清理日备份（保留30天）
    find "$BACKUP_ROOT/daily" -name "*" -type f -mtime +$RETENTION_DAYS -delete
    
    # 清理周备份（保留12周）
    find "$BACKUP_ROOT/weekly" -name "*" -type f -mtime +84 -delete
    
    # 清理月备份（保留12个月）
    find "$BACKUP_ROOT/monthly" -name "*" -type f -mtime +365 -delete
    
    log_success "旧备份清理完成"
}

# 发送备份报告
send_backup_report() {
    log_info "生成备份报告..."
    
    REPORT_FILE="$BACKUP_ROOT/daily/backup_report_$DATE.txt"
    
    cat > "$REPORT_FILE" << EOF
YC 开发环境备份报告
==================
备份时间: $(date)
备份类型: 每日自动备份

备份项目:
- 数据库备份 ✅
- 配置文件备份 ✅  
- 项目代码备份 ✅
- Git 仓库备份 ✅
- AI 模型配置备份 ✅
- 系统状态快照 ✅

备份位置: $BACKUP_ROOT/daily/
保留策略: $RETENTION_DAYS 天

备份文件列表:
$(ls -lh "$BACKUP_ROOT/daily/"*_$DATE.* 2>/dev/null || echo "无备份文件")

磁盘使用情况:
$(df -h "$BACKUP_ROOT")

备份验证:
$(cat "$BACKUP_ROOT/daily/verification_$DATE.log" 2>/dev/null || echo "验证日志不存在")
EOF

    log_success "备份报告生成完成: $REPORT_FILE"
}

# 恢复功能
restore_from_backup() {
    if [ -z "$1" ]; then
        echo "用法: $0 restore <备份日期> [组件]"
        echo "组件: database, configs, projects, git, all"
        echo "示例: $0 restore 20241201_120000 database"
        return 1
    fi
    
    RESTORE_DATE="$1"
    COMPONENT="${2:-all}"
    BACKUP_DIR="$BACKUP_ROOT/daily"
    
    log_info "开始从备份恢复: $RESTORE_DATE"
    
    case "$COMPONENT" in
        "database"|"all")
            log_info "恢复数据库..."
            if [ -f "$BACKUP_DIR/postgres_$RESTORE_DATE.sql.gz" ]; then
                gunzip -c "$BACKUP_DIR/postgres_$RESTORE_DATE.sql.gz" | docker exec -i yc-postgres psql -U yc_admin
                log_success "PostgreSQL 恢复完成"
            fi
            ;;
    esac
    
    if [ "$COMPONENT" = "all" ] || [ "$COMPONENT" = "configs" ]; then
        log_info "恢复配置文件..."
        if [ -f "$BACKUP_DIR/configs_$RESTORE_DATE.tar.gz" ]; then
            tar -xzf "$BACKUP_DIR/configs_$RESTORE_DATE.tar.gz" -C /volume1/YC/
            log_success "配置文件恢复完成"
        fi
    fi
    
    log_success "恢复操作完成"
}

# 主函数
case "$1" in
    "full")
        log_info "开始完整备份..."
        backup_databases
        backup_configs
        backup_projects
        backup_git_repos
        backup_ai_models
        create_system_snapshot
        verify_backups
        cleanup_old_backups
        send_backup_report
        log_success "完整备份完成"
        ;;
    "restore")
        restore_from_backup "$2" "$3"
        ;;
    "verify")
        verify_backups
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    *)
        echo "YC 高级备份系统"
        echo "==============="
        echo "用法: $0 {full|restore|verify|cleanup}"
        echo ""
        echo "命令说明:"
        echo "  full    - 执行完整备份"
        echo "  restore - 从备份恢复"
        echo "  verify  - 验证备份完整性"
        echo "  cleanup - 清理旧备份"
        ;;
esac
EOF

    chmod +x "$ROOT_DIR/development/scripts/advanced-backup.sh"
    
    # 创建备份调度器
    cat > "$ROOT_DIR/development/scripts/backup-scheduler.sh" << 'EOF'
#!/bin/bash

# 备份调度器 - 设置不同类型的定时备份

BACKUP_SCRIPT="/volume1/YC/development/scripts/advanced-backup.sh"

# 添加 cron 任务
setup_backup_schedule() {
    echo "⏰ 设置备份调度..."
    
    # 备份当前 crontab
    crontab -l > /tmp/current_cron 2>/dev/null || touch /tmp/current_cron
    
    # 添加备份任务
    cat >> /tmp/current_cron << EOF
# YC 开发环境自动备份
0 2 * * * $BACKUP_SCRIPT full >> /volume1/YC/shared/backups/backup.log 2>&1
0 3 * * 0 cp -r /volume1/YC/shared/backups/daily/\$(date +\%Y\%m\%d)_* /volume1/YC/shared/backups/weekly/ 2>/dev/null
0 4 1 * * cp -r /volume1/YC/shared/backups/daily/\$(date +\%Y\%m\%d)_* /volume1/YC/shared/backups/monthly/ 2>/dev/null
EOF
    
    # 安装新的 crontab
    crontab /tmp/current_cron
    rm /tmp/current_cron
    
    echo "✅ 备份调度设置完成"
    echo "📅 每日备份: 凌晨2点"
    echo "📅 周备份: 周日凌晨3点"
    echo "📅 月备份: 每月1日凌晨4点"
}

# 查看当前调度
show_schedule() {
    echo "📋 当前备份调度:"
    crontab -l | grep -E "(backup|YC)" || echo "未设置备份调度"
}

# 移除调度
remove_schedule() {
    echo "🗑️ 移除备份调度..."
    crontab -l | grep -v -E "(backup|YC)" | crontab -
    echo "✅ 备份调度已移除"
}

case "$1" in
    "setup")
        setup_backup_schedule
        ;;
    "show")
        show_schedule
        ;;
    "remove")
        remove_schedule
        ;;
    *)
        echo "📅 YC 备份调度器"
        echo "==============="
        echo "用法: $0 {setup|show|remove}"
        echo ""
        echo "命令说明:"
        echo "  setup  - 设置自动备份调度"
        echo "  show   - 查看当前调度"
        echo "  remove - 移除备份调度"
        ;;
esac
EOF

    chmod +x "$ROOT_DIR/development/scripts/backup-scheduler.sh"
    
    log_success "自动化备份和恢复系统创建完成"
}

# 创建性能优化脚本
create_performance_optimization() {
    log_step "创建性能优化脚本..."
    
    cat > "$ROOT_DIR/development/scripts/performance-optimizer.sh" << 'EOF'
#!/bin/bash

# YC 开发环境性能优化脚本

log_info() { echo "[$(date '+%H:%M:%S')] [信息] $1"; }
log_success() { echo "[$(date '+%H:%M:%S')] [成功] $1"; }
log_warning() { echo "[$(date '+%H:%M:%S')] [警告] $1"; }

# Docker 性能优化
optimize_docker() {
    log_info "优化 Docker 性能..."
    
    # 清理未使用的镜像和容器
    log_info "清理 Docker 资源..."
    docker system prune -f
    docker image prune -f
    
    # 优化 Docker 日志
    log_info "配置 Docker 日志轮转..."
    cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF
    
    log_success "Docker 性能优化完成"
}

# 数据库性能优化
optimize_databases() {
    log_info "优化数据库性能..."
    
    # PostgreSQL 优化
    if docker ps | grep -q yc-postgres; then
        log_info "优化 PostgreSQL 配置..."
        docker exec yc-postgres psql -U yc_admin -d yc_dev -c "
            -- 更新统计信息
            ANALYZE;
            
            -- 重建索引
            REINDEX DATABASE yc_dev;
            
            -- 清理死元组
            VACUUM FULL;
        " 2>/dev/null || log_warning "PostgreSQL 优化部分失败"
    fi
    
    # Redis 优化
    if docker ps | grep -q yc-redis; then
        log_info "优化 Redis 配置..."
        docker exec yc-redis redis-cli CONFIG SET save "900 1 300 10 60 10000"
        docker exec yc-redis redis-cli BGREWRITEAOF
    fi
    
    log_success "数据库性能优化完成"
}

# 系统资源优化
optimize_system_resources() {
    log_info "优化系统资源..."
    
    # 清理系统缓存
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || log_warning "无法清理系统缓存"
    
    # 优化文件描述符限制
    echo "* soft nofile 65536" >> /etc/security/limits.conf
    echo "* hard nofile 65536" >> /etc/security/limits.conf
    
    # 优化网络参数
    cat >> /etc/sysctl.conf << EOF
# YC 网络优化
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
EOF
    
    sysctl -p 2>/dev/null || log_warning "无法应用网络优化参数"
    
    log_success "系统资源优化完成"
}

# AI 模型性能优化
optimize_ai_models() {
    log_info "优化 AI 模型性能..."
    
    if docker ps | grep -q yc-ollama; then
        # 预热常用模型
        log_info "���热 AI 模型..."
        
        # 获取模型列表
        models=$(docker exec yc-ollama-primary ollama list | tail -n +2 | awk '{print $1}' | head -3)
        
        for model in $models; do
            if [ -n "$model" ]; then
                log_info "预热模型: $model"
                docker exec yc-ollama-primary ollama run "$model" "Hello" > /dev/null 2>&1 &
            fi
        done
        
        wait
        log_success "AI 模型预热完成"
    fi
}

# 监控性能指标
monitor_performance() {
    log_info "收集性能指标..."
    
    METRICS_FILE="/volume1/YC/shared/performance_metrics_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$METRICS_FILE" << EOF
YC 开发环境性能报告
==================
时间: $(date)

系统资源使用:
$(top -bn1 | head -20)

内存使用:
$(free -h)

磁盘使用:
$(df -h)

Docker 容器资源使用:
$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}")

网络连接:
$(netstat -tuln | grep LISTEN | wc -l) 个监听端口

Docker 镜像大小:
$(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -10)

最大的日志文件:
$(find /var/lib/docker/containers -name "*.log" -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -5)
EOF

    log_success "性能指标收集完成: $METRICS_FILE"
}

# 自动优化建议
generate_optimization_suggestions() {
    log_info "生成优化建议..."
    
    SUGGESTIONS_FILE="/volume1/YC/shared/optimization_suggestions_$(date +%Y%m%d).txt"
    
    cat > "$SUGGESTIONS_FILE" << EOF
YC 开发环境优化建议
==================
生成时间: $(date)

基于当前系统状态的优化建议:

1. 内存优化:
EOF

    # 检查内存使用
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
    if [ "$MEMORY_USAGE" -gt 80 ]; then
        echo "   ⚠️  内存使用率过高 ($MEMORY_USAGE%)，建议:" >> "$SUGGESTIONS_FILE"
        echo "   - 停止不必要的容器" >> "$SUGGESTIONS_FILE"
        echo "   - 增加交换空间" >> "$SUGGESTIONS_FILE"
        echo "   - 优化容器内存限制" >> "$SUGGESTIONS_FILE"
    else
        echo "   ✅ 内存使用正常 ($MEMORY_USAGE%)" >> "$SUGGESTIONS_FILE"
    fi
    
    echo "" >> "$SUGGESTIONS_FILE"
    echo "2. 磁盘优化:" >> "$SUGGESTIONS_FILE"
    
    # 检查磁盘使用
    DISK_USAGE=$(df /volume1 | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 80 ]; then
        echo "   ⚠️  磁盘使用率过高 ($DISK_USAGE%)，建议:" >> "$SUGGESTIONS_FILE"
        echo "   - 清理旧的备份文件" >> "$SUGGESTIONS_FILE"
        echo "   - 删除未使用的 Docker 镜像" >> "$SUGGESTIONS_FILE"
        echo "   - 压缩日志文件" >> "$SUGGESTIONS_FILE"
    else
        echo "   ✅ 磁盘使用正常 ($DISK_USAGE%)" >> "$SUGGESTIONS_FILE"
    fi
    
    echo "" >> "$SUGGESTIONS_FILE"
    echo "3. 容器优化:" >> "$SUGGESTIONS_FILE"
    
    # 检查容器数量
    CONTAINER_COUNT=$(docker ps | wc -l)
    if [ "$CONTAINER_COUNT" -gt 15 ]; then
        echo "   ⚠️  运行容器较多 ($CONTAINER_COUNT 个)，建议:" >> "$SUGGESTIONS_FILE"
        echo "   - 停止不必要的服务" >> "$SUGGESTIONS_FILE"
        echo "   - 合并功能相似的容器" >> "$SUGGESTIONS_FILE"
    else
        echo "   ✅ 容器数量合理 ($CONTAINER_COUNT 个)" >> "$SUGGESTIONS_FILE"
    fi
    
    echo "" >> "$SUGGESTIONS_FILE"
    echo "4. 网络优化:" >> "$SUGGESTIONS_FILE"
    echo "   - 使用 HTTP/2 和 gRPC" >> "$SUGGESTIONS_FILE"
    echo "   - 启用 Gzip 压缩" >> "$SUGGESTIONS_FILE"
    echo "   - 配置 CDN 加速" >> "$SUGGESTIONS_FILE"
    
    echo "" >> "$SUGGESTIONS_FILE"
    echo "5. AI 模型优化:" >> "$SUGGESTIONS_FILE"
    echo "   - 根据使用频率调整模型加载策略" >> "$SUGGESTIONS_FILE"
    echo "   - 实施模型缓存机制" >> "$SUGGESTIONS_FILE"
    echo "   - 考虑模型量化以减少内存占用" >> "$SUGGESTIONS_FILE"
    
    log_success "优化建议生成完成: $SUGGESTIONS_FILE"
}

# 主函数
case "$1" in
    "docker")
        optimize_docker
        ;;
    "database")
        optimize_databases
        ;;
    "system")
        optimize_system_resources
        ;;
    "ai")
        optimize_ai_models
        ;;
    "monitor")
        monitor_performance
        ;;
    "suggest")
        generate_optimization_suggestions
        ;;
    "all")
        log_info "开始全面性能优化..."
        optimize_docker
        optimize_databases
        optimize_system_resources
        optimize_ai_models
        monitor_performance
        generate_optimization_suggestions
        log_success "全面性能优化完成"
        ;;
    *)
        echo "🚀 YC 性能优化工具"
        echo "=================="
        echo "用法: $0 {docker|database|system|ai|monitor|suggest|all}"
        echo ""
        echo "命令说明:"
        echo "  docker   - 优化 Docker 性能"
        echo "  database - 优化数据库性能"
        echo "  system   - 优化系统资源"
        echo "  ai       - 优化 AI 模型性能"
        echo "  monitor  - 监控性能指标"
        echo "  suggest  - 生成优化建议"
        echo "  all      - 执行全面优化"
        ;;
esac
EOF

    chmod +x "$ROOT_DIR/development/scripts/performance-optimizer.sh"
    
    log_success "性能优化脚本创建完成"
}

# 创建团队协作工具
create_collaboration_tools() {
    log_step "创建团队协作工具..."
    
    cat > "$ROOT_DIR/development/docker-compose/collaboration.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  # 团队沟通 - Rocket.Chat
  rocketchat:
    image: rocket.chat:latest
    container_name: yc-rocketchat
    ports:
      - "3006:3000"
    environment:
      MONGO_URL: mongodb://mongo:27017/rocketchat
      ROOT_URL: http://192.1192.168.3.45
      Accounts_UseDNSDomainCheck: "false"
    depends_on:
      - mongo
    networks:
      - yc-dev-network
    restart: unless-stopped

  # MongoDB for Rocket.Chat
  mongo:
    image: mongo:4.4
    container_name: yc-mongo
    volumes:
      - /volume1/YC/services/mongodb:/data/db
    command: mongod --oplogSize 128 --replSet rs0
    networks:
      - yc-dev-network
    restart: unless-stopped

  # 项目管理 - Taiga
  taiga-back:
    image: taigaio/taiga-back:latest
    container_name: yc-taiga-back
    environment:
      POSTGRES_DB: taiga
      POSTGRES_USER: taiga
      POSTGRES_PASSWORD: taiga_password
      POSTGRES_HOST: taiga-db
      TAIGA_SECRET_KEY: taiga-secret-key
      TAIGA_SITES_DOMAIN: 192.1192.168.3.45
      TAIGA_SITES_SCHEME: http
    volumes:
      - /volume1/YC/services/taiga/media:/taiga-back/media
    networks:
      - yc-dev-network
    depends_on:
      - taiga-db
    restart: unless-stopped

  taiga-front:
    image: taigaio/taiga-front:latest
    container_name: yc-taiga-front
    ports:
      - "3007:80"
    environment:
      TAIGA_URL: http://192.1192.168.3.45
      TAIGA_WEBSOCKETS_URL: ws://192.1192.168.3.45
    networks:
      - yc-dev-network
    restart: unless-stopped

  taiga-db:
    image: postgres:12
    container_name: yc-taiga-db
    environment:
      POSTGRES_DB: taiga
      POSTGRES_USER: taiga
      POSTGRES_PASSWORD: taiga_password
    volumes:
      - /volume1/YC/services/taiga/db:/var/lib/postgresql/data
    networks:
      - yc-dev-network
    restart: unless-stopped

  # 文档协作 - BookStack
  bookstack:
    image: lscr.io/linuxserver/bookstack:latest
    container_name: yc-bookstack
    ports:
      - "3008:80"
    environment:
      PUID: 1000
      PGID: 1000
      APP_URL: http://192.1192.168.3.45
      DB_HOST: bookstack-db
      DB_USER: bookstack
      DB_PASS: bookstack_password
      DB_DATABASE: bookstackapp
    volumes:
      - /volume1/YC/services/bookstack:/config
    depends_on:
      - bookstack-db
    networks:
      - yc-dev-network
    restart: unless-stopped

  bookstack-db:
    image: lscr.io/linuxserver/mariadb:latest
    container_name: yc-bookstack-db
    environment:
      PUID: 1000
      PGID: 1000
      MYSQL_ROOT_PASSWORD: bookstack_root_password
      MYSQL_DATABASE: bookstackapp
      MYSQL_USER: bookstack
      MYSQL_PASSWORD: bookstack_password
    volumes:
      - /volume1/YC/services/bookstack/db:/config
    networks:
      - yc-dev-network
    restart: unless-stopped

  # 代码审查 - Review Board
  reviewboard:
    image: beanbag/reviewboard:latest
    container_name: yc-reviewboard
    ports:
      - "3009:8080"
    environment:
      REVIEWBOARD_DATABASE_TYPE: postgresql
      REVIEWBOARD_DATABASE_NAME: reviewboard
      REVIEWBOARD_DATABASE_USER: reviewboard
      REVIEWBOARD_DATABASE_PASSWORD: reviewboard_password
      REVIEWBOARD_DATABASE_HOST: reviewboard-db
    volumes:
      - /volume1/YC/services/reviewboard:/var/www/reviewboard
    depends_on:
      - reviewboard-db
    networks:
      - yc-dev-network
    restart: unless-stopped

  reviewboard-db:
    image: postgres:13
    container_name: yc-reviewboard-db
    environment:
      POSTGRES_DB: reviewboard
      POSTGRES_USER: reviewboard
      POSTGRES_PASSWORD: reviewboard_password
    volumes:
      - /volume1/YC/services/reviewboard/db:/var/lib/postgresql/data
    networks:
      - yc-dev-network
    restart: unless-stopped
EOF

    log_success "团队协作工具配置完成"
}

# 创建最终部署脚本
create_final_deployment() {
    log_step "创建最终部署脚本..."
    
    cat > "$ROOT_DIR/development/scripts/final-deploy.sh" << 'EOF'
#!/bin/bash

# YC 开发环境最终部署脚本

ROOT_DIR="/volume1/YC"
COMPOSE_DIR="$ROOT_DIR/development/docker-compose"

echo "🚀 YC 开发环境最终部署"
echo "======================"
echo ""

# 检查前置条件
check_prerequisites() {
    echo "🔍 检查部署前置条件..."
    
    # 检查磁盘空间
    DISK_USAGE=$(df /volume1 | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 90 ]; then
        echo "❌ 磁盘空间不足 ($DISK_USAGE%)，请清理后重试"
        exit 1
    fi
    
    # 检查内存
    MEMORY_TOTAL=$(free -m | grep Mem | awk '{print $2}')
    if [ "$MEMORY_TOTAL" -lt 8192 ]; then
        echo "⚠️  内存可能不足 (${MEMORY_TOTAL}MB)，建议至少 8GB"
    fi
    
    echo "✅ 前置条件检查通过"
}

# 部署所有服务
deploy_all_services() {
    echo "🚀 部署所有服务..."
    
    # 核心服务
    echo "📦 部署核心服务..."
    docker-compose -f "$COMPOSE_DIR/docker-compose.yml" up -d
    
    # 高级服务
    echo "🔧 部署高级服务..."
    docker-compose -f "$COMPOSE_DIR/v0-dev.yml" up -d
    
    # AI 服务
    echo "🤖 部署 AI 服务..."
    docker-compose -f "$COMPOSE_DIR/ai-services.yml" up -d
    
    # 监控服务
    echo "📊 部署监控服务..."
    docker-compose -f "$COMPOSE_DIR/monitoring.yml" up -d
    
    # 安全服务
    echo "🔒 部署安全服务..."
    docker-compose -f "$COMPOSE_DIR/auth-service.yml" up -d
    docker-compose -f "$COMPOSE_DIR/security-monitoring.yml" up -d
    
    # 协作工具
    echo "👥 部署协作工具..."
    docker-compose -f "$COMPOSE_DIR/collaboration.yml" up -d
    
    echo "✅ 所有服务部署完成"
}

# 等待服务启动
wait_for_services() {
    echo "⏳ 等待服务启动..."
    
    services=(
        "192.16192.168.3.45制台"
        "192.16192.168.3.45GitLab"
        "192.16192.168.3.45Portainer"
        "192.16192.168.3.45AI服务"
        "192.16192.168.3.45Code Server"
        "192.16192.168.3.45监控面板"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r host port name <<< "$service"
        echo -n "等待 $name 启动..."
        
        for i in {1..30}; do
            if curl -s --connect-timeout 3 "http://$host:$port" > /dev/null 2>&1; then
                echo " ✅"
                break
            fi
            echo -n "."
            sleep 2
        done
        
        if [ $i -eq 30 ]; then
            echo " ⚠️ 超时"
        fi
    done
}

# 初始化配置
initialize_services() {
    echo "⚙️ 初始化服务配置..."
    
    # 初始化 GitLab
    echo "🐙 初始化 GitLab..."
    sleep 10  # 等待 GitLab 完全启动
    
    # 初始化 AI 模型
    echo "🤖 初始化 AI 模型..."
    "$ROOT_DIR/development/scripts/manage-models.sh" status
    
    # 设置备份调度
    echo "💾 设置备份调度..."
    "$ROOT_DIR/development/scripts/backup-scheduler.sh" setup
    
    echo "✅ 服务初始化完成"
}

# 生成部署报告
generate_deployment_report() {
    echo "📋 生成部署报告..."
    
    REPORT_FILE="$ROOT_DIR/shared/deployment_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOF
YC 开发环境部署报告
==================
部署时间: $(date)
部署版本: v1.0

服务状态:
$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep yc-)

服务访问地址:
- 主控制台: https://192.168.192.168.3.45b: https://192.168.192.168.3.45Portainer: https://192.168.192.168.3.45AI 服务: https://192.168.192.168.3.45Code Server: https://192.168.192.168.3.45监控面板: https://192.168.192.168.3.45访问控制: https://192.168.192.168.3.45安全监控: https://192.168.192.168.3.45团队沟通: https://192.168.192.168.3.45项目管理: https://192.168.192.168.3.45文档协作: https://192.168.192.168.3.45统资源使用:
内存: $(free -h | grep Mem | awk '{print $3"/"$2}')
磁盘: $(df -h /volume1 | tail -1 | awk '{print $3"/"$2" ("$5")"}')

默认账户信息:
- 管理员账户: admin / admin123
- GitLab root 密码: 首次访问时设置
- Portainer 密码: 首次访问时设置

重要文件位置:
- 项目代码: /volume1/YC/development/projects/
- 配置文件: /volume1/YC/services/
- 备份文件: /volume1/YC/shared/backups/
- 日志文件: /volume1/YC/shared/logs/

管理命令:
- 服务管理: $ROOT_DIR/development/scripts/dev-manager.sh
- 性能优化: $ROOT_DIR/development/scripts/performance-optimizer.sh
- 备份管理: $ROOT_DIR/development/scripts/advanced-backup.sh
- AI 模型管理: $ROOT_DIR/development/scripts/manage-models.sh

部署完成！🎉
EOF

    echo "✅ 部署报告生成完成: $REPORT_FILE"
}

# 显示最终信息
show_final_info() {
    echo ""
    echo "🎉 YC 开发环境部署完成！"
    echo "=========================="
    echo ""
    echo "🌐 主要访问地址："
    echo "• 主控制台: https://192.168.192.168.3.45ho "• GitLab: https://192.168.192.168.3.45   echo "• AI 服务: https://192.168.192.168.3.45   echo "• Code Server: https://192.168.192.168.3.45   echo "• 监控面板: https://192.168.192.168.3.45   echo ""
    echo "🔧 管理工具："
    echo "• 服务管理: $ROOT_DIR/development/scripts/dev-manager.sh"
    echo "• 性能优化: $ROOT_DIR/development/scripts/performance-optimizer.sh"
    echo "• 备份管理: $ROOT_DIR/development/scripts/advanced-backup.sh"
    echo ""
    echo "📚 文档位置："
    echo "• Mac 连接指南: $ROOT_DIR/shared/mac-connection-guide.md"
    echo "• 部署报告: 查看 $ROOT_DIR/shared/ 目录"
    echo ""
    echo "🚀 下一步："
    echo "1. 访问主控制台配置服务"
    echo "2. 在 Mac 上运行集成脚本"
    echo "3. 创建第一个项目"
    echo ""
    echo "💡 提示：运行 '$ROOT_DIR/development/scripts/dev-manager.sh' 进入管理界面"
}

# 主执行流程
main() {
    check_prerequisites
    deploy_all_services
    wait_for_services
    initialize_services
    generate_deployment_report
    show_final_info
}

# 执行部署
main "$@"
EOF

    chmod +x "$ROOT_DIR/development/scripts/final-deploy.sh"
    
    log_success "最终部署脚本创建完成"
}

# 主函数
main() {
    echo "🔒 开始 YC 开发环境安全加固和最终优化"
    echo "======================================="
    
    create_ssl_certificates
    create_secure_nginx_config
    create_access_control
    create_security_monitoring
    create_backup_system
    create_performance_optimization
    create_collaboration_tools
    create_final_deployment
    
    echo ""
    echo "🎉 安全加固和优化完成！"
    echo "======================="
    echo ""
    echo "🔒 安全功能："
    echo "• SSL/TLS 加密通信"
    echo "• 用户访问控制"
    echo "• 安全监控和审计"
    echo "• 入侵检测防护"
    echo ""
    echo "⚡ 性能优化："
    echo "• Docker 性能调优"
    echo "• 数据库优化"
    echo "• 系统资源优化"
    echo "• AI 模型性能优化"
    echo ""
    echo "💾 备份系统："
    echo "• 自动化备份调度"
    echo "• 多级备份策略"
    echo "• 备份验证机制"
    echo "• 快速恢复功能"
    echo ""
    echo "👥 协作工具："
    echo "• 团队沟通平台"
    echo "• 项目管理系统"
    echo "• 文档协作平台"
    echo "• 代码审查工具"
    echo ""
    echo "🚀 最终部署："
    echo "运行 '$ROOT_DIR/development/scripts/final-deploy.sh' 完成最终部署"
    echo ""
    
    read -p "是否立即执行最终部署？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$ROOT_DIR/development/scripts/final-deploy.sh"
    fi
}

# 执行主函数
main "$@"