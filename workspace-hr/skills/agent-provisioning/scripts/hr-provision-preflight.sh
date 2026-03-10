#!/usr/bin/env bash
# Provision preflight checks for HR recruitment workflow.

set -euo pipefail

MODEL=""
ALLOW_TOOLS=""
DENY_TOOLS=""
CHANNEL=""
GROUP_ID=""
EXEC_HOST=""

usage() {
  cat <<'EOF'
用法:
  hr-provision-preflight.sh \
    --model <model-id> \
    --allow-tools <tool1,tool2,...> \
    [--deny-tools <tool1,tool2,...>] \
    [--channel feishu|telegram|discord] \
    [--group-id <peer-id>]

说明:
  - OpenClaw 默认使用 sandbox 作为 exec host，无需额外配置
  - 该脚本只做招聘前预检，不修改任何配置
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      MODEL="${2:-}"
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

if [ -z "$MODEL" ] || [ -z "$ALLOW_TOOLS" ]; then
  echo "❌ 缺少必填参数 --model 或 --allow-tools"
  usage
  exit 1
fi

for bin in openclaw jq awk; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "❌ 错误: 未找到依赖命令 $bin"
    exit 1
  fi
done

declare -a ERRORS=()
declare -a WARNINGS=()

add_error() {
  ERRORS+=("$1")
}

add_warning() {
  WARNINGS+=("$1")
}

csv_to_json_array() {
  local csv="$1"
  printf '%s' "$csv" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))'
}

json_from_noisy_stdout() {
  awk 'BEGIN{emit=0} /^[[:space:]]*\{/{emit=1} emit {print}'
}

ALLOW_JSON="$(csv_to_json_array "$ALLOW_TOOLS")"
DENY_JSON="$(csv_to_json_array "$DENY_TOOLS")"

if echo "$ALLOW_JSON" | jq -e 'length == 0' >/dev/null; then
  add_error "allow-tools 不能为空"
fi

BASELINE='["write","edit","web_fetch","sessions_list","sessions_send","sessions_history","memory_search","memory_get","message"]'
while IFS= read -r missing; do
  add_error "缺少生命线权限: ${missing}"
done < <(
  jq -nr --argjson allow "$ALLOW_JSON" --argjson baseline "$BASELINE" '
    $baseline[] as $tool | select(($allow | index($tool)) | not) | $tool
  '
)

while IFS= read -r overlap; do
  add_error "工具同时出现在 allow 和 deny 中: ${overlap}"
done < <(
  jq -nr --argjson allow "$ALLOW_JSON" --argjson deny "$DENY_JSON" '
    $allow[] as $tool | select(($deny | index($tool)) != null) | $tool
  '
)

MODELS_JSON="$(openclaw models status --json 2>/dev/null || echo '{}')"
if ! echo "$MODELS_JSON" | jq -e --arg model "$MODEL" '(.allowed // []) | index($model) != null' >/dev/null; then
  add_error "模型未出现在 openclaw models 的 configured / allowed 列表中: ${MODEL}"
fi

HAS_EXEC="$(echo "$ALLOW_JSON" | jq -r 'index("exec") != null')"
SANDBOX_MODE="$(openclaw config get agents.defaults.sandbox.mode 2>/dev/null | tail -n 1 | tr -d '"' || true)"
if [ "$HAS_EXEC" = "true" ] && [ -n "$EXEC_HOST" ]; then
  if [ "$EXEC_HOST" != "gateway" ] && [ "$EXEC_HOST" != "sandbox" ]; then
    add_error "不支持的 exec-host: ${EXEC_HOST}"
  elif [ "$EXEC_HOST" = "sandbox" ] && [ "$SANDBOX_MODE" != "all" ] && [ "$SANDBOX_MODE" != "non-main" ]; then
    add_warning "exec-host=sandbox，但 agents.defaults.sandbox.mode 未启用 all / non-main，可能无法使用 exec"
  fi
fi

if [ -n "$CHANNEL" ]; then
  case "$CHANNEL" in
    feishu|telegram|discord)
      ;;
    *)
      add_error "不支持的渠道: ${CHANNEL}"
      ;;
  esac

  if [ "$CHANNEL" = "feishu" ]; then
    if [ -z "$GROUP_ID" ]; then
      add_error "飞书群绑定必须显式提供 --group-id（例如 oc_xxx）"
    elif [[ ! "$GROUP_ID" =~ ^oc_[A-Za-z0-9]+$ ]]; then
      add_error "飞书 group id 格式不合法: ${GROUP_ID}"
    fi
  fi

  if [ "$CHANNEL" = "telegram" ] && [ -z "$GROUP_ID" ]; then
    add_error "Telegram 群绑定必须显式提供 --group-id"
  fi

  if [ "$CHANNEL" = "telegram" ] && [ -n "$GROUP_ID" ] && [[ ! "$GROUP_ID" =~ ^-?[0-9]+$ ]] && [[ ! "$GROUP_ID" =~ ^@ ]]; then
    add_error "Telegram group id / target 格式不合法: ${GROUP_ID}"
  fi

  CHANNELS_JSON_RAW="$(openclaw channels list --json 2>/dev/null || true)"
  CHANNELS_JSON="$(printf '%s\n' "$CHANNELS_JSON_RAW" | json_from_noisy_stdout)"
  if [ -z "$CHANNELS_JSON" ]; then
    add_warning "无法读取 channels list JSON；请确认 Gateway 已启动并且渠道已登录"
  elif [ "$CHANNEL" != "discord" ] && ! printf '%s\n' "$CHANNELS_JSON" | jq -e --arg channel "$CHANNEL" '(.chat[$channel] // []) | index("default") != null' >/dev/null; then
    add_error "渠道 ${CHANNEL}:default 尚未配置，绑定前请先完成渠道登录"
  fi
fi

SESSIONS_JSON="$(openclaw sessions --all-agents --active 1440 --json 2>/dev/null || echo '{}')"
if ! echo "$SESSIONS_JSON" | jq -e '.sessions[]? | select(.key == "agent:hr:main")' >/dev/null; then
  add_warning "当前未发现 agent:hr:main 主会话；Watcher 会在重启后尝试激活"
fi
if ! echo "$SESSIONS_JSON" | jq -e '.sessions[]? | select(.key == "agent:it-support:main")' >/dev/null; then
  add_warning "当前未发现 agent:it-support:main 主会话；Watcher 会在重启后尝试激活"
fi

if [ "${#WARNINGS[@]}" -gt 0 ]; then
  echo "⚠️ Provision 预检警告:"
  for warning in "${WARNINGS[@]}"; do
    echo "  - ${warning}"
  done
fi

if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo "❌ Provision 预检失败:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "✅ Provision 预检通过"
echo "  - model: ${MODEL}"
echo "  - allow-tools: ${ALLOW_TOOLS}"
if [ -n "$EXEC_HOST" ]; then
  echo "  - exec-host: ${EXEC_HOST}"
fi
if [ -n "$CHANNEL" ]; then
  echo "  - channel: ${CHANNEL}"
fi
if [ -n "$GROUP_ID" ]; then
  echo "  - group-id: ${GROUP_ID}"
fi
