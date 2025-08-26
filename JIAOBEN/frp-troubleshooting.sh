#!/bin/bash

# FRP 故障排除脚本

echo "🔧 FRP 故障排除工具"
echo "=================="

check_frp_status() {
    echo "📊 检查 FRP 状态..."
    
    # 检查客户端容器
    if docker ps | grep -q "frp-client"; then
        echo "✅ FRP 客户端容器运行中"
    else
        echo "❌ FRP 客户端容器未运行"
        echo "💡 解决方案: docker-compose up -d"
    fi
    
    # 检查日志
    echo ""
    echo "📋 最近日志："
    docker logs --tail 10 frp-client 2>/dev/null || echo "无法获取日志"
}

test_connection() {
    echo ""
    echo "🌐 测试连接..."
    
    read -p "请输入您的域名 (如: yc.yourdomain.com): " DOMAIN
    
    if curl -s --connect-timeout 5 "http://$DOMAIN" > /dev/null; then
        echo "✅ 连接成功！"
    else
        echo "❌ 连接失败"
        echo ""
        echo "🔍 可能的原因："
        echo "1. 服务端未启动"
        echo "2. 域名解析错误"
        echo "3. 防火墙阻止"
        echo "4. 配置文件错误"
    fi
}

show_common_issues() {
    echo ""
    echo "❓ 常见问题解决方案："
    echo "==================="
    echo ""
    echo "1. 🔌 连接被拒绝"
    echo "   • 检查服务端是否启动"
    echo "   • 检查端口 7000 是否开放"
    echo "   • 验证 token 是否一致"
    echo ""
    echo "2. 🌐 域名无法访问"
    echo "   • 检查域名解析是否正确"
    echo "   • 确认 A 记录指向服务器 IP"
    echo "   • 等待 DNS 生效 (最多24小时)"
    echo ""
    echo "3. 🔥 防火墙问题"
    echo "   • 阿里云安全组开放端口"
    echo "   • 服务器防火墙开放端口"
    echo "   • 检查 iptables 规则"
    echo ""
    echo "4. 📝 配置文件错误"
    echo "   • 检查 INI 文件格式"
    echo "   • 验证 IP 地址和端口"
    echo "   • 确认服务名称唯一"
}

# 主菜单
while true; do
    echo ""
    echo "请选择操作："
    echo "1. 检查 FRP 状态"
    echo "2. 测试连接"
    echo "3. 查看常见问题"
    echo "0. 退出"
    
    read -p "选择 (0-3): " choice
    
    case $choice in
        1) check_frp_status ;;
        2) test_connection ;;
        3) show_common_issues ;;
        0) echo "👋 再见！"; exit 0 ;;
        *) echo "❌ 无效选择" ;;
    esac
done
