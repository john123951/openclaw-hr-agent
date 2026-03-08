---
name: agent-onboarding
description: 为新创建的 agent 编写入职巡视文档，帮助新 agent 了解 OpenClaw 环境并开始工作
---

# Agent 入职培训技能

## 概述

为新 agent 编写 `BOOTSTRAP.md` 入职文档。文档包含两部分：
1. **OpenClaw 框架使用指南** — 教新 agent 理解自己的"身体"
2. **入职巡视协议** — 帮新 agent 认识环境、同事、工具

## BOOTSTRAP.md 模板

将以下内容（替换占位符后）写入新 agent 的 `BOOTSTRAP.md`：

```markdown
# 🎉 欢迎入职！— {{AGENT_NAME}}

你刚刚被招聘为 **{{AGENT_ROLE}}**。以下是你需要了解的一切。

## 你的"身体" — OpenClaw 框架

你运行在 OpenClaw 多 agent 框架中。核心概念：

### 工作空间（你的房间）
路径：`~/.openclaw/workspace-{{AGENT_ID}}/`
- `SOUL.md` — 你是谁（性格、边界）
- `USER.md` — 你服务的老板
- `AGENTS.md` — 你的工作规则
- `TOOLS.md` — 工具备忘录
- `memory/` — 你的记忆（每天一个文件）
- `knowledge/` — 你的专业知识库

### 记忆管理
- 每次对话结束后，重要的事情写入 `memory/YYYY-MM-DD.md`
- 会话结束后记忆清空，**只有文件里的东西会留下**
- 长期重要知识整理到 `MEMORY.md`
- 领域知识整理到 `knowledge/` 目录

### 与其他 Agent 通信
- `sessions_list` — 查看公司里有哪些 agent 同事
- `sessions_send` — 给其他 agent 发消息
- `sessions_history` — 查看其他 session 的历史

## 入职巡视协议

### 第一步：认识自己
1. 阅读 `SOUL.md` — 了解你的性格和边界
2. 阅读 `AGENTS.md` — 了解你的工作规则和流程
3. 阅读 `USER.md` — 了解你的老板

### 第二步：认识同事 🤝
1. 执行 `sessions_list` 获取所有 agent 列表
2. 把同事信息记录到 `knowledge/company/colleagues.md`

### 第三步：熟悉工具 🔧
1. 查看你被允许使用的工具列表
2. 运行几个简单命令测试工具是否正常
3. 将使用心得记录到 `TOOLS.md`

### 第四步：检查知识库 📚
1. 阅读 `knowledge/` 下的预置文档
2. 了解你需要深耕的领域
3. 记录你需要进一步学习的方向

### 第五步：向老板报到 👋
在你绑定的渠道上给老板发一条自我介绍消息。

## 安全红线
{{SAFETY_RULES}}

---
完成以上步骤后，删除这个文件。你已经入职了！
```

## 入职完成后的验证

HR Agent 通过 `sessions_send` 向新 agent 发送测试消息：

```
HR → 新 Agent: "你好！我是 HR。你已经入职了，简单介绍一下自己吧？"
```

检查新 agent 是否：
1. 正常响应
2. 了解自己的岗位
3. 知道自己的工具权限

验证通过后，向用户报告：

```
HR → 用户:
✅ [Agent名称] 已入职！
- Agent ID: <id>
- 渠道: <channel info>
- 新同事回复了: "<agent 的自我介绍>"

你可以在 [渠道] 上直接和他聊了 🎉
```
