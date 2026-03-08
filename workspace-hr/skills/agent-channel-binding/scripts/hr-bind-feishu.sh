#!/usr/bin/env bash
# HR Agent Binding Helper
# 用法: ./hr-bind-feishu.sh <agent-id> [group-id] [--require-mention true|false] [--reply-to all|first|off]
# 目的: 安全地将 agent 绑定到 feishu channel，并且允许通过标志位配置群聊免打扰、提及要求与API优化。

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

echo "[Binding Helper] 开始为 Agent '$AGENT_ID' 绑定飞书渠道..."

# 1. 总是确保基础的 channel 绑定存在
openclaw agents bind --agent "$AGENT_ID" --bind "feishu:default" > /dev/null 2>&1 || true
echo "[Binding Helper] ✅ 成功绑定飞书基础账号渠道"

# 2. 如果提供了 Group ID，进行高级群组 peer 配置
if [ -n "$GROUP_ID" ]; then
    echo "[Binding Helper] 正在尝试绑定至特定飞书群: $GROUP_ID"
    
    # Check existing bindings for this group ID
    CONFLICT_AGENT=$(openclaw config get bindings --json | jq -r --arg gid "$GROUP_ID" '
        .[] | select(.match.channel == "feishu" and .match.peer.id == $gid) | .agentId
    ' | head -n 1)
    
    if [ -n "$CONFLICT_AGENT" ]; then
        if [ "$CONFLICT_AGENT" = "$AGENT_ID" ]; then
            echo "[Binding Helper] ⚠️ 该群组绑定已存在（已经是当前 Agent），跳过追加。"
        else
            echo "[Binding Helper] ❌ 严重拦截：飞书群组 ($GROUP_ID) 已经被另一位员工 ('$CONFLICT_AGENT') 绑定！"
            echo "[Binding Helper] OpenClaw 暂不支持一个群组内存在多个 Agent (会导致消息路由混乱)。请更换群组，或先解绑 '$CONFLICT_AGENT'。"
            exit 1
        fi
    else
        NEXT_INDEX=$(openclaw config get bindings --json | jq 'length')
        openclaw config set "bindings[$NEXT_INDEX]" \
            "{\"agentId\":\"$AGENT_ID\",\"match\":{\"channel\":\"feishu\",\"peer\":{\"kind\":\"group\",\"id\":\"$GROUP_ID\"}}}" \
            --strict-json
        echo "[Binding Helper] ✅ 成功追加飞书群组 peer 路由 ($GROUP_ID)"
    fi

    # 配置是否需要 @mention
    if [ "$REQ_MENTION" = "false" ]; then
        echo "[Binding Helper] 🔄 设置群组内 [无需 @ 即可唤醒]"
        openclaw config set "channels.feishu.groups.$GROUP_ID.requireMention" false --strict-json > /dev/null 2>&1 || true
    else
        echo "[Binding Helper] 🔄 设置群组内 [必须严格 @ 才可唤醒]"
        openclaw config set "channels.feishu.groups.$GROUP_ID.requireMention" true --strict-json > /dev/null 2>&1 || true
    fi

    # 配置文件级的回复模式 (及关闭冲突的卡片流)
    if [ -n "$REPLY_MODE" ]; then
        if [ "$REPLY_MODE" != "off" ]; then
            # 开启引用箭头必须关闭流式输出，否则冲突
            openclaw config set "channels.feishu.streaming" false --strict-json > /dev/null 2>&1 || true
            openclaw config set "channels.feishu.blockStreaming" false --strict-json > /dev/null 2>&1 || true
            echo "[Binding Helper] ⚠️ 检测到开启引用回复 ($REPLY_MODE)。已自动关闭卡片流式输出 (streaming) 防止冲突。"
        fi
        echo "[Binding Helper] 🔄 设置群聊消息引用模式: $REPLY_MODE"
        openclaw config set "channels.feishu.groups.$GROUP_ID.replyToMode" "\"$REPLY_MODE\"" --strict-json > /dev/null 2>&1 || true
    fi
fi

# 验证最终配置
openclaw config validate > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "[Binding Helper] 配置写入完成并已通过安全校验！"
    exit 0
else
    echo "[Binding Helper] ❌ 警告：写入后导致配置格式破损，请检查 openclaw.json"
    exit 1
fi
