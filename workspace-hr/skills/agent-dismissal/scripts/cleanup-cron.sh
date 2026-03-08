#!/usr/bin/env bash
# cleanup-cron.sh
# 此脚本用于清理指定被辞退 Agent 遗留的所有后台定时任务。
# 用法: ./cleanup-cron.sh <AGENT_ID>

set -e

AGENT_ID=$1

if [ -z "$AGENT_ID" ]; then
    echo "错误: 未提供待清理员工的 Agent ID"
    exit 1
fi

echo "正在从系统中检索并清理属于该员工 ($AGENT_ID) 的全部待办定时任务..."

# 遍历符合 agentId 匹配条件的任务 ID 并移除
for job_id in $(openclaw cron list --json | jq -r --arg aid "$AGENT_ID" '.jobs[] | select(.agentId == $aid) | .id'); do
    echo "  - 移除了关联定时任务 / cron: $job_id"
    openclaw cron rm "$job_id" > /dev/null 2>&1 || true
done

echo "✅ 定时任务清理完成。"
