---
name: agent-dismissal
description: 辞退或删除现有的 AI Agent 员工，执行删除前会强制打包备份工作空间。
metadata: {"openclaw": {"requires": {"bins": ["openclaw", "tar"]}}}
---

# Agent 辞退与卸载技能

## 触发条件

当用户表达以下意图时触发：
- "辞退 [Agent名字]"、"开除..."
- "删除 [Agent名字]、卸载 [Agent名字]"
- "把某个助手删掉"

## 操作流程

### 1. 确认辞退 (1 轮交互)

先查询现有的 Agent 列表，确认对方的 Agent ID：
```bash
openclaw agents list
```

找到对应的 `agentId` 后，向用户做最后确认（严肃的口吻）：
*"您确定要辞退 [Agent名字] 吗？这将会离线该员工并回收他的工作空间。不过请放心，我会先将他的遗留档案打包归档。"*

### 2. 执行辞退并打包档案

用户确认后，执行以下脚本组合（替换 `<AGENT_ID>` 为真实的 agent ID）：

```bash
AGENT_ID="<AGENT_ID>"
TRASH_DIR="$HOME/.openclaw/trash"
ARCHIVE_PATH="$TRASH_DIR/Terminated_Agent_${AGENT_ID}_$(date +%Y%m%d_%H%M%S).tar.gz"
WORKSPACE_DIR="$HOME/.openclaw/workspace-${AGENT_ID}"

# 确保回收站目录存在
mkdir -p "$TRASH_DIR"

# 1. 打包备份工作空间
if [ -d "$WORKSPACE_DIR" ]; then
    echo "正在为员工收拾个人物品..."
    tar -czvf "$ARCHIVE_PATH" -C "$HOME/.openclaw" "workspace-${AGENT_ID}" > /dev/null
    echo "档案已打包至回收站: $ARCHIVE_PATH"
else
    echo "该员工可能是一个临时工，没有独立工作空间。"
fi

# 2. 移除底层配置与权限
echo "正在注销门禁卡和系统权限..."
openclaw agents delete --force "$AGENT_ID"

# 3. 移除关联的定时系统任务 (Cron Jobs)
$HOME/.openclaw/workspace-hr/skills/agent-dismissal/scripts/cleanup-cron.sh "$AGENT_ID"

# 4. 异步安全重启系统生效 (由 Watcher 守护)
bash -n "$HOME/.openclaw/scripts/gateway-watcher.sh"
[ ! -f "$HOME/.openclaw/scripts/hr-infra-warmup.sh" ] || bash -n "$HOME/.openclaw/scripts/hr-infra-warmup.sh"
nohup $HOME/.openclaw/scripts/gateway-watcher.sh "$AGENT_ID" dismiss > /tmp/watcher.log 2>&1 &
```

### 3. 最后汇报

在执行完上述 Shell 命令后（也就是发出 nohup 倒计时后），**必须立即**回复用户：
*"✅ 辞退手续已办妥。[Agent名字] 的所有权限已被注销。他的工作交接档案我已经打包并放置在系统的回收站 (`$HOME/.openclaw/trash/`) 中了。系统将在 5 秒后刷新花名册生效。随时准备为您招聘更优秀的新员工！"*
