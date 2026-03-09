#!/usr/bin/env bash
# Validate rendered workspace docs to block partial/broken outputs.

set -euo pipefail

WORKSPACE=""
AGENT_ID=""

usage() {
  echo "用法: $0 --workspace <workspace-dir> [--agent-id <agent-id>]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      WORKSPACE="${2:-}"
      shift 2
      ;;
    --agent-id)
      AGENT_ID="${2:-}"
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

if [ -z "$WORKSPACE" ]; then
  echo "❌ 缺少 --workspace"
  usage
  exit 1
fi

if [ ! -d "$WORKSPACE" ]; then
  echo "❌ 错误: workspace 不存在: $WORKSPACE"
  exit 1
fi

if [ -z "$AGENT_ID" ]; then
  workspace_base="$(basename "$WORKSPACE")"
  if [[ "$workspace_base" =~ ^workspace-([a-z0-9-]+)$ ]]; then
    AGENT_ID="${BASH_REMATCH[1]}"
  else
    echo "❌ 无法从 workspace 路径推断 agent id，请显式提供 --agent-id"
    exit 1
  fi
fi

declare -a ERRORS=()
add_error() {
  ERRORS+=("$1")
}

AGENTS_FILE="${WORKSPACE}/AGENTS.md"
SOUL_FILE="${WORKSPACE}/SOUL.md"
BOOTSTRAP_FILE="${WORKSPACE}/BOOTSTRAP.md"

for file in "$AGENTS_FILE" "$SOUL_FILE" "$BOOTSTRAP_FILE"; do
  if [ ! -f "$file" ]; then
    add_error "文件不存在: $file"
    continue
  fi
  if [ ! -s "$file" ]; then
    add_error "文件为空: $file"
  fi
done

scan_placeholders() {
  local file="$1"
  if [ ! -f "$file" ]; then
    return
  fi
  local unresolved
  unresolved="$(grep -nE '\{\{[A-Z0-9_]+\}\}' "$file" || true)"
  if [ -n "$unresolved" ]; then
    add_error "文件存在未替换占位符: $file"
  fi
}

require_contains() {
  local file="$1"
  local text="$2"
  if [ ! -f "$file" ]; then
    return
  fi
  if ! grep -Fq "$text" "$file"; then
    add_error "文件缺少必需段落 '$text': $file"
  fi
}

scan_placeholders "$AGENTS_FILE"
scan_placeholders "$SOUL_FILE"
scan_placeholders "$BOOTSTRAP_FILE"

require_contains "$AGENTS_FILE" "## 会话启动"
require_contains "$AGENTS_FILE" "## 你的工作"
require_contains "$AGENTS_FILE" "## 安全红线"
require_contains "$SOUL_FILE" "## 核心信念"
require_contains "$BOOTSTRAP_FILE" "## 入职巡视协议"
require_contains "$BOOTSTRAP_FILE" "## 安全红线"

if [ -f "$AGENTS_FILE" ] && [ -f "$SOUL_FILE" ] && [ -f "$BOOTSTRAP_FILE" ]; then
  agent_name_agents="$(head -n 1 "$AGENTS_FILE" | sed 's/^# AGENTS\.md — //')"
  agent_name_soul="$(head -n 1 "$SOUL_FILE" | sed 's/^# SOUL\.md — //')"
  agent_name_bootstrap="$(head -n 1 "$BOOTSTRAP_FILE" | sed 's/^# 🎉 欢迎入职！— //')"

  if [ -z "$agent_name_agents" ] || [ -z "$agent_name_soul" ] || [ -z "$agent_name_bootstrap" ]; then
    add_error "文档标题中的 agent 名称为空"
  elif [ "$agent_name_agents" != "$agent_name_soul" ] || [ "$agent_name_agents" != "$agent_name_bootstrap" ]; then
    add_error "文档标题中的 agent 名称不一致: AGENTS='${agent_name_agents}', SOUL='${agent_name_soul}', BOOTSTRAP='${agent_name_bootstrap}'"
  fi
fi

if [ -f "$BOOTSTRAP_FILE" ]; then
  if ! grep -Fq "workspace-${AGENT_ID}/" "$BOOTSTRAP_FILE"; then
    add_error "BOOTSTRAP.md 未包含正确的工作空间路径: workspace-${AGENT_ID}/"
  fi
fi

if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo "❌ 渲染结果校验失败:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

echo "✅ 渲染结果校验通过: $WORKSPACE"
