#!/usr/bin/env bash
# HR Permission Discover — 动态发现当前系统所有可配置的权限
# 用法: ./hr-permission-discover.sh
# 仅供 HR Agent 参考，帮助了解系统中有哪些权限可分配
#
# 本脚本从两个来源汇总权限信息：
# 1. OpenClaw 内置工具组（固定列表）
# 2. 已安装的 Plugin（动态发现）

set -euo pipefail

if ! command -v openclaw &> /dev/null; then
    echo "❌ 错误: 未找到 openclaw CLI"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ 错误: 未找到 jq"
    exit 1
fi

echo "========================================"
echo "📋 OpenClaw 权限全景发现报告"
echo "========================================"
echo ""
echo "═══════════════════════════════════════"
echo "📦 内置工具（固定）"
echo "═══════════════════════════════════════"
echo ""
echo "  group:fs        → read, write, edit, apply_patch"
echo "  group:runtime   → exec, process"
echo "  group:sessions  → sessions_list, sessions_history, sessions_send, sessions_spawn, session_status"
echo "  group:memory    → memory_search, memory_get"
echo "  group:web       → web_search, web_fetch"
echo "  group:ui        → browser, canvas"
echo "  group:automation→ cron, gateway"
echo "  group:messaging → message"
echo "  group:nodes     → nodes"
echo "  其他            → image, agents_list"
echo ""

echo "═══════════════════════════════════════"
echo "🔌 已安装的 Plugin（动态）"
echo "═══════════════════════════════════════"
echo ""

# 尝试从 openclaw.json 读取已安装的 plugin
PLUGINS_INSTALLS=$(openclaw config get plugins.installs 2>/dev/null || echo '{}')
PLUGINS_ENTRIES=$(openclaw config get plugins.entries 2>/dev/null || echo '{}')

if [ "$PLUGINS_INSTALLS" = "{}" ] && [ "$PLUGINS_ENTRIES" = "{}" ]; then
    echo "  （未安装任何 Plugin）"
else
    echo "  已安装的 Plugin:"
    echo "$PLUGINS_INSTALLS" | jq -r 'keys[]' 2>/dev/null | while read -r plugin_id; do
        SOURCE=$(echo "$PLUGINS_INSTALLS" | jq -r --arg id "$plugin_id" '.[$id].source // "unknown"')
        VERSION=$(echo "$PLUGINS_INSTALLS" | jq -r --arg id "$plugin_id" '.[$id].resolvedVersion // "unknown"')
        ENABLED=$(echo "$PLUGINS_ENTRIES" | jq -r --arg id "$plugin_id" '.[$id].enabled // true')
        echo "    • $plugin_id (版本: $VERSION, 来源: $SOURCE, 启用: $ENABLED)"
    done
    echo ""
    echo "  ⚠️ Plugin 可能注册额外的工具名称。"
    echo "  请在 tools.allow/tools.deny 中使用 Plugin ID 作为工具名来控制。"
    echo "  例如: tools.allow 中添加 \"semrush\" 以允许使用 Semrush 插件。"
fi

echo ""
echo "═══════════════════════════════════════"
echo "👥 当前各 Agent 权限概览"
echo "═══════════════════════════════════════"
echo ""

AGENTS_LIST=$(openclaw config get agents.list 2>/dev/null || echo '[]')

echo "$AGENTS_LIST" | jq -r '.[] | .id' | while read -r agent_id; do
    AGENT_INDEX=$(echo "$AGENTS_LIST" | jq --arg id "$agent_id" '[.[].id] | index($id)')
    AGENT_NAME=$(echo "$AGENTS_LIST" | jq -r --arg id "$agent_id" '.[] | select(.id == $id) | .identity.name // "(无名称)"')
    ALLOW=$(echo "$AGENTS_LIST" | jq -r --arg id "$agent_id" '.[] | select(.id == $id) | .tools.allow // [] | join(", ")')
    DENY=$(echo "$AGENTS_LIST" | jq -r --arg id "$agent_id" '.[] | select(.id == $id) | .tools.deny // [] | join(", ")')

    # 检查基线权限是否完整
    HAS_SESSIONS_LIST=$(echo "$AGENTS_LIST" | jq --arg id "$agent_id" '.[] | select(.id == $id) | .tools.allow // [] | any(. == "sessions_list")')
    HAS_SESSIONS_SEND=$(echo "$AGENTS_LIST" | jq --arg id "$agent_id" '.[] | select(.id == $id) | .tools.allow // [] | any(. == "sessions_send")')
    HAS_SESSIONS_HISTORY=$(echo "$AGENTS_LIST" | jq --arg id "$agent_id" '.[] | select(.id == $id) | .tools.allow // [] | any(. == "sessions_history")')

    BASELINE_OK="✅"
    BASELINE_MISSING=""
    if [ "$HAS_SESSIONS_LIST" != "true" ]; then
        BASELINE_OK="❌"
        BASELINE_MISSING="sessions_list "
    fi
    if [ "$HAS_SESSIONS_SEND" != "true" ]; then
        BASELINE_OK="❌"
        BASELINE_MISSING="${BASELINE_MISSING}sessions_send "
    fi
    if [ "$HAS_SESSIONS_HISTORY" != "true" ]; then
        BASELINE_OK="❌"
        BASELINE_MISSING="${BASELINE_MISSING}sessions_history "
    fi

    echo "  [$agent_id] $AGENT_NAME"
    echo "    allow: $ALLOW"
    echo "    deny:  $DENY"
    if [ "$BASELINE_OK" = "❌" ]; then
        echo "    ⚠️ 基线缺失: $BASELINE_MISSING"
    else
        echo "    $BASELINE_OK 基线权限完整"
    fi
    echo ""
done

echo "========================================"
echo "💡 详细权限说明请查阅:"
echo "   \$HOME/.openclaw/workspace-hr/skills/agent-permission/permission-catalog.md"
echo "========================================"
