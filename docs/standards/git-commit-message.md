# Tidy Git 提交消息规范

> 最后更新：2026-07-28 | 版本：v0.1
> 文档状态：草案
> 适用范围：Tidy 仓库所有 Git 提交

## 格式

```text
<type>(<scope>): <简洁祈使语气主题>
```

### type

| type | 用途 |
|------|------|
| feat | 新功能 |
| fix | 缺陷修复 |
| docs | 文档变更 |
| refactor | 重构（不改变外部行为） |
| test | 测试相关 |
| chore | 构建、配置、工具变更 |
| build | 构建系统变更 |
| ci | CI 流水线变更 |
| perf | 性能优化 |
| style | 代码格式调整（不影响逻辑） |

### scope

| scope | 用途 |
|-------|------|
| governance | 文档治理（docs.md、AGENTS.md） |
| roadmap | 路线图 |
| architecture | 架构契约与 ADR |
| adr | 单个 ADR |
| phase-P{n} | 准备阶段文档 |
| phase-F{n} | 功能阶段文档 |
| standards | 编码规范 |
| spec | 已实现行为规格 |
| history | 历史归档 |
| agents | AI 协作约定 |
| tidycore | 核心逻辑层代码 |
| tidyui | UI 层代码 |
| tidyapp | 应用入口层代码 |

## 规则

- 一个提交只处理一个可独立审查的主题
- 主题行不超过 72 字符
- 主题行使用祈使语气（如"添加"而非"添加了"）
- 主题行不加句号
- 正文（如需）与主题行之间空一行
- 正文说明"为什么"做这个变更，而非"做了什么"（diff 已显示内容）
- Breaking change 在正文末尾注明：`BREAKING CHANGE: <说明>`

## 禁止行为

- 不得提交包含密钥、凭证或敏感信息的文件
- 不得使用 `git add -A` 或 `git add .`，应按文件名精确暂存
- 提交消息不得作为 lint 豁免机制

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v0.1 | 2026-07-28 | 建立 Git 提交消息规范草案 |
