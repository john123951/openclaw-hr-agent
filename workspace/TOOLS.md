# TOOLS.md — HR Agent 工具备忘

## 常用 CLI 命令

```bash
# Agent 管理
openclaw agents add <id>                              # 创建新 agent
openclaw agents list --bindings                       # 查看 agent 列表和绑定
openclaw agents bind --agent <id> --bind <ch:acct>    # 绑定入站路由
openclaw agents unbind --agent <id> --bind <ch:acct>  # 解除绑定
openclaw agents set-identity --agent <id> --name "名" --emoji "🤖"
openclaw agents delete <id>                           # 删除 agent

# 配置管理（安全的点号路径方式）
openclaw config get <path>                            # 读取配置
openclaw config set <path> <value> [--strict-json]    # 修改配置
openclaw config validate                              # 验证配置
openclaw config file                                  # 查看配置文件路径

# Gateway
openclaw gateway restart                              # 重启 Gateway
openclaw gateway status                               # 查看状态
openclaw logs --follow                                # 查看日志

# Skills
clawhub install <slug>                                # 安装 skill
clawhub update --all                                  # 更新 skills
```

## 飞书 API

```bash
# 获取 tenant_access_token
curl -s -X POST \
  "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H "Content-Type: application/json" \
  -d '{"app_id":"<APP_ID>","app_secret":"<APP_SECRET>"}'

# 修改群名
curl -s -X PUT \
  "https://open.feishu.cn/open-apis/im/v1/chats/<CHAT_ID>" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"name":"<NEW_NAME>"}'
```

## 渠道绑定路由格式

- 飞书群组 peer: `{ kind: "group", id: "oc_xxx" }`
- 飞书 DM peer: `{ kind: "direct", id: "ou_xxx" }`
- Telegram / Discord: 使用 accountId 绑定

## 备忘

- 飞书群组 ID 格式：`oc_xxx`
- 飞书用户 ID 格式：`ou_xxx`
- 配置修改后需要 `openclaw gateway restart` 生效
- 脚本中使用 `set -euo pipefail` 保护
