#!/bin/bash

# YYC³ 最终部署检查脚本
# 执行部署前的全面系统检查

set -e

ROOT_DIR="/volume2/YC"
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

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ██╗   ██╗██╗   ██╗ ██████╗██████╗     ███████╗██╗███╗   ██╗ █████╗ ██╗     
    ╚██╗ ██╔╝╚██╗ ██╔╝██╔════╝╚════██╗    ██╔════╝██║████╗  ██║██╔══██╗██║     
     ╚████╔╝  ╚████╔╝ ██║      █████╔╝    █████╗  ██║██╔██╗ ██║███████║██║     
      ╚██╔╝    ╚██╔╝  ██║      ╚═══██╗    ██╔══╝  ██║██║╚██╗██║██╔══██║██║     
       ██║      ██║   ╚██████╗██████╔╝    ██║     ██║██║ ╚████║██║  ██║███████╗
       ╚═╝      ╚═╝    ╚═════╝╚═════╝     ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝
                                                                                
    YYC³ 最终部署检查
    Final Deployment Check
    ======================
EOF
    echo -e "${NC}"
    echo ""
    echo "🔍 执行部署前的全面系统检查"
    echo "📅 检查时间: $(date)"
    echo "🌐 目标服务器: $NAS_IP"
    echo "📁 根目录: $ROOT_DIR"
    echo ""
}

# 检查系统环境
check_system_environment() {
    log_step "检查系统环境..."
    
    # 检查操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "操作系统: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log_success "操作系统: macOS"
    else
        log_warning "操作系统: $OSTYPE (可能需要调整脚本)"
    fi
    
    # 检查 Docker
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        log_success "Docker 版本: $DOCKER_VERSION"
        
        # 检查 Docker 服务状态
        if docker info &> /dev/null; then
            log_success "Docker 服务运行正常"
        else
            log_error "Docker 服务未运行，请启动 Docker"
            return 1
        fi
    else
        log_error "Docker 未安装，请先安装 Docker"
        return 1
    fi
    
    # 检查 Docker Compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        log_success "Docker Compose 版本: $COMPOSE_VERSION"
    else
        log_error "Docker Compose 未安装"
        return 1
    fi
    
    # 检查网络连接
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_success "网络连接正常"
    else
        log_warning "网络连接可能有问题"
    fi
    
    # 检查磁盘空间
    DISK_USAGE=$(df -h "$ROOT_DIR" 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
    if [ "$DISK_USAGE" -lt 80 ]; then
        log_success "磁盘空间充足 (已使用: ${DISK_USAGE}%)"
    else
        log_warning "磁盘空间不足 (已使用: ${DISK_USAGE}%)"
    fi
    
    # 检查内存
    if command -v free &> /dev/null; then
        MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
        if [ "$MEMORY_USAGE" -lt 80 ]; then
            log_success "内存使用正常 (已使用: ${MEMORY_USAGE}%)"
        else
            log_warning "内存使用率较高 (已使用: ${MEMORY_USAGE}%)"
        fi
    fi
}

# 检查目录结构
check_directory_structure() {
    log_step "检查目录结构..."
    
    local required_dirs=(
        "$ROOT_DIR"
        "$ROOT_DIR/scripts"
        "$ROOT_DIR/configs"
        "$ROOT_DIR/docs"
        "$ROOT_DIR/services"
        "$ROOT_DIR/gitlab"
        "$ROOT_DIR/ai-models"
        "$ROOT_DIR/monitoring"
        "$ROOT_DIR/backups"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_success "目录存在: $dir"
        else
            log_warning "目录不存在: $dir"
            mkdir -p "$dir"
            log_info "已创建目录: $dir"
        fi
    done
}

# 检查脚本文件
check_script_files() {
    log_step "检查脚本文件..."
    
    local required_scripts=(
        "advanced-setup.sh"
        "mac-integration.sh"
        "security-hardening.sh"
        "health-check.sh"
        "microservices-setup.sh"
        "complete-deployment.sh"
        "network-penetration.sh"
        "local-server-penetration.sh"
        "frp-beginner-setup.sh"
        "frp-troubleshooting.sh"
        "storage-optimized-setup.sh"
        "yyc3-devkit-setup.sh"
        "yyc3-management-dashboard.sh"
        "gitlab-integration.sh"
        "ai-model-optimizer.sh"
        "monitoring-alerts.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        local script_path="$ROOT_DIR/scripts/$script"
        if [ -f "$script_path" ]; then
            if [ -x "$script_path" ]; then
                log_success "脚本可执行: $script"
            else
                log_warning "脚本不可执行: $script"
                chmod +x "$script_path"
                log_info "已设置执行权限: $script"
            fi
        else
            log_error "脚本不存在: $script"
        fi
    done
}

# 检查配置文件
check_config_files() {
    log_step "检查配置文件..."
    
    local config_files=(
        "configs/vscode-workspace.json"
        "services/frp-beginner/frps.ini"
        "services/frp-beginner/frpc.ini"
    )
    
    for config in "${config_files[@]}"; do
        local config_path="$ROOT_DIR/$config"
        if [ -f "$config_path" ]; then
            log_success "配置文件存在: $config"
        else
            log_warning "配置文件不存在: $config"
        fi
    done
}

# 检查 Docker 网络
check_docker_network() {
    log_step "检查 Docker 网络..."
    
    if docker network ls | grep -q "yyc3-network"; then
        log_success "Docker 网络 yyc3-network 已存在"
    else
        log_info "创建 Docker 网络 yyc3-network"
        docker network create yyc3-network
        log_success "Docker 网络创建完成"
    fi
}

# 检查端口占用
check_port_usage() {
    log_step "检查端口占用情况..."
    
    local required_ports=(
        "3001:YYC³ 管理面板"
        "4873:NPM 私有仓库"
        "8080:GitLab"
        "8888:AI 路由器"
        "9090:Prometheus"
        "3000:Grafana"
        "9093:AlertManager"
        "11434:Ollama 1"
        "11435:Ollama 2"
        "6380:Redis"
    )
    
    for port_info in "${required_ports[@]}"; do
        local port=$(echo "$port_info" | cut -d':' -f1)
        local service=$(echo "$port_info" | cut -d':' -f2)
        
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            log_warning "端口 $port 已被占用 ($service)"
        else
            log_success "端口 $port 可用 ($service)"
        fi
    done
}

# 检查环境变量
check_environment_variables() {
    log_step "检查环境变量..."
    
    local required_vars=(
        "YYC3_REGISTRY"
        "NEXT_PUBLIC_BASE_URL"
        "PORT"
        "JWT_SECRET"
        "MONITORING_ENDPOINT"
        "ALERT_WEBHOOK"
        "WECHAT_WEBHOOK_URL"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -n "${!var}" ]; then
            log_success "环境变量已设置: $var"
        else
            log_warning "环境变量未设置: $var"
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_highlight "需要设置的环境变量:"
        for var in "${missing_vars[@]}"; do
            case $var in
                "YYC3_REGISTRY")
                    echo "  export YYC3_REGISTRY=http://192.168.3.45:4873"
                    ;;
                "NEXT_PUBLIC_BASE_URL")
                    echo "  export NEXT_PUBLIC_BASE_URL=http://192.168.3.45:3001"
                    ;;
                "PORT")
                    echo "  export PORT=3001"
                    ;;
                "JWT_SECRET")
                    echo "  export JWT_SECRET=$(openssl rand -base64 32)"
                    ;;
                "MONITORING_ENDPOINT")
                    echo "  export MONITORING_ENDPOINT=http://192.168.3.45:9090"
                    ;;
                "ALERT_WEBHOOK")
                    echo "  export ALERT_WEBHOOK=http://192.168.3.45:9093"
                    ;;
                "WECHAT_WEBHOOK_URL")
                    echo "  export WECHAT_WEBHOOK_URL=your-wechat-webhook-url"
                    ;;
            esac
        done
    fi
}

# 检查依赖工具
check_dependencies() {
    log_step "检查依赖工具..."
    
    local tools=(
        "curl:HTTP 客户端"
        "jq:JSON 处理工具"
        "git:版本控制"
        "openssl:加密工具"
        "bc:计算器"
    )
    
    for tool_info in "${tools[@]}"; do
        local tool=$(echo "$tool_info" | cut -d':' -f1)
        local desc=$(echo "$tool_info" | cut -d':' -f2)
        
        if command -v "$tool" &> /dev/null; then
            log_success "$desc ($tool) 已安装"
        else
            log_warning "$desc ($tool) 未安装"
            
            # 提供安装建议
            case $tool in
                "jq")
                    echo "  安装命令: sudo apt-get install jq (Ubuntu/Debian) 或 brew install jq (macOS)"
                    ;;
                "bc")
                    echo "  安装命令: sudo apt-get install bc (Ubuntu/Debian) 或 brew install bc (macOS)"
                    ;;
                *)
                    echo "  请安装 $tool"
                    ;;
            esac
        fi
    done
}

# 生成部署报告
generate_deployment_report() {
    log_step "生成部署报告..."
    
    local report_file="$ROOT_DIR/deployment-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# YYC³ 部署前检查报告

**生成时间**: $(date)
**检查版本**: YYC³ v1.0.0
**目标环境**: $NAS_IP

## 系统环境

- **操作系统**: $(uname -s) $(uname -r)
- **Docker 版本**: $(docker --version 2>/dev/null || echo "未安装")
- **Docker Compose 版本**: $(docker-compose --version 2>/dev/null || echo "未安装")
- **磁盘使用率**: $(df -h "$ROOT_DIR" 2>/dev/null | awk 'NR==2 {print $5}' || echo "未知")
- **内存使用率**: $(free 2>/dev/null | grep Mem | awk '{printf("%.0f%%", $3/$2 * 100.0)}' || echo "未知")

## 服务端口分配

| 端口 | 服务 | 状态 |
|------|------|------|
| 3001 | YYC³ 管理面板 | $(netstat -tuln 2>/dev/null | grep -q ":3001 " && echo "占用" || echo "可用") |
| 4873 | NPM 私有仓库 | $(netstat -tuln 2>/dev/null | grep -q ":4873 " && echo "占用" || echo "可用") |
| 8080 | GitLab | $(netstat -tuln 2>/dev/null | grep -q ":8080 " && echo "占用" || echo "可用") |
| 8888 | AI 路由器 | $(netstat -tuln 2>/dev/null | grep -q ":8888 " && echo "占用" || echo "可用") |
| 9090 | Prometheus | $(netstat -tuln 2>/dev/null | grep -q ":9090 " && echo "占用" || echo "可用") |
| 3000 | Grafana | $(netstat -tuln 2>/dev/null | grep -q ":3000 " && echo "占用" || echo "可用") |

## 目录结构

\`\`\`
$ROOT_DIR/
├── scripts/           # 部署脚本
├── configs/           # 配置文件
├── docs/             # 文档
├── services/         # 服务配置
├── gitlab/           # GitLab 数据
├── ai-models/        # AI 模型
├── monitoring/       # 监控配置
└── backups/          # 备份数据
\`\`\`

## 环境变量检查

$(for var in YYC3_REGISTRY NEXT_PUBLIC_BASE_URL PORT JWT_SECRET; do
    if [ -n "${!var}" ]; then
        echo "- ✅ $var: 已设置"
    else
        echo "- ❌ $var: 未设置"
    fi
done)

## 建议的部署顺序

1. 设置环境变量
2. 执行基础设置脚本
3. 部署核心服务
4. 配置 AI 服务
5. 启动监控系统
6. 验证服务状态

---

**报告生成时间**: $(date)
EOF

    log_success "部署报告已生成: $report_file"
}

# 主执行函数
main() {
    show_welcome
    
    local check_passed=true
    
    # 执行各项检查
    check_system_environment || check_passed=false
    check_directory_structure
    check_script_files
    check_config_files
    check_docker_network
    check_port_usage
    check_environment_variables
    check_dependencies
    
    # 生成报告
    generate_deployment_report
    
    echo ""
    if [ "$check_passed" = true ]; then
        log_success "🎉 系统检查完成，可以开始部署！"
        echo ""
        log_highlight "📋 建议的部署步骤:"
        echo "  1. 设置环境变量 (如果有未设置的)"
        echo "  2. 运行 ./scripts/advanced-setup.sh"
        echo "  3. 运行 ./scripts/gitlab-integration.sh"
        echo "  4. 运行 ./scripts/ai-model-optimizer.sh"
        echo "  5. 运行 ./scripts/monitoring-alerts.sh"
        echo "  6. 运行 ./scripts/health-check.sh"
    else
        log_error "❌ 系统检查发现问题，请先解决后再部署"
    fi
    
    echo ""
    log_highlight "🔧 快速命令:"
    echo "  • 查看详细报告: cat $ROOT_DIR/deployment-report-*.md"
    echo "  • 设置环境变量: source $ROOT_DIR/scripts/set-env.sh"
    echo "  • 开始部署: $ROOT_DIR/scripts/advanced-setup.sh"
    echo ""
}

# 执行主函数
main "$@"
