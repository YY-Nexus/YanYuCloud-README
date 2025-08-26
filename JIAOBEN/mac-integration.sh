#!/bin/bash

# Mac 客户端集成脚本
# 在 Mac 上运行此脚本以配置开发环境

NAS_IP="192.168.3.45"
LOCAL_DEV_DIR="$HOME/YC-Dev"

echo "🍎 配置 Mac 开发环境集成"
echo "========================"

# 创建本地开发目录
mkdir -p "$LOCAL_DEV_DIR"/{projects,scripts,configs}

# 创建连接脚本
cat > "$LOCAL_DEV_DIR/scripts/connect-nas.sh" << 'EOF'
#!/bin/bash

# 连接到 NAS 开发环境

NAS_IP="192.168.3.45"

echo "🔗 连接到 YC NAS 开发环境..."

# 挂载 NAS 共享
if ! mount | grep -q "/Volumes/YC"; then
    echo "📁 挂载 NAS 共享..."
    mkdir -p /Volumes/YC
    mount -t smbfs //admin@$NAS_IP/YC /Volumes/YC
fi

# 检查服务状态
echo "🔍 检查服务状态..."
services=(
    "主控制台:80"
    "GitLab:8080"
    "AI服务:3000"
    "Code Server:8443"
    "监控面板:3002"
)

for service in "${services[@]}"; do
    name=$(echo $service | cut -d: -f1)
    port=$(echo $service | cut -d: -f2)
    if curl -s --connect-timeout 3 "http://$NAS_IP:$port" > /dev/null; then
        echo "✅ $name - 在线"
    else
        echo "❌ $name - 离线"
    fi
done

echo ""
echo "🌐 服务访问地址："
echo "• 主控制台: http://$NAS_IP"
echo "• GitLab: http://$NAS_IP:8080"
echo "• AI 服务: http://$NAS_IP:3000"
echo "• Code Server: http://$NAS_IP:8443"
echo "• 监控面板: http://$NAS_IP:3002"
EOF

chmod +x "$LOCAL_DEV_DIR/scripts/connect-nas.sh"

# 创建 VS Code 配置
cat > "$LOCAL_DEV_DIR/configs/vscode-settings.json" << 'EOF'
{
    "remote.SSH.remotePlatform": {
        "192.168.3.45": "linux"
    },
    "remote.SSH.configFile": "~/.ssh/config",
    "git.defaultCloneDirectory": "/Volumes/YC/development/projects",
    "terminal.integrated.defaultProfile.osx": "zsh",
    "workbench.startupEditor": "none",
    "extensions.autoUpdate": false,
    "telemetry.telemetryLevel": "off"
}
EOF

# 创建 SSH 配置
cat > "$LOCAL_DEV_DIR/configs/ssh-config" << 'EOF'
Host yc-nas
    HostName 192.168.3.45
    User admin
    Port 22
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

# 创建开发工具快捷脚本
cat > "$LOCAL_DEV_DIR/scripts/dev-tools.sh" << 'EOF'
#!/bin/bash

# Mac 开发工具集

NAS_IP="192.168.3.45"

case "$1" in
    "connect")
        echo "🔗 连接到 NAS..."
        ./connect-nas.sh
        ;;
    "code")
        echo "💻 打开 Code Server..."
        open "http://$NAS_IP:8443"
        ;;
    "git")
        echo "🐙 打开 GitLab..."
        open "http://$NAS_IP:8080"
        ;;
    "ai")
        echo "🤖 打开 AI 服务..."
        open "http://$NAS_IP:3000"
        ;;
    "monitor")
        echo "📊 打开监控面板..."
        open "http://$NAS_IP:3002"
        ;;
    "ssh")
        echo "🔧 SSH 连接到 NAS..."
        ssh admin@$NAS_IP
        ;;
    "sync")
        if [ -z "$2" ]; then
            echo "❌ 请指定项目名称"
            echo "用法: $0 sync <项目名称>"
            exit 1
        fi
        echo "🔄 同步项目: $2"
        rsync -avz --progress "/Volumes/YC/development/projects/$2/" "$HOME/YC-Dev/projects/$2/"
        ;;
    *)
        echo "🛠️ YC Mac 开发工具"
        echo "=================="
        echo "用法: $0 {connect|code|git|ai|monitor|ssh|sync}"
        echo ""
        echo "命令说明："
        echo "  connect - 连接并检查 NAS 服务"
        echo "  code    - 打开 Code Server"
        echo "  git     - 打开 GitLab"
        echo "  ai      - 打开 AI 服务"
        echo "  monitor - 打开监控面板"
        echo "  ssh     - SSH 连接到 NAS"
        echo "  sync    - 同步项目到本地"
        ;;
esac
EOF

chmod +x "$LOCAL_DEV_DIR/scripts/dev-tools.sh"

# 创建 Ollama 本地配置脚本
cat > "$LOCAL_DEV_DIR/scripts/setup-local-ollama.sh" << 'EOF'
#!/bin/bash

# 在 Mac 上设置本地 Ollama 服务

echo "🤖 配置 Mac 本地 Ollama 服务..."

# 检查是否已安装 Ollama
if ! command -v ollama &> /dev/null; then
    echo "📥 安装 Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
fi

# 启动 Ollama 服务
echo "🚀 启动 Ollama 服务..."
ollama serve &

# 等待服务启动
sleep 5

# 拉取轻量级模型到本地
echo "📦 拉取轻量级模型..."
models=("phi3:latest" "qwen2:latest" "codellama:latest")

for model in "${models[@]}"; do
    echo "⬇️ 拉取模型: $model"
    ollama pull "$model"
done

echo "✅ 本地 Ollama 配置完成"
echo "🌐 本地服务地址: http://localhost:11434"

# 创建负载均衡配置
cat > ~/.ollama-config << 'OLLAMA_EOF'
# Ollama 负载均衡配置
PRIMARY_ENDPOINT="http://192.168.3.45:11434"
LOCAL_ENDPOINT="http://localhost:11434"
FALLBACK_ENDPOINTS=("http://192.168.3.45:11434")
OLLAMA_EOF

echo "⚖️ 负载均衡配置已保存到 ~/.ollama-config"
EOF

chmod +x "$LOCAL_DEV_DIR/scripts/setup-local-ollama.sh"

# 添加到 shell 配置
SHELL_CONFIG=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_CONFIG="$HOME/.bash_profile"
fi

if [ -n "$SHELL_CONFIG" ]; then
    echo "" >> "$SHELL_CONFIG"
    echo "# YC 开发环境快捷命令" >> "$SHELL_CONFIG"
    echo "export YC_NAS_IP=\"$NAS_IP\"" >> "$SHELL_CONFIG"
    echo "export YC_DEV_DIR=\"$LOCAL_DEV_DIR\"" >> "$SHELL_CONFIG"
    echo "alias yc-connect=\"$LOCAL_DEV_DIR/scripts/connect-nas.sh\"" >> "$SHELL_CONFIG"
    echo "alias yc-dev=\"$LOCAL_DEV_DIR/scripts/dev-tools.sh\"" >> "$SHELL_CONFIG"
    echo "alias yc-ssh=\"ssh admin@$NAS_IP\"" >> "$SHELL_CONFIG"
    echo "alias yc-mount=\"mount -t smbfs //admin@$NAS_IP/YC /Volumes/YC\"" >> "$SHELL_CONFIG"
    
    echo "✅ 快捷命令已添加到 $SHELL_CONFIG"
    echo "🔄 请运行 'source $SHELL_CONFIG' 或重启终端"
fi

echo ""
echo "🎉 Mac 集成配置完成！"
echo "===================="
echo ""
echo "📋 可用命令："
echo "• yc-connect  - 连接并检查 NAS 服务"
echo "• yc-dev      - 开发工具菜单"
echo "• yc-ssh      - SSH 连接到 NAS"
echo "• yc-mount    - 挂载 NAS 共享"
echo ""
echo "📁 配置文件位置: $LOCAL_DEV_DIR"
echo ""
echo "🚀 下一步："
echo "1. 运行 'yc-connect' 连接到 NAS"
echo "2. 运行 '$LOCAL_DEV_DIR/scripts/setup-local-ollama.sh' 配置本地 AI"
echo "3. 配置 VS Code Remote SSH"
