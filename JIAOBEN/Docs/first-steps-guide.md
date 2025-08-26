# YYC³ 开发者工具包首次使用指南

## 🎯 部署完成后的首要步骤

### 1. 验证服务状态 ✅

\`\`\`bash
# 检查所有容器运行状态
docker ps

# 使用管理脚本检查
cd /volume2/YC
./manage.sh status

# 检查关键服务
curl -I http://192.168.0.9:3001  # 管理面板
curl -I http://192.168.0.9:4873  # NPM 仓库
curl -I http://192.168.0.9:8080  # GitLab
\`\`\`

### 2. 初始化 GitLab 🔧

\`\`\`bash
# 获取 GitLab root 初始密码
docker exec yc-gitlab cat /etc/gitlab/initial_root_password

# 访问 GitLab Web 界面
# URL: http://192.168.0.9:8080
# 用户名: root
# 密码: (上面命令获取的密码)
\`\`\`

**GitLab 初始配置步骤:**
1. 登录后立即修改 root 密码
2. 创建组织 (例如: YYC³)
3. 创建第一个项目
4. 配置 SSH 密钥
5. 注册 GitLab Runner

### 3. 配置 NPM 私有仓库 📦

\`\`\`bash
# 设置 NPM 仓库地址
npm config set registry http://192.168.0.9:4873

# 创建用户账户
npm adduser --registry http://192.168.0.9:4873

# 测试发布包
mkdir test-package && cd test-package
npm init -y
npm publish --registry http://192.168.0.9:4873
\`\`\`

### 4. 配置监控系统 📊

**访问 Grafana:**
- URL: http://192.168.0.9:3000
- 用户名: admin
- 密码: yyc3admin

**首次配置步骤:**
1. 修改默认密码
2. 验证 Prometheus 数据源连接
3. 导入预设仪表板
4. 配置告警通知渠道

### 5. 设置 AI 模型 🤖

\`\`\`bash
# 使用 AI 模型管理工具
cd /volume2/YC/ai-models
./manage-models.sh install-recommended

# 测试 AI 服务
./manage-models.sh test llama3.2:3b

# 检查 AI 路由器状态
curl http://192.168.0.9:8888/health
\`\`\`

## 🔐 安全配置 (重要!)

### 1. 修改默认密码

\`\`\`bash
# GitLab root 密码 (通过 Web 界面)
# Grafana admin 密码 (通过 Web 界面)

# 生成新的 JWT 密钥
openssl rand -base64 32
# 更新环境变量文件中的 JWT_SECRET
\`\`\`

### 2. 配置防火墙

\`\`\`bash
# Ubuntu/Debian
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 3001/tcp    # 管理面板
sudo ufw allow 8080/tcp    # GitLab
sudo ufw allow 3000/tcp    # Grafana
sudo ufw enable

# 检查防火墙状态
sudo ufw status
\`\`\`

### 3. 设置 SSL 证书 (推荐)

\`\`\`bash
# 安装 Certbot
sudo apt-get install certbot

# 申请证书 (需要域名)
sudo certbot certonly --standalone -d your-domain.com

# 配置 Nginx SSL
sudo nano /etc/nginx/sites-available/yyc3-ssl
\`\`\`

## 📱 配置微信通知

### 1. 获取企业微信 Webhook

1. 登录企业微信管理后台
2. 创建群聊机器人
3. 获取 Webhook URL

### 2. 更新配置

\`\`\`bash
# 编辑环境变量
nano /volume2/YC/.env

# 更新 WECHAT_WEBHOOK_URL
WECHAT_WEBHOOK_URL=https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY

# 重新加载环境变量
source /volume2/YC/.env

# 测试告警通知
cd /volume2/YC/monitoring
./manage-monitoring.sh test-alerts
\`\`\`

## 🚀 创建第一个项目

### 1. 使用 GitLab 创建项目

\`\`\`bash
# 克隆项目模板
git clone http://192.168.0.9:8080/templates/nextjs-app.git my-first-app
cd my-first-app

# 配置 NPM 仓库
npm config set registry http://192.168.0.9:4873

# 安装依赖
npm install

# 启动开发服务器
npm run dev
\`\`\`

### 2. 配置 CI/CD 流水线

在项目根目录创建 `.gitlab-ci.yml`:

\`\`\`yaml
# 使用 YYC³ Next.js 模板
include:
  - project: 'templates/nextjs-app'
    file: '.gitlab-ci.yml'

variables:
  PROJECT_NAME: "my-first-app"
  DEPLOY_ENV: "staging"

# 自定义部署步骤
deploy-custom:
  stage: deploy
  script:
    - echo "部署到自定义环境"
  only:
    - main
\`\`\`

### 3. 配置品牌合规检查

\`\`\`bash
# 安装 YYC³ CLI 工具
npm install -g @yanyucloud/cli

# 初始化品牌配置
yyc init

# 执行品牌检查
yyc brand-check --strict
\`\`\`

## 📚 开发工作流程

### 1. 标准开发流程

\`\`\`bash
# 1. 创建功能分支
git checkout -b feature/new-feature

# 2. 开发和测试
npm run dev
npm run test
npm run lint

# 3. 品牌合规检查
yyc brand-check

# 4. 提交代码
git add .
git commit -m "feat: 添加新功能"
git push origin feature/new-feature

# 5. 创建 Merge Request
# 通过 GitLab Web 界面创建
\`\`\`

### 2. 包管理工作流程

\`\`\`bash
# 发布内部包
npm publish --registry http://192.168.0.9:4873

# 安装内部包
npm install @yyc3/component-library --registry http://192.168.0.9:4873

# 更新包版本
npm version patch
npm publish --registry http://192.168.0.9:4873
\`\`\`

## 🔍 监控和维护

### 1. 日常监控检查

\`\`\`bash
# 检查服务状态
./manage.sh status

# 查看资源使用情况
docker stats

# 检查磁盘空间
df -h /volume2/YC

# 查看系统负载
htop
\`\`\`

### 2. 日志管理

\`\`\`bash
# 查看应用日志
./manage.sh logs yc-gitlab

# 查看监控日志
cd /volume2/YC/monitoring
./manage-monitoring.sh logs prometheus

# 清理旧日志
find /volume2/YC -name "*.log" -mtime +7 -delete
\`\`\`

### 3. 备份管理

\`\`\`bash
# 手动备份
./manage.sh backup

# 设置自动备份
crontab -e
# 添加: 0 2 * * * /volume2/YC/manage.sh backup

# 验证备份
ls -la /volume2/YC/backups/
\`\`\`

## 🎯 性能优化建议

### 1. 系统优化

\`\`\`bash
# 优化 Docker 配置
sudo nano /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}

# 重启 Docker
sudo systemctl restart docker
\`\`\`

###
  },
  "storage-driver": "overlay2"
}

# 重启 Docker
sudo systemctl restart docker
\`\`\`

### 2. 容器资源限制

\`\`\`bash
# 编辑 docker-compose.yml 文件，添加资源限制
services:
  gitlab:
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2'
        reservations:
          memory: 2G
          cpus: '1'
  
  prometheus:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1'
\`\`\`

### 3. 数据库优化

\`\`\`bash
# 优化 GitLab PostgreSQL 配置
docker exec yc-gitlab gitlab-ctl reconfigure

# 清理 Docker 系统
docker system prune -a --volumes

# 优化磁盘 I/O
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
\`\`\`

## 🚨 故障排除

### 常见问题解决方案

#### 1. 服务无法启动

\`\`\`bash
# 检查端口冲突
sudo netstat -tulpn | grep :3001

# 检查 Docker 网络
docker network ls
docker network inspect yyc3-network

# 重新创建网络
docker network rm yyc3-network
docker network create yyc3-network
\`\`\`

#### 2. GitLab 502 错误

\`\`\`bash
# 检查 GitLab 容器状态
docker logs yc-gitlab

# 重启 GitLab 服务
docker restart yc-gitlab

# 等待服务完全启动 (可能需要 5-10 分钟)
\`\`\`

#### 3. AI 服务响应慢

\`\`\`bash
# 检查 AI 服务资源使用
docker stats yc-ollama-1 yc-ollama-2

# 重启 AI 服务
cd /volume2/YC/ai-models
docker-compose restart

# 清理模型缓存
./manage-models.sh status
\`\`\`

#### 4. 监控数据丢失

\`\`\`bash
# 检查 Prometheus 数据目录
ls -la /volume2/YC/monitoring/prometheus/data/

# 重启监控服务
cd /volume2/YC/monitoring
./manage-monitoring.sh restart

# 检查磁盘空间
df -h /volume2/YC/monitoring/
\`\`\`

## 📞 技术支持

### 获取帮助的渠道

1. **查看日志文件**
   \`\`\`bash
   # 系统日志
   tail -f /tmp/yyc3-*.log
   
   # 容器日志
   docker logs -f container-name
   \`\`\`

2. **系统诊断**
   \`\`\`bash
   # 运行健康检查
   cd /volume2/YC
   ./scripts/health-check.sh
   
   # 生成诊断报告
   ./scripts/final-deployment-check.sh
   \`\`\`

3. **社区支持**
   - 查看文档: `/volume2/YC/docs/`
   - 提交问题: GitLab Issues
   - 技术交流: 企业微信群

## 🎉 恭喜！

您已经成功部署并配置了 YYC³ 开发者工具包！现在您可以：

- ✅ 使用私有 NPM 仓库管理包
- ✅ 通过 GitLab 进行代码管理和 CI/CD
- ✅ 利用 AI 服务提升开发效率
- ✅ 通过监控系统掌握系统状态
- ✅ 享受完整的企业级开发体验

**下一步建议:**
1. 创建您的第一个项目
2. 邀请团队成员加入
3. 配置个性化的开发环境
4. 探索 AI 辅助开发功能

---

**记住**: 定期备份数据，保持系统更新，关注安全通知！
