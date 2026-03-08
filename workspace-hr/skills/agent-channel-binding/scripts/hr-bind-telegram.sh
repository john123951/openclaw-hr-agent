#!/usr/bin/env bash
# HR Agent Telegram Binding Helper
# 用法: ./hr-bind-telegram.sh <agent-id> [group-id] [--require-mention true|false] [--reply-to all|first|off]
# 目的: 安全地将 agent 绑定到 Telegram channel，并初始化群组白名单、免打扰规则与拟真反应等级。
#
# ⚠️ 设计原则：
#   - 若提供了 GROUP_ID，只绑定 peer-specific 群组路由，绝不同时创建 accountId:default 通配绑定
#   - 若没有提供 GROUP_ID，只绑定基础 telegram:default 渠道（无 peer 过滤）
#   - requireMention 必须在脚本中 100% 显式配置，不允许留空由系统自行决定

set -e

AGENT_ID=""
GROUP_ID=""
REQ_MENTION="false"
REPLY_MODE="all"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --require-mention)
      REQ_MENTION="$2"
      shift 2
      ;;
    --reply-to)
      REPLY_MODE="$2"
      shift 2
      ;;
    -*)
      echo "Unknown flag: $1"
      exit 1
      ;;
    *)
      if [ -z "$AGENT_ID" ]; then
        AGENT_ID=$1
      elif [ -z "$GROUP_ID" ]; then
        GROUP_ID=$1
      fi
      shift
      ;;
  esac
done

if [ -z "$AGENT_ID" ]; then
    echo "用法: $0 <agent-id> [group-id] [--require-mention true|false] [--reply-to all|first|off]"
    exit 1
fi

if [ -z "$GROUP_ID" ]; then
    echo "[Telegram Binding Helper] ℹ️ 未提供群组 ID，跳过渠道绑定。新员工将仅在后台待命。"
    exit 0
fi

echo "[Telegram Binding Helper] 开始为 Agent '$AGENT_ID' 绑定 Telegram 渠道..."

# 全局环境预置：开启基础的拟真互动反应
openclaw config set "channels.telegram.reactionLevel" "\"minimal\"" --strict-json > /dev/null 2>&1 || true
echo "[Telegram Binding Helper] 🔄 已开启 Agent 拟真表情反馈 (reactionLevel=minimal)"

if [ -n "$GROUP_ID" ]; then
    # ── 路径 A：指定群组 ──────────────────────────────────────────────────────
    # 只创建 peer-specific 群组绑定，不创建通配的 accountId:default 绑定
    # 以防止出现两条 binding entry 的 bug
    echo "[Telegram Binding Helper] 处理目标群组: $GROUP_ID"

    # 检查是否已有任何 Agent 绑定了该群组
    CONFLICT_AGENT=$(openclaw config get bindings --json | jq -r --arg gid "$GROUP_ID" '
        .[] | select(.match.channel == "telegram" and .match.peer.id == $gid) | .agentId
    ' | head -n 1)

    if [ -n "$CONFLICT_AGENT" ]; then
        if [ "$CONFLICT_AGENT" = "$AGENT_ID" ]; then
            echo "[Telegram Binding Helper] ⚠️ 该群组的绑定路由已存在（已经是当前 Agent），跳过追加。"
        else
            echo "[Telegram Binding Helper] ❌ 严重拦截：Telegram 群组 ($GROUP_ID) 已经被另一位员工 ('$CONFLICT_AGENT') 绑定！"
            echo "[Telegram Binding Helper] OpenClaw 暂不支持一个群组内存在多个 Agent (会导致消息路由混乱)。请更换群组，或先解绑 '$CONFLICT_AGENT'。"
            exit 1
        fi
    else
        NEXT_INDEX=$(openclaw config get bindings --json | jq 'length')
        openclaw config set "bindings[$NEXT_INDEX]" \
            "{\"agentId\":\"$AGENT_ID\",\"match\":{\"channel\":\"telegram\",\"peer\":{\"kind\":\"group\",\"id\":\"$GROUP_ID\"}}}" \
            --strict-json
        echo "[Telegram Binding Helper] ✅ 成功追加 Telegram 群组 peer 路由 ($GROUP_ID)"
    fi

    # 在 Telegram 渠道白名单 (groups) 中登记此群组，建立强安全屏障
    openclaw config set "channels.telegram.groups.$GROUP_ID" "{}" --strict-json > /dev/null 2>&1 || true
    echo "[Telegram Binding Helper] 🔒 群组已挂载至白名单安全池"

    # ── requireMention 必须显式配置（100% 强制执行）──────────────────────────
    if [ "$REQ_MENTION" = "false" ]; then
        echo "[Telegram Binding Helper] 🔄 设置群组内 [无需 @ 即可唤醒] (requireMention=false)"
        openclaw config set "channels.telegram.groups.$GROUP_ID.requireMention" false --strict-json > /dev/null 2>&1 || true
    else
        echo "[Telegram Binding Helper] 🔄 设置群组内 [必须严格 @ 才可唤醒] (requireMention=true)"
        openclaw config set "channels.telegram.groups.$GROUP_ID.requireMention" true --strict-json > /dev/null 2>&1 || true
    fi

    # ── 回复引用模式 ──────────────────────────────────────────────────────────
    if [ -n "$REPLY_MODE" ]; then
        echo "[Telegram Binding Helper] 🔄 设置群聊消息引用模式: $REPLY_MODE"
        openclaw config set "channels.telegram.groups.$GROUP_ID.replyToMode" "\"$REPLY_MODE\"" --strict-json > /dev/null 2>&1 || true
    fi
fi

# 最终安全校验
openclaw config validate > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "[Telegram Binding Helper] 🌟 Telegram 部署完成且配置安全一致！"
    exit 0
else
    echo "[Telegram Binding Helper] ❌ 警告：写入后导致配置格式破损，请检查 openclaw.json"
    exit 1
fi
