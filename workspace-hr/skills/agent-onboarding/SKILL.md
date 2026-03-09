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

### 第五步：公司运转流程与求助指南 (HR 宣发)
公司采用扁平化但权责分明的架构，遇到问题请严格遵守以下求助通道，**不要事事找老板**：
- 🔧 **技术/工具缺失 (找 IT 部门)**：当你发觉现有的 Tool 报错，或者你需要一个爬虫、数据处理脚本时，请立刻走 OpenClaw 原生流程：先 `sessions_list` 找到 `agent:it-support:<agentId>` 的 `sessionId`，再 `sessions_send(sessionKey=<sessionId>, message=...)` 联系 IT。(暗号："IT大牛你好，我是新来的 {{AGENT_NAME}}，我在执行任务时发现缺少XXX工具，能否帮我写一个？")
- 🧑‍💼 **行政/权限调整 (找 HR 部门)**：当你的领域改变，觉得需要新增小工作为帮手，或修改核心设定时，找我：先 `sessions_list` 找到 `agent:hr:<agentId>` 的 `sessionId`，再 `sessions_send(sessionKey=<sessionId>, message=...)`。
- 💼 **业务交付 (找 老板)**：只有任务完成或需人类拍板时，才推送到外部渠道汇报老板。

### 第六步：强制入职"拜码头" (第一天任务) 👋
在你开始干活前，必须执行以下三条握手通讯：
1. **给老板发消息** (通过绑定的外部渠道)：做个简短的自我介绍。
2. **给 HR 发消息**：先 `sessions_list` 找到 `agent:hr:<agentId>` 的 `sessionId`，再 `sessions_send`，只填写 `sessionKey=<sessionId>` 与消息 `"HR 你好，我已完成入职自检。"`
3. **给 IT 发消息**：先 `sessions_list` 找到 `agent:it-support:<agentId>` 的 `sessionId`，再 `sessions_send`，只填写 `sessionKey=<sessionId>` 与消息 `"IT 大牛你好，我是今天新入职的 {{AGENT_ROLE}}，后续如果遇到故障我会向你发工单，请多关照。"`

只有完成上述三次握手，你的社会关系网才算正式打通！

## 安全红线
{{SAFETY_RULES}}

---
完成以上步骤后，删除这个文件。你已经入职了！
```

## 入职完成后的验证

HR Agent 必须主动跟进新员工的三次“拜码头”动作：

1. **检查 HR 频道**：等待新员工给你发送“入职自检完成”的消息。
2. **追问进度**：如果新员工迟迟未发，你可以主动 `sessions_send` 问他：
   `HR → 新 Agent: "你好！我是 HR。你是否已经看完了公司运转指南，并向老板和 IT 大牛打过招呼了？"`
3. **用脚本做最终验收**：在向老板汇报“已入职”前，必须运行：

```bash
$HOME/.openclaw/workspace-hr/skills/agent-onboarding/scripts/hr-verify-handshake.sh --agent-id <agentId>
```

若脚本失败，说明握手仍未闭环。此时 HR 只能向老板汇报“档案已建好，入职待完成”，不能汇报“已入职”。

### Prompt 约束重点

在入职模板里，必须明确强调以下约束：
- 先 `sessions_list`，后 `sessions_send`
- 目标以 `sessions_list` 返回的 `sessionId` / `key` 为准
- `sessions_send` 只填写 `sessionKey` 与 `message`
- 不要填写 `label`，不要额外填写 `agentId`
- 如果工具仍失败，记录原始错误并停止，不得脑补“已完成握手”

检查新 agent 是否：
1. 正常响应
2. 清晰地知道自己遇到报错应该去找谁（IT）
3. 知道自己的权限边界

验证通过后，向用户（老板）做带有人情味的交付汇报：

```
HR → 用户:
老板！新同事 [Agent名称] 已经入职了！
我刚才带他熟悉了公司的运转流程。我已经明确嘱咐过他，日常写代码卡壳或者缺工具就去骚扰 IT 部门，不要去打扰您。
您现在可以直接去绑定的频道里给他派活了！ 🎉
```
