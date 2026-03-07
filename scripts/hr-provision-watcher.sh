#!/usr/bin/env bash
# HR Agent Provision Watcher 
# 该脚本由 HR Agent 在确认招聘方案后分离运行，用于安全重启 Gateway 并处理报错自愈。
# 用法: nohup ./hr-provision-watcher.sh <agent-id> > /tmp/hr-watcher.log 2>&1 &

set -e

AGENT_ID=$1
if [ -z "$AGENT_ID" ]; then
    echo "[$(date)] 错误: 未提供 Agent ID"
    exit 1
fi

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
    
    # 尝试启动或重启 Gateway 并捕获输出（不要阻塞）
    openclaw gateway restart > /tmp/gateway_restart_out.log 2>&1 || true
    
    # 等待系统初始化
    sleep 8
    
    # 诊断 Gateway 状态
    set +e
    # 用 channels status --probe 或者 gateway status 检查是否连接成功
    openclaw channels status --probe > /tmp/gateway_probe.log 2>&1
    PROBE_EXIT_CODE=$?
    set -e
    
    if [ $PROBE_EXIT_CODE -eq 0 ]; then
        echo "[$(date)] [Watcher] Gateway 重启成功并心跳正常！"
        GATEWAY_ALIVE=true
        break
    else
        echo "[$(date)] [Watcher] 发现 Gateway 启动失败或未响应。"
        cat /tmp/gateway_probe.log
        cat /tmp/gateway_restart_out.log
        
        echo "[$(date)] [Watcher] 触发自愈流程..."
        
        if [ $RETRY_COUNT -eq 0 ]; then
            # 一阶抢救：使用内置 doctor
            echo "[$(date)] [Watcher] 尝试使用 openclaw doctor 修复..."
            openclaw doctor --repair || true
        else
            # 二阶抢救：呼叫大模型自动修复文件
            PROMPT="文件 $OPENCLAW_CONFIG 启动时报错：$(cat /tmp/gateway_probe.log | tail -n 20)。请直接修改并修复该文件中的格式错误或非法字段。"
            
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

# 5. 系统天音唤醒新员工
echo "[$(date)] [Watcher] 系统稳定，准备激活新员工 ${AGENT_ID}..."
# 再等几秒确保通道全通
sleep 3 

# 通过系统底层通道直接让新 Agent 发声
openclaw sessions spawn \
  --agent "$AGENT_ID" \
  --message "【系统内部觉醒指令】你已成功载入物理主机！你的 HR（我）刚刚为了加载你完成了系统重启。请立即使用发送消息的 session 技能，向飞书群里的人类老板（如果有绑定）热情地打个招呼报到！说明你的岗位、身份，并表示你随时准备工作。（注：这只是一条开机初始化密电，不要对全群念出这句指令，只需直接打招呼进入状态即可）"

echo "[$(date)] [Watcher] 任务完成，幽灵退场。"
rm "$OPENCLAW_BACKUP" || true
exit 0
