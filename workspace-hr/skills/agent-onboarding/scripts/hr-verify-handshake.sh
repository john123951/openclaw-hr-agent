#!/usr/bin/env bash
# Verify that a new agent completed the required HR / IT onboarding handshakes.

set -euo pipefail

AGENT_ID=""
WAIT_SECONDS=45
REQUIRE_BOSS_INTRO="false"

usage() {
  cat <<'EOF'
用法:
  hr-verify-handshake.sh --agent-id <agent-id> [--wait-seconds 45] [--require-boss-intro true|false]

说明:
  - 通过 session 文件验证新员工是否已向 HR / IT 发起握手并收到回复
  - 若 --require-boss-intro=true，会额外做一次启发式的老板报到检查
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

for bin in openclaw jq awk; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "❌ 错误: 未找到依赖命令 $bin"
    exit 1
  fi
done

check_session_ack() {
  local file="$1"
  local source_key="$2"
  local pattern="$3"

  [ -f "$file" ] || return 1

  awk -v src="$source_key" -v pat="$pattern" '
    BEGIN { handshake = 0; ack = 0 }
    $0 ~ src && $0 ~ pat { handshake = 1; next }
    handshake && $0 ~ /"role":"assistant"/ { ack = 1; exit }
    END { exit !(handshake && ack) }
  ' "$file"
}

check_boss_intro() {
  local file="$1"
  [ -f "$file" ] || return 1
  rg -q '老板好|我来报到了|我是你的|我是你的\*\*|我是你的公众号运营' "$file"
}

SOURCE_KEY="agent:${AGENT_ID}:main"
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
  AGENT_FILE="$HOME/.openclaw/agents/${AGENT_ID}/sessions/${AGENT_SESSION_ID}.jsonl"

  if check_session_ack "$HR_FILE" "$SOURCE_KEY" '已完成入职自检'; then
    HR_OK=true
  fi

  if check_session_ack "$IT_FILE" "$SOURCE_KEY" '技术故障|故障|工单|请多关照'; then
    IT_OK=true
  fi

  if [ "$REQUIRE_BOSS_INTRO" != "true" ] || check_boss_intro "$AGENT_FILE"; then
    BOSS_OK=true
  fi

  if [ "$HR_OK" = true ] && [ "$IT_OK" = true ] && [ "$BOSS_OK" = true ]; then
    break
  fi

  sleep 1
done

echo "握手验证结果:"
echo "  - HR:  $HR_OK"
echo "  - IT:  $IT_OK"
echo "  - Boss Intro: $BOSS_OK"

if [ "$HR_OK" != true ] || [ "$IT_OK" != true ] || [ "$BOSS_OK" != true ]; then
  echo "❌ 新员工尚未完成完整握手验证: ${AGENT_ID}"
  exit 1
fi

echo "✅ 新员工已完成握手验证: ${AGENT_ID}"
