#!/usr/bin/env bash
# Verify that a new agent completed the required HR / IT onboarding handshakes.
#
# ============================================================================
# 架构说明 (ARCHITECTURE NOTE):
# ============================================================================
# 本脚本验证新员工是否完成了结构化握手协议：
#   - [ONBOARD][HR][SELF_CHECK_COMPLETE] 标记 + HR 回复
#   - [ONBOARD][IT][INTRO] 标记 + IT 回复
#   - onboarding-status.md 中的 boss_intro_status=delivered
#
# 这是从"自然语言猜测"到"结构化协议"的正确演进方向。
# ============================================================================
# 技术债务说明 (TECHNICAL DEBT):
# ============================================================================
# 现状: 当前实现直接读取 OpenClaw 内部存储格式 (JSONL) 进行握手验证。
#       这绕过了 OpenClaw 原生的 sessions_history API。
#
# 原因: sessions_history API 可能不支持按标记搜索，或性能不够。
#
# 风险: 如果 OpenClaw 改变存储格式，此脚本会失效。
#
# 升级路径: 当 OpenClaw 提供以下原生能力后应切换：
#   openclaw sessions history --session "agent:hr:main" --since "1h" --json | \
#     jq -e '.[] | select(.content | contains("[ONBOARD][HR][SELF_CHECK_COMPLETE]"))'
#
# 追踪: 见 docs/openclaw-feature-requests.md
# ============================================================================

set -euo pipefail

# OpenClaw 版本检测 (为未来 API 切换做准备)
OPENCLAW_VERSION="$(openclaw --version 2>/dev/null | head -n1 || echo "unknown")"
USE_NATIVE_API=false  # 当前强制使用 JSONL 解析，待 OpenClaw 支持后切换

AGENT_ID=""
WAIT_SECONDS=45
REQUIRE_BOSS_INTRO="false"

usage() {
  cat <<'EOF'
用法:
  hr-verify-handshake.sh --agent-id <agent-id> [--wait-seconds 45] [--require-boss-intro true|false]

说明:
  - 通过结构化握手标记验证新员工是否已向 HR / IT 发起入职握手并收到回复
  - 若 --require-boss-intro=true，会额外检查 onboarding-status.md 中是否明确记录 boss_intro_status=delivered
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id)
      AGENT_ID="${2:-}"
      shift 2
      ;;
    --wait-seconds)
      WAIT_SECONDS="${2:-45}"
      shift 2
      ;;
    --require-boss-intro)
      REQUIRE_BOSS_INTRO="${2:-false}"
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

for bin in openclaw jq awk rg; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "❌ 错误: 未找到依赖命令 $bin"
    exit 1
  fi
done

# ============================================================================
# 会话标记验证函数
# ============================================================================

# JSONL 解析实现 (当前方案)
# 直接读取 OpenClaw 内部存储格式，验证消息标记 + 助手回复
# 技术债务：绕过原生 API，与框架内部实现耦合
check_session_marker_ack_jsonl() {
  local file="$1"
  local source_key="$2"
  local marker="$3"

  [ -f "$file" ] || return 1

  awk -v src="$source_key" -v pat="$marker" '
    BEGIN { seen = 0; ack = 0 }
    index($0, src) && index($0, pat) { seen = 1; next }
    seen && $0 ~ /"role":"assistant"/ { ack = 1; exit }
    END { exit !(seen && ack) }
  ' "$file"
}

# 原生 API 实现 (未来方案 - 待 OpenClaw 支持)
# 使用 sessions_history API 获取历史并搜索标记
# 升级路径：当 OpenClaw 支持 --since 和内容过滤后启用
check_session_marker_ack_native() {
  local session_key="$1"
  local marker="$2"

  # TODO: 等待 OpenClaw 支持 sessions history 的内容过滤
  # 预期 API: openclaw sessions history --session "$session_key" --since "1h" --json
  echo "❌ 原生 API 尚未实现，请使用 JSONL 解析" >&2
  return 1
}

# 统一入口：根据 OpenClaw 版本选择实现
check_session_marker_ack() {
  local file_or_key="$1"
  local source_key="$2"
  local marker="$3"

  if [ "$USE_NATIVE_API" = true ]; then
    check_session_marker_ack_native "$file_or_key" "$marker"
  else
    check_session_marker_ack_jsonl "$file_or_key" "$source_key" "$marker"
  fi
}

read_status_value() {
  local file="$1"
  local key="$2"

  [ -f "$file" ] || return 1
  rg -o "^${key}:[[:space:]]*.*$" "$file" | tail -n 1 | sed -E "s/^${key}:[[:space:]]*//"
}

SOURCE_KEY="agent:${AGENT_ID}:main"
WORKSPACE_DIR="$HOME/.openclaw/workspace-${AGENT_ID}"
STATUS_FILE="$WORKSPACE_DIR/knowledge/company/onboarding-status.md"
HR_OK=false
IT_OK=false
BOSS_OK=false

for _ in $(seq 1 "$WAIT_SECONDS"); do
  SESSIONS_JSON="$(openclaw sessions --all-agents --active 1440 --json 2>/dev/null || echo '{}')"
  AGENT_SESSION_ID="$(echo "$SESSIONS_JSON" | jq -r --arg key "$SOURCE_KEY" '.sessions[]? | select(.key == $key) | .sessionId' | head -n 1)"
  HR_SESSION_ID="$(echo "$SESSIONS_JSON" | jq -r '.sessions[]? | select(.key == "agent:hr:main") | .sessionId' | head -n 1)"
  IT_SESSION_ID="$(echo "$SESSIONS_JSON" | jq -r '.sessions[]? | select(.key == "agent:it-support:main") | .sessionId' | head -n 1)"

  HR_FILE="$HOME/.openclaw/agents/hr/sessions/${HR_SESSION_ID}.jsonl"
  IT_FILE="$HOME/.openclaw/agents/it-support/sessions/${IT_SESSION_ID}.jsonl"

  if check_session_marker_ack "$HR_FILE" "$SOURCE_KEY" '[ONBOARD][HR][SELF_CHECK_COMPLETE]'; then
    HR_OK=true
  fi

  if check_session_marker_ack "$IT_FILE" "$SOURCE_KEY" '[ONBOARD][IT][INTRO]'; then
    IT_OK=true
  fi

  if [ "$REQUIRE_BOSS_INTRO" != "true" ]; then
    BOSS_OK=true
  elif [ -f "$STATUS_FILE" ]; then
    BOSS_STATUS="$(read_status_value "$STATUS_FILE" 'boss_intro_status' 2>/dev/null || true)"
    if [ "$BOSS_STATUS" = "delivered" ]; then
      BOSS_OK=true
    fi
  fi

  if [ "$HR_OK" = true ] && [ "$IT_OK" = true ] && [ "$BOSS_OK" = true ]; then
    break
  fi

  sleep 1
done

echo "握手验证结果:"
echo "  - 验证方法: $([ "$USE_NATIVE_API" = true ] && echo "原生 API" || echo "JSONL 解析 (技术债务)")"
echo "  - OpenClaw 版本: $OPENCLAW_VERSION"
echo "  - HR marker + ack:  $HR_OK"
echo "  - IT marker + ack:  $IT_OK"
echo "  - Boss status file: $BOSS_OK"
echo "  - Status file path: $STATUS_FILE"

if [ "$USE_NATIVE_API" = false ]; then
  echo ""
  echo "⚠️  技术债务提醒: 当前使用 JSONL 文件解析进行验证"
  echo "   当 OpenClaw 提供原生 sessions_history 内容过滤 API 后应切换"
  echo "   详见: docs/openclaw-feature-requests.md"
fi

if [ "$HR_OK" != true ] || [ "$IT_OK" != true ] || [ "$BOSS_OK" != true ]; then
  echo "❌ 新员工尚未完成完整握手验证: ${AGENT_ID}"
  echo "提示: HR/IT 验证依赖结构化消息标记；老板报到验证依赖 onboarding-status.md 中的 boss_intro_status=delivered"
  exit 1
fi

echo "✅ 新员工已完成握手验证: ${AGENT_ID}"
