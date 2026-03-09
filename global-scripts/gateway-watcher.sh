#!/usr/bin/env bash
# OpenClaw HR 守护程序 (HR Gateway Watcher)
# 该脚本由代理执行核心操作后分离运行，用于安全重启 Gateway 并处理报错自愈。
# 用法: nohup $HOME/.openclaw/scripts/gateway-watcher.sh <agent-id> [action] > /tmp/watcher.log 2>&1 &

set -euo pipefail

AGENT_ID=$1
ACTION=${2:-provision}
WORKSPACE_DIR="$HOME/.openclaw/workspace-${AGENT_ID}"
WAKE_MARKER="$WORKSPACE_DIR/.watcher-last-wake"

if [ -z "$AGENT_ID" ]; then
    echo "[$(date)] 错误: 未提供 Agent ID"
    exit 1
fi

mkdir -p "$WORKSPACE_DIR"

OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
OPENCLAW_BACKUP="$HOME/.openclaw/openclaw.json.hr_backup"

echo "[$(date)] [Watcher] Watcher 进程启动，接管重启流程 (PID: $$)"
echo "[$(date)] [Watcher] 目标新员工: $AGENT_ID"

# 1. 创建安全快照
if [ -f "$OPENCLAW_CONFIG" ]; then
    cp "$OPENCLAW_CONFIG" "$OPENCLAW_BACKUP"
    echo "[$(date)] [Watcher] 备份配置文件到: $OPENCLAW_BACKUP"
else
    echo "[$(date)] [Watcher] 错误: 找不到 $OPENCLAW_CONFIG"
    exit 1
fi

# 等待 HR Agent 把消息发送完再重启
sleep 5

MAX_RETRIES=3
RETRY_COUNT=0
GATEWAY_ALIVE=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "[$(date)] [Watcher] 正在尝试启动/重启 Gateway (尝试次数: $((RETRY_COUNT+1)))"
    
    # 尝试启动或重启 Gateway 并捕获输出（优先使用 install + start，如果已存在则 fallback 给 restart）
    echo "[$(date)] [Watcher] 执行 Gateway 唤醒指令..."
    (openclaw gateway install && openclaw gateway start || openclaw gateway restart) > /tmp/gateway_restart_out.log 2>&1 || true
    
    # 等待系统初始化
    sleep 8
    
    # 诊断 Gateway 状态
    openclaw gateway status > /tmp/gateway_status.log 2>&1
    
    if grep -q "RPC probe: ok" /tmp/gateway_status.log; then
        PROBE_EXIT_CODE=0
    else
        PROBE_EXIT_CODE=1
    fi
    
    if [ $PROBE_EXIT_CODE -eq 0 ]; then
        echo "[$(date)] [Watcher] Gateway 重启成功并心跳正常！"
        GATEWAY_ALIVE=true
        break
    else
        echo "[$(date)] [Watcher] 发现 Gateway 启动失败或未响应。"
        cat /tmp/gateway_status.log
        
        echo "[$(date)] [Watcher] 触发自愈流程..."
        
        if [ $RETRY_COUNT -eq 0 ]; then
            # 一阶抢救：使用内置 doctor
            echo "[$(date)] [Watcher] 尝试使用 openclaw doctor 修复..."
            openclaw doctor --repair || true
        else
            # 二阶抢救：提取真实的错误日志，呼叫大模型自动修复文件
            ERROR_LOG=$(tail -n 30 "$HOME/.openclaw/logs/gateway.log" 2>/dev/null || echo "无法读取 gateway 日志")
            PROMPT="文件 $OPENCLAW_CONFIG 启动时网关崩溃。真正的底层报错日志如下：\n$ERROR_LOG\n请直接修改并修复上述 JSON 文件中的格式错误或非法字段。"
            
            set +e
            if command -v claudecode &>/dev/null; then
                echo "[$(date)] [Watcher] 使用 claudecode 直接修复..."
                claudecode -p "$PROMPT"
            elif command -v codex &>/dev/null; then
                echo "[$(date)] [Watcher] 使用 codex 直接修复..."
                codex "$PROMPT"
            elif command -v gemini &>/dev/null; then
                echo "[$(date)] [Watcher] 使用 gemini 直接修复..."
                gemini "$PROMPT"
            else
                echo "[$(date)] [Watcher] 未安装任何受支持的 LLM CLI (claudecode/codex/gemini)，跳过 LLM 修复"
            fi
            set -e
            
            echo "[$(date)] [Watcher] 大模型尝试修复完毕"
        fi
        
        RETRY_COUNT=$((RETRY_COUNT+1))
    fi
done

# 如果三次抢救都没活过来，物理回滚
if [ "$GATEWAY_ALIVE" = false ]; then
    echo "[$(date)] [Watcher] 💥 灾难级故障！自愈失败，执行紧急回滚！"
    cp "$OPENCLAW_BACKUP" "$OPENCLAW_CONFIG"
    openclaw gateway restart
    exit 1
fi

# 4. 基础设施心跳 (System Heartbeat)
# ============================================================================
# 技术债务说明 (TECHNICAL DEBT):
# ============================================================================
# 现状: OpenClaw 网关刚重启时 HR/IT 会话处于静默态，新同事执行 sessions_list 会看不见他们。
#       我们通过发送系统探测信来激活 Session，确保握手链路通畅。
#
# 问题: 这是绕过框架的 workaround，污染会话历史，且消息内容无业务意义。
#
# 升级路径: 当 OpenClaw 提供以下原生能力后应移除此逻辑：
#   1. 会话预热 API: openclaw sessions warmup --agent hr
#   2. Agent 创建后 Hook: openclaw agents add --on-create-hook “script.sh”
#
# 追踪: 见 docs/openclaw-feature-requests.md
#
# 独立模块: 已提取为 hr-infra-warmup.sh，此处在过渡期调用
# ============================================================================
if [ “$ACTION” = “provision” ]; then
    echo “[$(date)] [Watcher] 💓 正在激活基础设施心跳 (HR/IT)...”
    # 调用独立的预热脚本 (技术债务：未来应使用 OpenClaw 原生 API)
    if [ -x “$HOME/.openclaw/scripts/hr-infra-warmup.sh” ]; then
        “$HOME/.openclaw/scripts/hr-infra-warmup.sh” --agents hr,it-support --new-agent “$AGENT_ID” --timeout 30
    else
        # Fallback: 内联实现 (向后兼容)
        echo “[$(date)] [Watcher] ⚠️ hr-infra-warmup.sh 未找到，使用内联实现”
        openclaw agent --agent hr --message “[SYSTEM] Session warmup for new agent: ${AGENT_ID}” > /dev/null 2>&1 &
        openclaw agent --agent it-support --message “[SYSTEM] Session warmup for new agent: ${AGENT_ID}” > /dev/null 2>&1 &

        for _ in $(seq 1 15); do
            SESSION_JSON=$(openclaw sessions --all-agents --active 1440 --json 2>/dev/null || echo '{}')
            if echo “$SESSION_JSON” | jq -e '.sessions[]? | select(.key == “agent:hr:main”)' >/dev/null \
              && echo “$SESSION_JSON” | jq -e '.sessions[]? | select(.key == “agent:it-support:main”)' >/dev/null; then
                echo “[$(date)] [Watcher] ✅ HR / IT 主会话已就绪，可供新员工握手。”
                break
            fi
            sleep 2
        done
    fi
fi

# 5. 系统天音唤醒新员工或结束
if [ "$ACTION" = "provision" ]; then
    echo "[$(date)] [Watcher] 系统稳定，准备激活新员工 ${AGENT_ID}..."
    # 再等几秒确保通道全通
    sleep 3 

    # 获取新员工的首选绑定渠道和目标
    BIND_INFO=$(openclaw config get bindings --json 2>/dev/null | jq -r ".[] | select(.agentId==\"$AGENT_ID\" and .match.peer != null) | \"\(.match.channel) \(.match.peer.id)\"" | head -n 1)
    CHANNEL=$(echo "$BIND_INFO" | awk '{print $1}')
    TARGET=$(echo "$BIND_INFO" | awk '{print $2}')
    
    if [ -n "$CHANNEL" ] && [ -n "$TARGET" ]; then
        WAKE_SIGNATURE="${ACTION}|${CHANNEL}|${TARGET}"
        if [ -f "$WAKE_MARKER" ] && [ "$(cat "$WAKE_MARKER" 2>/dev/null || true)" = "$WAKE_SIGNATURE" ]; then
            echo "[$(date)] [Watcher] ℹ️ 检测到相同渠道与目标的唤醒消息已发送过，跳过重复外发。"
            rm "$OPENCLAW_BACKUP" || true
            exit 0
        fi

        echo "[$(date)] [Watcher] 员工已绑定 $CHANNEL:$TARGET，正在发送觉醒通知..."
        # 框架级通知：仅告知系统已就绪，业务逻辑由 BOOTSTRAP.md 驱动
        # 架构设计说明：
        #   - 此消息仅负责"通知已就绪"，不包含具体业务指令
        #   - 具体做什么由 BOOTSTRAP.md 的 prompt 驱动
        #   - 如入职流程变化，只需改模板，不需改脚本
        openclaw agent \
          --agent "$AGENT_ID" \
          --message "[SYSTEM] Gateway restarted. Your BOOTSTRAP.md is ready for execution." \
          --reply-channel "$CHANNEL" \
          --reply-to "$TARGET" \
          --deliver > /dev/null 2>&1

        printf '%s' "$WAKE_SIGNATURE" > "$WAKE_MARKER"
    else
        echo "[$(date)] [Watcher] ⚠️ 员工未绑定特定群组，跳过觉醒问候。"
    fi
else
    echo "[$(date)] [Watcher] 系统稳定，Action=$ACTION，无需唤醒新对象。"
fi

echo "[$(date)] [Watcher] 任务完成，幽灵退场。"
rm "$OPENCLAW_BACKUP" || true
exit 0
