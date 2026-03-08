#!/usr/bin/env bash
# Permission Selfcheck — AI 员工权限自检脚本
# 用法: $HOME/.openclaw/scripts/permission-selfcheck.sh <agent-id>
#
# 本脚本部署到 ~/.openclaw/scripts/，任何 Agent 均可通过 exec 调用。
# 功能：
#   1. 查询自身当前权限
#   2. 尝试执行受控测试操作以验证权限是否真正生效
#   3. 输出诊断报告（包含建议）

set -euo pipefail

AGENT_ID="${1:-}"

if [ -z "$AGENT_ID" ]; then
    echo "❌ 用法: $0 <你的agent-id>"
    echo "   示例: $0 librarian"
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

# 查找 agent
AGENT_INDEX=$(openclaw config get agents.list | jq --arg id "$AGENT_ID" '[.[].id] | index($id)')

if [ "$AGENT_INDEX" = "null" ] || [ -z "$AGENT_INDEX" ]; then
    echo "❌ 错误: 未找到 Agent '$AGENT_ID'"
    exit 1
fi

ALLOW=$(openclaw config get "agents.list[$AGENT_INDEX].tools.allow" 2>/dev/null || echo '[]')
DENY=$(openclaw config get "agents.list[$AGENT_INDEX].tools.deny" 2>/dev/null || echo '[]')
WORKSPACE=$(openclaw config get "agents.list[$AGENT_INDEX].workspace" 2>/dev/null | tr -d '"' || echo "")
WORKSPACE="${WORKSPACE/#\~/$HOME}"

echo "========================================"
echo "🔍 Agent 权限自检报告: $AGENT_ID"
echo "========================================"
echo ""

# 检查常用权限状态
declare -a ISSUES=()
declare -a SUGGESTIONS=()

check_tool() {
    local tool="$1"
    local desc="$2"
    local in_allow=$(echo "$ALLOW" | jq --arg t "$tool" 'any(. == $t)')
    local in_deny=$(echo "$DENY" | jq --arg t "$tool" 'any(. == $t)')

    if [ "$in_allow" = "true" ] && [ "$in_deny" = "true" ]; then
        echo "   ⚠️ $tool ($desc): 冲突！同时在 allow 和 deny 中"
        ISSUES+=("$tool 存在 allow/deny 冲突")
        SUGGESTIONS+=("向 HR 申请修复 $tool 的冲突配置")
    elif [ "$in_allow" = "true" ]; then
        echo "   ✅ $tool ($desc): 已授权"
    elif [ "$in_deny" = "true" ]; then
        echo "   🚫 $tool ($desc): 已禁止"
    else
        echo "   ⚪ $tool ($desc): 未明确配置（取决于系统默认）"
    fi
}

echo "📋 工具权限状态："
echo ""
check_tool "read" "读取文件"
check_tool "write" "写入文件"
check_tool "edit" "编辑文件"
check_tool "exec" "执行命令"
check_tool "browser" "浏览器"
check_tool "cron" "定时任务"
check_tool "sessions_list" "查看会话"
check_tool "sessions_send" "发送消息"
check_tool "sessions_spawn" "创建子Agent"
check_tool "sessions_history" "查看历史"
check_tool "memory_search" "搜索记忆"
check_tool "memory_get" "获取记忆"
check_tool "web_fetch" "网页抓取"
check_tool "message" "消息工具"
check_tool "canvas" "画布"
check_tool "nodes" "节点"

echo ""
echo "🔍 检查基线权限完整性..."
baselines=("write" "edit" "web_fetch" "sessions_list" "sessions_send" "sessions_history" "memory_search" "memory_get" "message")
for base in "${baselines[@]}"; do
    if ! echo "$ALLOW" | jq -e --arg t "$base" 'any(. == $t)' >/dev/null; then
        echo "   ❌ 缺失基线权限: $base"
        ISSUES+=("缺失基线权限: $base")
        SUGGESTIONS+=("向 HR 申请基线权限: $base")
    fi
done

# 工作空间写入测试
if [ -n "$WORKSPACE" ] && [ -d "$WORKSPACE" ]; then
    echo "📁 工作空间测试 ($WORKSPACE)："
    TEST_FILE="$WORKSPACE/.permission-test-$(date +%s)"
    if echo "test" > "$TEST_FILE" 2>/dev/null; then
        rm -f "$TEST_FILE"
        echo "   ✅ 工作空间可写"
    else
        echo "   🚫 工作空间不可写（文件系统层面）"
    fi
else
    echo "📁 工作空间：未配置或不存在"
fi

echo ""
echo "========================================"

# 输出建议
if [ ${#ISSUES[@]} -gt 0 ]; then
    echo ""
    echo "⚠️ 发现 ${#ISSUES[@]} 个问题："
    for issue in "${ISSUES[@]}"; do
        echo "   • $issue"
    done
    echo ""
    echo "💡 建议操作："
    for sug in "${SUGGESTIONS[@]}"; do
        echo "   → $sug"
    done
    echo ""
    echo "📤 向 HR 申请权限的标准话术："
    echo '   "HR 你好，我是 '"$AGENT_ID"'。我在执行工作时发现权限不足：'
    for issue in "${ISSUES[@]}"; do
        echo "   - $issue"
    done
    echo '   请协助调整我的工具权限，谢谢！"'
else
    echo ""
    echo "✅ 当前权限配置无明显问题。"
fi
