#!/usr/bin/env bash
# HR Permission Check — 查询指定 Agent 的当前工具权限
# 用法: ./hr-permission-check.sh <agent-id>
# 输出: JSON 格式的权限状态
#
# ⚠️ 本脚本不修改任何配置，纯只读查询。任何 Agent 均可通过 exec 安全调用。

set -euo pipefail

AGENT_ID="${1:-}"

if [ -z "$AGENT_ID" ]; then
    echo "❌ 用法: $0 <agent-id>"
    echo "   示例: $0 librarian"
    exit 1
fi

# 检查 openclaw CLI 是否可用
if ! command -v openclaw &> /dev/null; then
    echo "❌ 错误: 未找到 openclaw CLI"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ 错误: 未找到 jq"
    exit 1
fi

# 查找 agent 在 agents.list 中的索引
AGENT_INDEX=$(openclaw config get agents.list | jq --arg id "$AGENT_ID" '[.[].id] | index($id)')

if [ "$AGENT_INDEX" = "null" ] || [ -z "$AGENT_INDEX" ]; then
    echo "❌ 错误: 未找到 Agent '$AGENT_ID'。请检查 ID 是否正确。"
    echo "当前已注册的 Agent 列表："
    openclaw config get agents.list | jq -r '.[].id'
    exit 1
fi

# 提取当前权限
ALLOW=$(openclaw config get "agents.list[$AGENT_INDEX].tools.allow" 2>/dev/null || echo '[]')
DENY=$(openclaw config get "agents.list[$AGENT_INDEX].tools.deny" 2>/dev/null || echo '[]')
AGENT_NAME=$(openclaw config get "agents.list[$AGENT_INDEX].identity.name" 2>/dev/null || echo '""')

# 统一格式化输出
echo "========================================"
echo "📋 Agent 权限报告: $AGENT_ID"
echo "========================================"
echo ""
echo "👤 名称: $(echo "$AGENT_NAME" | tr -d '"')"
echo ""
echo "✅ 已授权工具 (allow):"
echo "$ALLOW" | jq -r '.[]? // empty' | while read -r tool; do
    echo "   ✓ $tool"
done
echo ""
echo "🚫 已禁止工具 (deny):"
echo "$DENY" | jq -r '.[]? // empty' | while read -r tool; do
    echo "   ✗ $tool"
done
echo ""

# 输出机器可读的 JSON 摘要
echo "--- JSON 摘要 ---"
jq -n \
    --arg id "$AGENT_ID" \
    --arg name "$(echo "$AGENT_NAME" | tr -d '"')" \
    --argjson allow "$ALLOW" \
    --argjson deny "$DENY" \
    '{ id: $id, name: $name, allow: $allow, deny: $deny }'
