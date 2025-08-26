#!/bin/bash

# YC 开发环境完整部署脚本 - 最终版本

set -e

ROOT_DIR="/volume1/YC"
NAS_IP="192.168.3.9"

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
    cat << 'EOF'
    ██╗   ██╗ ██████╗    ██████╗ ███████╗██╗   ██╗
    ╚██╗ ██╔╝██╔════╝    ██╔══██╗██╔════╝██║   ██║
     ╚████╔╝ ██║         ██║  ██║█████╗  ██║   ██║
      ╚██╔╝  ██║         ██║  ██║██╔══╝  ╚██╗ ██╔╝
       ██║   ╚██████╗    ██████╔╝███████╗ ╚████╔╝ 
       ╚═╝    ╚═════╝    ╚═════╝ ╚══════╝  ╚═══╝  
                                                   
    全栈开发环境 - 企业级解决方案
    ============================
EOF
    echo -e "${NC}"
    echo ""
    echo "🚀 欢迎使用 YC 全栈开发环境部署系统"
    echo "📅 部署时间: $(date)"
    echo "🌐 目标服务器: $NAS_IP"
    echo "📁 安装目录: $ROOT_DIR"
    echo ""
}

# 检查系统要求
check_system_requirements() {
    log_step "检查系统要求..."
    
    # 检查操作系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "此脚本需要在 Linux 系统上运行"
        exit 1
    fi
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    # 检查磁盘空间 (至少需要 50GB)
    AVAILABLE_SPACE=$(df /volume1 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
    REQUIRED_SPACE=$((50 * 1024 * 1024)) # 50GB in KB
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        log_error "磁盘空间不足，至少需要 50GB 可用空间"
        exit 1
    fi
    
    # 检查内存 (建议至少 16GB)
    TOTAL_MEMORY=$(free -m | grep Mem | awk '{print $2}')
    if [ "$TOTAL_MEMORY" -lt 16384 ]; then
        log_warning "内存可能不足 (${TOTAL_MEMORY}MB)，建议至少 16GB"
        read -p "是否继续部署？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "系统要求检查通过"
}

# 显示部署选项
show_deployment_options() {
    echo ""
    log_highlight "请选择部署模式："
    echo "1. 🚀 快速部署 (核心服务 + AI + 监控)"
    echo "2. 🔧 标准部署 (包含开发工具和安全功能)"
    echo "3. 🏢 企业部署 (完整功能 + 企业集成)"
    echo "4. 🎯 自定义部署 (选择特定组件)"
    echo "5. 📋 查看部署清单"
    echo "0. ❌ 退出"
    echo ""
    
    while true; do
        read -p "请选择部署模式 (0-5): " choice
        case $choice in
            1) DEPLOYMENT_MODE="quick"; break ;;
            2) DEPLOYMENT_MODE="standard"; break ;;
            3) DEPLOYMENT_MODE="enterprise"; break ;;
            4) DEPLOYMENT_MODE="custom"; break ;;
            5) show_deployment_manifest; continue ;;
            0) echo "👋 部署已取消"; exit 0 ;;
            *) echo "❌ 无效选择，请重新输入" ;;
        esac
    done
}

# 显示部署清单
show_deployment_manifest() {
    echo ""
    log_highlight "YC 开发环境部署清单"
    echo "===================="
    echo ""
    echo "🔧 核心服务:"
    echo "  • Nginx (反向代理)"
    echo "  • GitLab (代码管理)"
    echo "  • PostgreSQL (数据库)"
    echo "  • Redis (缓存)"
    echo "  • Portainer (容器管理)"
    echo ""
    echo "🤖 AI 服务:"
    echo "  • Ollama (大语言模型)"
    echo "  • Open WebUI (AI 交互界面)"
    echo "  • AI Gateway (负载均衡)"
    echo "  • AI Dashboard (模型管理)"
    echo ""
    echo "📊 监控服务:"
    echo "  • Prometheus (指标收集)"
    echo "  • Grafana (监控面板)"
    echo "  • AlertManager (告警管理)"
    echo "  • Node Exporter (系统监控)"
    echo ""
    echo "💻 开发工具:"
    echo "  • Code Server (Web IDE)"
    echo "  • v0 开发环境 (Next.js)"
    echo "  • Jenkins (CI/CD)"
    echo "  • MinIO (对象存储)"
    echo ""
    echo "🔒 安全服务:"
    echo "  • SSL/TLS 证书"
    echo "  • OAuth2 认证"
    echo "  • Fail2Ban 防护"
    echo "  • 安全扫描器"
    echo ""
    echo "🏗️ 微服务架构:"
    echo "  • Kong API 网关"
    echo "  • Consul 服务发现"
    echo "  • Jaeger 分布式追踪"
    echo "  • NATS 消息队列"
    echo ""
    echo "🏢 企业集成:"
    echo "  • LDAP 目录服务"
    echo "  • Keycloak 身份认证"
    echo "  • SonarQube 代码质量"
    echo "  • Nexus 制品仓库"
    echo ""
    echo "🤖 智能运维:"
    echo "  • 日志收集分析"
    echo "  • 混沌工程"
    echo "  • 智能告警"
    echo "  • 性能优化"
    echo ""
    read -p "按回车键返回..."
}

# 执行部署
execute_deployment() {
    log_step "开始执行 $DEPLOYMENT_MODE 模式部署..."
    
    case $DEPLOYMENT_MODE in
        "quick")
            deploy_quick_mode
            ;;
        "standard")
            deploy_standard_mode
            ;;
        "enterprise")
            deploy_enterprise_mode
            ;;
        "custom")
            deploy_custom_mode
            ;;
    esac
}

# 快速部署模式
deploy_quick_mode() {
    log_info "执行快速部署模式..."
    
    # 基础环境
    log_step "1/4 部署基础环境..."
    "$ROOT_DIR/development/scripts/setup-dev-environment.sh" || handle_error "基础环境部署失败"
    
    # AI 服务
    log_step "2/4 部署 AI 服务..."
    docker-compose -f "$ROOT_DIR/development/docker-compose/ai-services.yml" up -d || handle_error "AI 服务部署失败"
    
    # 监控服务
    log_step "3/4 部署监控服务..."
    docker-compose -f "$ROOT_DIR/development/docker-compose/monitoring.yml" up -d || handle_error "监控服务部署失败"
    
    # 健康检查
    log_step "4/4 执行健康检查..."
    sleep 30
    "$ROOT_DIR/development/scripts/health-check.sh" || log_warning "健康检查发现问题"
    
    log_success "快速部署完成！"
}

# 标准部署模式
deploy_standard_mode() {
    log_info "执行标准部署模式..."
    
    # 基础环境
    log_step "1/6 部署基础环境..."
    "$ROOT_DIR/development/scripts/setup-dev-environment.sh" || handle_error "基础环境部署失败"
    
    # 高级功能
    log_step "2/6 部署高级功能..."
    "$ROOT_DIR/development/scripts/advanced-setup.sh" || handle_error "高级功能部署失败"
    
    # 安全加固
    log_step "3/6 行安全加固..."
    "$ROOT_DIR/development/scripts/security-hardening.sh" || handle_error "安全加固失败"
    
    # 微服务架构
    log_step "4/6 部署微服务架构..."
    "$ROOT_DIR/development/scripts/microservices-setup.sh" || handle_error "微服务架构部署失败"
    
    # 智能运维
    log_step "5/6 部署智能运维..."
    docker-compose -f "$ROOT_DIR/development/docker-compose/intelligent-ops.yml" up -d || handle_error "智能运维部署失败"
    
    # 健康检查
    log_step "6/6 执行健康检查..."
    sleep 60
    "$ROOT_DIR/development/scripts/health-check.sh" || log_warning "健康检查发现问题"
    
    log_success "标准部署完成！"
}

# 企业部署模式
deploy_enterprise_mode() {
    log_info "执行企业部署模式..."
    
    # 执行标准部署
    deploy_standard_mode
    
    # 企业集成
    log_step "部署企业集成服务..."
    docker-compose -f "$ROOT_DIR/development/docker-compose/enterprise.yml" up -d || handle_error "企业集成部署失败"
    
    # 协作工具
    log_step "部署协作工具..."
    docker-compose -f "$ROOT_DIR/development/docker-compose/collaboration.yml" up -d || handle_error "协作工具部署失败"
    
    log_success "企业部署完成！"
}

# 自定义部署模式
deploy_custom_mode() {
    log_info "执行自定义部署模式..."
    
    echo ""
    echo "请选择要部署的组件："
    echo "1. ✅ 核心服务 (必选)"
    echo "2. 🤖 AI 服务"
    echo "3. 📊 监控服务"
    echo "4. 💻 开发工具"
    echo "5. 🔒 安全服务"
    echo "6. 🏗️ 微服务架构"
    echo "7. 🏢 企业集成"
    echo "8. 👥 协作工具"
    echo "9. 🤖 智能运维"
    echo ""
    
    # 核心服务是必选的
    DEPLOY_CORE=true
    
    read -p "部署 AI 服务？(y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && DEPLOY_AI=true || DEPLOY_AI=false
    read -p "部署监控服务？(y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && DEPLOY_MONITORING=true || DEPLOY_MONITORING=false
    read -p "部署开发工具？(y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && DEPLOY_DEVTOOLS=true || DEPLOY_DEVTOOLS=false
    read -p "部署安全服务？(y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && DEPLOY_SECURITY=true || DEPLOY_SECURITY=false
    read -p "部署微服务架构？(y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && DEPLOY_MICROSERVICES=true || DEPLOY_MICROSERVICES=false
    read -p "部署企业集成？(y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && DEPLOY_ENTERPRISE=true || DEPLOY_ENTERPRISE=false
    read -p "部署协作工具？(y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && DEPLOY_COLLABORATION=true || DEPLOY_COLLABORATION=false
    read -p "部署智能运维？(y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && DEPLOY_INTELLIGENT_OPS=true || DEPLOY_INTELLIGENT_OPS=false
    
    # 执行选定的部署
    step=1
    total_steps=$(( $DEPLOY_CORE + $DEPLOY_AI + $DEPLOY_MONITORING + $DEPLOY_DEVTOOLS + $DEPLOY_SECURITY + $DEPLOY_MICROSERVICES + $DEPLOY_ENTERPRISE + $DEPLOY_COLLABORATION + $DEPLOY_INTELLIGENT_OPS ))
    
    if [ "$DEPLOY_CORE" = true ]; then
        log_step "$step/$total_steps 部署核心服务..."
        "$ROOT_DIR/development/scripts/setup-dev-environment.sh" || handle_error "核心服务部署失败"
        ((step++))
    fi
    
    if [ "$DEPLOY_AI" = true ]; then
        log_step "$step/$total_steps 部署 AI 服务..."
        docker-compose -f "$ROOT_DIR/development/docker-compose/ai-services.yml" up -d || handle_error "AI 服务部署失败"
        ((step++))
    fi
    
    if [ "$DEPLOY_MONITORING" = true ]; then
        log_step "$step/$total_steps 部署监控服务..."
        docker-compose -f "$ROOT_DIR/development/docker-compose/monitoring.yml" up -d || handle_error "监控服务部署失败"
        ((step++))
    fi
    
    if [ "$DEPLOY_DEVTOOLS" = true ]; then
        log_step "$step/$total_steps 部署开发工具..."
        docker-compose -f "$ROOT_DIR/development/docker-compose/v0-dev.yml" up -d || handle_error "开发工具部署失败"
        ((step++))
    fi
    
    if [ "$DEPLOY_SECURITY" = true ]; then
        log_step "$step/$total_steps 部署安全服务..."
        "$ROOT_DIR/development/scripts/security-hardening.sh" || handle_error "安全服务部署失败"
        ((step++))
    fi
    
    if [ "$DEPLOY_MICROSERVICES" = true ]; then
        log_step "$step/$total_steps 部署微服务架构..."
        docker-compose -f "$ROOT_DIR/development/docker-compose/microservices.yml" up -d || handle_error "微服务架构部署失败"
        ((step++))
    fi
    
    if [ "$DEPLOY_ENTERPRISE" = true ]; then
        log_step "$step/$total_steps 部署企业集成..."
        docker-compose -f "$ROOT_DIR/development/docker-compose/enterprise.yml" up -d || handle_error "企业集成部署失败"
        ((step++))
    fi
    
    if [ "$DEPLOY_COLLABORATION" = true ]; then
        log_step "$step/$total_steps 部署协作工具..."
        docker-compose -f "$ROOT_DIR/development/docker-compose/collaboration.yml" up -d || handle_error "协作工具部署失败"
        ((step++))
    fi
    
    if [ "$DEPLOY_INTELLIGENT_OPS" = true ]; then
        log_step "$step/$total_steps 部署智能运维..."
        docker-compose -f "$ROOT_DIR/development/docker-compose/intelligent-ops.yml" up -d || handle_error "智能运维部署失败"
        ((step++))
    fi
    
    log_success "自定义部署完成！"
}

# 错误处理
handle_error() {
    log_error "$1"
    echo ""
    echo "🔧 故障排除建议："
    echo "1. 检查 Docker 服务状态: systemctl status docker"
    echo "2. 检查磁盘空间: df -h"
    echo "3. 检查内存使用: free -h"
    echo "4. 查看详细日志: docker-compose logs"
    echo "5. 重启 Docker 服务: systemctl restart docker"
    echo ""
    read -p "是否继续部署其他组件？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
}

# 等待服务启动
wait_for_services() {
    log_step "等待服务启动并进行健康检查..."
    
    # 关键服务列表
    services=(
        "192.168.3.9:80:主控制台"
        "192.168.3.9:8080:GitLab"
        "192.168.3.9:9000:Portainer"
    )
    
    # 根据部署模式添加服务
    if [ "$DEPLOY_AI" = true ] || [ "$DEPLOYMENT_MODE" != "custom" ]; then
        services+=("192.168.3.9:3000:AI服务")
        services+=("192.168.3.9:11434:Ollama")
    fi
    
    if [ "$DEPLOY_MONITORING" = true ] || [ "$DEPLOYMENT_MODE" != "custom" ]; then
        services+=("192.168.3.9:3002:Grafana")
        services+=("192.168.3.9:9090:Prometheus")
    fi
    
    echo ""
    log_info "检查服务启动状态..."
    
    for service in "${services[@]}"; do
        IFS=':' read -r host port name <<< "$service"
        echo -n "等待 $name 启动..."
        
        for i in {1..30}; do
            if curl -s --connect-timeout 3 "http://$host:$port" > /dev/null 2>&1; then
                echo " ✅"
                break
            fi
            echo -n "."
            sleep 5
        done
        
        if [ $i -eq 30 ]; then
            echo " ⚠️ 超时"
            log_warning "$name 启动超时，请稍后手动检查"
        fi
    done
}

# 生成部署报告
generate_deployment_report() {
    log_step "生成部署报告..."
    
    REPORT_FILE="$ROOT_DIR/shared/complete_deployment_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOF
YC 全栈开发环境部署报告
========================
部署时间: $(date)
部署模式: $DEPLOYMENT_MODE
服务器IP: $NAS_IP
安装目录: $ROOT_DIR

系统信息:
- 操作系统: $(uname -a)
- Docker 版本: $(docker --version)
- Docker Compose 版本: $(docker-compose --version)
- 可用内存: $(free -h | grep Mem | awk '{print $7}')
- 可用磁盘: $(df -h /volume1 | tail -1 | awk '{print $4}')

部署的服务:
$(docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep yc-)

服务访问地址:
- 🏠 主控制台: https://$NAS_IP
- 🐙 GitLab: https://$NAS_IP:8080
- 🐳 Portainer: https://$NAS_IP:9000
- 🤖 AI 服务: https://$NAS_IP:3000
- 💻 Code Server: https://$NAS_IP:8443
- 📊 Grafana: https://$NAS_IP:3002
- 🔍 Prometheus: https://$NAS_IP:9090
- 🔐 访问控制: https://$NAS_IP:3004
- 🛡️ 安全监控: https://$NAS_IP:3005

管理工具:
- 🎛️ 开发环境管理: $ROOT_DIR/development/scripts/dev-manager.sh
- ⚡ 性能优化: $ROOT_DIR/development/scripts/performance-optimizer.sh
- 💾 备份管理: $ROOT_DIR/development/scripts/advanced-backup.sh
- 🏥 健康检查: $ROOT_DIR/development/scripts/health-check.sh
- 🏢 企业管理: $ROOT_DIR/development/scripts/enterprise-manager.sh

默认账户信息:
- 系统管理员: admin / admin123
- GitLab root: 首次访问时设置
- Portainer: 首次访问时设置
- Grafana: admin / admin123

重要文件位置:
- 项目代码: $ROOT_DIR/development/projects/
- 配置文件: $ROOT_DIR/services/
- 备份文件: $ROOT_DIR/shared/backups/
- 日志文件: $ROOT_DIR/shared/logs/
- SSL 证书: $ROOT_DIR/services/ssl/

下一步操作:
1. 访问主控制台: https://$NAS_IP
2. 配置 GitLab 管理员密码
3. 在 Mac 上运行客户端集成脚本
4. 创建第一个项目
5. 设置自动备份计划

技术支持:
- 健康检查: $ROOT_DIR/development/scripts/health-check.sh
- 故障排除: 查看 Docker 日志
- 性能优化: 运行性能优化脚本
- 备份恢复: 使用备份管理工具

部署完成！🎉
感谢使用 YC 全栈开发环境！
EOF

    log_success "部署报告生成完成: $REPORT_FILE"
}

# 显示完成信息
show_completion_info() {
    clear
    echo -e "${GREEN}"
    cat << 'EOF'
    ✅ 部署完成！
    ===============
    
    🎉 恭喜！YC 全栈开发环境已成功部署！
    
EOF
    echo -e "${NC}"
    
    echo -e "${CYAN}🌐 主要访问地址：${NC}"
    echo "• 主控制台: https://$NAS_IP"
    echo "• GitLab: https://$NAS_IP:8080"
    echo "• AI 服务: https://$NAS_IP:3000"
    echo "• Code Server: https://$NAS_IP:8443"
    echo "• 监控面板: https://$NAS_IP:3002"
    echo ""
    
    echo -e "${CYAN}🛠️ 管理工具：${NC}"
    echo "• 开发环境管理: $ROOT_DIR/development/scripts/dev-manager.sh"
    echo "• 健康检查: $ROOT_DIR/development/scripts/health-check.sh"
    echo "• 性能优化: $ROOT_DIR/development/scripts/performance-optimizer.sh"
    echo ""
    
    echo -e "${CYAN}📚 下一步：${NC}"
    echo "1. 🌐 访问主控制台配置服务"
    echo "2. 🍎 在 Mac 上运行集成脚本"
    echo "3. 🚀 创建第一个项目"
    echo "4. 👥 配置团队协作工具"
    echo ""
    
    echo -e "${YELLOW}💡 提示：${NC}"
    echo "• 运行健康检查确保所有服务正常"
    echo "• 查看部署报告了解详细信息"
    echo "• 定期运行备份脚本保护数据"
    echo ""
    
    read -p "是否立即运行健康检查？(Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        "$ROOT_DIR/development/scripts/health-check.sh"
    fi
    
    echo ""
    echo -e "${GREEN}🎊 部署成功完成！欢迎使用 YC 全栈开发环境！${NC}"
}

# 主函数
main() {
    show_welcome
    check_system_requirements
    show_deployment_options
    execute_deployment
    wait_for_services
    generate_deployment_report
    show_completion_info
}

# 执行主函数
main "$@"
