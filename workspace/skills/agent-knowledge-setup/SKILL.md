---
name: agent-knowledge-setup
description: 为新创建的 agent 初始化领域知识库，启用语义搜索，预置岗位相关知识
---

# Agent 知识库搭建技能

## 概述

为新 agent 搭建知识管理体系，让他成为**专精领域的专家**而非泛泛之谈的通才。

## 知识库目录结构

在新 agent 的工作空间下创建：

```
knowledge/
├── README.md           # 知识库索引和使用指南
├── domain/             # 行业/领域知识
│   ├── concepts.md     # 核心概念
│   ├── glossary.md     # 术语表
│   └── best-practices.md  # 最佳实践
├── tools/              # 工具使用经验
│   └── api-notes.md    # API 和工具使用笔记
├── cases/              # 案例库
│   └── .gitkeep
└── references/         # 参考资料索引
    └── bookmarks.md    # 有价值的外部资源链接
```

## 初始化步骤

### 1. 创建目录结构

```bash
WORKSPACE="~/.openclaw/workspace-<agentId>"
mkdir -p "$WORKSPACE/knowledge/domain"
mkdir -p "$WORKSPACE/knowledge/tools"
mkdir -p "$WORKSPACE/knowledge/cases"
mkdir -p "$WORKSPACE/knowledge/references"
```

### 2. 写入知识库 README

`knowledge/README.md` 内容：

```markdown
# 知识库

这是你的专业知识库。在工作中持续积累和整理。

## 使用方法
- `memory_search` 可以搜索这里的内容（已纳入向量索引）
- 新学到的知识写入对应目录
- 定期整理和更新

## 目录说明
- `domain/` — 你的专业领域知识
- `tools/` — 工具和 API 使用经验
- `cases/` — 值得记录的案例
- `references/` — 外部资源链接
```

### 3. 预置领域知识

根据岗位类型，在 `knowledge/domain/` 下预置入门知识文档。
知识内容参考 `{baseDir}/../../templates/new-agent/knowledge-init.md.template`。

### 4. 启用知识库语义搜索

通过配置 `memorySearch.extraPaths` 将 knowledge/ 纳入搜索索引：

```bash
AGENT_INDEX=<index>
openclaw config set \
  "agents.list[$AGENT_INDEX].memorySearch.extraPaths" \
  '["knowledge/"]' --strict-json
```

### 5. 在 AGENTS.md 中写入知识管理规则

在新 agent 的 AGENTS.md 中加入知识管理章节，引导 agent：
- 工作后记录新知识到 `knowledge/domain/`
- 遇到新术语更新 `knowledge/domain/glossary.md`
- 解决有价值的问题记录到 `knowledge/cases/`
- 发现有价值的资源更新 `knowledge/references/bookmarks.md`
- 利用 heartbeat 时间阅读行业资讯

## 岗位知识预设表

| 岗位 | 预置知识内容 |
|-----|------------|
| 产品经理 | 需求分析方法、PRD 模板、用户故事格式 |
| 市场销售 | 销售漏斗、客户画像、转化率指标 |
| 程序员 | 代码规范、Git 工作流、调试方法论 |
| 运营 | 用户增长模型、数据指标体系、活动策划框架 |
| 研究员 | 调研方法论、报告模板、数据源列表 |
| 天气助手 | 气象术语、天气 API 文档、预警级别 |
| 股票监控 | 技术指标定义、K 线形态、风控规则 |
