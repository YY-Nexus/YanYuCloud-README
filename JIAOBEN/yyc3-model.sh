#!/bin/bash

# YYC AI模型集成管理系统
# 支持国内外主流大模型统一调用和管理

set -e

ROOT_DIR="/volume1/YC"
AI_DIR="$ROOT_DIR/ai-models"

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

# 创建AI模型管理目录结构
create_ai_directories() {
    log_step "创建AI模型管理目录结构..."
    
    mkdir -p "$AI_DIR"/{
        models/{local,remote,custom},
        configs,
        logs,
        cache,
        training/{datasets,models,checkpoints},
        deployment/{docker,kubernetes},
        api/{gateway,adapters},
        management/{web,api}
    }
    
    log_success "AI模型目录结构创建完成"
}

# 创建AI模型统一网关服务
create_ai_gateway() {
    log_step "创建AI模型统一网关服务..."
    
    cat > "$AI_DIR/api/gateway/server.js" << 'EOF'
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');

const app = express();
const PORT = process.env.AI_GATEWAY_PORT || 3010;

// 中间件配置
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// 模型配置存储
let modelConfigs = {};
let modelStats = {};

// 加载模型配置
async function loadModelConfigs() {
    try {
        const configPath = path.join(__dirname, '../../configs/models.json');
        const data = await fs.readFile(configPath, 'utf8');
        modelConfigs = JSON.parse(data);
        console.log('✅ 模型配置加载成功');
    } catch (error) {
        console.log('⚠️ 模型配置文件不存在，使用默认配置');
        modelConfigs = getDefaultModelConfigs();
        await saveModelConfigs();
    }
}

// 保存模型配置
async function saveModelConfigs() {
    try {
        const configPath = path.join(__dirname, '../../configs/models.json');
        await fs.writeFile(configPath, JSON.stringify(modelConfigs, null, 2));
    } catch (error) {
        console.error('❌ 保存模型配置失败:', error);
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

        // 根据提供商调用相应的适配器
        const response = await callModelAdapter(modelConfig, {
            model,
            messages,
            stream,
            ...options
        });

        res.json(response);

    } catch (error) {
        console.error('❌ 聊天请求失败:', error);
        res.status(500).json({
            error: '内部服务器错误',
            details: error.message
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
        console.error(`❌ 调用${config.name}失败:`, error.response?.data || error.message);
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
        console.error('❌ 调用本地模型失败:', error);
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

// 启动函数
create_ai_directories()
        
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
        res.status(500).json({ error: '配置更新失败', details: error.message });
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
        console.log(`🤖 AI模型网关服务启动成功`);
        console.log(`🌐 服务地址: http://0.0.0.0:${PORT}`);
        console.log(`📊 管理面板: http://0.0.0.0:${PORT}/admin`);
        console.log(`🔍 健康检查: http://0.0.0.0:${PORT}/health`);
    });
}

startServer().catch(console.error);
EOF

    log_success "AI模型统一网关服务创建完成"
}

# 创建智谱AI专项集成
create_zhipu_integration() {
    log_step "创建智谱AI专项集成..."
    
    cat > "$AI_DIR/api/adapters/zhipu-ai.js" << 'EOF'
const axios = require('axios');
const crypto = require('crypto');

class ZhipuAI {
    constructor(apiKey) {
        this.apiKey = apiKey;
        this.baseURL = 'https://open.bigmodel.cn/api/paas/v4';
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

            return response.data;

        } catch (error) {
            console.error('智谱AI调用失败:', error.response?.data || error.message);
            throw new Error(`智谱AI调用失败: ${error.response?.data?.error?.message || error.message}`);
        }
    }

    // 图像理解 (GLM-4V)
    async imageUnderstanding(params) {
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

            return response.data;

        } catch (error) {
            console.error('智谱AI图像理解失败:', error.response?.data || error.message);
            throw new Error(`智谱AI图像理解失败: ${error.response?.data?.error?.message || error.message}`);
        }
    }

    // 代码生成
    async codeGeneration(params) {
        try {
            const token = this.generateToken();
            
            const response = await axios.post(`${this.baseURL}/chat/completions`, {
                model: 'codegeex-4',
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

            return response.data;

        } catch (error) {
            console.error('智谱AI代码生成失败:', error.response?.data || error.message);
            throw new Error(`智谱AI代码生成失败: ${error.response?.data?.error?.message || error.message}`);
        }
    }

    // 文档问答
    async documentQA(params) {
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

            return response.data;

        } catch (error) {
            console.error('智谱AI文档问答失败:', error.response?.data || error.message);
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
            console.error('获取智谱AI模型列表失败:', error.response?.data || error.message);
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
                timestamp: new Date().toISOString()
            };
        } catch (error) {
            return {
                status: 'error',
                error: error.message,
                timestamp: new Date().toISOString()
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
    
    cat > "$AI_DIR/training/trainer.py" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import torch
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from transformers import (
    AutoTokenizer, 
    AutoModelForCausalLM,
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling
)
from datasets import Dataset, load_dataset
import wandb

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/volume1/YC/ai-models/logs/training.log'),
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

class CustomModelTrainer:
    """自定义模型训练器"""
    
    def __init__(self, config: TrainingConfig):
        self.config = config
        self.tokenizer = None
        self.model = None
        self.train_dataset = None
        self.eval_dataset = None
        
        # 创建输出目录
        Path(config.output_dir).mkdir(parents=True, exist_ok=True)
        
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
            
            self.model = AutoModelForCausalLM.from_pretrained(
                self.config.base_model,
                trust_remote_code=True,
                torch_dtype=torch.float16 if self.config.fp16 else torch.float32,
                device_map="auto"
            )
            
            logger.info("模型和分词器加载成功")
            
        except Exception as e:
            logger.error(f"加载模型失败: {e}")
            raise
    
    def prepare_dataset(self):
        """准备训练数据集"""
        logger.info(f"准备数据集: {self.config.dataset_path}")
        
        try:
            # 加载数据集
            if self.config.dataset_path.endswith('.json'):
                with open(self.config.dataset_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                dataset = Dataset.from_list(data)
            else:
                dataset = load_dataset(self.config.dataset_path)['train']
            
            # 数据预处理
            def preprocess_function(examples):
                # 假设数据格式为 {"input": "问题", "output": "答案"}
                texts = []
                for i in range(len(examples['input'])):
                    text = f"问题: {examples['input'][i]}\n答案: {examples['output'][i]}"
                    texts.append(text)
                
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
                output_dir=self.config.output_dir,
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
                run_name=self.config.model_name
            )
            
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
                tokenizer=self.tokenizer
            )
            
            # 开始训练
            trainer.train()
            
            # 保存最终模型
            trainer.save_model()
            self.tokenizer.save_pretrained(self.config.output_dir)
            
            # 保存训练配置
            config_path = os.path.join(self.config.output_dir, "training_config.json")
            with open(config_path, 'w', encoding='utf-8') as f:
                json.dump(self.config.__dict__, f, indent=2, ensure_ascii=False)
            
            logger.info(f"训练完成，模型保存至: {self.config.output_dir}")
            
        except Exception as e:
            logger.error(f"训练失败: {e}")
            raise
    
    def evaluate(self):
        """评估模型"""
        logger.info("开始模型评估")
        
        try:
            # 加载训练好的模型
            model = AutoModelForCausalLM.from_pretrained(self.config.output_dir)
            tokenizer = AutoTokenizer.from_pretrained(self.config.output_dir)
            
            # 简单的生成测试
            test_inputs = [
                "问题: 什么是人工智能？",
                "问题: 如何学习机器学习？",
                "问题: Python有什么优势？"
            ]
            
            results = []
            for test_input in test_inputs:
                inputs = tokenizer(test_input, return_tensors="pt")
                
                with torch.no_grad():
                    outputs = model.generate(
                        inputs.input_ids,
                        max_length=200,
                        num_return_sequences=1,
                        temperature=0.7,
                        do_sample=True,
                        pad_token_id=tokenizer.eos_token_id
                    )
                
                generated_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
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
    import argparse
    
    parser = argparse.ArgumentParser(description="自定义模型训练")
    parser.add_argument("--config", type=str, required=True, help="训练配置文件路径")
    args = parser.parse_args()
    
    # 加载配置
    with open(args.config, 'r', encoding='utf-8') as f:
        config_dict = json.load(f)
    
    config = TrainingConfig(**config_dict)
    
    # 创建训练器
    trainer = CustomModelTrainer(config)
    
    # 执行训练流程
    trainer.load_model_and_tokenizer()
    trainer.prepare_dataset()
    trainer.train()
    trainer.evaluate()
    
    logger.info("训练流程完成")

if __name__ == "__main__":
    main()
EOF

    # 创建训练配置模板
    cat > "$AI_DIR/training/config_template.json" << 'EOF'
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
    "wandb_project": "yc-custom-models"
}
EOF

    # 创建数据集示例
    cat > "$AI_DIR/training/datasets/sample_dataset.json" << 'EOF'
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
    }
]
EOF

    log_success "自定义模型训练系统创建完成"
}

# 创建移动端应用
create_mobile_app() {
    log_step "创建移动端应用..."
    
    # 创建React Native应用结构
    mkdir -p "$AI_DIR/../mobile-app"/{
        src/{components,screens,services,utils,store},
        assets/{images,fonts},
        android,
        ios
    }
    
    # 创建移动端主应用
    cat > "$AI_DIR/../mobile-app/App.js" << 'EOF'
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { Provider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import Icon from 'react-native-vector-icons/MaterialIcons';

import { store, persistor } from './src/store';
import HomeScreen from './src/screens/HomeScreen';
import ChatScreen from './src/screens/ChatScreen';
import FilesScreen from './src/screens/FilesScreen';
import SettingsScreen from './src/screens/SettingsScreen';
import LoginScreen from './src/screens/LoginScreen';
import LoadingScreen from './src/components/LoadingScreen';

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
          } else if (route.name === '文件') {
            iconName = 'folder';
          } else if (route.name === '设置') {
            iconName = 'settings';
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
      <Tab.Screen name="文件" component={FilesScreen} />
      <Tab.Screen name="设置" component={SettingsScreen} />
    </Tab.Navigator>
  );
}

// 主应用导航
function AppNavigator() {
  return (
    <Stack.Navigator initialRouteName="Login">
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
    cat > "$AI_DIR/../mobile-app/src/screens/ChatScreen.js" << 'EOF'
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
  ActivityIndicator
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useSelector, useDispatch } from 'react-redux';

import { sendMessage, clearMessages } from '../store/chatSlice';
import { AIService } from '../services/AIService';

export default function ChatScreen() {
  const [inputText, setInputText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [selectedModel, setSelectedModel] = useState('glm-4');
  const flatListRef = useRef(null);
  
  const dispatch = useDispatch();
  const { messages, models } = useSelector(state => state.chat);
  const { user } = useSelector(state => state.auth);

  useEffect(() => {
    // 滚动到底部
    if (messages.length > 0) {
      flatListRef.current?.scrollToEnd({ animated: true });
    }
  }, [messages]);

  const handleSendMessage = async () => {
    if (!inputText.trim() || isLoading) return;

    const userMessage = {
      id: Date.now().toString(),
      text: inputText.trim(),
      sender: 'user',
      timestamp: new Date().toISOString(),
      model: selectedModel
    };

    dispatch(sendMessage(userMessage));
    setInputText('');
    setIsLoading(true);

    try {
      const response = await AIService.sendMessage({
        model: selectedModel,
        messages: [
          ...messages.map(msg => ({
            role: msg.sender === 'user' ? 'user' : 'assistant',
            content: msg.text
          })),
          { role: 'user', content: userMessage.text }
        ]
      });

      const aiMessage = {
        id: (Date.now() + 1).toString(),
        text: response.choices[0].message.content,
        sender: 'assistant',
        timestamp: new Date().toISOString(),
        model: selectedModel
      };

      dispatch(sendMessage(aiMessage));

    } catch (error) {
      console.error('发送消息失败:', error);
      Alert.alert('错误', '发送消息失败，请重试');
    } finally {
      setIsLoading(false);
    }
  };

  const renderMessage = ({ item }) => (
    <View style={[
      styles.messageContainer,
      item.sender === 'user' ? styles.userMessage : styles.aiMessage
    ]}>
      <View style={[
        styles.messageBubble,
        item.sender === 'user' ? styles.userBubble : styles.aiBubble
      ]}>
        <Text style={[
          styles.messageText,
          item.sender === 'user' ? styles.userText : styles.aiText
        ]}>
          {item.text}
        </Text>
        <Text style={styles.timestamp}>
          {new Date(item.timestamp).toLocaleTimeString()}
        </Text>
        {item.model && (
          <Text style={styles.modelTag}>
            {item.model}
          </Text>
        )}
      </View>
    </View>
  );

  const renderModelSelector = () => (
    <View style={styles.modelSelector}>
      <Text style={styles.modelLabel}>AI模型:</Text>
      <TouchableOpacity
        style={styles.modelButton}
        onPress={() => {
          // 显示模型选择器
          Alert.alert(
            '选择AI模型',
            '请选择要使用的AI模型',
            [
              { text: 'GLM-4', onPress: () => setSelectedModel('glm-4') },
              { text: 'GPT-4', onPress: () => setSelectedModel('gpt-4') },
              { text: 'Claude-3', onPress: () => setSelectedModel('claude-3-sonnet') },
              { text: '通义千问', onPress: () => setSelectedModel('qwen-turbo') },
              { text: '取消', style: 'cancel' }
            ]
          );
        }}
      >
        <Text style={styles.modelButtonText}>{selectedModel}</Text>
        <Icon name="arrow-drop-down" size={20} color="#007AFF" />
      </TouchableOpacity>
    </View>
  );

  return (
    <KeyboardAvoidingView 
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      {renderModelSelector()}
      
      <FlatList
        ref={flatListRef}
        data={messages}
        renderItem={renderMessage}
        keyExtractor={item => item.id}
        style={styles.messagesList}
        contentContainerStyle={styles.messagesContainer}
      />

      <View style={styles.inputContainer}>
        <TextInput
          style={styles.textInput}
          value={inputText}
          onChangeText={setInputText}
          placeholder="输入消息..."
          multiline
          maxLength={1000}
          editable={!isLoading}
        />
        <TouchableOpacity
          style={[styles.sendButton, (!inputText.trim() || isLoading) && styles.sendButtonDisabled]}
          onPress={handleSendMessage}
          disabled={!inputText.trim() || isLoading}
        >
          {isLoading ? (
            <ActivityIndicator size="small" color="#fff" />
          ) : (
            <Icon name="send" size={24} color="#fff" />
          )}
        </TouchableOpacity>
      </View>

      <View style={styles.toolbar}>
        <TouchableOpacity
          style={styles.toolButton}
          onPress={() => dispatch(clearMessages())}
        >
          <Icon name="clear" size={20} color="#666" />
          <Text style={styles.toolButtonText}>清空</Text>
        </TouchableOpacity>
        
        <TouchableOpacity
          style={styles.toolButton}
          onPress={() => {
            // 语音输入功能
            Alert.alert('提示', '语音输入功能开发中...');
          }}
        >
          <Icon name="mic" size={20} color="#666" />
          <Text style={styles.toolButtonText}>语音</Text>
        </TouchableOpacity>
        
        <TouchableOpacity
          style={styles.toolButton}
          onPress={() => {
            // 图片上传功能
            Alert.alert('提示', '图片上传功能开发中...');
          }}
        >
          <Icon name="image" size={20} color="#666" />
          <Text style={styles.toolButtonText}>图片</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  modelSelector: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 10,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  modelLabel: {
    fontSize: 14,
    color: '#666',
    marginRight: 10,
  },
  modelButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: '#f0f0f0',
    borderRadius: 16,
  },
  modelButtonText: {
    fontSize: 14,
    color: '#007AFF',
    marginRight: 4,
  },
  messagesList: {
    flex: 1,
  },
  messagesContainer: {
    padding: 16,
  },
  messageContainer: {
    marginBottom: 16,
  },
  userMessage: {
    alignItems: 'flex-end',
  },
  aiMessage: {
    alignItems: 'flex-start',
  },
  messageBubble: {
    maxWidth: '80%',
    padding: 12,
    borderRadius: 18,
  },
  userBubble: {
    backgroundColor: '#007AFF',
  },
  aiBubble: {
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  messageText: {
    fontSize: 16,
    lineHeight: 22,
  },
  userText: {
    color: '#fff',
  },
  aiText: {
    color: '#333',
  },
  timestamp: {
    fontSize: 12,
    color: '#999',
    marginTop: 4,
  },
  modelTag: {
    fontSize: 10,
    color: '#666',
    marginTop: 2,
    fontStyle: 'italic',
  },
  inputContainer: {
    flexDirection: 'row',
    padding: 16,
    backgroundColor: '#fff',
    alignItems: 'flex-end',
  },
  textInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 10,
    fontSize: 16,
    maxHeight: 100,
    marginRight: 12,
  },
  sendButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  sendButtonDisabled: {
    backgroundColor: '#ccc',
  },
  toolbar: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    padding: 12,
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
  },
  toolButton: {
    alignItems: 'center',
    padding: 8,
  },
  toolButtonText: {
    fontSize: 12,
    color: '#666',
    marginTop: 4,
  },
});
EOF

    # 创建AI服务
    cat > "$AI_DIR/../mobile-app/src/services/AIService.js" << 'EOF'
import AsyncStorage from '@react-native-async-storage/async-storage';

class AIService {
  constructor() {
    this.baseURL = 'http://192.168.0.9:3010'; // AI网关地址
    this.timeout = 30000;
  }

  async getAuthToken() {
    try {
      return await AsyncStorage.getItem('authToken');
    } catch (error) {
      console.error('获取认证令牌失败:', error);
      return null;
    }
  }

  async request(endpoint, options = {}) {
    const token = await this.getAuthToken();
    
    const config = {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...(token && { 'Authorization': `Bearer ${token}` }),
        ...options.headers,
      },
      timeout: this.timeout,
      ...options,
    };

    if (config.body && typeof config.body === 'object') {
      config.body = JSON.stringify(config.body);
    }

    try {
      const response = await fetch(`${this.baseURL}${endpoint}`, config);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.error || `HTTP ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('API请求失败:', error);
      throw error;
    }
  }

  // 发送聊天消息
  async sendMessage(params) {
    return await this.request('/api/chat', {
      method: 'POST',
      body: params,
    });
  }

  // 获取可用模型列表
  async getModels() {
    return await this.request('/api/models');
  }

  // 获取模型统计信息
  async getStats() {
    return await this.request('/api/stats');
  }

  // 图像理解
  async imageUnderstanding(params) {
    return await this.request('/api/image/understand', {
      method: 'POST',
      body: params,
    });
  }

  // 代码生成
  async generateCode(params) {
    return await this.request('/api/code/generate', {
      method: 'POST',
      body: params,
    });
  }

  // 文档问答
  async documentQA(params) {
    return await this.request('/api/document/qa', {
      method: 'POST',
      body: params,
    });
  }

  // 语音转文字
  async speechToText(audioData) {
    const formData = new FormData();
    formData.append('audio', {
      uri: audioData.uri,
      type: 'audio/wav',
      name: 'audio.wav',
    });

    return await this.request('/api/speech/to-text', {
      method: 'POST',
      body: formData,
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  }

  // 文字转语音
  async textToSpeech(text, voice = 'default') {
    return await this.request('/api/speech/to-speech', {
      method: 'POST',
      body: { text, voice },
    });
  }

  // 健康检查
  async healthCheck() {
    return await this.request('/health');
  }
}

export default new AIService();
EOF

    # 创建文件管理界面
    cat > "$AI_DIR/../mobile-app/src/screens/FilesScreen.js" << 'EOF'
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  Alert,
  RefreshControl,
  Modal,
  TextInput,
  ActivityIndicator
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import DocumentPicker from 'react-native-document-picker';
import { useSelector, useDispatch } from 'react-redux';

import { FileService } from '../services/FileService';
import { loadFiles, uploadFile, deleteFile } from '../store/filesSlice';

export default function FilesScreen() {
  const [refreshing, setRefreshing] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [showCreateFolder, setShowCreateFolder] = useState(false);
  const [folderName, setFolderName] = useState('');
  const [currentPath, setCurrentPath] = useState('/');

  const dispatch = useDispatch();
  const { files, loading } = useSelector(state => state.files);

  useEffect(() => {
    loadFileList();
  }, [currentPath]);

  const loadFileList = async () => {
    try {
      dispatch(loadFiles({ path: currentPath }));
    } catch (error) {
      Alert.alert('错误', '加载文件列表失败');
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadFileList();
    setRefreshing(false);
  };

  const handleUploadFile = async () => {
    try {
      const result = await DocumentPicker.pick({
        type: [DocumentPicker.types.allFiles],
        allowMultiSelection: true,
      });

      setUploading(true);

      for (const file of result) {
        await dispatch(uploadFile({
          file,
          path: currentPath,
        }));
      }

      await loadFileList();
      Alert.alert('成功', '文件上传完成');

    } catch (error) {
      if (!DocumentPicker.isCancel(error)) {
        Alert.alert('错误', '文件上传失败');
      }
    } finally {
      setUploading(false);
    }
  };

  const handleCreateFolder = async () => {
    if (!folderName.trim()) {
      Alert.alert('错误', '请输入文件夹名称');
      return;
    }

    try {
      await FileService.createFolder({
        name: folderName.trim(),
        path: currentPath,
      });

      setShowCreateFolder(false);
      setFolderName('');
      await loadFileList();
      Alert.alert('成功', '文件夹创建成功');

    } catch (error) {
      Alert.alert('错误', '文件夹创建失败');
    }
  };

  const handleDeleteFile = (file) => {
    Alert.alert(
      '确认删除',
      `确定要删除 "${file.name}" 吗？`,
      [
        { text: '取消', style: 'cancel' },
        {
          text: '删除',
          style: 'destructive',
          onPress: async () => {
            try {
              await dispatch(deleteFile({ id: file.id }));
              await loadFileList();
              Alert.alert('成功', '文件删除成功');
            } catch (error) {
              Alert.alert('错误', '文件删除失败');
            }
          },
        },
      ]
    );
  };

  const handleFilePress = (file) => {
    if (file.type === 'folder') {
      setCurrentPath(`${currentPath}${file.name}/`);
    } else {
      // 预览或下载文件
      Alert.alert(
        file.name,
        '选择操作',
        [
          { text: '预览', onPress: () => previewFile(file) },
          { text: '下载', onPress: () => downloadFile(file) },
          { text: '分享', onPress: () => shareFile(file) },
          { text: '取消', style: 'cancel' },
        ]
      );
    }
  };

  const previewFile = (file) => {
    // 实现文件预览
    Alert.alert('提示', '文件预览功能开发中...');
  };

  const downloadFile = (file) => {
    // 实现文件下载
    Alert.alert('提示', '文件下载功能开发中...');
  };

  const shareFile = (file) => {
    // 实现文件分享
    Alert.alert('提示', '文件分享功能开发中...');
  };

  const goBack = () => {
    if (currentPath !== '/') {
      const pathParts = currentPath.split('/').filter(Boolean);
      pathParts.pop();
      setCurrentPath(pathParts.length > 0 ? `/${pathParts.join('/')}/` : '/');
    }
  };

  const getFileIcon = (file) => {
    if (file.type === 'folder') {
      return 'folder';
    }
    
    const extension = file.name.split('.').pop().toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'movie';
      case 'mp3':
      case 'wav':
      case 'flac':
        return 'music-note';
      case 'pdf':
        return 'picture-as-pdf';
      case 'doc':
      case 'docx':
        return 'description';
      case 'xls':
      case 'xlsx':
        return 'table-chart';
      case 'zip':
      case 'rar':
      case '7z':
        return 'archive';
      default:
        return 'insert-drive-file';
    }
  };

  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const renderFile = ({ item }) => (
    <TouchableOpacity
      style={styles.fileItem}
      onPress={() => handleFilePress(item)}
      onLongPress={() => handleDeleteFile(item)}
    >
      <Icon
        name={getFileIcon(item)}
        size={40}
        color={item.type === 'folder' ? '#FFA500' : '#666'}
        style={styles.fileIcon}
      />
      <View style={styles.fileInfo}>
        <Text style={styles.fileName} numberOfLines={2}>
          {item.name}
        </Text>
        <Text style={styles.fileDetails}>
          {item.type === 'folder' ? '文件夹' : formatFileSize(item.size)}
          {' • '}
          {new Date(item.modified).toLocaleDateString()}
        </Text>
      </View>
      <TouchableOpacity
        style={styles.moreButton}
        onPress={() => handleDeleteFile(item)}
      >
        <Icon name="more-vert" size={24} color="#666" />
      </TouchableOpacity>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      {/* 路径导航 */}
      <View style={styles.pathBar}>
        {currentPath !== '/' && (
          <TouchableOpacity style={styles.backButton} onPress={goBack}>
            <Icon name="arrow-back" size={24} color="#007AFF" />
          </TouchableOpacity>
        )}
        <Text style={styles.pathText}>{currentPath}</Text>
      </View>

      {/* 文件列表 */}
      <FlatList
        data={files}
        renderItem={renderFile}
        keyExtractor={item => item.id}
        style={styles.filesList}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
        }
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Icon name="folder-open" size={64} color="#ccc" />
            <Text style={styles.emptyText}>此文件夹为空</Text>
          </View>
        }
      />

      {/* 操作按钮 */}
      <View style={styles.actionButtons}>
        <TouchableOpacity
          style={styles.actionButton}
          onPress={handleUploadFile}
          disabled={uploading}
        >
          {uploading ? (
            <ActivityIndicator size="small" color="#fff" />
          ) : (
            <Icon name="cloud-upload" size={24} color="#fff" />
          )}
          <Text style={styles.actionButtonText}>
            {uploading ? '上传中...' : '上传'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.actionButton}
          onPress={() => setShowCreateFolder(true)}
        >
          <Icon name="create-new-folder" size={24} color="#fff" />
          <Text style={styles.actionButtonText}>新建文件夹</Text>
        </TouchableOpacity>
      </View>

      {/* 创建文件夹模态框 */}
      <Modal
        visible={showCreateFolder}
        transparent
        animationType="slide"
        onRequestClose={() => setShowCreateFolder(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>新建文件夹</Text>
            <TextInput
              style={styles.modalInput}
              value={folderName}
              onChangeText={setFolderName}
              placeholder="输入文件夹名称"
              autoFocus
            />
            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalButton, styles.cancelButton]}
                onPress={() => {
                  setShowCreateFolder(false);
                  setFolderName('');
                }}
              >
                <Text style={styles.cancelButtonText}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, styles.confirmButton]}
                onPress={handleCreateFolder}
              >
                <Text style={styles.confirmButtonText}>创建</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  pathBar: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  backButton: {
    marginRight: 12,
  },
  pathText: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  filesList: {
    flex: 1,
  },
  fileItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  fileIcon: {
    marginRight: 16,
  },
  fileInfo: {
    flex: 1,
  },
  fileName: {
    fontSize: 16,
    color: '#333',
    fontWeight: '500',
  },
  fileDetails: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  moreButton: {
    padding: 8,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: 100,
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    marginTop: 16,
  },
  actionButtons: {
    flexDirection: 'row',
    padding: 16,
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#007AFF',
    paddingVertical: 12,
    borderRadius: 8,
    marginHorizontal: 4,
  },
  actionButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '500',
    marginLeft: 8,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 24,
    width: '80%',
    maxWidth: 300,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 20,
  },
  modalInput: {
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    marginBottom: 20,
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  modalButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    marginHorizontal: 4,
  },
  cancelButton: {
    backgroundColor: '#f0f0f0',
  },
  confirmButton: {
    backgroundColor: '#007AFF',
  },
  cancelButtonText: {
    color: '#666',
    textAlign: 'center',
    fontSize: 16,
  },
  confirmButtonText: {
    color: '#fff',
    textAlign: 'center',
    fontSize: 16,
    fontWeight: '500',
  },
});
EOF

    # 创建移动端协作功能
    cat > "$AI_DIR/../mobile-app/src/screens/CollaborationScreen.js" << 'EOF'
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Modal,
  TextInput,
  Switch,
  ActivityIndicator
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useSelector, useDispatch } from 'react-redux';

import { CollaborationService } from '../services/CollaborationService';

export default function CollaborationScreen() {
  const [projects, setProjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showCreateProject, setShowCreateProject] = useState(false);
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [selectedProject, setSelectedProject] = useState(null);
  const [projectName, setProjectName] = useState('');
  const [projectDescription, setProjectDescription] = useState('');
  const [inviteEmail, setInviteEmail] = useState('');
  const [isPublic, setIsPublic] = useState(false);

  const { user } = useSelector(state => state.auth);

  useEffect(() => {
    loadProjects();
  }, []);

  const loadProjects = async () => {
    try {
      setLoading(true);
      const response = await CollaborationService.getProjects();
      setProjects(response.projects || []);
    } catch (error) {
      Alert.alert('错误', '加载项目列表失败');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateProject = async () => {
    if (!projectName.trim()) {
      Alert.alert('错误', '请输入项目名称');
      return;
    }

    try {
      await CollaborationService.createProject({
        name: projectName.trim(),
        description: projectDescription.trim(),
        isPublic,
      });

      setShowCreateProject(false);
      setProjectName('');
      setProjectDescription('');
      setIsPublic(false);
      await loadProjects();
      Alert.alert('成功', '项目创建成功');

    } catch (error) {
      Alert.alert('错误', '项目创建失败');
    }
  };

  const handleInviteMember = async () => {
    if (!inviteEmail.trim()) {
      Alert.alert('错误', '请输入邮箱地址');
      return;
    }

    try {
      await CollaborationService.inviteMember({
        projectId: selectedProject.id,
        email: inviteEmail.trim(),
      });

      setShowInviteModal(false);
      setInviteEmail('');
      Alert.alert('成功', '邀请已发送');

    } catch (error) {
      Alert.alert('错误', '发送邀请失败');
    }
  };

  const handleJoinProject = async (project) => {
    try {
      await CollaborationService.joinProject(project.id);
      await loadProjects();
      Alert.alert('成功', '已加入项目');
    } catch (error) {
      Alert.alert('错误', '加入项目失败');
    }
  };

  const handleLeaveProject = async (project) => {
    Alert.alert(
      '确认退出',
      `确定要退出项目 "${project.name}" 吗？`,
      [
        { text: '取消', style: 'cancel' },
        {
          text: '退出',
          style: 'destructive',
          onPress: async () => {
            try {
              await CollaborationService.leaveProject(project.id);
              await loadProjects();
              Alert.alert('成功', '已退出项目');
            } catch (error) {
              Alert.alert('错误', '退出项目失败');
            }
          },
        },
      ]
    );
  };

  const renderProject = ({ item }) => (
    <View style={styles.projectCard}>
      <View style={styles.projectHeader}>
        <View style={styles.projectInfo}>
          <Text style={styles.projectName}>{item.name}</Text>
          <Text style={styles.projectDescription}>{item.description}</Text>
        </View>
        <View style={styles.projectStatus}>
          {item.isPublic && (
            <Icon name="public" size={16} color="#4CAF50" />
          )}
          {item.role === 'owner' && (
            <Icon name="star" size={16} color="#FFC107" />
          )}
        </View>
      </View>

      <View style={styles.projectStats}>
        <View style={styles.stat}>
          <Icon name="people" size={16} color="#666" />
          <Text style={styles.statText}>{item.memberCount} 成员</Text>
        </View>
        <View style={styles.stat}>
          <Icon name="folder" size={16} color="#666" />
          <Text style={styles.statText}>{item.fileCount} 文件</Text>
        </View>
        <View style={styles.stat}>
          <Icon name="access-time" size={16} color="#666" />
          <Text style={styles.statText}>
            {new Date(item.lastActivity).toLocaleDateString()}
          </Text>
        </View>
      </View>

      <View style={styles.projectActions}>
        <TouchableOpacity
          style={styles.actionButton}
          onPress={() => {
            // 进入项目详情
            Alert.alert('提示', '项目详情功能开发中...');
          }}
        >
          <Icon name="open-in-new" size={20} color="#007AFF" />
          <Text style={styles.actionButtonText}>打开</Text>
        </TouchableOpacity>

        {item.role === 'owner' && (
          <TouchableOpacity
            style={styles.actionButton}
            onPress={() => {
              setSelectedProject(item);
              setShowInviteModal(true);
            }}
          >
            <Icon name="person-add" size={20} color="#4CAF50" />
            <Text style={styles.actionButtonText}>邀请</Text>
          </TouchableOpacity>
        )}

        {item.role !== 'owner' && (
          <TouchableOpacity
            style={styles.actionButton}
            onPress={() => handleLeaveProject(item)}
          >
            <Icon name="exit-to-app" size={20} color="#F44336" />
            <Text style={styles.actionButtonText}>退出</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#007AFF" />
        <Text style={styles.loadingText}>加载中...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>协作项目</Text>
        <TouchableOpacity
          style={styles.createButton}
          onPress={() => setShowCreateProject(true)}
        >
          <Icon name="add" size={24} color="#fff" />
        </TouchableOpacity>
      </View>

      <FlatList
        data={projects}
        renderItem={renderProject}
        keyExtractor={item => item.id}
        style={styles.projectsList}
        contentContainerStyle={styles.projectsContainer}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Icon name="group-work" size={64} color="#ccc" />
            <Text style={styles.emptyText}>暂无协作项目</Text>
            <TouchableOpacity
              style={styles.emptyButton}
              onPress={() => setShowCreateProject(true)}
            >
              <Text style={styles.emptyButtonText}>创建第一个项目</Text>
            </TouchableOpacity>
          </View>
        }
      />

      {/* 创建项目模态框 */}
      <Modal
        visible={showCreateProject}
        transparent
        animationType="slide"
        onRequestClose={() => setShowCreateProject(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>创建新项目</Text>
            
            <TextInput
              style={styles.modalInput}
              value={projectName}
              onChangeText={setProjectName}
              placeholder="项目名称"
              autoFocus
            />
            
            <TextInput
              style={[styles.modalInput, styles.textArea]}
              value={projectDescription}
              onChangeText={setProjectDescription}
              placeholder="项目描述（可选）"
              multiline
              numberOfLines={3}
            />

            <View style={styles.switchContainer}>
              <Text style={styles.switchLabel}>公开项目</Text>
              <Switch
                value={isPublic}
                onValueChange={setIsPublic}
                trackColor={{ false: '#767577', true: '#81b0ff' }}
                thumbColor={isPublic ? '#007AFF' : '#f4f3f4'}
              />
            </View>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalButton, styles.cancelButton]}
                onPress={() => {
                  setShowCreateProject(false);
                  setProjectName('');
                  setProjectDescription('');
                  setIsPublic(false);
                }}
              >
                <Text style={styles.cancelButtonText}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, styles.confirmButton]}
                onPress={handleCreateProject}
              >
                <Text style={styles.confirmButtonText}>创建</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* 邀请成员模态框 */}
      <Modal
        visible={showInviteModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowInviteModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>邀请成员</Text>
            <Text style={styles.modalSubtitle}>
              邀请新成员加入 "{selectedProject?.name}"
            </Text>
            
            <TextInput
              style={styles.modalInput}
              value={inviteEmail}
              onChangeText={setInviteEmail}
              placeholder="输入邮箱地址"
              keyboardType="email-address"
              autoCapitalize="none"
              autoFocus
            />

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalButton, styles.cancelButton]}
                onPress={() => {
                  setShowInviteModal(false);
                  setInviteEmail('');
                }}
              >
                <Text style={styles.cancelButtonText}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, styles.confirmButton]}
                onPress={handleInviteMember}
              >
                <Text style={styles.confirmButtonText}>发送邀请</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
  },
  createButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  projectsList: {
    flex: 1,
  },
  projectsContainer: {
    padding: 16,
  },
  projectCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  projectHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  projectInfo: {
    flex: 1,
  },
  projectName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  projectDescription: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
  },
  projectStatus: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  projectStats: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  stat: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statText: {
    fontSize: 12,
    color: '#666',
    marginLeft: 4,
  },
  projectActions: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    borderTopWidth: 1,
    borderTopColor: '#f0f0f0',
    paddingTop: 12,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  actionButtonText: {
    fontSize: 14,
    marginLeft: 4,
    fontWeight: '500',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: 100,
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    marginTop: 16,
    marginBottom: 24,
  },
  emptyButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  emptyButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '500',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 24,
    width: '90%',
    maxWidth: 400,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 8,
  },
  modalSubtitle: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    marginBottom: 20,
  },
  modalInput: {
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    marginBottom: 16,
  },
  textArea: {
    height: 80,
    textAlignVertical: 'top',
  },
  switchContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  switchLabel: {
    fontSize: 16,
    color: '#333',
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  modalButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    marginHorizontal: 4,
  },
  cancelButton: {
    backgroundColor: '#f0f0f0',
  },
  confirmButton: {
    backgroundColor: '#007AFF',
  },
  cancelButtonText: {
    color: '#666',
    textAlign: 'center',
    fontSize: 16,
  },
  confirmButtonText: {
    color: '#fff',
    textAlign: 'center',
    fontSize: 16,
    fontWeight: '500',
  },
});
EOF

    # 创建移动端package.json
    cat > "$AI_DIR/../mobile-app/package.json" << 'EOF'
{
  "name": "YYC3MobileApp",
  "version": "1.0.0",
  "description": "YYC³ NAS移动端应用",
  "main": "index.js",
  "scripts": {
    "android": "react-native run-android",
    "ios": "react-native run-ios",
    "start": "react-native start",
    "test": "jest",
    "lint": "eslint .",
    "build:android": "cd android && ./gradlew assembleRelease",
    "build:ios": "cd ios && xcodebuild -workspace YYC3MobileApp.xcworkspace -scheme YYC3MobileApp -configuration Release -destination generic/platform=iOS -archivePath YYC3MobileApp.xcarchive archive"
  },
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.72.6",
    "@react-navigation/native": "^6.1.9",
    "@react-navigation/bottom-tabs": "^6.5.11",
    "@react-navigation/stack": "^6.3.20",
    "react-native-screens": "^3.27.0",
    "react-native-safe-area-context": "^4.7.4",
    "react-native-gesture-handler": "^2.13.4",
    "react-native-vector-icons": "^10.0.2",
    "@reduxjs/toolkit": "^1.9.7",
    "react-redux": "^8.1.3",
    "redux-persist": "^6.0.0",
    "@react-native-async-storage/async-storage": "^1.19.5",
    "react-native-document-picker": "^9.1.1",
    "react-native-image-picker": "^7.0.3",
    "react-native-permissions": "^3.10.1",
    "react-native-fs": "^2.20.0",
    "react-native-share": "^9.4.1",
    "react-native-audio-recorder-player": "^3.6.2",
    "react-native-video": "^5.2.1",
    "react-native-pdf": "^6.7.3",
    "react-native-webview": "^13.6.3",
    "react-native-reanimated": "^3.5.4",
    "react-native-svg": "^13.14.0"
  },
  "devDependencies": {
    "@babel/core": "^7.20.0",
    "@babel/preset-env": "^7.20.0",
    "@babel/runtime": "^7.20.0",
    "@react-native/eslint-config": "^0.72.2",
    "@react-native/metro-config": "^0.72.11",
    "@tsconfig/react-native": "^3.0.0",
    "@types/react": "^18.0.24",
    "@types/react-test-renderer": "^18.0.0",
    "babel-jest": "^29.2.1",
    "eslint": "^8.19.0",
    "jest": "^29.2.1",
    "metro-react-native-babel-preset": "0.76.8",
    "prettier": "^2.4.1",
    "react-test-renderer": "18.2.0",
    "typescript": "4.8.4"
  },
  "engines": {
    "node": ">=16"
  }
}
EOF

    log_success "移动端应用创建完成"
}

# 创建AI模型管理后台
create_ai_management_dashboard() {
    log_step "创建AI模型管理后台..."
    
    cat > "$AI_DIR/management/web/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>YC AI模型管理后台</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            color: #333;
        }

        .header {
            background: #fff;
            padding: 1rem 2rem;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .logo {
            font-size: 1.5rem;
            font-weight: bold;
            color: #007AFF;
        }

        .nav {
            display: flex;
            gap: 2rem;
        }

        .nav-item {
            padding: 0.5rem 1rem;
            border-radius: 6px;
            cursor: pointer;
            transition: background 0.2s;
        }

        .nav-item:hover {
            background: #f0f0f0;
        }

        .nav-item.active {
            background: #007AFF;
            color: white;
        }

        .container {
            max-width: 1200px;
            margin: 2rem auto;
            padding: 0 2rem;
        }

        .card {
            background: white;
            border-radius: 12px;
            padding: 1.5rem;
            margin-bottom: 1.5rem;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }

        .card-title {
            font-size: 1.25rem;
            font-weight: 600;
            margin-bottom: 1rem;
            color: #333;
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 1.5rem;
            border-radius: 12px;
            text-align: center;
        }

        .stat-value {
            font-size: 2rem;
            font-weight: bold;
            margin-bottom: 0.5rem;
        }

        .stat-label {
            opacity: 0.9;
            font-size: 0.9rem;
        }

        .model-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 1rem;
        }

        .model-card {
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 1rem;
            transition: transform 0.2s, box-shadow 0.2s;
        }

        .model-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }

        .model-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 0.5rem;
        }

        .model-name {
            font-weight: 600;
            color: #333;
        }

        .model-status {
            padding: 0.25rem 0.5rem;
            border-radius: 12px;
            font-size: 0.75rem;
            font-weight: 500;
        }

        .status-online {
            background: #d4edda;
            color: #155724;
        }

        .status-offline {
            background: #f8d7da;
            color: #721c24;
        }

        .model-info {
            font-size: 0.9rem;
            color: #666;
            margin-bottom: 1rem;
        }

        .model-actions {
            display: flex;
            gap: 0.5rem;
        }

        .btn {
            padding: 0.5rem 1rem;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.9rem;
            transition: background 0.2s;
        }

        .btn-primary {
            background: #007AFF;
            color: white;
        }

        .btn-primary:hover {
            background: #0056b3;
        }

        .btn-secondary {
            background: #6c757d;
            color: white;
        }

        .btn-secondary:hover {
            background: #545b62;
        }

        .btn-danger {
            background: #dc3545;
            color: white;
        }

        .btn-danger:hover {
            background: #c82333;
        }

        .form-group {
            margin-bottom: 1rem;
        }

        .form-label {
            display: block;
            margin-bottom: 0.5rem;
            font-weight: 500;
        }

        .form-input {
            width: 100%;
            padding: 0.75rem;
            border: 1px solid #ddd;
            border-radius: 6px;
            font-size: 1rem;
        }

        .form-input:focus {
            outline: none;
            border-color: #007AFF;
            box-shadow: 0 0 0 3px rgba(0, 122, 255, 0.1);
        }

        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            z-index: 1000;
        }

        .modal-content {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: white;
            border-radius: 12px;
            padding: 2rem;
            width: 90%;
            max-width: 500px;
        }

        .modal-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1.5rem;
        }

        .modal-title {
            font-size: 1.25rem;
            font-weight: 600;
        }

        .close-btn {
            background: none;
            border: none;
            font-size: 1.5rem;
            cursor: pointer;
            color: #666;
        }

        .loading {
            text-align: center;
            padding: 2rem;
        }

        .spinner {
            border: 3px solid #f3f3f3;
            border-top: 3px solid #007AFF;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 1rem;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        .hidden {
            display: none;
        }

        .alert {
            padding: 1rem;
            border-radius: 6px;
            margin-bottom: 1rem;
        }

        .alert-success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }

        .alert-error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="logo">🤖 YC AI模型管理</div>
        <nav class="nav">
            <div class="nav-item active" data-tab="dashboard">仪表板</div>
            <div class="nav-item" data-tab="models">模型管理</div>
            <div class="nav-item" data-tab="training">模型训练</div>
            <div class="nav-item" data-tab="settings">系统设置</div>
        </nav>
    </div>

    <div class="container">
        <!-- 仪表板 -->
        <div id="dashboard" class="tab-content">
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-value" id="totalModels">-</div>
                    <div class="stat-label">总模型数</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="onlineModels">-</div>
                    <div class="stat-label">在线模型</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="totalRequests">-</div>
                    <div class="stat-label">总请求数</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="avgResponseTime">-</div>
                    <div class="stat-label">平均响应时间</div>
                </div>
            </div>

            <div class="card">
                <div class="card-title">系统状态</div>
                <div id="systemStatus">
                    <div class="loading">
                        <div class="spinner"></div>
                        <div>加载中...</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- 模型管理 -->
        <div id="models" class="tab-content hidden">
            <div class="card">
                <div class="card-title">
                    模型列表
                    <button class="btn btn-primary" onclick="showAddModelModal()" style="float: right;">
                        添加模型
                    </button>
                </div>
                <div id="modelsList">
                    <div class="loading">
                        <div class="spinner"></div>
                        <div>加载模型列表...</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- 模型训练 -->
        <div id="training" class="tab-content hidden">
            <div class="card">
                <div class="card-title">自定义模型训练</div>
                <form id="trainingForm">
                    <div class="form-group">
                        <label class="form-label">模型名称</label>
                        <input type="text" class="form-input" name="modelName" placeholder="输入模型名称" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label">基础模型</label>
                        <select class="form-input" name="baseModel" required>
                            <option value="">选择基础模型</option>
                            <option value="Qwen/Qwen2-1.5B-Instruct">Qwen2-1.5B-Instruct</option>
                            <option value="Qwen/Qwen2-7B-Instruct">Qwen2-7B-Instruct</option>
                            <option value="microsoft/DialoGPT-medium">DialoGPT-medium</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">训练数据集</label>
                        <input type="file" class="form-input" name="dataset" accept=".json,.csv" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label">训练轮数</label>
                        <input type="number" class="form-input" name="epochs" value="3" min="1" max="10">
                    </div>
                    <div class="form-group">
                        <label class="form-label">学习率</label>
                        <input type="number" class="form-input" name="learningRate" value="0.00002" step="0.00001" min="0.00001" max="0.001">
                    </div>
                    <button type="submit" class="btn btn-primary">开始训练</button>
                </form>
            </div>

            <div class="card">
                <div class="card-title">训练任务</div>
                <div id="trainingJobs">
                    <div class="loading">
                        <div class="spinner"></div>
                        <div>加载训练任务...</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- 系统设置 -->
        <div id="settings" class="tab-content hidden">
            <div class="card">
                <div class="card-title">API配置</div>
                <form id="settingsForm">
                    <div class="form-group">
                        <label class="form-label">智谱AI API Key</label>
                        <input type="password" class="form-input" name="zhipuApiKey" placeholder="输入智谱AI API Key">
                    </div>
                    <div class="form-group">
                        <label class="form-label">OpenAI API Key</label>
                        <input type="password" class="form-input" name="openaiApiKey" placeholder="输入OpenAI API Key">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Claude API Key</label>
                        <input type="password" class="form-input" name="claudeApiKey" placeholder="输入Claude API Key">
                    </div>
                    <div class="form-group">
                        <label class="form-label">通义千问API Key</label>
                        <input type="password" class="form-input" name="qwenApiKey" placeholder="输入通义千问API Key">
                    </div>
                    <button type="submit" class="btn btn-primary">保存配置</button>
                </form>
            </div>
        </div>
    </div>

    <!-- 添加模型模态框 -->
    <div id="addModelModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <div class="modal-title">添加新模型</div>
                <button class="close-btn" onclick="hideAddModelModal()">&times;</button>
            </div>
            <form id="addModelForm">
                <div class="form-group">
                    <label class="form-label">模型名称</label>
                    <input type="text" class="form-input" name="name" required>
                </div>
                <div class="form-group">
                    <label class="form-label">提供商</label>
                    <select class="form-input" name="provider" required>
                        <option value="">选择提供商</option>
                        <option value="zhipu-ai">智谱AI</option>
                        <option value="openai">OpenAI</option>
                        <option value="claude">Claude</option>
                        <option value="qwen">通义千问</option>
                        <option value="ollama">本地Ollama</option>
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">API端点</label>
                    <input type="url" class="form-input" name="endpoint" required>
                </div>
                <div class="form-group">
                    <label class="form-label">API密钥</label>
                    <input type="password" class="form-input" name="apiKey">
                </div>
                <div style="text-align: right;">
                    <button type="button" class="btn btn-secondary" onclick="hideAddModelModal()">取消</button>
                    <button type="submit" class="btn btn-primary">添加</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        // 全局变量
        let currentTab = 'dashboard';
        let models = [];
        let stats = {};

        // 初始化
        document.addEventListener('DOMContentLoaded', function() {
            initTabs();
            loadDashboard();
        });

        // 标签页切换
        function initTabs() {
            document.querySelectorAll('.nav-item').forEach(item => {
                item.addEventListener('click', function() {
                    const tab = this.dataset.tab;
                    switchTab(tab);
                });
            });
        }

        function switchTab(tab) {
            // 更新导航状态
            document.querySelectorAll('.nav-item').forEach(item => {
                item.classList.remove('active');
            });
            document.querySelector(`[data-tab="${tab}"]`).classList.add('active');

            // 显示对应内容
            document.querySelectorAll('.tab-content').forEach(content => {
                content.classList.add('hidden');
            });
            document.getElementById(tab).classList.remove('hidden');

            currentTab = tab;

            // 加载对应数据
            switch(tab) {
                case 'dashboard':
                    loadDashboard();
                    break;
                case 'models':
                    loadModels();
                    break;
                case 'training':
                    loadTrainingJobs();
                    break;
                case 'settings':
                    loadSettings();
                    break;
            }
        }

        // 加载仪表板数据
        async function loadDashboard() {
            try {
                const response = await fetch('/api/stats');
                const data = await response.json();
                
                document.getElementById('totalModels').textContent = data.models || 0;
                document.getElementById('onlineModels').textContent = data.providers || 0;
                document.getElementById('totalRequests').textContent = data.totalRequests || 0;
                document.getElementById('avgResponseTime').textContent = data.avgResponseTime || '0ms';

                // 显示系统状态
                const statusHtml = `
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
                        <div style="padding: 1rem; border: 1px solid #e0e0e0; border-radius: 8px;">
                            <div style="font-weight: 600; margin-bottom: 0.5rem;">系统运行时间</div>
                            <div>${formatUptime(data.uptime)}</div>
                        </div>
                        <div style="padding: 1rem; border: 1px solid #e0e0e0; border-radius: 8px;">
                            <div style="font-weight: 600; margin-bottom: 0.5rem;">内存使用</div>
                            <div>正常</div>
                        </div>
                        <div style="padding: 1rem; border: 1px solid #e0e0e0; border-radius: 8px;">
                            <div style="font-weight: 600; margin-bottom: 0.5rem;">网络状态</div>
                            <div style="color: #28a745;">良好</div>
                        </div>
                    </div>
                `;
                document.getElementById('systemStatus').innerHTML = statusHtml;

            } catch (error) {
                console.error('加载仪表板数据失败:', error);
                showAlert('加载仪表板数据失败', 'error');
            }
        }

        // 加载模型列表
        async function loadModels() {
            try {
                const response = await fetch('/api/admin/configs');
                const configs = await response.json();
                
                let html = '<div class="model-grid">';
                
                for (const [key, config] of Object.entries(configs)) {
                    const status = config.enabled ? 'online' : 'offline';
                    const statusClass = config.enabled ? 'status-online' : 'status-offline';
                    const statusText = config.enabled ? '在线' : '离线';
                    
                    html += `
                        <div class="model-card">
                            <div class="model-header">
                                <div class="model-name">${config.name}</div>
                                <div class="model-status ${statusClass}">${statusText}</div>
                            </div>
                            <div class="model-info">
                                类型: ${config.type}<br>
                                模型数: ${config.models.length}<br>
                                端点: ${config.endpoint}
                            </div>
                            <div class="model-actions">
                                <button class="btn btn-primary" onclick="testModel('${key}')">测试</button>
                                <button class="btn btn-secondary" onclick="editModel('${key}')">编辑</button>
                                <button class="btn ${config.enabled ? 'btn-danger' : 'btn-primary'}" 
                                        onclick="toggleModel('${key}', ${!config.enabled})">
                                    ${config.enabled ? '禁用' : '启用'}
                                </button>
                            </div>
                        </div>
                    `;
                }
                
                html += '</div>';
                document.getElementById('modelsList').innerHTML = html;

            } catch (error) {
                console.error('加载模型列表失败:', error);
                showAlert('加载模型列表失败', 'error');
            }
        }

        // 加载训练任务
        async function loadTrainingJobs() {
            // 模拟训练任务数据
            const jobs = [
                {
                    id: '1',
                    name: 'custom-model-v1',
                    status: 'training',
                    progress: 65,
                    startTime: '2024-01-15 10:30:00',
                    estimatedTime: '2小时30分钟'
                },
                {
                    id: '2',
                    name: 'chat-model-v2',
                    status: 'completed',
                    progress: 100,
                    startTime: '2024-01-14 14:20:00',
                    completedTime: '2024-01-14 18:45:00'
                }
            ];

            let html = '';
            jobs.forEach(job => {
                const statusColor = job.status === 'completed' ? '#28a745' : 
                                  job.status === 'training' ? '#007AFF' : '#dc3545';
                const statusText = job.status === 'completed' ? '已完成' : 
                                 job.status === 'training' ? '训练中' : '失败';

                html += `
                    <div style="border: 1px solid #e0e0e0; border-radius: 8px; padding: 1rem; margin-bottom: 1rem;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem;">
                            <div style="font-weight: 600;">${job.name}</div>
                            <div style="color: ${statusColor}; font-weight: 500;">${statusText}</div>
                        </div>
                        <div style="font-size: 0.9rem; color: #666; margin-bottom: 1rem;">
                            开始时间: ${job.startTime}<br>
                            ${job.completedTime ? `完成时间: ${job.completedTime}` : `预计剩余: ${job.estimatedTime}`}
                        </div>
                        ${job.status === 'training' ? `
                            <div style="background: #f0f0f0; border-radius: 4px; height: 8px; margin-bottom: 0.5rem;">
                                <div style="background: #007AFF; height: 100%; border-radius: 4px; width: ${job.progress}%;"></div>
                            </div>
                            <div style="text-align: center; font-size: 0.9rem; color: #666;">${job.progress}%</div>
                        ` : ''}
                    </div>
                `;
            });

            document.getElementById('trainingJobs').innerHTML = html || '<div style="text-align: center; color: #666;">暂无训练任务</div>';
        }

        // 加载设置
        function loadSettings() {
            // 这里可以加载已保存的设置
        }

        // 显示添加模型模态框
        function showAddModelModal() {
            document.getElementById('addModelModal').style.display = 'block';
        }

        // 隐藏添加模型模态框
        function hideAddModelModal() {
            document.getElementById('addModelModal').style.display = 'none';
            document.getElementById('addModelForm').reset();
        }

        // 测试模型
        async function testModel(key) {
            try {
                showAlert('正在测试模型连接...', 'info');
                
                const response = await fetch('/api/chat', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        provider: key,
                        model: 'test',
                        messages: [{ role: 'user', content: '你好' }]
                    })
                });

                if (response.ok) {
                    showAlert('模型测试成功', 'success');
                } else {
                    showAlert('模型测试失败', 'error');
                }

            } catch (error) {
                console.error('测试模型失败:', error);
                showAlert('模型测试失败', 'error');
            }
        }

        // 切换模型状态
        async function toggleModel(key, enabled) {
            try {
                const response = await fetch('/api/admin/configs');
                const configs = await response.json();
                
                configs[key].enabled = enabled;
                
                const updateResponse = await fetch('/api/admin/configs', {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(configs)
                });

                if (updateResponse.ok) {
                    showAlert(`模型已${enabled ? '启用' : '禁用'}`, 'success');
                    loadModels();
                } else {
                    showAlert('操作失败', 'error');
                }

            } catch (error) {
                console.error('切换模型状态失败:', error);
                showAlert('操作失败', 'error');
            }
        }

        // 显示提示信息
        function showAlert(message, type = 'info') {
            const alertClass = type === 'success' ? 'alert-success' : 'alert-error';
            const alertHtml = `<div class="alert ${alertClass}">${message}</div>`;
            
            // 在页面顶部显示提示
            const container = document.querySelector('.container');
            container.insertAdjacentHTML('afterbegin', alertHtml);
            
            // 3秒后自动移除
            setTimeout(() => {
                const alert = container.querySelector('.alert');
                if (alert) alert.remove();
            }, 3000);
        }

        // 格式化运行时间
        function formatUptime(seconds) {
            const days = Math.floor(seconds / 86400);
            const hours = Math.floor((seconds % 86400) / 3600);
            const minutes = Math.floor((seconds % 3600) / 60);
            
            if (days > 0) {
                return `${days}天 ${hours}小时 ${minutes}分钟`;
            } else if (hours > 0) {
                return `${hours}小时 ${minutes}分钟`;
            } else {
                return `${minutes}分钟`;
            }
        }

        // 表单提交处理
        document.getElementById('trainingForm').addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            const trainingData = {
                modelName: formData.get('modelName'),
                baseModel: formData.get('baseModel'),
                epochs: parseInt(formData.get('epochs')),
                learningRate: parseFloat(formData.get('learningRate'))
            };

            try {
                showAlert('训练任务已提交，正在准备...', 'success');
                // 这里可以调用训练API
                console.log('训练参数:', trainingData);
                
            } catch (error) {
                console.error('提交训练任务失败:', error);
                showAlert('提交训练任务失败', 'error');
            }
        });

        document.getElementById('settingsForm').addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            const settings = {
                zhipuApiKey: formData.get('zhipuApiKey'),
                openaiApiKey: formData.get('openaiApiKey'),
                claudeApiKey: formData.get('claudeApiKey'),
                qwenApiKey: formData.get('qwenApiKey')
            };

            try {
                // 这里可以保存设置到后端
                showAlert('设置保存成功', 'success');
                console.log('保存设置:', settings);
                
            } catch (error) {
                console.error('保存设置失败:', error);
                showAlert('保存设置失败', 'error');
            }
        });

        document.getElementById('addModelForm').addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            const modelData = {
                name: formData.get('name'),
                provider: formData.get('provider'),
                endpoint: formData.get('endpoint'),
                apiKey: formData.get('apiKey')
            };

            try {
                // 这里可以添加模型到配置
                showAlert('模型添加成功', 'success');
                hideAddModelModal();
                loadModels();
                console.log('添加模型:', modelData);
                
            } catch (error) {
                console.error('添加模型失败:', error);
                showAlert('添加模型失败', 'error');
            }
        });
    </script>
</body>
</html>
EOF

    log_success "AI模型管理后台创建完成"
}

# 创建部署配置
create_deployment_configs() {
    log_step "创建部署配置..."
    
    # AI服务Docker Compose配置
    cat > "$AI_DIR/../development/docker-compose/ai-enhanced.yml" << 'EOF'
version: '3.8'

networks:
  yc-dev-network:
    external: true

services:
  # AI模型网关
  ai-gateway:
    build:
      context: /volume1/YC/ai-models/api/gateway
      dockerfile: Dockerfile
    container_name: yc-ai-gateway
    ports:
      - "3010:3010"
    volumes:
      - /volume1/YC/ai-models/configs:/app/configs
      - /volume1/YC/ai-models/logs:/app/logs
    environment:
      - NODE_ENV=production
      - AI_GATEWAY_PORT=3010
      - ZHIPU_API_KEY=${ZHIPU_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - CLAUDE_API_KEY=${CLAUDE_API_KEY}
      - QWEN_API_KEY=${QWEN_API_KEY}
    networks:
      - yc-dev-network
    restart: unless-stopped

  # AI管理后台
  ai-dashboard:
    image: nginx:alpine
    container_name: yc-ai-dashboard
    ports:
      - "3011:80"
    volumes:
      - /volume1/YC/ai-models/management/web:/usr/share/nginx/html
      - /volume1/YC/ai-models/management/nginx.conf:/etc/nginx/nginx.conf
    networks:
      - yc-dev-network
    restart: unless-stopped

  # 模型训练服务
  model-trainer:
    image: pytorch/pytorch:latest
    container_name: y