---
name: agent-permission
description: 管理 AI 员工的工具权限：查询、授予、回收权限。处理员工的权限申请请求。
metadata: {"openclaw": {"requires": {"bins": ["openclaw", "jq"]}}}
---

# Agent 权限管理技能

## 概述

当 AI 员工在工作中发现自己权限不足时，可以通过 `sessions_send → hr` 向 HR 发起权限申请。HR 使用本技能中封装的安全脚本处理权限变更，**绝不手动编辑 openclaw.json**。

### 参考资料
- **权限速查清单**：`{baseDir}/permission-catalog.md` — 所有内置工具的风险等级、适用场景、审批标准
- **动态发现脚本**：`{baseDir}/scripts/hr-permission-discover.sh` — 查看当前系统已安装 Plugin 扩展的权限，以及各 Agent 基线权限是否完整

## 触发条件

当收到以下类型的消息时触发：
- 其他 Agent 通过 `sessions_send` 发来的权限申请
- 用户直接要求调整某个 Agent 的权限
- 关键词：「权限」「申请」「write权限」「没有权限」「permission」「工具不够用」

## 处理流程

### 第一步：查询当前权限

先用查询脚本了解该员工的当前权限状态：

```bash
$HOME/.openclaw/workspace-hr/skills/agent-permission/scripts/hr-permission-check.sh <agentId>
```

### 第二步：评估申请合理性

根据员工的岗位职责判断权限是否合理：

| 权限 | 低风险（HR 可自行批复） | 高风险（需老板确认） |
|------|----------------------|-------------------|
| `read` | ✅ | — |
| `write` | ✅ 知识/文案类岗位 | ⚠️ 监控类岗位 |
| `edit` | ✅ 开发/文案类岗位 | ⚠️ 其他岗位 |
| `browser` | ✅ 调研/监控类 | ⚠️ 其他岗位 |
| `exec` | ✅ 大多数岗位 | — |
| `memory_search` / `memory_get` | ✅ | — |
| `sessions_spawn` | ⚠️ 需确认理由 | ⚠️ 一般需老板确认 |
| `cron` | ✅ 定时任务类 | ⚠️ 其他岗位 |
| `canvas` / `nodes` | — | ❌ 一般不授予 |

**判断原则**：
- 参考 `{baseDir}/../../templates/jobs/job-profiles.json` 中该岗位的推荐权限
- 如果申请的权限在该岗位模板的 `allow` 中已经有，HR 可直接批复
- 如果申请模板中 `deny` 的权限，需要充分的理由并向老板确认

### 第三步：执行权限变更

#### 授予权限

```bash
$HOME/.openclaw/workspace-hr/skills/agent-permission/scripts/hr-permission-grant.sh <agentId> <tool1,tool2,...> --restart
```

#### 回收权限

```bash
$HOME/.openclaw/workspace-hr/skills/agent-permission/scripts/hr-permission-revoke.sh <agentId> <tool1,tool2,...> --restart
```

### 第四步：通知员工

权限变更后，通过 `sessions_send` 通知该员工：

> "你好 [Agent名称]，你申请的 [权限列表] 权限已经批复并生效。系统正在重启中，稍后你就可以使用新权限了。祝工作顺利！"

如果被驳回：

> "你好 [Agent名称]，你申请的 [权限列表] 权限经评估暂不适合开放。原因：[具体原因]。如有疑问请再次沟通。"

## 批量诊断（主动巡检）

HR 可以主动对所有在职员工进行权限健康检查：

```bash
# 列出所有 agent 及其权限
for agent_id in $(openclaw config get agents.list | jq -r '.[].id'); do
    echo "========= $agent_id ========="
    $HOME/.openclaw/workspace-hr/skills/agent-permission/scripts/hr-permission-check.sh "$agent_id"
    echo ""
done
```

## 安全规则

- **绝不手动编辑 openclaw.json** — 只通过本技能的封装脚本操作
- **高危权限必须经老板确认** — `sessions_spawn`、非岗位模板推荐的权限
- **每次变更后必须验证** — 脚本内已内置 `openclaw config validate`
- **变更需重启才生效** — 脚本的 `--restart` 参数会安全触发 Watcher 重启
- **保持最小权限原则** — 只授予工作确实需要的权限，不多给
