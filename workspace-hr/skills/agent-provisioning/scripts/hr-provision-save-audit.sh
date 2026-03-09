#!/usr/bin/env bash

set -euo pipefail

AGENT_ID=""
SCRIPT_FILE=""
PAYLOAD_FILE=""

usage() {
  echo "用法: $0 --agent-id <agent-id> --script <provision.sh> --payload <payload.json>"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id)
      AGENT_ID="${2:-}"
      shift 2
      ;;
    --script)
      SCRIPT_FILE="${2:-}"
      shift 2
      ;;
    --payload)
      PAYLOAD_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "❌ 未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$AGENT_ID" ] || [ -z "$SCRIPT_FILE" ] || [ -z "$PAYLOAD_FILE" ]; then
  echo "❌ 缺少必要参数" >&2
  usage >&2
  exit 1
fi

if [[ ! "$AGENT_ID" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "❌ agent-id 格式不合法: $AGENT_ID" >&2
  exit 1
fi

if [ ! -f "$SCRIPT_FILE" ]; then
  echo "❌ 脚本文件不存在: $SCRIPT_FILE" >&2
  exit 1
fi

if [ ! -s "$SCRIPT_FILE" ]; then
  echo "❌ 脚本文件为空: $SCRIPT_FILE" >&2
  exit 1
fi

if [ ! -f "$PAYLOAD_FILE" ]; then
  echo "❌ payload 文件不存在: $PAYLOAD_FILE" >&2
  exit 1
fi

if [ ! -s "$PAYLOAD_FILE" ]; then
  echo "❌ payload 文件为空: $PAYLOAD_FILE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HR_WORKSPACE="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AUDIT_ROOT="${HR_WORKSPACE}/audit/provisioning"
DATE_DIR="$(date '+%F')"
TIMESTAMP="$(date '+%H%M%S')"
AUDIT_DIR="${AUDIT_ROOT}/${DATE_DIR}/${TIMESTAMP}-${AGENT_ID}"

counter=0
while [ -e "$AUDIT_DIR" ]; do
  counter=$((counter + 1))
  AUDIT_DIR="${AUDIT_ROOT}/${DATE_DIR}/${TIMESTAMP}-${AGENT_ID}-${counter}"
done

mkdir -p "$AUDIT_DIR"
cp "$SCRIPT_FILE" "${AUDIT_DIR}/provision.sh"
cp "$PAYLOAD_FILE" "${AUDIT_DIR}/payload.json"
chmod 600 "${AUDIT_DIR}/provision.sh" "${AUDIT_DIR}/payload.json"

echo "✅ 审计归档已保存: ${AUDIT_DIR}" >&2
echo "$AUDIT_DIR"
