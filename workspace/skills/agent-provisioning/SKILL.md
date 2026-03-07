---
name: agent-provisioning
description: 通过 OpenClaw CLI 命令自动创建新 agent，生成并执行安全的创建脚本
metadata: {"openclaw": {"requires": {"bins": ["openclaw"]}}}
---

# Agent 创建配置技能

## 概述

在招聘方案确认后，使用 OpenClaw CLI 命令创建新 agent。**绝不手动编辑 openclaw.json**。

## 创建流程

### 步骤 1：创建 Agent

```bash
openclaw agents add <agentId>
```

这会自动创建：
- `~/.openclaw/workspace-<agentId>/`
- `~/.openclaw/agents/<agentId>/agent/`
- `~/.openclaw/agents/<agentId>/sessions/`

### 步骤 2：设置身份

```bash
openclaw agents set-identity --agent <agentId> \
  --name "<Agent名称>" --emoji "<Emoji>"
```

### 步骤 3：配置模型和工具权限

先查找 agent 在 `agents.list` 中的索引：

```bash
openclaw config get agents.list
```

然后用索引设置配置：

```bash
# 设置模型
openclaw config set "agents.list[<INDEX>].model" "<model>"

# 设置工具权限（根据岗位模板）
openclaw config set "agents.list[<INDEX>].tools.allow" \
  '["exec","read","cron"]' --strict-json
openclaw config set "agents.list[<INDEX>].tools.deny" \
  '["write","edit","browser","canvas","nodes"]' --strict-json
```

### 步骤 4：写入工作空间文件

从模板生成并写入以下文件到 `~/.openclaw/workspace-<agentId>/`：

1. **AGENTS.md** — 基于 `{baseDir}/../../templates/new-agent/AGENTS.md.template`
2. **SOUL.md** — 基于 `{baseDir}/../../templates/new-agent/SOUL.md.template`
3. **BOOTSTRAP.md** — 基于 `{baseDir}/../../templates/new-agent/BOOTSTRAP.md.template`

模板中的占位符替换规则：
- `{{AGENT_ID}}` → agent ID
- `{{AGENT_NAME}}` → agent 显示名称
- `{{AGENT_ROLE}}` → 岗位职责描述
- `{{AGENT_TOOLS_DESC}}` → 工具说明（人话）
- `{{WORK_SCHEDULE}}` → 工作时间/频率
- `{{SAFETY_RULES}}` → 安全红线
- `{{KNOWLEDGE_FOCUS}}` → 知识领域

### 步骤 5：验证配置

```bash
openclaw config validate
```

### 步骤 6：通过 Watcher Daemon 安全重启 Gateway（关键）

Gateway 重启后你的进程会被杀掉，用户也收不到确认消息，甚至如果配置错误 Gateway 会崩溃。因此**绝对不能**直接调用 `openclaw gateway restart`。

请运行系统自带的 Watcher 守护进程，它会负责安全的延时重启、故障自愈、大模型修复，并最终自动唤醒新角色！

```bash
nohup $HOME/.openclaw/workspace-hr/scripts/hr-gateway-watcher.sh <agentId> provision > /tmp/hr-watcher.log 2>&1 &
```

执行后，立即回复用户："✅ 新同事 <Agent名称> 的档案已建好！系统正由 Watcher 接管，将在后台进行安全校验与重启... 苏醒后新同事会亲自向您报告！"

### 步骤 7：验证

```bash
openclaw agents list --bindings
```

## 安全规则

- **执行前展示脚本给用户确认**
- 使用 `set -euo pipefail` 保护脚本
- 不在脚本中硬编码密钥或 token
- 失败时停止并报告，不静默继续
- 每一步都检查上一步是否成功
