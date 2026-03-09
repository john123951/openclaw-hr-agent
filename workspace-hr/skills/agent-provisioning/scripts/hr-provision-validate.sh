#!/usr/bin/env bash
# Validate structured provisioning payload for workspace file rendering.

set -euo pipefail

PAYLOAD=""
SCHEMA=""

usage() {
  echo "用法: $0 --payload <provision-payload.json> [--schema <provision.schema.json>]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --payload)
      PAYLOAD="${2:-}"
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

if [ -z "$PAYLOAD" ]; then
  echo "❌ 缺少 --payload"
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "$SCHEMA" ]; then
  SCHEMA="${SCRIPT_DIR}/../schema/provision.schema.json"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ 错误: 未找到 jq，请先安装 jq"
  exit 1
fi

if [ ! -f "$PAYLOAD" ]; then
  echo "❌ 错误: payload 文件不存在: $PAYLOAD"
  exit 1
fi

if [ ! -f "$SCHEMA" ]; then
  echo "❌ 错误: schema 文件不存在: $SCHEMA"
  exit 1
fi

if ! jq empty "$PAYLOAD" >/dev/null 2>&1; then
  echo "❌ 错误: payload 不是合法 JSON: $PAYLOAD"
  exit 1
fi

if ! jq empty "$SCHEMA" >/dev/null 2>&1; then
  echo "❌ 错误: schema 不是合法 JSON: $SCHEMA"
  exit 1
fi

if [ "$(jq -r 'type' "$PAYLOAD")" != "object" ]; then
  echo "❌ 错误: payload 顶层必须是 object"
  exit 1
fi

declare -a ERRORS=()

add_error() {
  ERRORS+=("$1")
}

# 1) Top-level unknown key check (additionalProperties=false).
while IFS= read -r unknown_key; do
  add_error "不允许的顶层字段: ${unknown_key}"
done < <(
  jq -r --slurpfile schema "$SCHEMA" '
    ($schema[0].properties | keys) as $allowed
    | keys[]
    | select(($allowed | index(.)) | not)
  ' "$PAYLOAD"
)

# 2) Required keys check.
while IFS= read -r required_key; do
  if ! jq -e --arg key "$required_key" 'has($key) and .[$key] != null' "$PAYLOAD" >/dev/null; then
    add_error "缺少必填字段: ${required_key}"
  fi
done < <(jq -r '.required[]?' "$SCHEMA")

# 3) Property type/length/pattern checks.
while IFS=$'\t' read -r key expected_type min_length max_length pattern; do
  if jq -e --arg key "$key" 'has($key)' "$PAYLOAD" >/dev/null; then
    if jq -e --arg key "$key" '.[$key] == null' "$PAYLOAD" >/dev/null; then
      add_error "字段 ${key} 不能为 null"
      continue
    fi

    actual_type="$(jq -r --arg key "$key" '.[$key] | type' "$PAYLOAD")"

    if [ -n "$expected_type" ] && [ "$actual_type" != "$expected_type" ]; then
      add_error "字段 ${key} 类型错误: 期望 ${expected_type}，实际 ${actual_type}"
      continue
    fi

    if [ "$expected_type" = "string" ]; then
      value_length="$(jq -r --arg key "$key" '.[$key] | length' "$PAYLOAD")"

      if [ "$min_length" -ge 0 ] && [ "$value_length" -lt "$min_length" ]; then
        add_error "字段 ${key} 长度过短: ${value_length} < ${min_length}"
      fi

      if [ "$max_length" -ge 0 ] && [ "$value_length" -gt "$max_length" ]; then
        add_error "字段 ${key} 长度过长: ${value_length} > ${max_length}"
      fi

      if [ -n "$pattern" ]; then
        if ! jq -e --arg key "$key" --arg pattern "$pattern" '.[$key] | test($pattern)' "$PAYLOAD" >/dev/null; then
          add_error "字段 ${key} 格式不合法: 未匹配 ${pattern}"
        fi
      fi
    fi
  fi
done < <(
  jq -r '
    .properties
    | to_entries[]
    | [
        .key,
        (.value.type // ""),
        ((.value.minLength // -1) | tostring),
        ((.value.maxLength // -1) | tostring),
        (.value.pattern // "")
      ]
    | @tsv
  ' "$SCHEMA"
)

# 4) Nested custom_sections checks (additionalProperties=false).
if jq -e '.custom_sections? != null' "$PAYLOAD" >/dev/null; then
  while IFS= read -r unknown_nested; do
    add_error "custom_sections 不允许的字段: ${unknown_nested}"
  done < <(
    jq -r --slurpfile schema "$SCHEMA" '
      ($schema[0].properties.custom_sections.properties | keys) as $allowed
      | .custom_sections
      | keys[]
      | select(($allowed | index(.)) | not)
    ' "$PAYLOAD"
  )

  while IFS=$'\t' read -r nested_key nested_type nested_max; do
    if jq -e --arg key "$nested_key" '.custom_sections | has($key)' "$PAYLOAD" >/dev/null; then
      if jq -e --arg key "$nested_key" '.custom_sections[$key] == null' "$PAYLOAD" >/dev/null; then
        add_error "custom_sections.${nested_key} 不能为 null"
        continue
      fi

      actual_nested_type="$(jq -r --arg key "$nested_key" '.custom_sections[$key] | type' "$PAYLOAD")"
      if [ "$actual_nested_type" != "$nested_type" ]; then
        add_error "custom_sections.${nested_key} 类型错误: 期望 ${nested_type}，实际 ${actual_nested_type}"
        continue
      fi

      nested_len="$(jq -r --arg key "$nested_key" '.custom_sections[$key] | length' "$PAYLOAD")"
      if [ "$nested_max" -ge 0 ] && [ "$nested_len" -gt "$nested_max" ]; then
        add_error "custom_sections.${nested_key} 长度过长: ${nested_len} > ${nested_max}"
      fi
    fi
  done < <(
    jq -r '
      .properties.custom_sections.properties
      | to_entries[]
      | [
          .key,
          (.value.type // "string"),
          ((.value.maxLength // -1) | tostring)
        ]
      | @tsv
    ' "$SCHEMA"
  )
fi

# 5) Business checks.
if jq -e '.agent_name? != null' "$PAYLOAD" >/dev/null; then
  if ! jq -e '.agent_name | test("\\S")' "$PAYLOAD" >/dev/null; then
    add_error "agent_name 不能是空白字符串"
  fi
fi

if jq -e '.safety_rules? != null' "$PAYLOAD" >/dev/null; then
  if ! jq -e '.safety_rules | test("(?m)^\\s*-\\s+\\S+")' "$PAYLOAD" >/dev/null; then
    add_error "safety_rules 至少要包含一条 Markdown bullet（以 '- ' 开头）"
  fi
fi

if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo "❌ Provision payload 校验失败:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "✅ Provision payload 校验通过: $PAYLOAD"
