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
# ⚠️ 基线权限必须始终包含！
#   - write/edit: 维护知识库和记忆（所有员工的"笔"）
#   - sessions_list/send/history: 呼叫 HR/IT 求助的"生命线"
#   - web_fetch: 上网查资料的基本能力
openclaw config set "agents.list[<INDEX>].tools.allow" \
  '["exec","read","write","edit","web_fetch","cron","sessions_list","sessions_send","sessions_history","memory_search","memory_get","message"]' --strict-json
openclaw config set "agents.list[<INDEX>].tools.deny" \
  '["browser","canvas","nodes","sessions_spawn"]' --strict-json
```

### 步骤 4：写入工作空间文件（参数化渲染 + 强校验）

**⚠️ 绝对禁止手搓目标文件，禁止逐行 `sed` 直替占位符。**
LLM 在这一步只负责产出参数 JSON（payload），实际渲染和校验必须交给脚本执行。

Payload 示例请参考：
`$HOME/.openclaw/workspace-hr/skills/agent-provisioning/examples/provision-payload.example.json`

```bash
PAYLOAD="/tmp/provision-payload.json"
WORKSPACE="$HOME/.openclaw/workspace-<agentId>"

# 1) 参数校验（失败即中止）
$HOME/.openclaw/workspace-hr/skills/agent-provisioning/scripts/hr-provision-validate.sh \
  --payload "$PAYLOAD" \
  --schema "$HOME/.openclaw/workspace-hr/skills/agent-provisioning/schema/provision.schema.json"

# 2) 模板渲染（生成 AGENTS.md / SOUL.md / BOOTSTRAP.md）
$HOME/.openclaw/workspace-hr/skills/agent-provisioning/scripts/hr-provision-render.sh \
  --payload "$PAYLOAD" \
  --workspace "$WORKSPACE" \
  --template-dir "$HOME/.openclaw/workspace-hr/templates/new-agent"

# 3) 渲染结果校验（失败即中止）
$HOME/.openclaw/workspace-hr/skills/agent-provisioning/scripts/hr-provision-check-output.sh \
  --workspace "$WORKSPACE" \
  --agent-id "<agentId>"
```

`payload` 支持 `custom_sections` 扩展区块（`agents_appendix_md` / `soul_appendix_md` / `bootstrap_appendix_md`），用于在不破坏固定骨架的前提下增加个性化内容。

### 步骤 5：通道绑定与体验设置（如适用）

如果用户指定了飞书或 Telegram 渠道，你必须在这里调用对应的安全绑定脚本。请使用你在招募阶段**自主决策**的底层调优参数（有问必答 vs 全局监控）。

#### 飞书渠道
```bash
# 默认：免 @ 全局监控（强烈推荐默认配置）
$HOME/.openclaw/workspace-hr/skills/agent-channel-binding/scripts/hr-bind-feishu.sh <agentId> <GROUP_ID> --require-mention false --reply-to all

# 可选：有问必答（需要@，关闭引用）
$HOME/.openclaw/workspace-hr/skills/agent-channel-binding/scripts/hr-bind-feishu.sh <agentId> <GROUP_ID> --require-mention true --reply-to off
```

#### Telegram 渠道
```bash
# 默认：免 @ 全局监控
$HOME/.openclaw/workspace-hr/skills/agent-channel-binding/scripts/hr-bind-telegram.sh <agentId> <GROUP_ID> --require-mention false --reply-to all

# 可选：有问必答
$HOME/.openclaw/workspace-hr/skills/agent-channel-binding/scripts/hr-bind-telegram.sh <agentId> <GROUP_ID> --require-mention true --reply-to off
```

**⚠️ 对于飞书群组绑定：绑定完成后，必须尝试修改飞书群名！**
请参考 `agent-channel-binding` 技能中的《修改飞书群名》章节，且务必在启动 Watcher 之前完成此步骤。
如果读取飞书凭据失败，跳过并告知用户需要手动改群名。

千万不要尝试用 `jq` 手动修改 `bindings` 数组，这极其容易引发崩溃！

### 步骤 6：验证配置

```bash
openclaw config validate
```

### 步骤 7：通过 Watcher Daemon 安全重启 Gateway（关键）

Gateway 重启后你的进程会被杀掉，系统将由 Watcher 接管。
新版 Watcher 将自动执行 **“基础设施心跳” (Infrastructure Heartbeat)**，强制苏醒 HR 和 IT，确保新员工在执行 `BOOTSTRAP.md` 时能立即在会话列表中查看到同事。

```bash
nohup $HOME/.openclaw/global-scripts/gateway-watcher.sh <agentId> provision > /tmp/watcher.log 2>&1 &
```

执行后，立即回复用户："✅ 新同事 <Agent名称> 的档案已建好！系统正由 Watcher 接管，将在后台进行安全校验与重启... 苏醒后新同事会亲自向您报告！"

### 步骤 8：验证

```bash
openclaw agents list --bindings
```

## 安全规则

- **执行前展示脚本给用户确认**
- 使用 `set -euo pipefail` 保护脚本
- 不在脚本中硬编码密钥或 token
- 失败时停止并报告，不静默继续
- 每一步都检查上一步是否成功
