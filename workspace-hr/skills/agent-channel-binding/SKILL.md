---
name: agent-channel-binding
description: 将新 agent 绑定到飞书/Telegram/Discord 等通信渠道，含飞书 API 修改群名
metadata: {"openclaw": {"requires": {"bins": ["openclaw", "curl"]}}}
---

# Agent 渠道绑定技能

## 概述

将新创建的 agent 绑定到用户指定的通信渠道，确保用户可以通过飞书/Telegram/Discord 等平台与新 agent 对话。

## 支持的渠道

| 渠道 | 绑定方式 | 额外操作 |
|------|---------|---------|
| 飞书群组 | peer binding (group) | 可自动改群名 |
| 飞书私聊 | peer binding (direct) | — |
| Telegram | account binding | — |
| Discord | account binding | — |
| WhatsApp | account binding | — |
| WebChat | 无需绑定 | 默认可用 |

## 飞书群组绑定（完整流程）

### 1. 使用专用绑定脚本（推荐、安全）

**注意：千万不要尝试直接用 `jq` 去手写 `openclaw.json` 中的 `bindings` 数组，这极其容易引发严重的重复项或 JSON 破损崩溃！**

请直接调用预置的安全绑定工具脚本：

```bash
# 基本绑定：只绑定到基础飞书渠道（不指定群组）
$HOME/.openclaw/workspace-hr/skills/agent-channel-binding/scripts/hr-bind-feishu.sh <agentId>

# 高级绑定：路由到特定飞书群（如 oc_12345），并附跟你自动决策的体验配置
# 参数解释：
# --require-mention <true/false>: true表示:必须@机器人，false表示:无需@机器人
# --reply-to <all/off>: all表示开启引用原消息，off表示关闭（注意：开启all会自动禁用系统卡片流式输出）

$HOME/.openclaw/workspace-hr/skills/agent-channel-binding/scripts/hr-bind-feishu.sh <agentId> <GROUP_ID> \
  --require-mention <true|false> \
  --reply-to <all|off>
```

只要脚本执行完毕，飞书路由通道及相关的体验/性能调优便完美建立。

### 2. 修改飞书群名（调用飞书 API）

**前提**：需要从配置中读取飞书 App ID 和 App Secret。

```bash
# 读取飞书凭据
APP_ID=$(openclaw config get channels.feishu.appId | tail -n 1 | tr -d '"')
APP_SECRET=$(openclaw config get channels.feishu.appSecret | tail -n 1 | tr -d '"')

# 获取 tenant_access_token
TOKEN=$(curl -s -X POST \
  "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['tenant_access_token'])")

# 修改群名
curl -s -X PUT \
  "https://open.feishu.cn/open-apis/im/v1/chats/<GROUP_ID>" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"<AGENT_NAME>\"}"
```

**注意**：
- 如果读不到飞书凭据，跳过改群名，告诉用户需要手动修改
- 修改群名需要 bot 在群内且有 `im:chat.members:bot_access` 权限

## Telegram 绑定（完整流程）

Telegram 由于是公开渠道，**安全白名单**与**体验控制**极其重要。
千万不要尝试直接修改 `bindings` 数组。请一律使用内置的 Telegram 绑定强化工具：

```bash
# 基本绑定：只绑定到基础 Telegram 渠道（开启私聊）
$HOME/.openclaw/workspace-hr/skills/agent-channel-binding/scripts/hr-bind-telegram.sh <agentId>

# 高级绑定：路由到特定的 Telegram 群组（如 -1001234567890），并由你自动附带体验配置
# 参数解释：
# --require-mention <true/false>: true表示:必须@机器人，false表示:无需@机器人
# --reply-to <all/off>: all表示开启引用原消息，off表示关闭

$HOME/.openclaw/workspace-hr/skills/agent-channel-binding/scripts/hr-bind-telegram.sh <agentId> <GROUP_ID> \
  --require-mention <true|false> \
  --reply-to <all|off>
```

无论哪种绑定，脚本都将自动为当前 Agent 开启**拟真表情反应互动** `reactionLevel=minimal`，让他活得更像个人。对于群组绑定，脚本也会自动将该群组列入 Telegram 频道的**强制安全白名单**中，防止乱入其他野群。

## Discord 绑定

```bash
openclaw agents bind --agent <agentId> --bind discord:default
```

如果需要绑定到特定 Discord 服务器频道，需要添加 peer 级别 binding。

## 验证

绑定完成后验证：

```bash
openclaw agents list --bindings

# 提示：不需要在这里重启 Gateway。
# 因为在此招聘流程的最后，一定要调用 `agent-provisioning` 里的 Watcher 脚本，
# 那个脚本会在后台自动执行校验、延迟重启和新员工唤醒。
```

```bash
# 重启完成后，可使用此命令检查健康状态（可选）：
openclaw channels status --probe
```

**补充纪律：**
- 群组绑定脚本只负责路由与群设置，不负责替 HR / IT 做外部汇报。
- 任何系统内部激活、握手探测、agent-to-agent 心跳，都**不得**使用外部渠道投递，除非显式带上目标 `chatId` / `reply-to`。
