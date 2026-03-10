#!/usr/bin/env bash
# HR Permission Revoke — 回收指定 Agent 的工具权限
# 用法: ./hr-permission-revoke.sh <agent-id> <tool1,tool2,...> [--restart]
# 仅供 HR Agent 调用！
#
# ⚠️ 设计原则：
#   - 将指定的工具从 tools.allow 中移除
#   - 同时加入 tools.deny（确保禁止生效）
#   - 执行 openclaw config validate 确认配置无误
#   - 可选通过 --restart 触发 Watcher 安全重启

set -euo pipefail

AGENT_ID="${1:-}"
TOOLS_CSV="${2:-}"
DO_RESTART="false"

# 解析参数
for arg in "$@"; do
    if [ "$arg" = "--restart" ]; then
        DO_RESTART="true"
    fi
done

if [ -z "$AGENT_ID" ] || [ -z "$TOOLS_CSV" ]; then
    echo "❌ 用法: $0 <agent-id> <tool1,tool2,...> [--restart]"
    echo "   示例: $0 librarian browser,canvas"
    echo "   带重启: $0 librarian browser,canvas --restart"
    exit 1
fi

if ! command -v openclaw &> /dev/null; then
    echo "❌ 错误: 未找到 openclaw CLI"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ 错误: 未找到 jq"
    exit 1
fi

# 查找 agent 索引
AGENT_INDEX=$(openclaw config get agents.list | jq --arg id "$AGENT_ID" '[.[].id] | index($id)')

if [ "$AGENT_INDEX" = "null" ] || [ -z "$AGENT_INDEX" ]; then
    echo "❌ 错误: 未找到 Agent '$AGENT_ID'"
    exit 1
fi

echo "[Permission Revoke] 开始回收 Agent '$AGENT_ID' 的权限..."

# 读取当前 allow 和 deny
CURRENT_ALLOW=$(openclaw config get "agents.list[$AGENT_INDEX].tools.allow" 2>/dev/null || echo '[]')
CURRENT_DENY=$(openclaw config get "agents.list[$AGENT_INDEX].tools.deny" 2>/dev/null || echo '[]')

echo "[Permission Revoke] 当前 allow: $CURRENT_ALLOW"
echo "[Permission Revoke] 当前 deny:  $CURRENT_DENY"

# 将逗号分隔的工具转为 JSON 数组
IFS=',' read -ra TOOLS_ARRAY <<< "$TOOLS_CSV"
TOOLS_JSON=$(printf '%s\n' "${TOOLS_ARRAY[@]}" | jq -R . | jq -s .)

echo "[Permission Revoke] 即将回收: $TOOLS_JSON"

# 1. 从 allow 中移除
NEW_ALLOW=$(echo "$CURRENT_ALLOW" | jq --argjson revoke "$TOOLS_JSON" '. - $revoke')

# 2. 添加到 deny（去重）
NEW_DENY=$(echo "$CURRENT_DENY" | jq --argjson revoke "$TOOLS_JSON" '. + $revoke | unique')

echo "[Permission Revoke] 新 allow: $NEW_ALLOW"
echo "[Permission Revoke] 新 deny:  $NEW_DENY"

# 3. 写入配置
openclaw config set "agents.list[$AGENT_INDEX].tools.allow" "$NEW_ALLOW" --strict-json
openclaw config set "agents.list[$AGENT_INDEX].tools.deny" "$NEW_DENY" --strict-json

# 4. 校验配置
echo "[Permission Revoke] 正在校验配置..."
if openclaw config validate > /dev/null 2>&1; then
    echo "[Permission Revoke] ✅ 配置校验通过！"
else
    echo "[Permission Revoke] ❌ 配置校验失败！请检查 openclaw.json"
    exit 1
fi

# 5. 可选：通过 Watcher 安全重启
if [ "$DO_RESTART" = "true" ]; then
    echo "[Permission Revoke] 🔄 正在通过 Watcher 安全重启 Gateway..."
    WATCHER_SCRIPT="$HOME/.openclaw/scripts/gateway-watcher.sh"
    WARMUP_SCRIPT="$HOME/.openclaw/scripts/hr-infra-warmup.sh"
    if [ -f "$WATCHER_SCRIPT" ]; then
        if ! bash -n "$WATCHER_SCRIPT"; then
            echo "[Permission Revoke] ❌ Watcher 脚本语法校验失败，已中止后台重启。"
            exit 1
        fi
        if [ -f "$WARMUP_SCRIPT" ] && ! bash -n "$WARMUP_SCRIPT"; then
            echo "[Permission Revoke] ❌ 基础设施预热脚本语法校验失败，已中止后台重启。"
            exit 1
        fi
        nohup "$WATCHER_SCRIPT" "$AGENT_ID" permission-update > /tmp/watcher.log 2>&1 &
        echo "[Permission Revoke] ✅ Watcher 已启动，Gateway 将在后台安全重启。"
    else
        echo "[Permission Revoke] ⚠️ 未找到 Watcher 脚本，请手动执行: openclaw gateway restart"
    fi
fi

echo ""
echo "[Permission Revoke] ✅ 权限回收完成！Agent '$AGENT_ID' 已被禁止使用工具: $TOOLS_CSV"
echo "[Permission Revoke] ⚠️ 提醒：权限变更需重启 Gateway 后生效。如未带 --restart，请手动重启。"
