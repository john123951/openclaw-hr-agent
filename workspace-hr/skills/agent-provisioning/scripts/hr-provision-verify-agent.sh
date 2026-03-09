#!/usr/bin/env bash
# Post-provision verification for agent config and binding state.

set -euo pipefail

AGENT_ID=""
ALLOW_TOOLS=""
DENY_TOOLS=""
CHANNEL=""
GROUP_ID=""
REQUIRE_MENTION=""
REPLY_TO=""
EXEC_HOST=""

usage() {
  cat <<'EOF'
用法:
  hr-provision-verify-agent.sh \
    --agent-id <agent-id> \
    --allow-tools <tool1,tool2,...> \
    [--deny-tools <tool1,tool2,...>] \
    [--exec-host gateway|sandbox] \
    [--channel feishu|telegram|discord] \
    [--group-id <peer-id>] \
    [--require-mention true|false] \
    [--reply-to all|first|off]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id)
      AGENT_ID="${2:-}"
      shift 2
      ;;
    --allow-tools)
      ALLOW_TOOLS="${2:-}"
      shift 2
      ;;
    --deny-tools)
      DENY_TOOLS="${2:-}"
      shift 2
      ;;
    --channel)
      CHANNEL="${2:-}"
      shift 2
      ;;
    --group-id)
      GROUP_ID="${2:-}"
      shift 2
      ;;
    --require-mention)
      REQUIRE_MENTION="${2:-}"
      shift 2
      ;;
    --reply-to)
      REPLY_TO="${2:-}"
      shift 2
      ;;
    --exec-host)
      EXEC_HOST="${2:-}"
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

if [ -z "$AGENT_ID" ] || [ -z "$ALLOW_TOOLS" ]; then
  echo "❌ 缺少必填参数 --agent-id 或 --allow-tools"
  usage
  exit 1
fi

for bin in openclaw jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "❌ 错误: 未找到依赖命令 $bin"
    exit 1
  fi
done

csv_to_json_array() {
  local csv="$1"
  printf '%s' "$csv" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))'
}

EXPECTED_ALLOW="$(csv_to_json_array "$ALLOW_TOOLS")"
EXPECTED_DENY="$(csv_to_json_array "$DENY_TOOLS")"
AGENT_JSON="$(openclaw config get agents.list --json | jq -c --arg id "$AGENT_ID" '.[] | select(.id == $id)')"

if [ -z "$AGENT_JSON" ]; then
  echo "❌ 未找到 Agent: $AGENT_ID"
  exit 1
fi

ACTUAL_ALLOW="$(printf '%s' "$AGENT_JSON" | jq '.tools.allow // []')"
ACTUAL_DENY="$(printf '%s' "$AGENT_JSON" | jq '.tools.deny // []')"
ACTUAL_EXEC_HOST="$(openclaw config get "agents.list[$(openclaw config get agents.list | jq --arg id "$AGENT_ID" '[.[].id] | index($id)')].tools.exec.host" 2>/dev/null | tail -n 1 | tr -d '"' || true)"

declare -a ERRORS=()
add_error() {
  ERRORS+=("$1")
}

while IFS= read -r missing; do
  add_error "allow 缺少预期工具: ${missing}"
done < <(
  jq -nr --argjson actual "$ACTUAL_ALLOW" --argjson expected "$EXPECTED_ALLOW" '
    $expected[] as $tool | select(($actual | index($tool)) | not) | $tool
  '
)

while IFS= read -r missing; do
  add_error "deny 缺少预期工具: ${missing}"
done < <(
  jq -nr --argjson actual "$ACTUAL_DENY" --argjson expected "$EXPECTED_DENY" '
    $expected[] as $tool | select(($tool | length) > 0 and (($actual | index($tool)) | not)) | $tool
  '
)

BASELINE='["write","edit","web_fetch","sessions_list","sessions_send","sessions_history","memory_search","memory_get","message"]'
while IFS= read -r missing; do
  add_error "实际配置缺少生命线权限: ${missing}"
done < <(
  jq -nr --argjson actual "$ACTUAL_ALLOW" --argjson baseline "$BASELINE" '
    $baseline[] as $tool | select(($actual | index($tool)) | not) | $tool
  '
)

while IFS= read -r overlap; do
  add_error "实际配置中 allow / deny 冲突: ${overlap}"
done < <(
  jq -nr --argjson allow "$ACTUAL_ALLOW" --argjson deny "$ACTUAL_DENY" '
    $allow[] as $tool | select(($deny | index($tool)) != null) | $tool
  '
)

if [ -n "$EXEC_HOST" ] && [ "$ACTUAL_EXEC_HOST" != "$EXEC_HOST" ]; then
  add_error "exec host 不匹配: 期望 ${EXEC_HOST}，实际 ${ACTUAL_EXEC_HOST:-<unset>}"
fi

if [ -n "$CHANNEL" ] && [ -n "$GROUP_ID" ]; then
  if ! openclaw config get bindings --json | jq -e --arg agent "$AGENT_ID" --arg channel "$CHANNEL" --arg gid "$GROUP_ID" '.[] | select(.agentId == $agent and .match.channel == $channel and .match.peer.id == $gid)' >/dev/null; then
    add_error "未找到期望的 ${CHANNEL} 群组绑定: ${GROUP_ID}"
  fi

  if [ -n "$REQUIRE_MENTION" ]; then
    ACTUAL_REQUIRE_MENTION="$(openclaw config get "channels.${CHANNEL}.groups.${GROUP_ID}.requireMention" 2>/dev/null | tail -n 1 | tr -d '"' || true)"
    if [ "$ACTUAL_REQUIRE_MENTION" != "$REQUIRE_MENTION" ]; then
      add_error "requireMention 不匹配: 期望 ${REQUIRE_MENTION}，实际 ${ACTUAL_REQUIRE_MENTION:-<unset>}"
    fi
  fi

  if [ -n "$REPLY_TO" ]; then
    ACTUAL_REPLY_TO="$(openclaw config get "channels.${CHANNEL}.groups.${GROUP_ID}.replyToMode" 2>/dev/null | tail -n 1 | tr -d '"' || true)"
    if [ "$ACTUAL_REPLY_TO" != "$REPLY_TO" ]; then
      add_error "replyToMode 不匹配: 期望 ${REPLY_TO}，实际 ${ACTUAL_REPLY_TO:-<unset>}"
    fi
  fi
fi

if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo "❌ Agent 配置校验失败:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "✅ Agent 配置校验通过: ${AGENT_ID}"
