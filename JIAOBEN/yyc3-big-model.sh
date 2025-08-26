#!/bin/bash

# YYC³ AI模型集成管理系统
# 支持国内外主流大模型统一调用和管理
# 作者：YYC³
# 版本：2.0
# 更新日期：2025-07-12

# 启用严格模式和错误捕获
set -euo pipefail
trap 'log_error "脚本在第 $LINENO 行执行失败"; cleanup; exit 1' ERR

# 基础配置（可通过交互修改）
ROOT_DIR="/volume1/YC"
NAS_IP="192.168.0.9"
LOG_DIR="$ROOT_DIR/logs"
AI_DIR="$ROOT_DIR/ai-models"
BACKUP_DIR="$ROOT_DIR/backups"
CONFIG_FILE="$AI_DIR/configs/system_config.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "${BLUE}${msg}${NC}"
    echo "${msg}" >> "$LOG_FILE"
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "${msg}" >> "$LOG_FILE"
}

log_warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "${msg}" >> "$LOG_FILE"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}${msg}${NC}"
    echo "${msg}" >> "$LOG_FILE"
}

log_step() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [STEP] $1"
    echo -e "${PURPLE}${msg}${NC}"
    echo "${msg}" >> "$LOG_FILE"
}

# 验证IP地址
validate_ip() {
    local ip=$1
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "无效的IP地址格式: $ip"
        return 1
    fi
    return 0
}

# 验证端口
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "无效的端口: $port"
        return 1
    fi
    return 0
}

# 检查依赖
check_dependencies() {
    log_step "检查系统依赖..."
    
    # 检查基础工具
    local basic_deps=("docker" "docker-compose" "curl" "wget" "git" "openssl" "python3" "pip3" "node" "npm")
    for dep in "${basic_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep 未安装，请先安装 $dep"
            
            # 提供安装建议
            if [ "$dep" = "docker" ]; then
                log_info "安装命令: curl -fsSL https://get.docker.com | sh"
            elif [ "$dep" = "node" ] || [ "$dep" = "npm" ]; then
                log_info "安装命令: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
            elif [ "$dep" = "python3" ] || [ "$dep" = "pip3" ]; then
                log_info "安装命令: sudo apt-get install -y python3 python3-pip"
            fi
            
            exit 1
        fi
    done
    
    # 检查Python库
    local python_deps=("torch" "transformers" "datasets" "accelerate" "wandb" "numpy" "pandas" "scikit-learn")
    for dep in "${python_deps[@]}"; do
        if ! pip3 list | grep -q "$dep"; then
            log_info "安装Python库: $dep"
            if ! pip3 install "$dep"; then
                log_error "安装 $dep 失败"
                exit 1
            fi
        fi
    done
    
    # 检查Node.js库
    local node_deps=("express" "axios" "cors" "jsonwebtoken" "dotenv" "winston")
    for dep in "${node_deps[@]}"; do
        if ! npm list -g | grep -q "$dep"; then
            log_info "全局安装Node.js库: $dep"
            if ! npm install -g "$dep"; then
                log_error "安装 $dep 失败"
                exit 1
            fi
        fi
    done
    
    log_success "依赖检查通过"
}

# 交互式配置
interactive_config() {
    log_step "交互式配置..."
    
    # 配置根目录
    read -p "请输入根目录 (默认: $ROOT_DIR): " input_root
    if [ -n "$input_root" ]; then
        ROOT_DIR="$input_root"
    fi
    
    # 确保目录存在
    mkdir -p "$ROOT_DIR"
    if [ ! -w "$ROOT_DIR" ]; then
        log_error "目录 $ROOT_DIR 不可写，请检查权限"
        exit 1
    fi
    
    # 配置NAS IP
    while true; do
        read -p "请输入NAS IP地址 (默认: $NAS_IP): " input_ip
        local new_ip=${input_ip:-$NAS_IP}
        if validate_ip "$new_ip"; then
            NAS_IP="$new_ip"
            break
        fi
        log_warning "请输入有效的IP地址"
    done
    
    # 配置端口
    local gateway_port=3010
    while true; do
        read -p "请输入AI网关端口 (默认: $gateway_port): " input_port
        local new_port=${input_port:-$gateway_port}
        if validate_port "$new_port"; then
            gateway_port="$new_port"
            break
        fi
        log_warning "请输入有效的端口"
    done
    
    local dashboard_port=3011
    while true; do
        read -p "请输入管理后台端口 (默认: $dashboard_port): " input_port
        local new_port=${input_port:-$dashboard_port}
        if validate_port "$new_port" && [ "$new_port" -ne "$gateway_port" ]; then
            dashboard_port="$new_port"
            break
        fi
        log_warning "请输入有效的端口，且与网关端口不同"
    done
    
    # 保存配置
    save_config "ROOT_DIR" "$ROOT_DIR"
    save_config "NAS_IP" "$NAS_IP"
    save_config "GATEWAY_PORT" "$gateway_port"
    save_config "DASHBOARD_PORT" "$dashboard_port"
    save_config "LOG_DIR" "$LOG_DIR"
    save_config "BACKUP_DIR" "$BACKUP_DIR"
    
    log_success "配置完成"
}

# 保存配置
save_config() {
    local key=$1
    local value=$2
    
    # 确保配置目录存在
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # 如果配置文件不存在，创建它
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "{}" > "$CONFIG_FILE"
    fi
    
    # 使用jq更新配置
    if command -v jq &> /dev/null; then
        jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        log_warning "jq 未安装，无法更新配置文件"
    fi
}

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log_step "加载配置文件..."
        
        # 读取配置值
        if command -v jq &> /dev/null; then
            local root_dir=$(jq -r '.ROOT_DIR' "$CONFIG_FILE")
            local nas_ip=$(jq -r '.NAS_IP' "$CONFIG_FILE")
            local gateway_port=$(jq -r '.GATEWAY_PORT' "$CONFIG_FILE")
            local dashboard_port=$(jq -r '.DASHBOARD_PORT' "$CONFIG_FILE")
            
            # 更新变量（如果配置文件中有值）
            if [ "$root_dir" != "null" ] && [ -n "$root_dir" ]; then
                ROOT_DIR="$root_dir"
            fi
            if [ "$nas_ip" != "null" ] && [ -n "$nas_ip" ]; then
                NAS_IP="$nas_ip"
            fi
            if [ "$gateway_port" != "null" ] && [ -n "$gateway_port" ]; then
                GATEWAY_PORT="$gateway_port"
            fi
            if [ "$dashboard_port" != "null" ] && [ -n "$dashboard_port" ]; then
                DASHBOARD_PORT="$dashboard_port"
            fi
        else
            log_warning "jq 未安装，使用默认配置"
        fi
    else
        log_warning "配置文件不存在，使用默认配置"
    fi
    
    # 更新依赖路径
    AI_DIR="$ROOT_DIR/ai-models"
    LOG_DIR="$ROOT_DIR/logs"
    BACKUP_DIR="$ROOT_DIR/backups"
    CONFIG_FILE="$AI_DIR/configs/system_config.json"
    
    # 确保目录存在
    mkdir -p "$AI_DIR" "$LOG_DIR" "$BACKUP_DIR"
}

# 创建目录结构
create_directories() {
    log_step "创建目录结构..."
    
    # 创建主目录结构
    mkdir -p "$AI_DIR"/{
        models/{local,remote,custom},
        configs,
        logs,
        cache,
        training/{datasets,models,checkpoints},
        deployment/{docker,kubernetes},
        api/{gateway,adapters},
        management/{web,api,nginx}
    }
    
    # 创建日志目录
    mkdir -p "$LOG_DIR"/{gateway,trainer,dashboard,system}
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"/{configs,models,data}
    
    log_success "目录结构创建完成"
}

# 创建AI模型统一网关服务
create_ai_gateway() {
    log_step "创建AI模型统一网关服务..."
    
    local gateway_dir="$AI_DIR/api/gateway"
    
    # 创建网关代码
    cat > "$gateway_dir/server.js" << 'EOF'
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');
const winston = require('winston');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
require('dotenv').config();

// 初始化日志
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.File({ filename: path.join(__dirname, '../../logs/gateway/error.log'), level: 'error' }),
        new winston.transports.File({ filename: path.join(__dirname, '../../logs/gateway/combined.log') })
    ]
});

if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.simple()
    }));
}

const app = express();
const PORT = process.env.AI_GATEWAY_PORT || 3010;
const NAS_IP = process.env.NAS_IP || '192.168.0.9';

// 安全中间件
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// 速率限制
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15分钟
    max: 100, // 每个IP限制100请求
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: '请求过于频繁，请稍后再试' }
});
app.use('/api/', apiLimiter);

// 模型配置存储
let modelConfigs = {};
let modelStats = {};
let configPath = path.join(__dirname, '../../configs/models.json');

// 加载模型配置
async function loadModelConfigs() {
    try {
        const data = await fs.readFile(configPath, 'utf8');
        modelConfigs = JSON.parse(data);
        logger.info('✅ 模型配置加载成功');
    } catch (error) {
        logger.warn('⚠️ 模型配置文件不存在，使用默认配置');
        modelConfigs = getDefaultModelConfigs();
        await saveModelConfigs();
    }
}

// 保存模型配置
async function saveModelConfigs() {
    try {
        await fs.writeFile(configPath, JSON.stringify(modelConfigs, null, 2));
        logger.info('✅ 模型配置保存成功');
    } catch (error) {
        logger.error('❌ 保存模型配置失败:', error);
    }
}

// 默认模型配置
function getDefaultModelConfigs() {
    return {
        "zhipu-ai": {
            name: "智谱AI",
            type: "remote",
            endpoint: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
            apiKey: process.env.ZHIPU_API_KEY || "",
            models: ["glm-4", "glm-4v", "glm-3-turbo"],
            enabled: true,
            rateLimit: 100,
            timeout: 30000
        },
        "openai": {
            name: "OpenAI",
            type: "remote",
            endpoint: "https://api.openai.com/v1/chat/completions",
            apiKey: process.env.OPENAI_API_KEY || "",
            models: ["gpt-4", "gpt-3.5-turbo", "gpt-4-turbo"],
            enabled: true,
            rateLimit: 60,
            timeout: 30000
        },
        "claude": {
            name: "Claude",
            type: "remote",
            endpoint: "https://api.anthropic.com/v1/messages",
            apiKey: process.env.CLAUDE_API_KEY || "",
            models: ["claude-3-opus", "claude-3-sonnet", "claude-3-haiku"],
            enabled: true,
            rateLimit: 50,
            timeout: 30000
        },
        "qwen": {
            name: "通义千问",
            type: "remote",
            endpoint: "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation",
            apiKey: process.env.QWEN_API_KEY || "",
            models: ["qwen-turbo", "qwen-plus", "qwen-max"],
            enabled: true,
            rateLimit: 100,
            timeout: 30000
        },
        "baichuan": {
            name: "百川智能",
            type: "remote",
            endpoint: "https://api.baichuan-ai.com/v1/chat/completions",
            apiKey: process.env.BAICHUAN_API_KEY || "",
            models: ["Baichuan2-Turbo", "Baichuan2-Turbo-192k"],
            enabled: true,
            rateLimit: 100,
            timeout: 30000
        },
        "moonshot": {
            name: "月之暗面",
            type: "remote",
            endpoint: "https://api.moonshot.cn/v1/chat/completions",
            apiKey: process.env.MOONSHOT_API_KEY || "",
            models: ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"],
            enabled: true,
            rateLimit: 100,
            timeout: 30000
        },
        "ollama": {
            name: "本地Ollama",
            type: "local",
            endpoint: "http://localhost:11434/api/chat",
            apiKey: "",
            models: ["llama2", "codellama", "mistral", "qwen"],
            enabled: true,
            rateLimit: 1000,
            timeout: 60000
        }
    };
}

// 统一聊天接口
app.post('/api/chat', async (req, res) => {
    try {
        const { model, messages, provider, stream = false, ...options } = req.body;
        
        if (!model || !messages) {
            return res.status(400).json({
                error: '缺少必要参数: model 和 messages'
            });
        }

        // 查找模型配置
        const modelConfig = findModelConfig(model, provider);
        if (!modelConfig) {
            return res.status(404).json({
                error: `未找到模型配置: ${model}`
            });
        }

        // 检查模型是否启用
        if (!modelConfig.enabled) {
            return res.status(403).json({
                error: `模型已禁用: ${model}`
            });
        }

        // 记录请求统计
        recordModelUsage(modelConfig.name, model);

        // 记录请求日志
        logger.info(`收到请求: ${modelConfig.name} - ${model}`);

        // 根据提供商调用相应的适配器
        const response = await callModelAdapter(modelConfig, {
            model,
            messages,
            stream,
            ...options
        });

        res.json(response);

    } catch (error) {
        logger.error('❌ 聊天请求失败:', error);
        res.status(500).json({
            error: '内部服务器错误',
            details: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// 查找模型配置
function findModelConfig(model, provider) {
    if (provider && modelConfigs[provider]) {
        return modelConfigs[provider];
    }
    
    // 遍历所有配置查找模型
    for (const [key, config] of Object.entries(modelConfigs)) {
        if (config.models.includes(model)) {
            return config;
        }
    }
    
    return null;
}

// 调用模型适配器
async function callModelAdapter(config, params) {
    switch (config.type) {
        case 'remote':
            return await callRemoteModel(config, params);
        case 'local':
            return await callLocalModel(config, params);
        default:
            throw new Error(`不支持的模型类型: ${config.type}`);
    }
}

// 调用远程模型
async function callRemoteModel(config, params) {
    const headers = {
        'Content-Type': 'application/json'
    };

    // 根据不同提供商设置认证头
    if (config.name === '智谱AI') {
        headers['Authorization'] = `Bearer ${config.apiKey}`;
    } else if (config.name === 'OpenAI') {
        headers['Authorization'] = `Bearer ${config.apiKey}`;
    } else if (config.name === 'Claude') {
        headers['x-api-key'] = config.apiKey;
        headers['anthropic-version'] = '2023-06-01';
    } else if (config.name === '通义千问') {
        headers['Authorization'] = `Bearer ${config.apiKey}`;
    } else {
        headers['Authorization'] = `Bearer ${config.apiKey}`;
    }

    // 转换请求格式
    const requestBody = transformRequest(config.name, params);

    try {
        const response = await axios.post(config.endpoint, requestBody, {
            headers,
            timeout: config.timeout
        });

        // 转换响应格式
        return transformResponse(config.name, response.data);

    } catch (error) {
        logger.error(`❌ 调用${config.name}失败:`, error.response?.data || error.message);
        throw new Error(`调用${config.name}失败: ${error.response?.data?.error?.message || error.message}`);
    }
}

// 调用本地模型
async function callLocalModel(config, params) {
    try {
        const response = await axios.post(config.endpoint, {
            model: params.model,
            messages: params.messages,
            stream: false
        }, {
            timeout: config.timeout
        });

        return {
            id: `local-${Date.now()}`,
            object: 'chat.completion',
            created: Math.floor(Date.now() / 1000),
            model: params.model,
            choices: [{
                index: 0,
                message: {
                    role: 'assistant',
                    content: response.data.message?.content || response.data.response
                },
                finish_reason: 'stop'
            }],
            usage: {
                prompt_tokens: 0,
                completion_tokens: 0,
                total_tokens: 0
            }
        };

    } catch (error) {
        logger.error('❌ 调用本地模型失败:', error);
        throw new Error(`调用本地模型失败: ${error.message}`);
    }
}

// 请求格式转换
function transformRequest(provider, params) {
    switch (provider) {
        case '智谱AI':
            return {
                model: params.model,
                messages: params.messages,
                temperature: params.temperature || 0.7,
                max_tokens: params.max_tokens || 1000,
                stream: params.stream || false
            };
        
        case 'Claude':
            return {
                model: params.model,
                max_tokens: params.max_tokens || 1000,
                messages: params.messages,
                temperature: params.temperature || 0.7
            };
        
        case '通义千问':
            return {
                model: params.model,
                input: {
                    messages: params.messages
                },
                parameters: {
                    temperature: params.temperature || 0.7,
                    max_tokens: params.max_tokens || 1000
                }
            };
        
        default:
            return {
                model: params.model,
                messages: params.messages,
                temperature: params.temperature || 0.7,
                max_tokens: params.max_tokens || 1000,
                stream: params.stream || false
            };
    }
}

// 响应格式转换
function transformResponse(provider, data) {
    switch (provider) {
        case '通义千问':
            return {
                id: data.request_id,
                object: 'chat.completion',
                created: Math.floor(Date.now() / 1000),
                model: data.output?.model || 'qwen',
                choices: [{
                    index: 0,
                    message: {
                        role: 'assistant',
                        content: data.output?.text || ''
                    },
                    finish_reason: data.output?.finish_reason || 'stop'
                }],
                usage: data.usage || {}
            };
        
        default:
            return data;
    }
}

// 记录模型使用统计
function recordModelUsage(provider, model) {
    const key = `${provider}-${model}`;
    if (!modelStats[key]) {
        modelStats[key] = {
            provider,
            model,
            requests: 0,
            lastUsed: null
        };
    }
    
    modelStats[key].requests++;
    modelStats[key].lastUsed = new Date().toISOString();
}

// 获取模型列表
app.get('/api/models', (req, res) => {
    const models = [];
    
    for (const [key, config] of Object.entries(modelConfigs)) {
        if (config.enabled) {
            config.models.forEach(model => {
                models.push({
                    id: model,
                    name: model,
                    provider: config.name,
                    type: config.type,
                    description: `${config.name} - ${model}`
                });
            });
        }
    }
    
    res.json({ models });
});

// 获取模型统计
app.get('/api/stats', (req, res) => {
    res.json({
        providers: Object.keys(modelConfigs).length,
        models: Object.values(modelConfigs).reduce((sum, config) => sum + config.models.length, 0),
        usage: modelStats,
        uptime: process.uptime()
    });
});

// 管理接口 - 获取配置
app.get('/api/admin/configs', (req, res) => {
    res.json(modelConfigs);
});

// 管理接口 - 更新配置
app.put('/api/admin/configs', async (req, res) => {
    try {
        modelConfigs = req.body;
        await saveModelConfigs();
        res.json({ success: true, message: '配置更新成功' });
    } catch (error) {
        logger.error('更新配置失败:', error);
        res.status(500).json({ error: '配置更新失败', details: process.env.NODE_ENV === 'development' ? error.message : undefined });
    }
});

// 健康检查
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        models: Object.keys(modelConfigs).length
    });
});

// 启动服务器
async function startServer() {
    await loadModelConfigs();
    
    app.listen(PORT, '0.0.0.0', () => {
        logger.info(`🤖 AI模型网关服务启动成功`);
        logger.info(`🌐 服务地址: http://0.0.0.0:${PORT}`);
        logger.info(`📊 管理面板: http://0.0.0.0:${PORT}/admin`);
        logger.info(`🔍 健康检查: http://0.0.0.0:${PORT}/health`);
    });
}

// 启动服务
startServer().catch(error => {
    logger.error('启动服务器失败:', error);
    process.exit(1);
});
EOF

    # 创建网关Dockerfile
    cat > "$gateway_dir/Dockerfile" << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

ENV NODE_ENV=production
ENV AI_GATEWAY_PORT=3010

EXPOSE 3010

CMD ["node", "server.js"]
EOF

    # 创建网关package.json
    cat > "$gateway_dir/package.json" << 'EOF'
{
  "name": "yyc3-ai-gateway",
  "version": "1.0.0",
  "description": "YYC³ AI模型统一网关",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "axios": "^1.6.2",
    "winston": "^3.11.0",
    "express-rate-limit": "^7.1.4",
    "helmet": "^7.1.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.2",
    "jest": "^29.7.0",
    "supertest": "^6.3.3"
  }
}
EOF

    log_success "AI模型统一网关服务创建完成"
}

# 创建智谱AI专项集成
create_zhipu_integration() {
    log_step "创建智谱AI专项集成..."
    
    local zhipu_dir="$AI_DIR/api/adapters"
    mkdir -p "$zhipu_dir"
    
    cat > "$zhipu_dir/zhipu-ai.js" << 'EOF'
const axios = require('axios');
const crypto = require('crypto');
const winston = require('winston');
const path = require('path');

// 配置日志
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.File({ filename: path.join(__dirname, '../../logs/gateway/zhipu-error.log'), level: 'error' }),
        new winston.transports.File({ filename: path.join(__dirname, '../../logs/gateway/zhipu-combined.log') })
    ]
});

if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.simple()
    }));
}

class ZhipuAI {
    constructor(apiKey) {
        this.apiKey = apiKey;
        this.baseURL = 'https://open.bigmodel.cn/api/paas/v4';
        this.stats = {
            totalRequests: 0,
            successfulRequests: 0,
            failedRequests: 0,
            totalTokens: 0,
            avgResponseTime: 0
        };
    }

    // 生成JWT Token
    generateToken() {
        const [apiKey, secret] = this.apiKey.split('.');
        
        const header = {
            alg: 'HS256',
            sign_type: 'SIGN'
        };
        
        const payload = {
            api_key: apiKey,
            exp: Math.floor(Date.now() / 1000) + 3600, // 1小时过期
            timestamp: Math.floor(Date.now() / 1000)
        };
        
        const headerBase64 = Buffer.from(JSON.stringify(header)).toString('base64url');
        const payloadBase64 = Buffer.from(JSON.stringify(payload)).toString('base64url');
        
        const signature = crypto
            .createHmac('sha256', secret)
            .update(`${headerBase64}.${payloadBase64}`)
            .digest('base64url');
        
        return `${headerBase64}.${payloadBase64}.${signature}`;
    }

    // 聊天完成
    async chatCompletions(params) {
        const startTime = Date.now();
        this.stats.totalRequests++;
        
        try {
            const token = this.generateToken();
            
            const response = await axios.post(`${this.baseURL}/chat/completions`, {
                model: params.model || 'glm-4',
                messages: params.messages,
                temperature: params.temperature || 0.7,
                max_tokens: params.max_tokens || 1000,
                stream: params.stream || false,
                tools: params.tools,
                tool_choice: params.tool_choice
            }, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                timeout: 30000
            });

            // 更新统计信息
            this.stats.successfulRequests++;
            const responseTime = Date.now() - startTime;
            this.stats.avgResponseTime = (this.stats.avgResponseTime * (this.stats.successfulRequests - 1) + responseTime) / this.stats.successfulRequests;
            
            // 记录token使用
            if (response.data.usage) {
                this.stats.totalTokens += response.data.usage.total_tokens;
            }

            logger.info(`智谱AI请求成功: ${params.model}, 耗时: ${responseTime}ms`);
            return response.data;

        } catch (error) {
            this.stats.failedRequests++;
            logger.error('智谱AI调用失败:', error.response?.data || error.message);
            throw new Error(`智谱AI调用失败: ${error.response?.data?.error?.message || error.message}`);
        }
    }

    // 图像理解 (GLM-4V)
    async imageUnderstanding(params) {
        const startTime = Date.now();
        this.stats.totalRequests++;
        
        try {
            const token = this.generateToken();
            
            const messages = params.messages.map(msg => {
                if (msg.role === 'user' && Array.isArray(msg.content)) {
                    return {
                        role: 'user',
                        content: msg.content.map(item => {
                            if (item.type === 'image_url') {
                                return {
                                    type: 'image_url',
                                    image_url: {
                                        url: item.image_url.url
                                    }
                                };
                            }
                            return item;
                        })
                    };
                }
                return msg;
            });

            const response = await axios.post(`${this.baseURL}/chat/completions`, {
                model: 'glm-4v',
                messages: messages,
                temperature: params.temperature || 0.7,
                max_tokens: params.max_tokens || 1000
            }, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                timeout: 30000
            });

            // 更新统计信息
            this.stats.successfulRequests++;
            const responseTime = Date.now() - startTime;
            this.stats.avgResponseTime = (this.stats.avgResponseTime * (this.stats.successfulRequests - 1) + responseTime) / this.stats.successfulRequests;
            
            logger.info(`智谱AI图像理解成功, 耗时: ${responseTime}ms`);
            return response.data;

        } catch (error) {
            this.stats.failedRequests++;
            logger.error('智谱AI图像理解失败:', error.response?.data || error.message);
            throw new Error(`智谱AI图像理解失败: ${error.response?.data?.error?.message || error.message}`);
        }
    }

    // 代码生成
    async codeGeneration(params) {
        const startTime = Date.now();
        this.stats.totalRequests++;
        
        try {
            const token = this.generateToken();
            
            const response = await axios.post(`${this.baseURL}/chat/completions`, {
                model: params.model || 'codegeex-4',
                messages: [
                    {
                        role: 'system',
                        content: '你是一个专业的代码生成助手，请根据用户需求生成高质量的代码。'
                    },
                    ...params.messages
                ],
                temperature: params.temperature || 0.1,
                max_tokens: params.max_tokens || 2000
            }, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                timeout: 30000
            });

            // 更新统计信息
            this.stats.successfulRequests++;
            const responseTime = Date.now() - startTime;
            this.stats.avgResponseTime = (this.stats.avgResponseTime * (this.stats.successfulRequests - 1) + responseTime) / this.stats.successfulRequests;
            
            logger.info(`智谱AI代码生成成功: ${params.model}, 耗时: ${responseTime}ms`);
            return response.data;

        } catch (error) {
            this.stats.failedRequests++;
            logger.error('智谱AI代码生成失败:', error.response?.data || error.message);
            throw new Error(`智谱AI代码生成失败: ${error.response?.data?.error?.message || error.message}`);
        }
    }

    // 文档问答
    async documentQA(params) {
        const startTime = Date.now();
        this.stats.totalRequests++;
        
        try {
            const token = this.generateToken();
            
            // 构建包含文档上下文的消息
            const contextMessage = {
                role: 'system',
                content: `基于以下文档内容回答用户问题：\n\n${params.document}\n\n请确保答案准确且基于文档内容。`
            };

            const response = await axios.post(`${this.baseURL}/chat/completions`, {
                model: params.model || 'glm-4',
                messages: [contextMessage, ...params.messages],
                temperature: params.temperature || 0.3,
                max_tokens: params.max_tokens || 1500
            }, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                timeout: 30000
            });

            // 更新统计信息
            this.stats.successfulRequests++;
            const responseTime = Date.now() - startTime;
            this.stats.avgResponseTime = (this.stats.avgResponseTime * (this.stats.successfulRequests - 1) + responseTime) / this.stats.successfulRequests;
            
            logger.info(`智谱AI文档问答成功: ${params.model}, 耗时: ${responseTime}ms`);
            return response.data;

        } catch (error) {
            this.stats.failedRequests++;
            logger.error('智谱AI文档问答失败:', error.response?.data || error.message);
            throw new Error(`智谱AI文档问答失败: ${error.response?.data?.error?.message || error.message}`);
        }
    }

    // 获取模型列表
    async getModels() {
        try {
            const token = this.generateToken();
            
            const response = await axios.get(`${this.baseURL}/models`, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });

            return response.data;

        } catch (error) {
            logger.error('获取智谱AI模型列表失败:', error.response?.data || error.message);
            throw new Error(`获取智谱AI模型列表失败: ${error.response?.data?.error?.message || error.message}`);
        }
    }

    // 检查API状态
    async checkStatus() {
        try {
            const models = await this.getModels();
            return {
                status: 'healthy',
                models: models.data?.length || 0,
                timestamp: new Date().toISOString(),
                stats: this.stats
            };
        } catch (error) {
            return {
                status: 'error',
                error: error.message,
                timestamp: new Date().toISOString(),
                stats: this.stats
            };
        }
    }
}

module.exports = ZhipuAI;
EOF

    log_success "智谱AI专项集成创建完成"
}

# 创建自定义模型训练系统
create_custom_training() {
    log_step "创建自定义模型训练系统..."
    
    local training_dir="$AI_DIR/training"
    
    cat > "$training_dir/trainer.py" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import torch
import logging
import argparse
import shutil
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from transformers import (
    AutoTokenizer, 
    AutoModelForCausalLM,
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling,
    BitsAndBytesConfig
)
from datasets import Dataset, load_dataset, concatenate_datasets
import wandb
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/volume1/YC/ai-models/logs/trainer/training.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class TrainingConfig:
    """训练配置类"""
    model_name: str
    base_model: str
    dataset_path: str
    output_dir: str
    max_length: int = 512
    batch_size: int = 4
    learning_rate: float = 2e-5
    num_epochs: int = 3
    warmup_steps: int = 100
    save_steps: int = 500
    eval_steps: int = 500
    logging_steps: int = 100
    gradient_accumulation_steps: int = 1
    fp16: bool = True
    use_wandb: bool = False
    wandb_project: str = "yc-custom-models"
    use_lora: bool = False  # 使用LoRA进行高效微调
    quantize: bool = False  # 量化模型以节省显存
    resume_from_checkpoint: Optional[str] = None  # 从检查点恢复训练

class CustomModelTrainer:
    """自定义模型训练器"""
    
    def __init__(self, config: TrainingConfig):
        self.config = config
        self.tokenizer = None
        self.model = None
        self.train_dataset = None
        self.eval_dataset = None
        self.training_stats = {
            "start_time": datetime.now().isoformat(),
            "end_time": None,
            "total_steps": 0,
            "training_loss": [],
            "eval_loss": [],
            "epoch_stats": []
        }
        
        # 创建输出目录
        Path(config.output_dir).mkdir(parents=True, exist_ok=True)
        Path(os.path.join(config.output_dir, "checkpoints")).mkdir(parents=True, exist_ok=True)
        
        # 初始化wandb
        if config.use_wandb:
            wandb.init(
                project=config.wandb_project,
                name=config.model_name,
                config=config.__dict__
            )
    
    def load_model_and_tokenizer(self):
        """加载基础模型和分词器"""
        logger.info(f"加载基础模型: {self.config.base_model}")
        
        try:
            self.tokenizer = AutoTokenizer.from_pretrained(
                self.config.base_model,
                trust_remote_code=True
            )
            
            # 设置pad_token
            if self.tokenizer.pad_token is None:
                self.tokenizer.pad_token = self.tokenizer.eos_token
            
            # 量化配置
            quantization_config = None
            if self.config.quantize:
                quantization_config = BitsAndBytesConfig(
                    load_in_4bit=True,
                    bnb_4bit_use_double_quant=True,
                    bnb_4bit_quant_type="nf4",
                    bnb_4bit_compute_dtype=torch.float16
                )
            
            # 加载模型
            self.model = AutoModelForCausalLM.from_pretrained(
                self.config.base_model,
                trust_remote_code=True,
                torch_dtype=torch.float16 if self.config.fp16 else torch.float32,
                device_map="auto",
                quantization_config=quantization_config if self.config.quantize else None
            )
            
            # 如果使用LoRA
            if self.config.use_lora:
                logger.info("应用LoRA配置...")
                lora_config = LoraConfig(
                    r=16,
                    lora_alpha=32,
                    target_modules=["q_proj", "v_proj"],
                    lora_dropout=0.05,
                    bias="none",
                    task_type="CAUSAL_LM"
                )
                
                # 准备模型进行量化训练
                if self.config.quantize:
                    self.model = prepare_model_for_kbit_training(self.model)
                    
                self.model = get_peft_model(self.model, lora_config)
                self.model.print_trainable_parameters()
            
            logger.info("模型和分词器加载成功")
            
        except Exception as e:
            logger.error(f"加载模型失败: {e}")
            raise
    
    def prepare_dataset(self):
        """准备训练数据集"""
        logger.info(f"准备数据集: {self.config.dataset_path}")
        
        try:
            # 加载数据集
            datasets = []
            
            # 支持多个数据集文件
            if os.path.isdir(self.config.dataset_path):
                # 如果是目录，加载所有JSON文件
                for filename in os.listdir(self.config.dataset_path):
                    if filename.endswith('.json'):
                        file_path = os.path.join(self.config.dataset_path, filename)
                        logger.info(f"加载数据集文件: {file_path}")
                        with open(file_path, 'r', encoding='utf-8') as f:
                            data = json.load(f)
                        datasets.append(Dataset.from_list(data))
            else:
                # 如果是文件，直接加载
                if self.config.dataset_path.endswith('.json'):
                    with open(self.config.dataset_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                    datasets.append(Dataset.from_list(data))
                else:
                    # 尝试从Hugging Face Hub加载
                    datasets.append(load_dataset(self.config.dataset_path)['train'])
            
            # 合并数据集
            dataset = concatenate_datasets(datasets)
            
            # 数据预处理
            def preprocess_function(examples):
                # 支持多种数据格式
                texts = []
                
                # 格式1: {"input": "问题", "output": "答案"}
                if 'input' in examples and 'output' in examples:
                    for i in range(len(examples['input'])):
                        text = f"问题: {examples['input'][i]}\n答案: {examples['output'][i]}"
                        texts.append(text)
                # 格式2: {"prompt": "提示", "response": "回应"}
                elif 'prompt' in examples and 'response' in examples:
                    for i in range(len(examples['prompt'])):
                        text = f"{examples['prompt'][i]}\n{examples['response'][i]}"
                        texts.append(text)
                # 格式3: {"text": "完整文本"}
                elif 'text' in examples:
                    texts = examples['text']
                else:
                    raise ValueError("不支持的数据集格式")
                
                # 分词
                tokenized = self.tokenizer(
                    texts,
                    truncation=True,
                    padding=True,
                    max_length=self.config.max_length,
                    return_tensors="pt"
                )
                
                # 设置labels
                tokenized["labels"] = tokenized["input_ids"].clone()
                
                return tokenized
            
            # 应用预处理
            tokenized_dataset = dataset.map(
                preprocess_function,
                batched=True,
                remove_columns=dataset.column_names
            )
            
            # 分割训练和验证集
            split_dataset = tokenized_dataset.train_test_split(test_size=0.1)
            self.train_dataset = split_dataset['train']
            self.eval_dataset = split_dataset['test']
            
            logger.info(f"数据集准备完成 - 训练集: {len(self.train_dataset)}, 验证集: {len(self.eval_dataset)}")
            
        except Exception as e:
            logger.error(f"数据集准备失败: {e}")
            raise
    
    def train(self):
        """开始训练"""
        logger.info("开始模型训练")
        
        try:
            # 训练参数
            training_args = TrainingArguments(
                output_dir=os.path.join(self.config.output_dir, "checkpoints"),
                overwrite_output_dir=True,
                num_train_epochs=self.config.num_epochs,
                per_device_train_batch_size=self.config.batch_size,
                per_device_eval_batch_size=self.config.batch_size,
                gradient_accumulation_steps=self.config.gradient_accumulation_steps,
                learning_rate=self.config.learning_rate,
                warmup_steps=self.config.warmup_steps,
                logging_steps=self.config.logging_steps,
                save_steps=self.config.save_steps,
                eval_steps=self.config.eval_steps,
                evaluation_strategy="steps",
                save_strategy="steps",
                load_best_model_at_end=True,
                metric_for_best_model="eval_loss",
                greater_is_better=False,
                fp16=self.config.fp16,
                dataloader_pin_memory=False,
                report_to="wandb" if self.config.use_wandb else None,
                run_name=self.config.model_name,
                resume_from_checkpoint=self.config.resume_from_checkpoint
            )
            
            # 定义训练回调以收集统计信息
            def log_trainer_callback(args, state, control, **kwargs):
                self.training_stats["total_steps"] = state.global_step
                if state.is_local_process_zero:
                    if state.training_loss is not None:
                        self.training_stats["training_loss"].append({
                            "step": state.global_step,
                            "loss": state.training_loss
                        })
            
            # 数据整理器
            data_collator = DataCollatorForLanguageModeling(
                tokenizer=self.tokenizer,
                mlm=False
            )
            
            # 创建训练器
            trainer = Trainer(
                model=self.model,
                args=training_args,
                train_dataset=self.train_dataset,
                eval_dataset=self.eval_dataset,
                data_collator=data_collator,
                tokenizer=self.tokenizer,
                callbacks=[log_trainer_callback]
            )
            
            # 开始训练
            trainer.train(resume_from_checkpoint=self.config.resume_from_checkpoint)
            
            # 保存最终模型
            logger.info("保存最终模型...")
            if self.config.use_lora:
                # 对于LoRA模型，保存Peft模型
                self.model.save_pretrained(os.path.join(self.config.output_dir, "lora_weights"))
                # 同时保存基础模型信息
                with open(os.path.join(self.config.output_dir, "base_model_info.txt"), "w") as f:
                    f.write(self.config.base_model)
            else:
                # 保存完整模型
                trainer.save_model(self.config.output_dir)
            
            self.tokenizer.save_pretrained(self.config.output_dir)
            
            # 保存训练配置
            config_path = os.path.join(self.config.output_dir, "training_config.json")
            with open(config_path, 'w', encoding='utf-8') as f:
                json.dump(self.config.__dict__, f, indent=2, ensure_ascii=False)
            
            # 保存训练统计
            self.training_stats["end_time"] = datetime.now().isoformat()
            stats_path = os.path.join(self.config.output_dir, "training_stats.json")
            with open(stats_path, 'w', encoding='utf-8') as f:
                json.dump(self.training_stats, f, indent=2, ensure_ascii=False)
            
            logger.info(f"训练完成，模型保存至: {self.config.output_dir}")
            
        except Exception as e:
            logger.error(f"训练失败: {e}")
            raise
    
    def evaluate(self):
        """评估模型"""
        logger.info("开始模型评估")
        
        try:
            # 加载训练好的模型
            if self.config.use_lora:
                from peft import PeftModel
                
                # 加载基础模型
                base_model = AutoModelForCausalLM.from_pretrained(
                    self.config.base_model,
                    trust_remote_code=True,
                    torch_dtype=torch.float16 if self.config.fp16 else torch.float32,
                    device_map="auto"
                )
                
                # 加载LoRA权重
                self.model = PeftModel.from_pretrained(
                    base_model,
                    os.path.join(self.config.output_dir, "lora_weights")
                )
                self.model.eval()
            else:
                self.model = AutoModelForCausalLM.from_pretrained(
                    self.config.output_dir,
                    trust_remote_code=True,
                    device_map="auto"
                )
            
            self.tokenizer = AutoTokenizer.from_pretrained(self.config.output_dir)
            
            # 简单的生成测试
            test_inputs = [
                "问题: 什么是人工智能？",
                "问题: 如何学习机器学习？",
                "问题: Python有什么优势？"
            ]
            
            results = []
            for test_input in test_inputs:
                inputs = self.tokenizer(test_input, return_tensors="pt").to("cuda" if torch.cuda.is_available() else "cpu")
                
                with torch.no_grad():
                    outputs = self.model.generate(
                        **inputs,
                        max_length=200,
                        num_return_sequences=1,
                        temperature=0.7,
                        do_sample=True,
                        pad_token_id=self.tokenizer.eos_token_id
                    )
                
                generated_text = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
                results.append({
                    "input": test_input,
                    "output": generated_text
                })
            
            # 保存评估结果
            eval_path = os.path.join(self.config.output_dir, "evaluation_results.json")
            with open(eval_path, 'w', encoding='utf-8') as f:
                json.dump(results, f, indent=2, ensure_ascii=False)
            
            logger.info(f"评估完成，结果保存至: {eval_path}")
            return results
            
        except Exception as e:
            logger.error(f"评估失败: {e}")
            raise

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="自定义模型训练")
    parser.add_argument("--config", type=str, required=True, help="训练配置文件路径")
    parser.add_argument("--only-evaluate", action="store_true", help="仅进行评估，不训练")
    args = parser.parse_args()
    
    # 加载配置
    with open(args.config, 'r', encoding='utf-8') as f:
        config_dict = json.load(f)
    
    config = TrainingConfig(** config_dict)
    
    # 创建训练器
    trainer = CustomModelTrainer(config)
    
    # 执行训练流程
    trainer.load_model_and_tokenizer()
    
    if not args.only_evaluate:
        trainer.prepare_dataset()
        trainer.train()
    
    trainer.evaluate()
    
    logger.info("训练流程完成")

if __name__ == "__main__":
    main()
EOF

    # 创建训练配置模板
    cat > "$training_dir/config_template.json" << 'EOF'
{
    "model_name": "yc-custom-model-v1",
    "base_model": "Qwen/Qwen2-1.5B-Instruct",
    "dataset_path": "/volume1/YC/ai-models/training/datasets/custom_dataset.json",
    "output_dir": "/volume1/YC/ai-models/training/models/yc-custom-model-v1",
    "max_length": 512,
    "batch_size": 4,
    "learning_rate": 2e-5,
    "num_epochs": 3,
    "warmup_steps": 100,
    "save_steps": 500,
    "eval_steps": 500,
    "logging_steps": 100,
    "gradient_accumulation_steps": 1,
    "fp16": true,
    "use_wandb": false,
    "wandb_project": "yc-custom-models",
    "use_lora": true,
    "quantize": true,
    "resume_from_checkpoint": null
}
EOF

    # 创建数据集示例
    cat > "$training_dir/datasets/sample_dataset.json" << 'EOF'
[
    {
        "input": "什么是机器学习？",
        "output": "机器学习是人工智能的一个分支，它使计算机能够在没有明确编程的情况下学习和改进。通过算法和统计模型，机器学习系统可以从数据中识别模式并做出预测或决策。"
    },
    {
        "input": "深度学习和机器学习有什么区别？",
        "output": "深度学习是机器学习的一个子集，它使用多层神经网络来模拟人脑的工作方式。与传统机器学习相比，深度学习能够自动提取特征，处理更复杂的数据，如图像、语音和自然语言。"
    },
    {
        "input": "如何开始学习人工智能？",
        "output": "学习人工智能建议从以下步骤开始：1. 掌握数学基础（线性代数、概率统计、微积分）；2. 学习编程语言（Python推荐）；3. 了解机器学习基础理论；4. 实践项目和案例；5. 深入特定领域（如计算机视觉、自然语言处理等）。"
    },
    {
        "input": "什么是神经网络？",
        "output": "神经网络是受人脑结构启发的计算模型，由相互连接的节点（神经元）组成。这些网络通过调整节点之间的连接强度（权重）来学习从输入到输出的映射，是深度学习的核心组成部分。"
    },
    {
        "input": "监督学习和无监督学习有什么区别？",
        "output": "监督学习使用标记数据（带有已知输出的输入）进行训练，目标是学习输入到输出的映射。无监督学习则使用未标记数据，目标是发现数据中隐藏的模式或结构，如聚类分析。"
    }
]
EOF

    # 创建训练启动脚本
    cat > "$training_dir/start_training.sh" << 'EOF'
#!/bin/bash

# 训练启动脚本
set -euo pipefail

# 日志配置
LOG_DIR="/volume1/YC/ai-models/logs/trainer"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/training_$(date +%Y%m%d_%H%M%S).log"

# 显示帮助
show_help() {
    echo "用法: $0 [选项] <配置文件路径>"
    echo "选项:"
    echo "  -h, --help      显示帮助信息"
    echo "  -e, --evaluate  仅进行评估，不训练"
    echo "  -d, --debug     显示调试信息"
    echo ""
}

# 解析参数
EVAL_ONLY=false
DEBUG=false
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -e|--evaluate)
            EVAL_ONLY=true
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        *)
            if [ -z "$CONFIG_FILE" ]; then
                CONFIG_FILE="$1"
                shift
            else
                echo "错误: 未知参数 $1"
                show_help
                exit 1
            fi
            ;;
    esac
done

# 检查配置文件
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件不存在: $CONFIG_FILE"
    show_help
    exit 1
fi

echo "开始训练流程，日志文件: $LOG_FILE"

# 构建命令
CMD="python3 /volume1/YC/ai-models/training/trainer.py --config \"$CONFIG_FILE\""
if [ "$EVAL_ONLY" = true ]; then
    CMD="$CMD --only-evaluate"
fi

# 执行命令
if [ "$DEBUG" = true ]; then
    echo "执行命令: $CMD"
    $CMD | tee "$LOG_FILE"
else
    $CMD > "$LOG_FILE" 2>&1
    echo "训练流程已启动，查看日志: tail -f $LOG_FILE"
    echo "训练状态: 运行中"
fi

# 检查执行结果
if [ $? -eq 0 ]; then
    echo "训练流程成功完成"
    exit 0
else
    echo "训练流程失败，查看日志获取详情: $LOG_FILE"
    exit 1
fi
EOF

chmod +x "$training_dir/start_training.sh"

    log_success "自定义模型训练系统创建完成"
}

# 创建移动端应用
create_mobile_app() {
    log_step "创建移动端应用..."
    
    local mobile_dir="$AI_DIR/../mobile-app"
    mkdir -p "$mobile_dir"/{
        src/{components,screens,services,utils,store},
        assets/{images,fonts},
        android,
        ios,
        __tests__
    }
    
    # 创建移动端主应用
    cat > "$mobile_dir/App.js" << 'EOF'
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { Provider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { LogBox, View } from 'react-native';

// 忽略警告
LogBox.ignoreLogs([
  'Non-serializable values were found in the navigation state',
  'VirtualizedLists should never be nested'
]);

import { store, persistor } from './src/store';
import HomeScreen from './src/screens/HomeScreen';
import ChatScreen from './src/screens/ChatScreen';
import ModelsScreen from './src/screens/ModelsScreen';
import FilesScreen from './src/screens/FilesScreen';
import SettingsScreen from './src/screens/SettingsScreen';
import LoginScreen from './src/screens/LoginScreen';
import TrainingScreen from './src/screens/TrainingScreen';
import LoadingScreen from './src/components/LoadingScreen';
import SplashScreen from './src/components/SplashScreen';

const Tab = createBottomTabNavigator();
const Stack = createStackNavigator();

// 主标签导航
function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName;

          if (route.name === '首页') {
            iconName = 'home';
          } else if (route.name === 'AI聊天') {
            iconName = 'chat';
          } else if (route.name === '模型管理') {
            iconName = 'settings_suggest';
          } else if (route.name === '文件') {
            iconName = 'folder';
          } else if (route.name === '训练') {
            iconName = 'auto_awesome';
          }

          return <Icon name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#007AFF',
        tabBarInactiveTintColor: 'gray',
        headerStyle: {
          backgroundColor: '#007AFF',
        },
        headerTintColor: '#fff',
        headerTitleStyle: {
          fontWeight: 'bold',
        },
      })}
    >
      <Tab.Screen name="首页" component={HomeScreen} />
      <Tab.Screen name="AI聊天" component={ChatScreen} />
      <Tab.Screen name="模型管理" component={ModelsScreen} />
      <Tab.Screen name="文件" component={FilesScreen} />
      <Tab.Screen name="训练" component={TrainingScreen} />
    </Tab.Navigator>
  );
}

// 主应用导航
function AppNavigator() {
  return (
    <Stack.Navigator initialRouteName="Splash">
      <Stack.Screen 
        name="Splash" 
        component={SplashScreen} 
        options={{ headerShown: false }}
      />
      <Stack.Screen 
        name="Login" 
        component={LoginScreen} 
        options={{ headerShown: false }}
      />
      <Stack.Screen 
        name="Main" 
        component={MainTabs} 
        options={{ headerShown: false }}
      />
      <Stack.Screen 
        name="Settings" 
        component={SettingsScreen} 
        options={{ 
          title: '设置',
          headerBackTitleVisible: false
        }}
      />
    </Stack.Navigator>
  );
}

export default function App() {
  return (
    <Provider store={store}>
      <PersistGate loading={<LoadingScreen />} persistor={persistor}>
        <NavigationContainer>
          <AppNavigator />
        </NavigationContainer>
      </PersistGate>
    </Provider>
  );
}
EOF

    # 创建AI聊天界面
    cat > "$mobile_dir/src/screens/ChatScreen.js" << 'EOF'
import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  FlatList,
  StyleSheet,
  Alert,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
  ScrollView,
  SafeAreaView
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useSelector, useDispatch } from 'react-redux';
import { useNavigation } from '@react-navigation/native';

import { sendMessage, clearMessages, setCurrentModel } from '../store/chatSlice';
import { AIService } from '../services/AIService';
import MessageItem from '../components/MessageItem';
import ModelSelector from '../components/ModelSelector';
import AttachmentButton from '../components/AttachmentButton';

export default function ChatScreen() {
  const [inputText, setInputText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [showModelSelector, setShowModelSelector] = useState(false);
  const flatListRef = useRef(null);
  
  const dispatch = useDispatch();
  const navigation = useNavigation();
  const { messages, models, currentModel } = useSelector(state => state.chat);
  const { user } = useSelector(state => state.auth);
  const { serverUrl } = useSelector(state => state.settings);

  useEffect(() => {
    // 滚动到底部
    if (messages.length > 0) {
      flatListRef.current?.scrollToEnd({ animated: true });
    }
  }, [messages]);

  // 加载模型列表
  useEffect(() => {
    const loadModels = async () => {
      try {
        const response = await AIService.getModels();
        // 可以在这里处理模型列表
      } catch (error) {
        console.error('加载模型列表失败:', error);
        Alert.alert('错误', '加载模型列表失败，请检查连接');
      }
    };

    loadModels();
  }, [serverUrl]);

  const handleSendMessage = async () => {
    if (!inputText.trim() || isLoading) return;

    const userMessage = {
      id: Date.now().toString(),
      text: inputText.trim(),
      sender: 'user',
      timestamp: new Date().toISOString</doubaocanvas>