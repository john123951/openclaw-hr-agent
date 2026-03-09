#!/usr/bin/env bash
# Onboarding State Machine Manager
# 管理新员工入职状态机的状态转换和验证
#
# 用法:
#   hr-onboarding-state.sh --agent-id <id> --action <action> [--transition <transition>]
#
# Actions:
#   status     - 显示当前状态
#   transition - 执行状态转换
#   validate   - 验证状态文件完整性
#   history    - 显示状态历史

set -euo pipefail

AGENT_ID=""
ACTION=""
TRANSITION=""
STATE_FILE=""

usage() {
  cat <<'EOF'
用法:
  hr-onboarding-state.sh --agent-id <agent-id> --action <action> [options]

Actions:
  status              显示当前状态
  transition          执行状态转换 (需要 --transition 参数)
  validate            验证状态文件完整性
  history             显示状态历史

Options:
  --agent-id <id>     Agent ID (必填)
  --transition <name> 状态转换名称 (transition action 必填)
  --help              显示帮助信息

示例:
  hr-onboarding-state.sh --agent-id dev-001 --action status
  hr-onboarding-state.sh --agent-id dev-001 --action transition --transition bootstrap_reading
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id)
      AGENT_ID="${2:-}"
      shift 2
      ;;
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --transition)
      TRANSITION="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "❌ 未知参数: $1"
      usage
      exit 1
      ;;
  esac
done

if [ -z "$AGENT_ID" ]; then
  echo "❌ 缺少 --agent-id"
  usage
  exit 1
fi

if [ -z "$ACTION" ]; then
  echo "❌ 缺少 --action"
  usage
  exit 1
fi

# 检查依赖
for bin in yq jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "❌ 错误: 未找到依赖命令 $bin"
    exit 1
  done
fi

WORKSPACE_DIR="$HOME/.openclaw/workspace-${AGENT_ID}"
STATE_FILE="$WORKSPACE_DIR/knowledge/company/onboarding-state.yaml"

# 确保状态文件存在
if [ ! -f "$STATE_FILE" ]; then
  echo "❌ 状态文件不存在: $STATE_FILE"
  echo "提示: 请确保已完成 Agent 初始化"
  exit 1
fi

# 获取当前状态
get_current_state() {
  yq -r '.current_state' "$STATE_FILE"
}

# 获取允许的转换
get_allowed_transitions() {
  local current_state="$1"
  yq -r ".states.${current_state}.transitions | keys | .[]" "$STATE_FILE" 2>/dev/null || true
}

# 验证状态转换是否合法
validate_transition() {
  local transition="$1"
  local current_state
  current_state=$(get_current_state)

  local target_state
  target_state=$(yq -r ".states.${current_state}.transitions.${transition}" "$STATE_FILE" 2>/dev/null)

  if [ -z "$target_state" ] || [ "$target_state" = "null" ]; then
    echo "❌ 非法状态转换: $transition (当前状态: $current_state)"
    echo "允许的转换:"
    get_allowed_transitions "$current_state" | while read -r t; do
      echo "  - $t"
    done
    return 1
  fi

  echo "$target_state"
}

# 执行状态转换
do_transition() {
  local transition="$1"
  local current_state
  current_state=$(get_current_state)

  local target_state
  target_state=$(validate_transition "$transition") || return 1

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # 更新状态
  yq -i ".current_state = \"$target_state\"" "$STATE_FILE"
  yq -i ".metadata.last_updated = \"$timestamp\"" "$STATE_FILE"

  # 添加历史记录
  local history_entry
  history_entry=$(cat <<EOF
{"from": "$current_state", "to": "$target_state", "at": "$timestamp", "trigger": "$transition"}
EOF
)
  yq -i ".history += [$history_entry]" "$STATE_FILE"

  echo "✅ 状态转换成功: $current_state → $target_state"
  echo "   触发: $transition"
  echo "   时间: $timestamp"
}

# 显示状态信息
show_status() {
  local current_state
  current_state=$(get_current_state)

  local description
  description=$(yq -r ".states.${current_state}.description // \"无描述\"" "$STATE_FILE")

  echo "📋 入职状态报告"
  echo "   Agent ID: $AGENT_ID"
  echo "   当前状态: $current_state"
  echo "   状态描述: $description"
  echo ""
  echo "📍 允许的转换:"
  get_allowed_transitions "$current_state" | while read -r t; do
    local target
    target=$(yq -r ".states.${current_state}.transitions.${t}" "$STATE_FILE")
    echo "   - $t → $target"
  done
}

# 显示历史
show_history() {
  echo "📜 状态历史"
  yq -r '.history[] | "  [\(.at)] \(.from) → \(.to) (\(.trigger))"' "$STATE_FILE" 2>/dev/null || echo "  (无历史记录)"
}

# 验证状态文件
validate_state_file() {
  echo "🔍 验证状态文件..."

  # 检查必需字段
  local required_fields="version agent_id state_machine states current_state metadata"
  for field in $required_fields; do
    if ! yq -e ".$field" "$STATE_FILE" >/dev/null 2>&1; then
      echo "❌ 缺少必需字段: $field"
      return 1
    fi
  done

  # 检查当前状态是否在 states 中定义
  local current_state
  current_state=$(get_current_state)
  if ! yq -e ".states.${current_state}" "$STATE_FILE" >/dev/null 2>&1; then
    echo "❌ 当前状态未定义: $current_state"
    return 1
  fi

  echo "✅ 状态文件验证通过"
}

# 执行操作
case "$ACTION" in
  status)
    show_status
    ;;
  transition)
    if [ -z "$TRANSITION" ]; then
      echo "❌ transition action 需要 --transition 参数"
      exit 1
    fi
    do_transition "$TRANSITION"
    ;;
  validate)
    validate_state_file
    ;;
  history)
    show_history
    ;;
  *)
    echo "❌ 未知 action: $ACTION"
    usage
    exit 1
    ;;
esac
