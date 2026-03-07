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

### 1. 添加基础绑定

```bash
openclaw agents bind --agent <agentId> --bind "feishu:main"
```

### 2. 添加 peer 级别路由（精确到群组）

读取现有 bindings 并追加新绑定：

```bash
# 方法一：使用 openclaw config set 添加绑定项
# 先查看当前 bindings 数量
openclaw config get bindings --strict-json

# 追加新 binding（使用下一个索引）
openclaw config set "bindings[<NEXT_INDEX>]" \
  '{"agentId":"<agentId>","match":{"channel":"feishu","peer":{"kind":"group","id":"<GROUP_ID>"}}}' \
  --strict-json
```

### 3. 配置群组不需要 @mention

```bash
openclaw config set \
  "channels.feishu.groups.<GROUP_ID>.requireMention" \
  false --strict-json
```

### 4. 修改飞书群名（调用飞书 API）

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

## Telegram 绑定

```bash
openclaw agents bind --agent <agentId> --bind telegram:default
```

如果需要绑定到特定 Telegram 账号：

```bash
openclaw agents bind --agent <agentId> --bind "telegram:<accountId>"
```

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
