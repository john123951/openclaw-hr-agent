#!/bin/bash
# ============================================================
# HR Agent 安装脚本
# 将 HR Agent 添加到 OpenClaw 多 agent 框架中
# ============================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# HR Agent 项目目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_SRC="$PROJECT_DIR/workspace"

echo -e "${BLUE}🧑‍💼 HR Agent 安装脚本${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 前置检查 ────────────────────────────────────

echo -e "\n${YELLOW}[1/7] 检查前置条件...${NC}"

if ! command -v openclaw &> /dev/null; then
    echo -e "${RED}❌ 未找到 openclaw CLI。请先安装 OpenClaw。${NC}"
    echo "   参考: https://docs.openclaw.com/start/getting-started"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} openclaw CLI 已安装"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ 未找到 python3。请先安装 Python 3。${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} python3 已安装"

# 检查 Gateway 状态
GATEWAY_RUNNING=false
if openclaw gateway status &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Gateway 正在运行"
    GATEWAY_RUNNING=true
else
    echo -e "  ${YELLOW}⚠${NC} Gateway 未运行（安装后需要启动）"
fi

# ── 创建 Agent ──────────────────────────────────

echo -e "\n${YELLOW}[2/7] 创建 HR Agent...${NC}"

# 检查 agent 是否已存在（不用 --strict-json）
HR_EXISTS=false
if openclaw config get agents.list 2>/dev/null | python3 -c "
import json, sys
lst = json.load(sys.stdin)
sys.exit(0 if any(a.get('id') == 'hr' for a in lst) else 1)
" 2>/dev/null; then
    HR_EXISTS=true
fi

if [ "$HR_EXISTS" = true ]; then
    echo -e "  ${YELLOW}⚠${NC} Agent 'hr' 已存在，跳过创建（将更新配置）"
else
    echo -e "  创建中（如果出现交互式向导，请按提示操作）..."
    openclaw agents add hr
    echo -e "  ${GREEN}✓${NC} Agent 'hr' 已创建"
fi

# ── 设置身份 ────────────────────────────────────

echo -e "\n${YELLOW}[3/7] 设置 HR Agent 身份...${NC}"
openclaw agents set-identity --agent hr \
    --name "HR Manager" --emoji "🧑‍💼" 2>/dev/null
echo -e "  ${GREEN}✓${NC} 身份已设置: 🧑‍💼 HR Manager"

# ── 查找 Agent 索引并配置 ────────────────────────

echo -e "\n${YELLOW}[4/7] 配置模型和工具权限...${NC}"

# 查找 hr agent 在 agents.list 中的索引
AGENT_INDEX=$(openclaw config get agents.list 2>/dev/null | \
    python3 -c "
import json, sys
lst = json.load(sys.stdin)
for i, a in enumerate(lst):
    if a.get('id') == 'hr':
        print(i)
        sys.exit(0)
print(-1)
")

if [ "$AGENT_INDEX" = "-1" ]; then
    echo -e "${RED}❌ 在配置中未找到 hr agent。请手动检查 openclaw config get agents.list${NC}"
    exit 1
fi

echo -e "  Agent 索引: $AGENT_INDEX"

openclaw config set "agents.list[$AGENT_INDEX].model" "anthropic/claude-sonnet-4-5" 2>/dev/null
echo -e "  ${GREEN}✓${NC} 模型: anthropic/claude-sonnet-4-5"

# HR 需要完整的工具权限来管理其他 agent
openclaw config set "agents.list[$AGENT_INDEX].tools.allow" \
    '["exec","read","write","edit","sessions_list","sessions_send","sessions_spawn","browser"]' \
    --strict-json 2>/dev/null
echo -e "  ${GREEN}✓${NC} 工具权限已配置"

# ── 复制工作空间文件 ──────────────────────────────

echo -e "\n${YELLOW}[5/7] 部署工作空间文件...${NC}"

# 获取 HR agent 的工作空间路径
HR_WORKSPACE=$(openclaw config get "agents.list[$AGENT_INDEX].workspace" 2>/dev/null || echo "")

# 去除引号
HR_WORKSPACE=$(echo "$HR_WORKSPACE" | tr -d '"')

if [ -z "$HR_WORKSPACE" ]; then
    HR_WORKSPACE="$HOME/.openclaw/workspace-hr"
fi

# 展开 ~ 为 $HOME
HR_WORKSPACE="${HR_WORKSPACE/#\~/$HOME}"

echo "  工作空间: $HR_WORKSPACE"
mkdir -p "$HR_WORKSPACE"

# 复制核心文件
for file in AGENTS.md SOUL.md IDENTITY.md USER.md TOOLS.md; do
    if [ -f "$WORKSPACE_SRC/$file" ]; then
        cp "$WORKSPACE_SRC/$file" "$HR_WORKSPACE/$file"
        echo -e "  ${GREEN}✓${NC} $file"
    fi
done

# 复制 skills 和 scripts
if [ -d "$WORKSPACE_SRC/skills" ]; then
    cp -r "$WORKSPACE_SRC/skills/" "$HR_WORKSPACE/skills/"
    echo -e "  ${GREEN}✓${NC} skills/ (6 个技能)"
fi
cp -r "scripts/" "$HR_WORKSPACE/scripts/"
echo -e "  ${GREEN}✓${NC} scripts/ (包含 Watcher Daemon)"

# 复制 templates 到工作空间（供 skills 引用）
if [ -d "$PROJECT_DIR/templates" ]; then
    mkdir -p "$HR_WORKSPACE/templates"
    cp -r "$PROJECT_DIR/templates/" "$HR_WORKSPACE/templates/"
    echo -e "  ${GREEN}✓${NC} templates/ (岗位模板)"
fi

# ── 验证 ────────────────────────────────────────

echo -e "\n${YELLOW}[6/7] 验证配置...${NC}"
if openclaw config validate &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} 配置验证通过"
else
    echo -e "  ${RED}❌ 配置验证失败${NC}"
    echo "  运行 openclaw config validate 查看详情"
    exit 1
fi

# ── 渠道绑定 ─────────────────────────────────────

echo -e "\n${YELLOW}[7/7] 配置通信渠道...${NC}"
echo ""
echo -e "  ${CYAN}请选择要绑定的渠道（让你可以直接和 HR Agent 聊天）：${NC}"
echo ""
echo "    1) 飞书群组 — 需要提供群组 ID (oc_xxx)"
echo "    2) 飞书私聊 — 绑定到飞书默认账号"
echo "    3) Telegram — 绑定到 Telegram 默认账号"
echo "    4) Discord  — 绑定到 Discord 默认账号"
echo "    5) 跳过     — 稍后手动配置"
echo ""
read -rp "  请输入选项 [1-5] (默认: 5): " CHANNEL_CHOICE
CHANNEL_CHOICE=${CHANNEL_CHOICE:-5}

case "$CHANNEL_CHOICE" in
    1)
        read -rp "  请输入飞书群组 ID (oc_xxx): " FEISHU_GROUP_ID
        if [ -z "$FEISHU_GROUP_ID" ]; then
            echo -e "  ${YELLOW}⚠${NC} 未提供群组 ID，跳过绑定"
        else
            # 添加 peer 级别绑定到 bindings
            BINDINGS_LENGTH=$(openclaw config get bindings 2>/dev/null | \
                python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

            openclaw config set "bindings[$BINDINGS_LENGTH]" \
                "{\"agentId\":\"hr\",\"match\":{\"channel\":\"feishu\",\"peer\":{\"kind\":\"group\",\"id\":\"$FEISHU_GROUP_ID\"}}}" \
                --strict-json 2>/dev/null

            # 设置群组不需要 @mention
            openclaw config set \
                "channels.feishu.groups.$FEISHU_GROUP_ID.requireMention" \
                false --strict-json 2>/dev/null

            echo -e "  ${GREEN}✓${NC} 已绑定到飞书群组: $FEISHU_GROUP_ID"
            echo -e "  ${GREEN}✓${NC} 已设置无需 @mention"

            # 可选：修改群名
            echo ""
            read -rp "  是否将飞书群名修改为「🧑‍💼 HR Manager」？[y/N]: " RENAME_GROUP
            if [[ "$RENAME_GROUP" =~ ^[Yy]$ ]]; then
                # 尝试从配置中读取飞书凭据
                APP_ID=$(openclaw config get channels.feishu.appId 2>/dev/null | tail -n 1 | tr -d '"' || echo "")
                APP_SECRET=$(openclaw config get channels.feishu.appSecret 2>/dev/null | tail -n 1 | tr -d '"' || echo "")

                if [ -n "$APP_ID" ] && [ -n "$APP_SECRET" ]; then
                    TOKEN=$(curl -s -X POST \
                        "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
                        -H "Content-Type: application/json" \
                        -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" \
                        | python3 -c "import json,sys; print(json.load(sys.stdin).get('tenant_access_token',''))" 2>/dev/null || echo "")

                    if [ -n "$TOKEN" ]; then
                        RESULT=$(curl -s -X PUT \
                            "https://open.feishu.cn/open-apis/im/v1/chats/$FEISHU_GROUP_ID" \
                            -H "Authorization: Bearer $TOKEN" \
                            -H "Content-Type: application/json" \
                            -d '{"name":"🧑‍💼 HR Manager"}')
                        echo -e "  ${GREEN}✓${NC} 飞书群名已修改为「🧑‍💼 HR Manager」"
                    else
                        echo -e "  ${YELLOW}⚠${NC} 获取飞书 Token 失败，请手动修改群名"
                    fi
                else
                    echo -e "  ${YELLOW}⚠${NC} 未找到飞书凭据，请手动修改群名"
                fi
            fi
        fi
        ;;
    2)
        openclaw agents bind --agent hr --bind feishu:main 2>/dev/null
        echo -e "  ${GREEN}✓${NC} 已绑定到飞书私聊"
        ;;
    3)
        openclaw agents bind --agent hr --bind telegram:default 2>/dev/null
        echo -e "  ${GREEN}✓${NC} 已绑定到 Telegram"
        ;;
    4)
        openclaw agents bind --agent hr --bind discord:default 2>/dev/null
        echo -e "  ${GREEN}✓${NC} 已绑定到 Discord"
        ;;
    5|*)
        echo -e "  ${YELLOW}跳过${NC} — 稍后可运行:"
        echo "    openclaw agents bind --agent hr --bind feishu:main"
        echo "    openclaw agents bind --agent hr --bind telegram:default"
        ;;
esac

# ── 重启 Gateway ────────────────────────────────

echo ""
if [ "$GATEWAY_RUNNING" = true ]; then
    echo -e "${YELLOW}正在重启 Gateway...${NC}"
    openclaw gateway restart 2>/dev/null
    echo -e "${GREEN}✓${NC} Gateway 已重启"
fi

# ── 完成 ────────────────────────────────────────

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 HR Agent 安装完成！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 显示最终状态
openclaw agents list --bindings 2>/dev/null | grep -A5 "hr" || true

echo ""
echo "现在你可以在绑定的渠道中与 HR Agent 对话，开始招聘新 agent 了！"
echo ""
