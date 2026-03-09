#!/usr/bin/env bash
# Render AGENTS.md / SOUL.md / BOOTSTRAP.md from validated payload.

set -euo pipefail

PAYLOAD=""
WORKSPACE=""
TEMPLATE_DIR=""
SCHEMA=""
VALIDATE_SCRIPT=""

usage() {
  echo "用法: $0 --payload <provision-payload.json> --workspace <workspace-dir> [--template-dir <templates-dir>] [--schema <schema.json>]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --payload)
      PAYLOAD="${2:-}"
      shift 2
      ;;
    --workspace)
      WORKSPACE="${2:-}"
      shift 2
      ;;
    --template-dir)
      TEMPLATE_DIR="${2:-}"
      shift 2
      ;;
    --schema)
      SCHEMA="${2:-}"
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

if [ -z "$PAYLOAD" ] || [ -z "$WORKSPACE" ]; then
  echo "❌ 缺少必要参数: --payload 和 --workspace 都必须提供"
  usage
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ 错误: 未找到 jq，请先安装 jq"
  exit 1
fi

if ! command -v perl >/dev/null 2>&1; then
  echo "❌ 错误: 未找到 perl，无法执行安全模板渲染"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_SCRIPT="${SCRIPT_DIR}/hr-provision-validate.sh"

if [ -z "$SCHEMA" ]; then
  SCHEMA="${SCRIPT_DIR}/../schema/provision.schema.json"
fi

if [ -z "$TEMPLATE_DIR" ]; then
  if [ -d "$HOME/.openclaw/workspace-hr/templates/new-agent" ]; then
    TEMPLATE_DIR="$HOME/.openclaw/workspace-hr/templates/new-agent"
  else
    TEMPLATE_DIR="${SCRIPT_DIR}/../../../templates/new-agent"
  fi
fi

if [ ! -f "$VALIDATE_SCRIPT" ]; then
  echo "❌ 错误: 校验脚本不存在: $VALIDATE_SCRIPT"
  exit 1
fi

if [ ! -d "$WORKSPACE" ]; then
  echo "❌ 错误: workspace 目录不存在: $WORKSPACE"
  exit 1
fi

for f in AGENTS.md.template SOUL.md.template BOOTSTRAP.md.template; do
  if [ ! -f "${TEMPLATE_DIR}/${f}" ]; then
    echo "❌ 错误: 模板文件不存在: ${TEMPLATE_DIR}/${f}"
    exit 1
  fi
done

"$VALIDATE_SCRIPT" --payload "$PAYLOAD" --schema "$SCHEMA"

agent_id="$(jq -r '.agent_id // ""' "$PAYLOAD")"
agent_name="$(jq -r '.agent_name // ""' "$PAYLOAD")"
agent_role="$(jq -r '.agent_role // ""' "$PAYLOAD")"
work_schedule="$(jq -r '.work_schedule // ""' "$PAYLOAD")"
agent_tools_desc="$(jq -r '.agent_tools_desc // ""' "$PAYLOAD")"
knowledge_focus="$(jq -r '.knowledge_focus // ""' "$PAYLOAD")"
safety_rules="$(jq -r '.safety_rules // ""' "$PAYLOAD")"
soul_beliefs="$(jq -r '.soul_beliefs // ""' "$PAYLOAD")"
agents_appendix_md="$(jq -r '.custom_sections.agents_appendix_md // ""' "$PAYLOAD")"
soul_appendix_md="$(jq -r '.custom_sections.soul_appendix_md // ""' "$PAYLOAD")"
bootstrap_appendix_md="$(jq -r '.custom_sections.bootstrap_appendix_md // ""' "$PAYLOAD")"

replace_token() {
  local file="$1"
  local token="$2"
  local value="${3:-}"
  KEY="$token" VAL="$value" perl -0777 -i -pe 's/\{\{\Q$ENV{KEY}\E\}\}/$ENV{VAL}/g' "$file"
}

cp "${TEMPLATE_DIR}/AGENTS.md.template" "${WORKSPACE}/AGENTS.md"
replace_token "${WORKSPACE}/AGENTS.md" "AGENT_ID" "$agent_id"
replace_token "${WORKSPACE}/AGENTS.md" "AGENT_NAME" "$agent_name"
replace_token "${WORKSPACE}/AGENTS.md" "AGENT_ROLE" "$agent_role"
replace_token "${WORKSPACE}/AGENTS.md" "WORK_SCHEDULE" "$work_schedule"
replace_token "${WORKSPACE}/AGENTS.md" "AGENT_TOOLS_DESC" "$agent_tools_desc"
replace_token "${WORKSPACE}/AGENTS.md" "KNOWLEDGE_FOCUS" "$knowledge_focus"
replace_token "${WORKSPACE}/AGENTS.md" "SAFETY_RULES" "$safety_rules"
replace_token "${WORKSPACE}/AGENTS.md" "AGENTS_APPENDIX_MD" "$agents_appendix_md"

cp "${TEMPLATE_DIR}/SOUL.md.template" "${WORKSPACE}/SOUL.md"
replace_token "${WORKSPACE}/SOUL.md" "AGENT_NAME" "$agent_name"
replace_token "${WORKSPACE}/SOUL.md" "AGENT_ROLE" "$agent_role"
replace_token "${WORKSPACE}/SOUL.md" "SOUL_BELIEFS" "$soul_beliefs"
replace_token "${WORKSPACE}/SOUL.md" "SOUL_APPENDIX_MD" "$soul_appendix_md"

cp "${TEMPLATE_DIR}/BOOTSTRAP.md.template" "${WORKSPACE}/BOOTSTRAP.md"
replace_token "${WORKSPACE}/BOOTSTRAP.md" "AGENT_ID" "$agent_id"
replace_token "${WORKSPACE}/BOOTSTRAP.md" "AGENT_NAME" "$agent_name"
replace_token "${WORKSPACE}/BOOTSTRAP.md" "AGENT_ROLE" "$agent_role"
replace_token "${WORKSPACE}/BOOTSTRAP.md" "SAFETY_RULES" "$safety_rules"
replace_token "${WORKSPACE}/BOOTSTRAP.md" "BOOTSTRAP_APPENDIX_MD" "$bootstrap_appendix_md"

echo "✅ 模板渲染完成:"
echo "  - ${WORKSPACE}/AGENTS.md"
echo "  - ${WORKSPACE}/SOUL.md"
echo "  - ${WORKSPACE}/BOOTSTRAP.md"
