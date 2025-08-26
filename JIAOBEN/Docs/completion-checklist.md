# YYC³ 开发者工具包完善清单

## 📋 当前状态分析

### ✅ 已完成项目
- [x] 存储优化部署脚本
- [x] 高级配置脚本  
- [x] Mac 客户端集成
- [x] 安全加固配置
- [x] 网络穿透配置
- [x] FRP 初学者配置
- [x] YYC³ 开发工具包核心
- [x] 管理面板框架

### 🔄 需要完善的核心功能

#### 1. 环境变量配置完善
\`\`\`bash
# 已配置
YYC3_REGISTRY=http://192.168.0.9:4873
PORT=3001
JWT_SECRET=your-jwt-secret-here

# 待配置
SERVICE_NAME=yyc3-devkit
SERVICE_HOST=192.168.0.9
WEBHOOK_URL=https://your-webhook-url
MONITORING_API_KEY=your-monitoring-key
\`\`\`

#### 2. GitLab 集成配置
- [ ] GitLab Runner 配置
- [ ] CI/CD 流水线
- [ ] 代码仓库模板
- [ ] 自动化部署

#### 3. AI 模型优化
- [ ] 模型负载均衡
- [ ] 智能路由分配
- [ ] 性能监控
- [ ] 资源管理

#### 4. 监控告警系统
- [ ] Prometheus 配置
- [ ] Grafana 仪表板
- [ ] 告警规则设置
- [ ] 微信通知集成

#### 5. HTTPS 证书配置
- [ ] SSL 证书申请
- [ ] Nginx HTTPS 配置
- [ ] 证书自动续期
- [ ] 安全策略优化

### 🚀 待开发功能模块

#### 1. 项目模板库
- [ ] Next.js 企业模板
- [ ] React 组件库模板
- [ ] Node.js API 模板
- [ ] 微服务架构模板

#### 2. 团队协作工具
- [ ] 代码审查流程
- [ ] 任务管理系统
- [ ] 文档协作平台
- [ ] 知识库管理

#### 3. 开发文档系统
- [ ] API 文档生成
- [ ] 组件文档
- [ ] 最佳实践指南
- [ ] 故障排除手册

### 📊 系统集成优化

#### 1. 数据库集成
- [ ] PostgreSQL 配置
- [ ] Redis 缓存
- [ ] 数据备份策略
- [ ] 性能优化

#### 2. 容器化部署
- [ ] Docker Compose 优化
- [ ] Kubernetes 配置
- [ ] 服务发现
- [ ] 负载均衡

#### 3. 安全加固
- [ ] 访问控制优化
- [ ] 审计日志
- [ ] 漏洞扫描
- [ ] 安全策略更新
\`\`\`

\`\`\`shellscript file="scripts/gitlab-integration.sh"
#!/bin/bash

# YYC³ GitLab 集成配置脚本
# 配置 GitLab 服务器和 CI/CD 流水线

set -e

ROOT_DIR="/volume2/YC"
GITLAB_DIR="/volume2/YC/gitlab"
GITLAB_DATA_DIR="/volume2/YC/gitlab-data"
NAS_IP="192.168.0.9"
GITLAB_PORT="8080"

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

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN}"
    cat &lt;&lt; 'EOF'
    ██╗   ██╗██╗   ██╗ ██████╗██████╗      ██████╗ ██╗████████╗██╗      █████╗ ██████╗ 
    ╚██╗ ██╔╝╚██╗ ██╔╝██╔════╝╚════██╗    ██╔════╝ ██║╚══██╔══╝██║     ██╔══██╗██╔══██╗
     ╚████╔╝  ╚████╔╝ ██║      █████╔╝    ██║  ███╗██║   ██║   ██║     ███████║██████╔╝
      ╚██╔╝    ╚██╔╝  ██║      ╚═══██╗    ██║   ██║██║   ██║   ██║     ██╔══██║██╔══██╗
       ██║      ██║   ╚██████╗██████╔╝    ╚██████╔╝██║   ██║   ███████╗██║  ██║██████╔╝
       ╚═╝      ╚═╝    ╚═════╝╚═════╝      ╚═════╝ ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═════╝ 
                                                                                        
    YYC³ GitLab 集成
    GitLab Integration
    ==================
EOF
    echo -e "${NC}"
    echo ""
    echo "🔧 配置 GitLab 服务器和 CI/CD 流水线"
    echo "📅 配置时间: $(date)"
    echo "🌐 目标服务器: $NAS_IP:$GITLAB_PORT"
    echo "📁 数据目录: $GITLAB_DATA_DIR"
    echo ""
}

# 创建 GitLab 目录结构
create_gitlab_structure() {
    log_step "创建 GitLab 目录结构..."
    
    mkdir -p "$GITLAB_DIR"/{config,logs,data}
    mkdir -p "$GITLAB_DATA_DIR"/{config,logs,data,backups}
    mkdir -p "$ROOT_DIR/gitlab-runner"/{config,builds}
    
    # 设置权限
    chown -R 998:998 "$GITLAB_DATA_DIR"
    chmod -R 755 "$GITLAB_DATA_DIR"
    
    log_success "目录结构创建完成"
}

# 创建 GitLab Docker Compose 配置
create_gitlab_compose() {
    log_step "创建 GitLab Docker Compose 配置..."
    
    cat > "$GITLAB_DIR/docker-compose.yml" &lt;&lt; 'EOF'
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: yc-gitlab
    hostname: 'gitlab.yyc3.local'
    restart: unless-stopped
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://192.168.0.9:8080'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        gitlab_rails['time_zone'] = 'Asia/Shanghai'
        
        # 邮件配置
        gitlab_rails['smtp_enable'] = true
        gitlab_rails['smtp_address'] = "smtp.qq.com"
        gitlab_rails['smtp_port'] = 587
        gitlab_rails['smtp_user_name'] = "your-email@qq.com"
        gitlab_rails['smtp_password'] = "your-password"
        gitlab_rails['smtp_domain'] = "qq.com"
        gitlab_rails['smtp_authentication'] = "login"
        gitlab_rails['smtp_enable_starttls_auto'] = true
        gitlab_rails['smtp_tls'] = false
        
        # 性能优化
        postgresql['shared_preload_libraries'] = 'pg_stat_statements'
        postgresql['max_connections'] = 200
        postgresql['shared_buffers'] = "256MB"
        
        # 备份配置
        gitlab_rails['backup_keep_time'] = 604800
        gitlab_rails['backup_path'] = "/var/opt/gitlab/backups"
        
        # 监控配置
        prometheus_monitoring['enable'] = true
        grafana['enable'] = true
        
        # 安全配置
        nginx['ssl_certificate'] = "/etc/gitlab/ssl/gitlab.crt"
        nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/gitlab.key"
        
    ports:
      - '8080:80'
      - '2222:22'
      - '9090:9090'  # Prometheus
      - '3000:3000'  # Grafana
    volumes:
      - '/volume2/YC/gitlab-data/config:/etc/gitlab'
      - '/volume2/YC/gitlab-data/logs:/var/log/gitlab'
      - '/volume2/YC/gitlab-data/data:/var/opt/gitlab'
      - '/volume2/YC/gitlab-data/backups:/var/opt/gitlab/backups'
    networks:
      - yyc3-network
    shm_size: '256m'

  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    container_name: yc-gitlab-runner
    restart: unless-stopped
    volumes:
      - '/volume2/YC/gitlab-runner/config:/etc/gitlab-runner'
      - '/var/run/docker.sock:/var/run/docker.sock'
      - '/volume2/YC/gitlab-runner/builds:/builds'
    networks:
      - yyc3-network
    depends_on:
      - gitlab

  redis:
    image: redis:7-alpine
    container_name: yc-gitlab-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - '/volume2/YC/gitlab-data/redis:/data'
    networks:
      - yyc3-network

networks:
  yyc3-network:
    external: true
EOF

    log_success "GitLab Docker Compose 配置创建完成"
}

# 创建 GitLab Runner 配置
create_runner_config() {
    log_step "创建 GitLab Runner 配置..."
    
    cat > "$ROOT_DIR/gitlab-runner/config/config.toml" &lt;&lt; 'EOF'
concurrent = 4
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "yyc3-docker-runner"
  url = "http://192.168.0.9:8080/"
  token = "YOUR_RUNNER_TOKEN"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "node:18-alpine"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
    network_mode = "yyc3-network"
    pull_policy = "if-not-present"

[[runners]]
  name = "yyc3-shell-runner"
  url = "http://192.168.0.9:8080/"
  token = "YOUR_RUNNER_TOKEN"
  executor = "shell"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
EOF

    log_success "GitLab Runner 配置创建完成"
}

# 创建 CI/CD 模板
create_cicd_templates() {
    log_step "创建 CI/CD 模板..."
    
    mkdir -p "$ROOT_DIR/gitlab-templates"/{nextjs,react,nodejs,docker}
    
    # Next.js CI/CD 模板
    cat > "$ROOT_DIR/gitlab-templates/nextjs/.gitlab-ci.yml" &lt;&lt; 'EOF'
# YYC³ Next.js CI/CD 流水线模板
# Copyright (c) 2024 YanYu Intelligence Cloud³

stages:
  - validate
  - test
  - build
  - deploy
  - notify

variables:
  NODE_VERSION: "18"
  REGISTRY_URL: "http://192.168.0.9:4873"
  DOCKER_REGISTRY: "192.168.0.9:5000"

# 品牌合规检查
brand-check:
  stage: validate
  image: node:${NODE_VERSION}-alpine
  script:
    - npm install -g @yanyucloud/cli
    - yyc brand-check --strict
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# 代码质量检查
lint:
  stage: validate
  image: node:${NODE_VERSION}-alpine
  script:
    - npm ci --registry=${REGISTRY_URL}
    - npm run lint
    - npm run type-check
  artifacts:
    reports:
      junit: reports/lint-results.xml
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# 单元测试
test:
  stage: test
  image: node:${NODE_VERSION}-alpine
  script:
    - npm ci --registry=${REGISTRY_URL}
    - npm run test:coverage
  coverage: '/All files[^|]*\|[^|]*\s+([\d\.]+)/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
      junit: reports/test-results.xml
    paths:
      - coverage/
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# 构建应用
build:
  stage: build
  image: node:${NODE_VERSION}-alpine
  script:
    - npm ci --registry=${REGISTRY_URL}
    - npm run build
    - yyc brand-check --build
  artifacts:
    paths:
      - .next/
      - out/
    expire_in: 1 hour
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# Docker 镜像构建
docker-build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  script:
    - docker build -t ${DOCKER_REGISTRY}/${CI_PROJECT_NAME}:${CI_COMMIT_SHA} .
    - docker build -t ${DOCKER_REGISTRY}/${CI_PROJECT_NAME}:latest .
    - docker push ${DOCKER_REGISTRY}/${CI_PROJECT_NAME}:${CI_COMMIT_SHA}
    - docker push ${DOCKER_REGISTRY}/${CI_PROJECT_NAME}:latest
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# 部署到测试环境
deploy-staging:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache curl
  script:
    - curl -X POST "${WEBHOOK_URL}/deploy" 
      -H "Content-Type: application/json" 
      -d '{"environment":"staging","image":"'${DOCKER_REGISTRY}/${CI_PROJECT_NAME}:${CI_COMMIT_SHA}'"}'
  environment:
    name: staging
    url: http://staging.yyc3.local
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# 部署到生产环境
deploy-production:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache curl
  script:
    - curl -X POST "${WEBHOOK_URL}/deploy" 
      -H "Content-Type: application/json" 
      -d '{"environment":"production","image":"'${DOCKER_REGISTRY}/${CI_PROJECT_NAME}:${CI_COMMIT_SHA}'"}'
  environment:
    name: production
    url: http://yyc3.local
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - when: manual

# 微信通知
notify-wechat:
  stage: notify
  image: alpine:latest
  before_script:
    - apk add --no-cache curl
  script:
    - |
      if [ "$CI_JOB_STATUS" == "success" ]; then
        MESSAGE="✅ YYC³ 项目 ${CI_PROJECT_NAME} 部署成功！
        📦 版本: ${CI_COMMIT_SHA:0:8}
        🌐 环境: ${CI_ENVIRONMENT_NAME}
        👤 提交者: ${GITLAB_USER_NAME}
        🕐 时间: $(date)"
      else
        MESSAGE="❌ YYC³ 项目 ${CI_PROJECT_NAME} 部署失败！
        📦 版本: ${CI_COMMIT_SHA:0:8}
        🌐 环境: ${CI_ENVIRONMENT_NAME}
        👤 提交者: ${GITLAB_USER_NAME}
        🕐 时间: $(date)"
      fi
      
      curl -X POST "${WECHAT_WEBHOOK_URL}" \
        -H "Content-Type: application/json" \
        -d "{\"msgtype\":\"text\",\"text\":{\"content\":\"$MESSAGE\"}}"
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - when: on_failure
    - when: on_success
EOF

    # React 组件库 CI/CD 模板
    cat > "$ROOT_DIR/gitlab-templates/react/.gitlab-ci.yml" &lt;&lt; 'EOF'
# YYC³ React 组件库 CI/CD 流水线模板
# Copyright (c) 2024 YanYu Intelligence Cloud³

stages:
  - validate
  - test
  - build
  - publish
  - deploy-docs

variables:
  NODE_VERSION: "18"
  REGISTRY_URL: "http://192.168.0.9:4873"

# 品牌合规检查
brand-check:
  stage: validate
  image: node:${NODE_VERSION}-alpine
  script:
    - npm install -g @yanyucloud/cli
    - yyc brand-check --components
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# 组件测试
test-components:
  stage: test
  image: node:${NODE_VERSION}-alpine
  script:
    - npm ci --registry=${REGISTRY_URL}
    - npm run test:components
    - npm run test:visual
  artifacts:
    reports:
      junit: reports/component-tests.xml
    paths:
      - screenshots/
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# 构建组件库
build-library:
  stage: build
  image: node:${NODE_VERSION}-alpine
  script:
    - npm ci --registry=${REGISTRY_URL}
    - npm run build:lib
    - npm run build:types
  artifacts:
    paths:
      - dist/
      - types/
    expire_in: 1 hour
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# 发布到私有 NPM 仓库
publish-npm:
  stage: publish
  image: node:${NODE_VERSION}-alpine
  script:
    - npm config set registry ${REGISTRY_URL}
    - npm publish --registry=${REGISTRY_URL}
  rules:
    - if: $CI_COMMIT_TAG

# 构建 Storybook 文档
build-storybook:
  stage: build
  image: node:${NODE_VERSION}-alpine
  script:
    - npm ci --registry=${REGISTRY_URL}
    - npm run build-storybook
  artifacts:
    paths:
      - storybook-static/
    expire_in: 1 week
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# 部署文档站点
deploy-docs:
  stage: deploy-docs
  image: alpine:latest
  script:
    - apk add --no-cache rsync openssh-client
    - rsync -avz --delete storybook-static/ user@192.168.0.9:/volume1/web/yyc3-components/
  environment:
    name: docs
    url: http://192.168.0.9/yyc3-components
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
EOF

    log_success "CI/CD 模板创建完成"
}

# 创建项目模板
create_project_templates() {
    log_step "创建项目模板..."
    
    mkdir -p "$ROOT_DIR/project-templates"/{nextjs-app,react-component,nodejs-api}
    
    # Next.js 应用模板
    cat > "$ROOT_DIR/project-templates/nextjs-app/template.json" &lt;&lt; 'EOF'
{
  "name": "YYC³ Next.js 应用模板",
  "description": "基于 Next.js 的企业级应用模板",
  "version": "1.0.0",
  "author": "YanYu Intelligence Cloud³",
  "license": "MIT",
  "keywords": ["yyc3", "nextjs", "template", "enterprise"],
  "repository": {
    "type": "git",
    "url": "http://192.168.0.9:8080/templates/nextjs-app.git"
  },
  "features": [
    "Next.js 14 App Router",
    "TypeScript 支持",
    "Tailwind CSS",
    "YYC³ 组件库",
    "ESLint + Prettier",
    "品牌合规检查",
    "CI/CD 流水线",
    "Docker 支持"
  ],
  "structure": {
    "app/": "Next.js App Router 目录",
    "components/": "自定义组件",
    "lib/": "工具函数",
    "public/": "静态资源",
    "styles/": "样式文件"
  },
  "scripts": {
    "create": "yyc create nextjs-app",
    "setup": "npm install && yyc brand-check",
    "dev": "next dev",
    "build": "next build",
    "deploy": "yyc deploy"
  }
}
EOF

    # React 组件库模板
    cat > "$ROOT_DIR/project-templates/react-component/template.json" &lt;&lt; 'EOF'
{
  "name": "YYC³ React 组件库模板",
  "description": "符合 YYC³ 品牌规范的 React 组件库模板",
  "version": "1.0.0",
  "author": "YanYu Intelligence Cloud³",
  "license": "MIT",
  "keywords": ["yyc3", "react", "components", "library"],
  "repository": {
    "type": "git",
    "url": "http://192.168.0.9:8080/templates/react-component.git"
  },
  "features": [
    "React 18",
    "TypeScript",
    "Storybook 文档",
    "Jest + Testing Library",
    "Rollup 构建",
    "品牌合规检查",
    "自动化测试",
    "NPM 发布"
  ],
  "structure": {
    "src/": "组件源码",
    "stories/": "Storybook 故事",
    "tests/": "测试文件",
    "dist/": "构建输出"
  },
  "scripts": {
    "create": "yyc create react-component",
    "setup": "npm install && yyc brand-check",
    "dev": "storybook dev",
    "build": "rollup -c",
    "publish": "npm publish --registry=http://192.168.0.9:4873"
  }
}
EOF

    log_success "项目模板创建完成"
}

# 启动 GitLab 服务
start_gitlab_services() {
    log_step "启动 GitLab 服务..."
    
    cd "$GITLAB_DIR"
    
    # 启动服务
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待 GitLab 服务启动（这可能需要几分钟）..."
    
    for i in {1..30}; do
        if curl -s "http://$NAS_IP:$GITLAB_PORT" > /dev/null 2>&1; then
            log_success "GitLab 服务启动成功"
            break
        fi
        
        if [ $i -eq 30 ]; then
            log_error "GitLab 服务启动超时"
            exit 1
        fi
        
        echo -n "."
        sleep 10
    done
    
    echo ""
}

# 配置 GitLab 初始设置
configure_gitlab() {
    log_step "配置 GitLab 初始设置..."
    
    # 获取初始 root 密码
    log_info "获取 GitLab root 初始密码..."
    
    # 等待密码文件生成
    for i in {1..10}; do
        if docker exec yc-gitlab cat /etc/gitlab/initial_root_password 2>/dev/null | grep "Password:" > /tmp/gitlab_password.txt; then
            GITLAB_ROOT_PASSWORD=$(cat /tmp/gitlab_password.txt | cut -d' ' -f2)
            log_success "获取到 root 密码: $GITLAB_ROOT_PASSWORD"
            break
        fi
        sleep 5
    done
    
    # 创建配置脚本
    cat > "$GITLAB_DIR/configure.sh" &lt;&lt; EOF
#!/bin/bash

# GitLab 配置脚本

echo "🔧 GitLab 配置信息"
echo "===================="
echo "访问地址: http://$NAS_IP:$GITLAB_PORT"
echo "用户名: root"
echo "密码: \$GITLAB_ROOT_PASSWORD"
echo ""
echo "📋 后续配置步骤:"
echo "1. 访问 GitLab Web 界面"
echo "2. 使用 root 账户登录"
echo "3. 修改管理员密码"
echo "4. 创建组织和项目"
echo "5. 配置 GitLab Runner"
echo ""
echo "🔧 Runner 注册命令:"
echo "docker exec -it yc-gitlab-runner gitlab-runner register"
echo ""
EOF

    chmod +x "$GITLAB_DIR/configure.sh"
    
    log_success "GitLab 初始配置完成"
}

# 主执行函数
main() {
    show_welcome
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        log_warning "建议使用 root 权限运行此脚本"
    fi
    
    # 执行配置步骤
    create_gitlab_structure
    create_gitlab_compose
    create_runner_config
    create_cicd_templates
    create_project_templates
    start_gitlab_services
    configure_gitlab
    
    # 显示完成信息
    echo ""
    log_success "🎉 YYC³ GitLab 集成配置完成！"
    echo ""
    log_highlight "📋 配置摘要:"
    echo "  🌐 GitLab 地址: http://$NAS_IP:$GITLAB_PORT"
    echo "  👤 管理员账户: root"
    echo "  🔑 初始密码: 请查看容器日志"
    echo "  📁 数据目录: $GITLAB_DATA_DIR"
    echo ""
    log_highlight "🚀 后续步骤:"
    echo "  1. 访问 GitLab Web 界面完成初始化"
    echo "  2. 运行 '$GITLAB_DIR/configure.sh' 查看配置信息"
    echo "  3. 注册 GitLab Runner"
    echo "  4. 创建项目并配置 CI/CD"
    echo ""
    log_highlight "🔧 管理命令:"
    echo "  • 查看服务状态: docker-compose -f $GITLAB_DIR/docker-compose.yml ps"
    echo "  • 重启服务: docker-compose -f $GITLAB_DIR/docker-compose.yml restart"
    echo "  • 查看日志: docker-compose -f $GITLAB_DIR/docker-compose.yml logs -f"
    echo ""
}

# 执行主函数
main "$@"
