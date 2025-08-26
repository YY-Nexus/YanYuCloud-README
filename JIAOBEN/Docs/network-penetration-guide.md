# 🌐 YC 开发环境内网穿透完整指南

## 📋 方案概览

### 1. 🚀 frp (推荐)
**适用场景**: 有自己的服务器，需要稳定的穿透服务

**优势**:
- 完全免费，无限制
- 性能优秀，延迟低
- 支持多种协议 (HTTP/HTTPS/TCP/UDP)
- 配置灵活，功能强大

**配置步骤**:
\`\`\`bash
# 1. 在服务器上部署 frp 服务端
wget https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_amd64.tar.gz
tar -xzf frp_0.52.3_linux_amd64.tar.gz
cd frp_0.52.3_linux_amd64

# 2. 配置服务端
cat > frps.ini << EOF
[common]
bind_port = 7000
vhost_http_port = 80
vhost_https_port = 443
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin123
token = your_secret_token
EOF

# 3. 启动服务端
./frps -c frps.ini

# 4. 在 NAS 上配置客户端
cd /volume1/YC/services/frp
./configure.sh
docker-compose up -d frpc
\`\`\`

**访问地址**:
- 主控制台: `http://yc.yourdomain.com`
- GitLab: `http://gitlab.yourdomain.com`
- AI 服务: `http://ai.yourdomain.com`

### 2. 🔗 ngrok (最简单)
**适用场景**: 快速测试，临时使用

**优势**:
- 零配置，即开即用
- 提供 HTTPS 支持
- 有 Web 管理界面
- 免费版提供 1 个隧道

**配置步骤**:
\`\`\`bash
# 1. 注册 ngrok 账户
# 访问 https://ngrok.com 注册

# 2. 获取 authtoken
# 在 ngrok 控制台获取您的 authtoken

# 3. 配置 ngrok
cd /volume1/YC/services/ngrok
./configure.sh
docker-compose up -d

# 4. 查看隧道地址
docker logs yc-ngrok
\`\`\`

**访问地址**:
- 主控制台: `https://yc-dev.ngrok.io`
- 管理界面: `http://localhost:4040`

### 3. 🌟 ZeroTier (组网方案)
**适用场景**: 多设备组网，安全性要求高

**优势**:
- P2P 连接，速度快
- 军用级加密
- 支持 25 个免费设备
- 跨平台支持

**配置步骤**:
\`\`\`bash
# 1. 注册 ZeroTier 账户
# 访问 https://my.zerotier.com 注册

# 2. 创建网络
# 在控制台创建新网络，获取网络ID

# 3. 在 NAS 上加入网络
cd /volume1/YC/services/zerotier
./configure.sh
docker-compose up -d

# 4. 在控制台授权设备
# 访问 https://my.zerotier.com 授权新设备

# 5. 在其他设备安装 ZeroTier 客户端
# 下载并安装客户端，加入相同网络
\`\`\`

**访问方式**:
- 通过分配的虚拟 IP 访问所有服务
- 例如: `http://10.147.17.123`

### 4. 🔧 Tailscale (现代化 VPN)
**适用场景**: 个人或小团队使用

**优势**:
- 零配置 VPN
- 基于 WireGuard
- 支持 20 个免费设备
- 自动 NAT 穿透

**配置步骤**:
\`\`\`bash
# 1. 注册 Tailscale 账户
# 访问 https://tailscale.com 注册

# 2. 生成 Auth Key
# 在设置中生成认证密钥

# 3. 在 NAS 上配置
cd /volume1/YC/services/tailscale
./configure.sh
docker-compose up -d

# 4. 在其他设备安装 Tailscale
# 下载客户端，使用相同账户登录
\`\`\`

**访问方式**:
- 通过 Tailscale IP 访问
- 例如: `http://100.64.0.1`

## 🔧 高级配置

### SSL 证书配置
\`\`\`bash
# 使用 Let's Encrypt 自动获取证书
docker run --rm \
  -v /volume1/YC/services/ssl:/etc/letsencrypt \
  certbot/certbot certonly \
  --standalone \
  -d yc.yourdomain.com \
  -d gitlab.yourdomain.com \
  -d ai.yourdomain.com
\`\`\`

### 域名解析配置
\`\`\`bash
# 配置域名解析 (以 Cloudflare 为例)
# 添加 A 记录指向您的服务器 IP
yc.yourdomain.com     A    YOUR_SERVER_IP
gitlab.yourdomain.com A    YOUR_SERVER_IP
ai.yourdomain.com     A    YOUR_SERVER_IP
*.yourdomain.com      A    YOUR_SERVER_IP
\`\`\`

### 安全加固
\`\`\`bash
# 1. 配置防火墙
ufw allow 7000/tcp  # frp 端口
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS

# 2. 配置 fail2ban
apt install fail2ban
systemctl enable fail2ban

# 3. 定期更新证书
echo "0 3 * * * certbot renew --quiet" | crontab -
\`\`\`

## 📊 性能优化

### 带宽优化
\`\`\`bash
# 配置 frp 带宽限制
[yc-web]
type = http
local_ip = 192.168.0.9
local_port = 80
custom_domains = yc.yourdomain.com
bandwidth_limit = 10MB  # 限制带宽
\`\`\`

### 连接优化
\`\`\`bash
# 配置连接池
[common]
pool_count = 5          # 连接池大小
max_pool_count = 10     # 最大连接数
tcp_mux = true          # 启用多路复用
\`\`\`

## 🛠️ 故障排除

### 常见问题

1. **连接超时**
\`\`\`bash
# 检查防火墙设置
ufw status
iptables -L

# 检查端口占用
netstat -tlnp | grep :7000
\`\`\`

2. **域名解析失败**
\`\`\`bash
# 检查 DNS 解析
nslookup yc.yourdomain.com
dig yc.yourdomain.com

# 刷新 DNS 缓存
systemctl restart systemd-resolved
\`\`\`

3. **证书问题**
\`\`\`bash
# 检查证书有效期
openssl x509 -in /path/to/cert.pem -text -noout

# 手动更新证书
certbot renew --force-renewal
\`\`\`

### 监控和日志
\`\`\`bash
# 查看 frp 日志
docker logs yc-frpc

# 查看 ngrok 日志
docker logs yc-ngrok

# 实时监控连接
watch -n 1 'netstat -an | grep :7000'
\`\`\`

## 📱 移动端访问

### iOS 配置
1. 安装 Tailscale 或 ZeroTier 客户端
2. 登录相同账户
3. 通过虚拟 IP 访问服务

### Android 配置
1. 下载对应客户端 APK
2. 配置网络连接
3. 访问内网服务

## 🔐 安全建议

1. **使用强密码和令牌**
2. **定期更新软件版本**
3. **配置访问控制列表**
4. **启用日志监控**
5. **使用 HTTPS 加密传输**

## 📈 成本对比

| 方案 | 月费用 | 带宽限制 | 设备数量 | 推荐指数 |
|------|--------|----------|----------|----------|
| frp (自建) | 服务器费用 | 无限制 | 无限制 | ⭐⭐⭐⭐⭐ |
| ngrok 免费版 | $0 | 有限制 | 1隧道 | ⭐⭐⭐ |
| ngrok 付费版 | $8+ | 较高 | 多隧道 | ⭐⭐⭐⭐ |
| ZeroTier 免费版 | $0 | 无限制 | 25设备 | ⭐⭐⭐⭐ |
| Tailscale 免费版 | $0 | 无限制 | 20设备 | ⭐⭐⭐⭐⭐ |

选择建议：
- **个人开发**: Tailscale 或 ZeroTier
- **团队协作**: frp 自建
- **临时测试**: ngrok
- **企业使用**: frp + 自建服务器
