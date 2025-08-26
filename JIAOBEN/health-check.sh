#!/bin/bash

# YC 开发环境健康检查脚本

ROOT_DIR="/volume1/YC"
NAS_IP="192.168.3.9"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[信息]${NC} $1"; }
log_success() { echo -e "${GREEN}[成功]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
log_error() { echo -e "${RED}[错误]${NC} $1"; }

# 健康检查结果
HEALTH_REPORT="$ROOT_DIR/shared/health_check_$(date +%Y%m%d_%H%M%S).txt"

echo "🏥 YC 开发环境健康检查" | tee "$HEALTH_REPORT"
echo "======================" | tee -a "$HEALTH_REPORT"
echo "检查时间: $(date)" | tee -a "$HEALTH_REPORT"
echo "" | tee -a "$HEALTH_REPORT"

# 检查系统资源
check_system_resources() {
    echo "💻 系统资源检查" | tee -a "$HEALTH_REPORT"
    echo "---------------" | tee -a "$HEALTH_REPORT"
    
    # CPU 使用率
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d'%' -f1)
    if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
        log_warning "CPU 使用率过高: ${CPU_USAGE}%" | tee -a "$HEALTH_REPORT"
    else
        log_success "CPU 使用率正常: ${CPU_USAGE}%" | tee -a "$HEALTH_REPORT"
    fi
    
    # 内存使用率
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    if (( $(echo "$MEMORY_USAGE > 85" | bc -l) )); then
        log_warning "内存使用率过高: ${MEMORY_USAGE}%" | tee -a "$HEALTH_REPORT"
    else
        log_success "内存使用率正常: ${MEMORY_USAGE}%" | tee -a "$HEALTH_REPORT"
    fi
    
    # 磁盘使用率
    DISK_USAGE=$(df /volume1 | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 85 ]; then
        log_warning "磁盘使用率过高: ${DISK_USAGE}%" | tee -a "$HEALTH_REPORT"
    else
        log_success "磁盘使用率正常: ${DISK_USAGE}%" | tee -a "$HEALTH_REPORT"
    fi
    
    echo "" | tee -a "$HEALTH_REPORT"
}

# 检查 Docker 服务
check_docker_services() {
    echo "🐳 Docker 服务检查" | tee -a "$HEALTH_REPORT"
    echo "------------------" | tee -a "$HEALTH_REPORT"
    
    # 检查 Docker 守护进程
    if systemctl is-active --quiet docker; then
        log_success "Docker 守护进程运行正常" | tee -a "$HEALTH_REPORT"
    else
        log_error "Docker 守护进程未运行" | tee -a "$HEALTH_REPORT"
    fi
    
    # 检查容器状态
    TOTAL_CONTAINERS=$(docker ps -a | wc -l)
    RUNNING_CONTAINERS=$(docker ps | wc -l)
    FAILED_CONTAINERS=$(docker ps -a --filter "status=exited" --filter "status=dead" | wc -l)
    
    echo "总容器数: $((TOTAL_CONTAINERS-1))" | tee -a "$HEALTH_REPORT"
    echo "运行中: $((RUNNING_CONTAINERS-1))" | tee -a "$HEALTH_REPORT"
    echo "异常容器: $((FAILED_CONTAINERS-1))" | tee -a "$HEALTH_REPORT"
    
    if [ "$FAILED_CONTAINERS" -gt 1 ]; then
        log_warning "发现异常容器" | tee -a "$HEALTH_REPORT"
        docker ps -a --filter "status=exited" --filter "status=dead" --format "table {{.Names}}\t{{.Status}}" | tee -a "$HEALTH_REPORT"
    fi
    
    echo "" | tee -a "$HEALTH_REPORT"
}

# 检查网络连通性
check_network_connectivity() {
    echo "🌐 网络连通性检查" | tee -a "$HEALTH_REPORT"
    echo "----------------" | tee -a "$HEALTH_REPORT"
    
    services=(
        "80:主控制台"
        "8080:GitLab"
        "9000:Portainer"
        "3000:AI服务"
        "8443:Code Server"
        "3002:监控面板"
        "11434:Ollama API"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r port name <<< "$service"
        if curl -s --connect-timeout 5 "http://192.168.3.9:$port" > /dev/null; then
            log_success "$name (端口 $port) 可访问" | tee -a "$HEALTH_REPORT"
        else
            log_error "$name (端口 $port) 不可访问" | tee -a "$HEALTH_REPORT"
        fi
    done
    
    echo "" | tee -a "$HEALTH_REPORT"
}

# 检查数据库状态
check_database_status() {
    echo "🗄️ 数据库状态检查" | tee -a "$HEALTH_REPORT"
    echo "----------------" | tee -a "$HEALTH_REPORT"
    
    # PostgreSQL
    if docker ps | grep -q yc-postgres; then
        if docker exec yc-postgres pg_isready -U yc_admin > /dev/null 2>&1; then
            log_success "PostgreSQL 运行正常" | tee -a "$HEALTH_REPORT"
        else
            log_error "PostgreSQL 连接失败" | tee -a "$HEALTH_REPORT"
        fi
    else
        log_warning "PostgreSQL 容器未运行" | tee -a "$HEALTH_REPORT"
    fi
    
    # Redis
    if docker ps | grep -q yc-redis; then
        if docker exec yc-redis redis-cli ping | grep -q PONG; then
            log_success "Redis 运行正常" | tee -a "$HEALTH_REPORT"
        else
            log_error "Redis 连接失败" | tee -a "$HEALTH_REPORT"
        fi
    else
        log_warning "Redis 容器未运行" | tee -a "$HEALTH_REPORT"
    fi
    
    echo "" | tee -a "$HEALTH_REPORT"
}

# 检查 AI 服务状态
check_ai_services() {
    echo "🤖 AI 服务状态检查" | tee -a "$HEALTH_REPORT"
    echo "-----------------" | tee -a "$HEALTH_REPORT"
    
    if docker ps | grep -q yc-ollama; then
        if curl -s "http://192.168.3.9:11434/api/tags" > /dev/null; then
            MODEL_COUNT=$(curl -s "http://192.168.3.9:11434/api/tags" | jq '.models | length' 2>/dev/null || echo "0")
            log_success "Ollama 服务运行正常，已加载 $MODEL_COUNT 个模型" | tee -a "$HEALTH_REPORT"
        else
            log_error "Ollama API 不可访问" | tee -a "$HEALTH_REPORT"
        fi
    else
        log_warning "Ollama 容器未运行" | tee -a "$HEALTH_REPORT"
    fi
    
    echo "" | tee -a "$HEALTH_REPORT"
}

# 检查备份状态
check_backup_status() {
    echo "💾 备份状态检查" | tee -a "$HEALTH_REPORT"
    echo "--------------" | tee -a "$HEALTH_REPORT"
    
    BACKUP_DIR="$ROOT_DIR/shared/backups/daily"
    if [ -d "$BACKUP_DIR" ]; then
        LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            BACKUP_AGE=$(find "$BACKUP_DIR" -name "$LATEST_BACKUP" -mtime +1)
            if [ -z "$BACKUP_AGE" ]; then
                log_success "最新备份: $LATEST_BACKUP (24小时内)" | tee -a "$HEALTH_REPORT"
            else
                log_warning "最新备份: $LATEST_BACKUP (超过24小时)" | tee -a "$HEALTH_REPORT"
            fi
        else
            log_error "未找到备份文件" | tee -a "$HEALTH_REPORT"
        fi
    else
        log_error "备份目录不存在" | tee -a "$HEALTH_REPORT"
    fi
    
    # 检查 cron 任务
    if crontab -l | grep -q backup; then
        log_success "自动备份任务已配置" | tee -a "$HEALTH_REPORT"
    else
        log_warning "未配置自动备份任务" | tee -a "$HEALTH_REPORT"
    fi
    
    echo "" | tee -a "$HEALTH_REPORT"
}

# 检查安全状态
check_security_status() {
    echo "🔒 安全状态检查" | tee -a "$HEALTH_REPORT"
    echo "--------------" | tee -a "$HEALTH_REPORT"
    
    # 检查 SSL 证书
    if [ -f "$ROOT_DIR/services/ssl/server-cert.pem" ]; then
        CERT_EXPIRY=$(openssl x509 -in "$ROOT_DIR/services/ssl/server-cert.pem" -noout -enddate | cut -d= -f2)
        DAYS_TO_EXPIRY=$(( ($(date -d "$CERT_EXPIRY" +%s) - $(date +%s)) / 86400 ))
        
        if [ "$DAYS_TO_EXPIRY" -gt 30 ]; then
            log_success "SSL 证书有效，$DAYS_TO_EXPIRY 天后过期" | tee -a "$HEALTH_REPORT"
        else
            log_warning "SSL 证书即将过期，$DAYS_TO_EXPIRY 天后过期" | tee -a "$HEALTH_REPORT"
        fi
    else
        log_error "SSL 证书文件不存在" | tee -a "$HEALTH_REPORT"
    fi
    
    # 检查防火墙状态
    if command -v ufw > /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_success "防火墙已启用" | tee -a "$HEALTH_REPORT"
        else
            log_warning "防火墙未启用" | tee -a "$HEALTH_REPORT"
        fi
    fi
    
    echo "" | tee -a "$HEALTH_REPORT"
}

# 生成健康评分
generate_health_score() {
    echo "📊 健康评分" | tee -a "$HEALTH_REPORT"
    echo "----------" | tee -a "$HEALTH_REPORT"
    
    # 统计成功、警告、错误数量
    SUCCESS_COUNT=$(grep -c "成功" "$HEALTH_REPORT" || echo 0)
    WARNING_COUNT=$(grep -c "警告" "$HEALTH_REPORT" || echo 0)
    ERROR_COUNT=$(grep -c "错误" "$HEALTH_REPORT" || echo 0)
    
    TOTAL_CHECKS=$((SUCCESS_COUNT + WARNING_COUNT + ERROR_COUNT))
    
    if [ "$TOTAL_CHECKS" -gt 0 ]; then
        HEALTH_SCORE=$(( (SUCCESS_COUNT * 100) / TOTAL_CHECKS ))
        
        echo "检查项目总数: $TOTAL_CHECKS" | tee -a "$HEALTH_REPORT"
        echo "成功: $SUCCESS_COUNT" | tee -a "$HEALTH_REPORT"
        echo "警告: $WARNING_COUNT" | tee -a "$HEALTH_REPORT"
        echo "错误: $ERROR_COUNT" | tee -a "$HEALTH_REPORT"
        echo "" | tee -a "$HEALTH_REPORT"
        
        if [ "$HEALTH_SCORE" -ge 90 ]; then
            echo "🟢 系统健康状态: 优秀 ($HEALTH_SCORE%)" | tee -a "$HEALTH_REPORT"
        elif [ "$HEALTH_SCORE" -ge 75 ]; then
            echo "🟡 系统健康状态: 良好 ($HEALTH_SCORE%)" | tee -a "$HEALTH_REPORT"
        elif [ "$HEALTH_SCORE" -ge 60 ]; then
            echo "🟠 系统健康状态: 一般 ($HEALTH_SCORE%)" | tee -a "$HEALTH_REPORT"
        else
            echo "🔴 系统健康状态: 需要关注 ($HEALTH_SCORE%)" | tee -a "$HEALTH_REPORT"
        fi
    fi
    
    echo "" | tee -a "$HEALTH_REPORT"
}

# 生成修复建议
generate_recommendations() {
    echo "💡 修复建议" | tee -a "$HEALTH_REPORT"
    echo "----------" | tee -a "$HEALTH_REPORT"
    
    if grep -q "CPU 使用率过高" "$HEALTH_REPORT"; then
        echo "• 运行性能优化脚本: $ROOT_DIR/development/scripts/performance-optimizer.sh" | tee -a "$HEALTH_REPORT"
    fi
    
    if grep -q "内存使用率过高" "$HEALTH_REPORT"; then
        echo "• 重启高内存占用的容器" | tee -a "$HEALTH_REPORT"
        echo "• 检查内存泄漏问题" | tee -a "$HEALTH_REPORT"
    fi
    
    if grep -q "磁盘使用率过高" "$HEALTH_REPORT"; then
        echo "• 清理旧备份文件" | tee -a "$HEALTH_REPORT"
        echo "• 运行 Docker 清理: docker system prune -f" | tee -a "$HEALTH_REPORT"
    fi
    
    if grep -q "异常容器" "$HEALTH_REPORT"; then
        echo "• 重启异常容器: docker restart <容器名>" | tee -a "$HEALTH_REPORT"
        echo "• 查看容器日志: docker logs <容器名>" | tee -a "$HEALTH_REPORT"
    fi
    
    if grep -q "不可访问" "$HEALTH_REPORT"; then
        echo "• 检查服务配置和网络连接" | tee -a "$HEALTH_REPORT"
        echo "• 重启相关服务" | tee -a "$HEALTH_REPORT"
    fi
    
    if grep -q "未配置自动备份" "$HEALTH_REPORT"; then
        echo "• 设置自动备份: $ROOT_DIR/development/scripts/backup-scheduler.sh setup" | tee -a "$HEALTH_REPORT"
    fi
    
    echo "" | tee -a "$HEALTH_REPORT"
}

# 主函数
main() {
    check_system_resources
    check_docker_services
    check_network_connectivity
    check_database_status
    check_ai_services
    check_backup_status
    check_security_status
    generate_health_score
    generate_recommendations
    
    echo "✅ 健康检查完成！"
    echo "📋 详细报告: $HEALTH_REPORT"
    echo ""
    echo "💡 建议定期运行此脚本以监控系统健康状态"
}

# 执行健康检查
main "$@"
