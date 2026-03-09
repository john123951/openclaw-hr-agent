#!/usr/bin/env bash
# HR Infrastructure Warmup Script
# 预热基础设施会话，确保新员工能在 sessions_list 中看到 HR/IT
#
# ============================================================================
# 技术债务说明 (TECHNICAL DEBT):
# ============================================================================
# 现状: OpenClaw 网关刚重启时 HR/IT 会话处于静默态，新同事执行 sessions_list 会看不见他们。
#       我们通过发送系统探测信来激活 Session，确保握手链路通畅。
#
# 问题: 这是绕过框架的 workaround，污染会话历史，且消息内容无业务意义。
#
# 升级路径: 当 OpenClaw 提供以下原生能力后应移除此脚本：
#   1. 会话预热 API: openclaw sessions warmup --agent hr
#   2. Agent 创建后 Hook: openclaw agents add --on-create-hook "script.sh"
#
# 追踪: 见 docs/openclaw-feature-requests.md
# ============================================================================
#
# 用法:
#   hr-infra-warmup.sh --agents hr,it-support [--new-agent <agent-id>]
#
# Options:
#   --agents <list>     要预热的 agent 列表 (逗号分隔，默认: hr,it-support)
#   --new-agent <id>    新入职的 agent ID (用于日志)
#   --timeout <seconds> 等待超时时间 (默认: 30)
#   --help              显示帮助信息

set -euo pipefail

AGENTS="hr,it-support"
NEW_AGENT=""
TIMEOUT=30

usage() {
  cat <<'EOF'
用法:
  hr-infra-warmup.sh [options]

Options:
  --agents <list>     要预热的 agent 列表 (逗号分隔，默认: hr,it-support)
  --new-agent <id>    新入职的 agent ID (用于日志)
  --timeout <seconds> 等待超时时间 (默认: 30)
  --help              显示帮助信息

示例:
  hr-infra-warmup.sh
  hr-infra-warmup.sh --agents hr,it-support --new-agent dev-001
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agents)
      AGENTS="${2:-}"
      shift 2
      ;;
    --new-agent)
      NEW_AGENT="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT="${2:-30}"
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

echo "[$(date)] [InfraWarmup] 基础设施会话预热开始"
echo "[$(date)] [InfraWarmup] 目标 agents: $AGENTS"
[ -n "$NEW_AGENT" ] && echo "[$(date)] [InfraWarmup] 新员工: $NEW_AGENT"

# 检查依赖
if ! command -v openclaw >/dev/null 2>&1; then
  echo "❌ 错误: 未找到 openclaw 命令"
  exit 1
fi

# 发送预热消息
IFS=',' read -ra AGENT_LIST <<< "$AGENTS"
for agent in "${AGENT_LIST[@]}"; do
  agent=$(echo "$agent" | xargs)  # trim whitespace
  if [ -n "$agent" ]; then
    echo "[$(date)] [InfraWarmup] 激活 $agent 会话..."
    openclaw agent --agent "$agent" \
      --message "[SYSTEM] Session warmup${NEW_AGENT:+ for new agent: $NEW_AGENT}" \
      > /dev/null 2>&1 &
  fi
done

# 等待会话就绪
echo "[$(date)] [InfraWarmup] 等待会话就绪 (超时: ${TIMEOUT}s)..."

WAIT_COUNT=0
ALL_READY=false

while [ $WAIT_COUNT -lt "$TIMEOUT" ]; do
  SESSION_JSON=$(openclaw sessions --all-agents --active 1440 --json 2>/dev/null || echo '{}')

  ALL_READY=true
  for agent in "${AGENT_LIST[@]}"; do
    agent=$(echo "$agent" | xargs)
    if [ -n "$agent" ]; then
      if ! echo "$SESSION_JSON" | jq -e ".sessions[]? | select(.key == \"agent:${agent}:main\")" >/dev/null 2>&1; then
        ALL_READY=false
        break
      fi
    fi
  done

  if [ "$ALL_READY" = true ]; then
    break
  fi

  sleep 2
  WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [ "$ALL_READY" = true ]; then
  echo "[$(date)] [InfraWarmup] ✅ 所有目标会话已就绪"
  for agent in "${AGENT_LIST[@]}"; do
    agent=$(echo "$agent" | xargs)
    [ -n "$agent" ] && echo "[$(date)] [InfraWarmup]   - agent:${agent}:main"
  done
else
  echo "[$(date)] [InfraWarmup] ⚠️ 部分会话未能及时就绪"
  for agent in "${AGENT_LIST[@]}"; do
    agent=$(echo "$agent" | xargs)
    if [ -n "$agent" ]; then
      if echo "$SESSION_JSON" | jq -e ".sessions[]? | select(.key == \"agent:${agent}:main\")" >/dev/null 2>&1; then
        echo "[$(date)] [InfraWarmup]   ✅ agent:${agent}:main"
      else
        echo "[$(date)] [InfraWarmup]   ❌ agent:${agent}:main (未就绪)"
      fi
    fi
  done
fi

echo "[$(date)] [InfraWarmup] 预热完成"
