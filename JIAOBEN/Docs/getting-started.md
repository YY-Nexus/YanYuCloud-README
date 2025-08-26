# YYC³ 开发者工具包入门指南

## 欢迎使用 YYC³

感谢您选择 YYC³（言语云³）开发者工具包！本工具包旨在帮助开发者快速构建符合企业级标准的应用程序，提供一致的开发体验和高效的开发流程。

## 系统要求

- **Node.js**: v16.0.0 或更高版本
- **npm**: v7.0.0 或更高版本（或 yarn/pnpm）
- **代码编辑器**: VS Code（推荐）或其他支持 TypeScript 的编辑器
- **版本控制**: Git

## 安装工具包

### 方式一：使用 CLI 工具

YYC³ 提供了强大的 CLI 工具来帮助您快速创建项目：

1. 全局安装 CLI 工具：
\`\`\`bash
npm install -g @yanyucloud/cli
# 或使用 yarn
yarn global add @yanyucloud/cli
\`\`\`

2. 验证安装：
\`\`\`bash
yyc --version
\`\`\`

### 方式二：使用项目模板

您也可以直接克隆项目模板：

\`\`\`bash
# 克隆 Next.js 模板
git clone http://192.168.0.9:3000/templates/nextjs-template.git my-app
cd my-app
npm install
\`\`\`

## 创建第一个项目

### 创建 Next.js 应用

\`\`\`bash
# 使用 CLI 创建
yyc create app my-yyc-app

# 进入项目目录
cd my-yyc-app

# 安装依赖
npm install

# 启动开发服务器
npm run dev
\`\`\`

### 创建 React 组件

\`\`\`bash
# 生成新组件
yyc generate component YYButton

# 生成带样式和测试的组件
yyc generate component YYCard --with-styles --with-tests
\`\`\`

## 核心概念

### 设计系统

YYC³ 设计系统提供了一套完整的视觉规范：

- **色彩系统**: 主色、辅助色、语义色彩
- **字体规范**: Inter 字体族和 JetBrains Mono 等宽字体
- **组件库**: 预构建的 UI 组件
- **布局模式**: 响应式布局和栅格系统

### 品牌合规

所有使用 YYC³ 工具包创建的项目都会自动遵循品牌规范：

\`\`\`bash
# 运行品牌合规检查
yyc brand-check

# 自动修复品牌问题
yyc brand-check --fix

# 生成合规报告
yyc brand-check --report
\`\`\`

### 组件命名规范

- **组件前缀**: 所有组件使用 `YY` 前缀
- **CSS 类名**: 使用 `yyc3-` 前缀
- **文件命名**: 使用 PascalCase

## 开发工作流

### 1. 项目初始化

\`\`\`bash
# 创建新项目
yyc create app my-project

# 初始化现有项目
cd existing-project
yyc init
\`\`\`

### 2. 开发阶段

\`\`\`bash
# 启动开发服务器
npm run dev

# 生成新组件
yyc generate component MyComponent

# 运行测试
npm test

# 代码检查
npm run lint
\`\`\`

### 3. 构建和部署

\`\`\`bash
# 构建项目
npm run build

# 品牌合规检查
yyc brand-check

# 部署到生产环境
yyc deploy --env production
\`\`\`

## 配置选项

### 项目配置

在项目根目录创建 `yyc3.config.js`：

\`\`\`javascript
module.exports = {
  // 品牌配置
  brand: {
    name: 'My YYC³ App',
    theme: 'light', // 'light' | 'dark' | 'auto'
  },
  
  // 组件配置
  components: {
    prefix: 'YY',
    generateTests: true,
    generateStories: true,
  },
  
  // 构建配置
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
};
\`\`\`

### 环境变量

创建 `.env.local` 文件：

\`\`\`bash
# YYC³ 配置
YYC3_REGISTRY=http://192.168.0.9:4873
YYC3_THEME=light
YYC3_BRAND_CHECK=true

# API 配置
NEXT_PUBLIC_API_URL=http://localhost:3000/api
\`\`\`

## 常用命令

### CLI 命令

\`\`\`bash
# 查看帮助
yyc --help

# 创建项目
yyc create <type> <name>

# 生成代码
yyc generate <type> <name>

# 构建项目
yyc build

# 运行开发服务器
yyc dev

# 品牌检查
yyc brand-check

# 部署项目
yyc deploy

# 升级工具包
yyc upgrade
\`\`\`

### NPM 脚本

\`\`\`bash
# 开发
npm run dev

# 构建
npm run build

# 测试
npm test
npm run test:watch

# 代码检查
npm run lint
npm run lint:fix

# 类型检查
npm run type-check

# 品牌检查
npm run brand-check
\`\`\`

## 最佳实践

### 1. 组件开发

\`\`\`tsx
// 使用 YYC³ 组件规范
import React from 'react';
import { cn } from '@yanyucloud/core';
import type { YYCBaseProps } from '@yanyucloud/core';

interface YYMyComponentProps extends YYCBaseProps {
  variant?: 'primary' | 'secondary';
  children?: React.ReactNode;
}

export const YYMyComponent: React.FC<YYMyComponentProps> = ({
  variant = 'primary',
  className,
  children,
  ...props
}) => {
  return (
    <div
      className={cn(
        'yyc3-my-component',
        `yyc3-my-component--${variant}`,
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
};

YYMyComponent.displayName = 'YYMyComponent';
\`\`\`

### 2. 样式规范

\`\`\`css
/* 使用 YYC³ CSS 变量 */
.yyc3-my-component {
  color: var(--yyc3-text-primary);
  background-color: var(--yyc3-bg-primary);
  border-radius: var(--yyc3-radius);
  padding: var(--yyc3-space-4);
}

.yyc3-my-component--primary {
  background-color: var(--yyc3-primary-500);
  color: white;
}

.yyc3-my-component--secondary {
  background-color: var(--yyc3-secondary-500);
  color: white;
}
\`\`\`

### 3. 测试规范

\`\`\`typescript
// 使用 YYC³ 测试工具
import { render, screen } from '@testing-library/react';
import { YYMyComponent } from './YYMyComponent';

describe('YYMyComponent', () => {
  it('renders correctly', () => {
    render(<YYMyComponent>Test content</YYMyComponent>);
    expect(screen.getByText('Test content')).toBeInTheDocument();
  });

  it('applies variant styles', () => {
    render(<YYMyComponent variant="secondary">Test</YYMyComponent>);
    const element = screen.getByText('Test');
    expect(element).toHaveClass('yyc3-my-component--secondary');
  });
});
\`\`\`

## 故障排除

### 常见问题

**Q: CLI 工具安装失败**
\`\`\`bash
# 清除 npm 缓存
npm cache clean --force

# 使用私有仓库安装
npm install -g @yanyucloud/cli --registry=http://192.168.0.9:4873
\`\`\`

**Q: 品牌检查失败**
\`\`\`bash
# 查看详细错误信息
yyc brand-check --verbose

# 自动修复问题
yyc brand-check --fix
\`\`\`

**Q: 组件样式不生效**
\`\`\`bash
# 确保导入了 CSS 变量
import '@yanyucloud/ui/styles/variables.css';

# 检查 Tailwind 配置
npx tailwindcss --init
\`\`\`

### 获取帮助

- 📚 [完整文档](http://192.168.0.9/yyc3-docs)
- 🐛 [问题反馈](http://192.168.0.9:3000/issues)
- 💬 [开发者社区](http://192.168.0.9:3000/discussions)
- 📧 [技术支持](mailto:support@yanyucloud.com)

## 下一步

现在您已经了解了 YYC³ 开发者工具包的基础知识，可以：

1. [查看组件库文档](./components.md)
2. [学习高级功能](./advanced.md)
3. [参与社区贡献](./contributing.md)
4. [查看示例项目](../examples/)

祝您使用愉快！🎉
\`\`\`

\`\`\`shellscript file="scripts/yyc3-management-dashboard.sh"
#!/bin/bash

# YYC³ 管理面板部署脚本
# 创建 Web 界面管理开发者工具包

set -e

ROOT_DIR="/volume2/YC"
DEVKIT_DIR="/volume2/YC/yyc3-devkit"
DASHBOARD_DIR="/volume2/YC/yyc3-dashboard"
NAS_IP="192.168.0.9"

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
    ██╗   ██╗██╗   ██╗ ██████╗██████╗     ███╗   ███╗ ██████╗ ████████╗
    ╚██╗ ██╔╝╚██╗ ██╔╝██╔════╝╚════██╗    ████╗ ████║██╔════╝ ╚══██╔══╝
     ╚████╔╝  ╚████╔╝ ██║      █████╔╝    ██╔████╔██║██║  ███╗   ██║   
      ╚██╔╝    ╚██╔╝  ██║      ╚═══██╗    ██║╚██╔╝██║██║   ██║   ██║   
       ██║      ██║   ╚██████╗██████╔╝    ██║ ╚═╝ ██║╚██████╔╝   ██║   
       ╚═╝      ╚═╝    ╚═════╝╚═════╝     ╚═╝     ╚═╝ ╚═════╝    ╚═╝   
                                                                        
    YYC³ 管理面板
    Management Dashboard
    ===================
EOF
    echo -e "${NC}"
    echo ""
    echo "🎛️ 创建 Web 界面管理开发者工具包"
    echo "📅 部署时间: $(date)"
    echo "🌐 目标服务器: $NAS_IP"
    echo "📁 安装目录: $DASHBOARD_DIR"
    echo ""
}

# 创建管理面板项目结构
create_dashboard_structure() {
    log_step "创建管理面板项目结构..."
    
    # 创建主目录
    mkdir -p "$DASHBOARD_DIR"/{src,public,dist,config}
    mkdir -p "$DASHBOARD_DIR/src"/{components,pages,hooks,utils,types,styles,api}
    mkdir -p "$DASHBOARD_DIR/src/components"/{layout,ui,forms,charts}
    mkdir -p "$DASHBOARD_DIR/src/pages"/{dashboard,packages,templates,docs,settings}
    mkdir -p "$DASHBOARD_DIR/public"/{images,icons,fonts}
    
    log_success "项目结构创建完成"
}

# 创建 package.json
create_package_json() {
    log_step "创建 package.json..."
    
    cat > "$DASHBOARD_DIR/package.json" &lt;&lt; 'EOF'
{
  "name": "yyc3-management-dashboard",
  "version": "1.0.0",
  "description": "YYC³ 开发者工具包管理面板",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3001",
    "build": "next build",
    "start": "next start -p 3001",
    "lint": "next lint",
    "type-check": "tsc --noEmit",
    "export": "next export"
  },
  "dependencies": {
    "next": "14.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@yanyucloud/core": "^1.0.0",
    "@yanyucloud/ui": "^1.0.0",
    "axios": "^1.5.0",
    "recharts": "^2.8.0",
    "react-hook-form": "^7.47.0",
    "react-query": "^3.39.0",
    "socket.io-client": "^4.7.0",
    "date-fns": "^2.30.0",
    "clsx": "^2.0.0",
    "lucide-react": "^0.290.0"
  },
  "devDependencies": {
    "@types/node": "^20.8.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "typescript": "^5.2.0",
    "tailwindcss": "^3.3.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0",
    "eslint": "^8.50.0",
    "eslint-config-next": "14.0.0"
  },
  "keywords": [
    "yyc3",
    "management",
    "dashboard",
    "developer-tools"
  ],
  "author": "YanYu Intelligence Cloud³",
  "license": "MIT"
}
EOF

    log_success "package.json 创建完成"
}

# 创建 Next.js 配置
create_nextjs_config() {
    log_step "创建 Next.js 配置..."
    
    cat > "$DASHBOARD_DIR/next.config.js" &lt;&lt; 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    appDir: true,
  },
  images: {
    domains: ['localhost', '192.168.0.9'],
  },
  env: {
    YYC3_VERSION: process.env.npm_package_version,
    YYC3_REGISTRY: process.env.YYC3_REGISTRY || 'http://192.168.0.9:4873',
  },
  async rewrites() {
    return [
      {
        source: '/api/registry/:path*',
        destination: 'http://192.168.0.9:4873/:path*',
      },
      {
        source: '/api/gitlab/:path*',
        destination: 'http://192.168.0.9:8080/api/v4/:path*',
      },
    ];
  },
}

module.exports = nextConfig
EOF

    # 创建 Tailwind 配置
    cat > "$DASHBOARD_DIR/tailwind.config.js" &lt;&lt; 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        yyc3: {
          primary: {
            50: '#f0f9ff',
            100: '#e0f2fe',
            200: '#bae6fd',
            300: '#7dd3fc',
            400: '#38bdf8',
            500: '#0ea5e9',
            600: '#0284c7',
            700: '#0369a1',
            800: '#075985',
            900: '#0c4a6e',
          },
          secondary: {
            50: '#fafafa',
            100: '#f4f4f5',
            200: '#e4e4e7',
            300: '#d4d4d8',
            400: '#a1a1aa',
            500: '#71717a',
            600: '#52525b',
            700: '#3f3f46',
            800: '#27272a',
            900: '#18181b',
          },
          accent: {
            500: '#d946ef',
            600: '#c026d3',
          },
          success: {
            500: '#22c55e',
            600: '#16a34a',
          },
          warning: {
            500: '#f59e0b',
            600: '#d97706',
          },
          error: {
            500: '#ef4444',
            600: '#dc2626',
          },
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'Consolas', 'monospace'],
      },
    },
  },
  plugins: [],
}
EOF

    # 创建 TypeScript 配置
    cat > "$DASHBOARD_DIR/tsconfig.json" &lt;&lt; 'EOF'
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "es6"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "@/components/*": ["./src/components/*"],
      "@/pages/*": ["./src/pages/*"],
      "@/hooks/*": ["./src/hooks/*"],
      "@/utils/*": ["./src/utils/*"],
      "@/types/*": ["./src/types/*"],
      "@/api/*": ["./src/api/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

    log_success "配置文件创建完成"
}

# 创建主应用文件
create_app_files() {
    log_step "创建主应用文件..."
    
    # 创建 app 目录
    mkdir -p "$DASHBOARD_DIR/app"/{dashboard,packages,templates,docs,settings,api}
    
    # 创建根布局
    cat > "$DASHBOARD_DIR/app/layout.tsx" &lt;&lt; 'EOF'
/**
 * YYC³ 管理面板根布局
 * Copyright (c) 2024 YanYu Intelligence Cloud³
 */

import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'YYC³ 管理面板',
  description: 'YanYu Intelligence Cloud³ 开发者工具包管理面板',
  keywords: ['YYC³', 'YanYu Intelligence Cloud', '管理面板', '开发者工具'],
  authors: [{ name: 'YanYu Intelligence Cloud³' }],
  creator: 'YanYu Intelligence Cloud³',
  publisher: 'YanYu Intelligence Cloud³',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="zh-CN" data-theme="light">
      <head>
        <link rel="icon" href="/favicon.ico" />
        <meta name="brand" content="YYC³" />
      </head>
      <body className={inter.className}>
        <div id="yyc3-dashboard">
          {children}
        </div>
      </body>
    </html>
  );
}
EOF

    # 创建主页面
    cat > "$DASHBOARD_DIR/app/page.tsx" &lt;&lt; 'EOF'
/**
 * YYC³ 管理面板主页
 * Copyright (c) 2024 YanYu Intelligence Cloud³
 */

'use client';

import { useState, useEffect } from 'react';
import { YYCard, YYButton } from '@yanyucloud/ui';
import { Package, FileText, Settings, Activity, Users, Download, TrendingUp, AlertCircle } from 'lucide-react';

interface DashboardStats {
  totalPackages: number;
  totalDownloads: number;
  activeUsers: number;
  systemHealth: 'healthy' | 'warning' | 'error';
}

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats>({
    totalPackages: 0,
    totalDownloads: 0,
    activeUsers: 0,
    systemHealth: 'healthy'
  });

  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // 模拟数据加载
    setTimeout(() => {
      setStats({
        totalPackages: 12,
        totalDownloads: 1547,
        activeUsers: 23,
        systemHealth: 'healthy'
      });
      setLoading(false);
    }, 1000);
  }, []);

  const quickActions = [
    {
      title: '创建新包',
      description: '创建新的 NPM 包',
      icon: Package,
      href: '/packages/create',
      color: 'bg-yyc3-primary-500'
    },
    {
      title: '生成模板',
      description: '创建项目模板',
      icon: FileText,
      href: '/templates/create',
      color: 'bg-yyc3-accent-500'
    },
    {
      title: '系统设置',
      description: '配置系统参数',
      icon: Settings,
      href: '/settings',
      color: 'bg-yyc3-secondary-500'
    },
    {
      title: '查看文档',
      description: '浏览开发文档',
      icon: FileText,
      href: '/docs',
      color: 'bg-yyc3-success-500'
    }
  ];

  const getHealthColor = (health: string) => {
    switch (health) {
      case 'healthy': return 'text-yyc3-success-500';
      case 'warning': return 'text-yyc3-warning-500';
      case 'error': return 'text-yyc3-error-500';
      default: return 'text-yyc3-secondary-500';
    }
  };

  const getHealthIcon = (health: string) => {
    switch (health) {
      case 'healthy': return '✅';
      case 'warning': return '⚠️';
      case 'error': return '❌';
      default: return '❓';
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-yyc3-primary-50 to-yyc3-accent-50">
      {/* 头部 */}
      <header className="bg-white shadow-sm border-b border-yyc3-secondary-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <h1 className="text-2xl font-bold text-yyc3-primary-900">
                YYC³ 管理面板
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <div className={`flex items-center space-x-2 ${getHealthColor(stats.systemHealth)}`}>
                <span>{getHealthIcon(stats.systemHealth)}</span>
                <span className="text-sm font-medium">
                  系统{stats.systemHealth === 'healthy' ? '正常' : '异常'}
                </span>
              </div>
              <YYButton variant="outline" size="sm">
                刷新
              </YYButton>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* 统计卡片 */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <YYCard className="p-6">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <Package className="h-8 w-8 text-yyc3-primary-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-yyc3-secondary-600">
                  总包数量
                </p>
                <p className="text-2xl font-bold text-yyc3-secondary-900">
                  {loading ? '...' : stats.totalPackages}
                </p>
              </div>
            </div>
          </YYCard>

          <YYCard className="p-6">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <Download className="h-8 w-8 text-yyc3-success-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-yyc3-secondary-600">
                  总下载量
                </p>
                <p className="text-2xl font-bold text-yyc3-secondary-900">
                  {loading ? '...' : stats.totalDownloads.toLocaleString()}
                </p>
              </div>
            </div>
          </YYCard>

          <YYCard className="p-6">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <Users className="h-8 w-8 text-yyc3-accent-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-yyc3-secondary-600">
                  活跃用户
                </p>
                <p className="text-2xl font-bold text-yyc3-secondary-900">
                  {loading ? '...' : stats.activeUsers}
                </p>
              </div>
            </div>
          </YYCard>

          <YYCard className="p-6">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <Activity className="h-8 w-8 text-yyc3-warning-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-yyc3-secondary-600">
                  系统状态
                </p>
                <p className={`text-2xl font-bold ${getHealthColor(stats.systemHealth)}`}>
                  {loading ? '...' : (stats.systemHealth === 'healthy' ? '正常' : '异常')}
                </p>
              </div>
            </div>
          </YYCard>
        </div>

        {/* 快速操作 */}
        <div className="mb-8">
          <h2 className="text-lg font-semibold text-yyc3-secondary-900 mb-4">
            快速操作
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {quickActions.map((action, index) => (
              <YYCard key={index} className="p-6 hover:shadow-lg transition-shadow cursor-pointer">
                <div className="flex items-center mb-4">
                  <div className={`p-2 rounded-lg ${action.color}`}>
                    <action.icon className="h-6 w-6 text-white" />
                  </div>
                </div>
                <h3 className="text-lg font-semibold text-yyc3-secondary-900 mb-2">
                  {action.title}
                </h3>
                <p className="text-sm text-yyc3-secondary-600 mb-4">
                  {action.description}
                </p>
                <YYButton variant="outline" size="sm" fullWidth>
                  开始
                </YYButton>
              </YYCard>
            ))}
          </div>
        </div>

        {/* 最近活动 */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <YYCard className="p-6">
            <h3 className="text-lg font-semibold text-yyc3-secondary-900 mb-4">
              最近发布
            </h3>
            <div className="space-y-4">
              {[
                { name: '@yanyucloud/ui', version: '1.0.3', time: '2小时前' },
                { name: '@yanyucloud/core', version: '1.0.2', time: '1天前' },
                { name: '@yanyucloud/cli', version: '1.0.1', time: '3天前' },
              ].map((pkg, index) => (
                <div key={index} className="flex items-center justify-between py-2 border-b border-yyc3-secondary-100 last:border-b-0">
                  <div>
                    <p className="font-medium text-yyc3-secondary-900">{pkg.name}</p>
                    <p className="text-sm text-yyc3-secondary-600">v{pkg.version}</p>
                  </div>
                  <span className="text-sm text-yyc3-secondary-500">{pkg.time}</span>
                </div>
              ))}
            </div>
          </YYCard>

          <YYCard className="p-6">
            <h3 className="text-lg font-semibold text-yyc3-secondary-900 mb-4">
              系统日志
            </h3>
            <div className="space-y-4">
              {[
                { type: 'info', message: '用户 admin 登录系统', time: '10分钟前' },
                { type: 'success', message: '包 @yanyucloud/ui 发布成功', time: '2小时前' },
                { type: 'warning', message: '磁盘使用率达到 75%', time: '1天前' },
              ].map((log, index) => (
                <div key={index} className="flex items-start space-x-3 py-2">
                  <div className={`flex-shrink-0 w-2 h-2 rounded-full mt-2 ${
                    log.type === 'info' ? 'bg-yyc3-primary-500' :
                    log.type === 'success' ? 'bg-yyc3-success-500' :
                    'bg-yyc3-warning-500'
                  }`} />
                  <div className="flex-1">
                    <p className="text-sm text-yyc3-secondary-900">{log.message}</p>
                    <p className="text-xs text-yyc3-secondary-500">{log.time}</p>
                  </div>
                </div>
              ))}
            </div>
          </YYCard>
        </div>
      </main>
    </div>
  );
}
EOF

    # 创建全局样式
    cat > "$DASHBOARD_DIR/app/globals.css" &lt;&lt; 'EOF'
/**
 * YYC³ 管理面板全局样式
 * Copyright (c) 2024 YanYu Intelligence Cloud³
 */

@import 'tailwindcss/base';
@import 'tailwindcss/components';
@import 'tailwindcss/utilities';

/* 字体导入 */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&display=swap');

/* 全局变量 */
:root {
  --yyc3-brand-primary: #0ea5e9;
  --yyc3-brand-secondary: #71717a;
  --yyc3-brand-accent: #d946ef;
  
  --yyc3-duration-fast: 150ms;
  --yyc3-duration-normal: 300ms;
  --yyc3-duration-slow: 500ms;
  
  --yyc3-z-dropdown: 1000;
  --yyc3-z-modal: 1050;
  --yyc3-z-tooltip: 1100;
  --yyc3-z-toast: 1200;
}

/* 基础样式 */
* {
  box-sizing: border-box;
}

html {
  scroll-behavior: smooth;
}

body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* 滚动条样式 */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: #f4f4f5;
}

::-webkit-scrollbar-thumb {
  background: #d4d4d8;
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: #a1a1aa;
}

/* 深色主题滚动条 */
[data-theme="dark"] ::-webkit-scrollbar-track {
  background: #27272a;
}

[data-theme="dark"] ::-webkit-scrollbar-thumb {
  background: #52525b;
}

[data-theme="dark"] ::-webkit-scrollbar-thumb:hover {
  background: #71717a;
}

/* 动画类 */
.yyc3-fade-in {
  animation: yyc3-fade-in var(--yyc3-duration-normal) ease-out;
}

.yyc3-slide-up {
  animation: yyc3-slide-up var(--yyc3-duration-normal) ease-out;
}

@keyframes yyc3-fade-in {
  from {
    opacity: 0;
    transform: translateY(4px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes yyc3-slide-up {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* 工具类 */
.yyc3-glass {
  backdrop-filter: blur(10px);
  background-color: rgba(255, 255, 255, 0.8);
}

.yyc3-shadow-glow {
  box-shadow: 0 0 20px rgba(14, 165, 233, 0.3);
}

/* 响应式工具 */
@media (max-width: 640px) {
  .yyc3-mobile-hidden {
    display: none;
  }
}

/* 打印样式 */
@media print {
  .yyc3-no-print {
    display: none !important;
  }
}

/* 高对比度模式 */
@media (prefers-contrast: high) {
  .yyc3-component {
    border: 1px solid currentColor;
  }
}

/* 减少动画偏好 */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
EOF

    log_success "主应用文件创建完成"
}

# 创建 API 路由
create_api_routes() {
    log_step "创建 API 路由..."
    
    # 创建包管理 API
    mkdir -p "$DASHBOARD_DIR/app/api"/{packages,templates,system,auth}
    
    cat > "$DASHBOARD_DIR/app/api/packages/route.ts" &lt;&lt; 'EOF'
/**
 * 包管理 API
 * Copyright (c) 2024 YanYu Intelligence Cloud³
 */

import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  try {
    // 从私有 NPM 仓库获取包列表
    const registryUrl = process.env.YYC3_REGISTRY || 'http://192.168.0.9:4873';
    const response = await fetch(`${registryUrl}/-/all`);
    
    if (!response.ok) {
      throw new Error('Failed to fetch packages');
    }
    
    const data = await response.json();
    
    // 过滤 YYC³ 相关包
    const yyc3Packages = Object.entries(data)
      .filter(([name]) => name.startsWith('@yanyucloud/'))
      .map(([name, info]: [string, any]) => ({
        name,
        version: info['dist-tags']?.latest || '0.0.0',
        description: info.description || '',
        author: info.author || 'YanYu Intelligence Cloud³',
        modified: info.time?.modified || new Date().toISOString(),
        downloads: Math.floor(Math.random() * 1000), // 模拟下载数
      }));
    
    return NextResponse.json({
      success: true,
      data: yyc3Packages,
      total: yyc3Packages.length,
    });
  } catch (error) {
    console.error('Error fetching packages:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch packages' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { name, version, description } = body;
    
    // 验证输入
    if (!name || !version) {
      return NextResponse.json(
        { success: false, error: 'Name and version are required' },
        { status: 400 }
      );
    }
    
    // 这里应该实现包的创建逻辑
    // 目前返回模拟响应
    return NextResponse.json({
      success: true,
      data: {
        name,
        version,
        description,
        created: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.error('Error creating package:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to create package' },
      { status: 500 }
    );
  }
}
EOF

    # 创建系统状态 API
    cat > "$DASHBOARD_DIR/app/api/system/status/route.ts" &lt;&lt; 'EOF'
/**
 * 系统状态 API
 * Copyright (c) 2024 YanYu Intelligence Cloud³
 */

import { NextRequest, NextResponse } from 'next/server';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export async function GET(request: NextRequest) {
  try {
    // 检查系统状态
    const [diskUsage, memoryUsage, dockerStatus] = await Promise.allSettled([
      getDiskUsage(),
      getMemoryUsage(),
      getDockerStatus(),
    ]);
    
    const systemHealth = determineSystemHealth({
      disk: diskUsage.status === 'fulfilled' ? diskUsage.value : null,
      memory: memoryUsage.status === 'fulfilled' ? memoryUsage.value : null,
      docker: dockerStatus.status === 'fulfilled' ? dockerStatus.value : null,
    });
    
    return NextResponse.json({
      success: true,
      data: {
        health: systemHealth,
        disk: diskUsage.status === 'fulfilled' ? diskUsage.value : null,
        memory: memoryUsage.status === 'fulfilled' ? memoryUsage.value : null,
        docker: dockerStatus.status === 'fulfilled' ? dockerStatus.value : null,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.error('Error getting system status:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to get system status' },
      { status: 500 }
    );
  }
}

async function getDiskUsage() {
  try {
    const { stdout } = await execAsync('df /volume2 | tail -1');
    const parts = stdout.trim().split(/\s+/);
    const usedPercent = parseInt(parts[4].replace('%', ''));
    
    return {
      total: parts[1],
      used: parts[2],
      available: parts[3],
      usedPercent,
    };
  } catch (error) {
    return null;
  }
}

async function getMemoryUsage() {
  try {
    const { stdout } = await execAsync('free -m | grep Mem');
    const parts = stdout.trim().split(/\s+/);
    const total = parseInt(parts[1]);
    const used = parseInt(parts[2]);
    const usedPercent = Math.round((used / total) * 100);
    
    return {
      total,
      used,
      available: total - used,
      usedPercent,
    };
  } catch (error) {
    return null;
  }
}

async function getDockerStatus() {
  try {
    const { stdout } = await execAsync('docker ps --format "table {{.Names}}\t{{.Status}}" | grep yc-');
    const lines = stdout.trim().split('\n').slice(1); // 跳过表头
    
    const services = lines.map(line => {
      const [name, status] = line.split('\t');
      return {
        name: name.trim(),
        status: status.trim(),
        healthy: status.includes('Up'),
      };
    });
    
    return {
      total: services.length,
      healthy: services.filter(s => s.healthy).length,
      services,
    };
  } catch (error) {
    return null;
  }
}

function determineSystemHealth(status: any): 'healthy' | 'warning' | 'error' {
  // 检查磁盘使用率
  if (status.disk && status.disk.usedPercent > 90) {
    return 'error';
  }
  
  // 检查内存使用率
  if (status.memory && status.memory.usedPercent > 90) {
    return 'error';
  }
  
  // 检查 Docker 服务
  if (status.docker && status.docker.healthy &lt; status.docker.total * 0.8) {
    return 'error';
  }
  
  // 警告级别检查
  if (status.disk && status.disk.usedPercent > 80) {
    return 'warning';
  }
  
  if (status.memory && status.memory.usedPercent > 80) {
    return 'warning';
  }
  
  return 'healthy';
}
EOF

    log_success "API 路由创建完成"
}

# 创建部署脚本
create_deployment_script() {
    log_step "创建部署脚本..."
    
    cat > "$DASHBOARD_DIR/deploy.sh" &lt;&lt; 'EOF'
#!/bin/bash

# YYC³ 管理面板部署脚本

set -e

DASHBOARD_DIR="/volume2/YC/yyc3-dashboard"
WEB_DIR="/volume1/web/yyc3-dashboard"
PORT=3001

log_info() { echo -e "\033[0;34m[信息]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[成功]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[错误]\033[0m $1"; }

# 安装依赖
install_dependencies() {
    log_info "安装依赖..."
    cd "$DASHBOARD_DIR"
    npm install
    log_success "依赖安装完成"
}

# 构建项目
build_project() {
    log_info "构建项目..."
    cd "$DASHBOARD_DIR"
    npm run build
    log_success "项目构建完成"
}

# 启动服务
start_service() {
    log_info "启动管理面板服务..."
    cd "$DASHBOARD_DIR"
    
    # 停止现有进程
    pkill -f "next start" || true
    
    # 启动新进程
    nohup npm start > /dev/null 2>&1 &
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if curl -s "http://localhost:$PORT" > /dev/null; then
        log_success "管理面板启动成功"
        log_info "访问地址: http://192.168.0.9:$PORT"
    else
        log_error "管理面板启动失败"
        exit 1
    fi
}

# 配置 Nginx 反向代理
configure_nginx() {
    log_info "配置 Nginx 反向代理..."
    
    cat > /etc/nginx/sites-available/yyc3-dashboard &lt;&lt; NGINX_EOF
server {
    listen 80;
    server_name yyc3-dashboard.local;
    
    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINX_EOF

    # 启用站点
    ln -sf /etc/nginx/sites-available/yyc3-dashboard /etc/nginx/sites-enabled/
    
    # 重载 Nginx
    nginx -t && systemctl reload nginx
    
    log_success "Nginx 配置完成"
}

# 主函数
main() {
    log_info "开始部署 YYC³ 管理面板..."
    
    install_dependencies
    build_project
    start_service
    configure_nginx
    
    echo ""
    log_success "🎉 YYC³ 管理面板部署完成！"
    echo ""
    echo "📋 访问信息:"
    echo "  🌐 直接访问: http://192.168.0.9:$PORT"
    echo "  🌐 域名访问: http://yyc3-dashboard.local"
    echo ""
    echo "🛠️ 管理命令:"
    echo "  启动服务: cd $DASHBOARD_DIR && npm start"
    echo "  停止服务: pkill -f 'next start'"
    echo "  查看日志: tail -f $DASHBOARD_DIR/logs/dashboard.log"
    echo ""
}

main "$@"
EOF

    chmod +x "$DASHBOARD_DIR/deploy.sh"
    
    log_success "部署脚本创建完成"
}

# 主执行函数
main() {
    show_welcome
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        log_warning "建议使用 root 权限运行此脚本"
    fi
    
    # 执行部署步骤
    create_dashboard_structure
    create_package_json
    create_nextjs_config
    create_app_files
    create_api_routes
    create_deployment_script
    
    # 设置权限
    chown -R admin:users "$DASHBOARD_DIR"
    chmod -R 755 "$DASHBOARD_DIR"
    
    # 显示完成信息
    echo ""
    log_success "🎉 YYC³ 管理面板创建完成！"
    echo ""
    log_highlight "📋 部署摘要:"
    echo "  📁 项目目录: $DASHBOARD_DIR"
    echo "  🌐 服务器地址: $NAS_IP"
    echo "  🚀 部署端口: 3001"
    echo ""
    log_highlight "🚀 后续步骤:"
    echo "  1. 运行 'cd $DASHBOARD_DIR && ./deploy.sh' 部署管理面板"
    echo "  2. 访问 http://$NAS_IP:3001 查看管理界面"
    echo "  3. 配置环境变量和系统设置"
    echo ""
    log_highlight "🔧 开发命令:"
    echo "  • 开发模式: cd $DASHBOARD_DIR && npm run dev"
    echo "  • 构建项目: cd $DASHBOARD_DIR && npm run build"
    echo "  • 启动服务: cd $DASHBOARD_DIR && npm start"
    echo ""
}

# 执行主函数
main "$@"
