# 仓库协作与 Copilot 指令说明

## 项目简介

Edu-ai-question-bank：基于 Python 的教育智能题库项目。

## 代码样式指南

- Python 代码遵循 PEP8 规范。
- Shell 脚本需兼容 Bash，推荐加上 `#!/bin/bash` 头部。

## 分支管理建议

- 主分支为 main。
- 新功能开发建议使用 `feature/*` 分支命名，如 `feature/xxx`。
- 修复 Bug 建议使用 `fix/*` 分支命名。

## 拉取请求工作流程

- 所有更改需通过 Pull Request 提交，禁止直接推送到主分支。
- PR 必须通过自动化检查（如单元测试、Lint）。
- 合并前需至少一名成员审核并通过 Review。

## 协作约定

- 定期清理自动生成的文件和无用分支，保持仓库整洁。
- 重要文档（如 readme、开发说明）请及时更新。
- 建议在提交信息中写明变更内容。

## Copilot 智能化提示

- 本仓库已配置 Copilot 指令与上下文协议，见 .github/copilot-mcp-config.yml。  
