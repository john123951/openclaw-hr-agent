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
NC='\033[0m' # No Color

# HR Agent 项目目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_SRC="$PROJECT_DIR/workspace"

echo -e "${BLUE}🧑‍💼 HR Agent 安装脚本${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 前置检查 ────────────────────────────────────

echo -e "\n${YELLOW}[1/6] 检查前置条件...${NC}"

if ! command -v openclaw &> /dev/null; then
    echo -e "${RED}❌ 未找到 openclaw CLI。请先安装 OpenClaw。${NC}"
    echo "   参考: https://docs.openclaw.com/start/getting-started"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} openclaw CLI 已安装"

# 检查 Gateway 状态
if openclaw gateway status &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Gateway 正在运行"
else
    echo -e "  ${YELLOW}⚠${NC} Gateway 未运行（安装后需要启动）"
fi

# ── 创建 Agent ──────────────────────────────────

echo -e "\n${YELLOW}[2/6] 创建 HR Agent...${NC}"

if openclaw config get agents.list --strict-json 2>/dev/null | grep -q '"hr"'; then
    echo -e "  ${YELLOW}⚠${NC} Agent 'hr' 已存在，跳过创建"
else
    openclaw agents add hr
    echo -e "  ${GREEN}✓${NC} Agent 'hr' 已创建"
fi

# ── 设置身份 ────────────────────────────────────

echo -e "\n${YELLOW}[3/6] 设置 HR Agent 身份...${NC}"
openclaw agents set-identity --agent hr \
    --name "HR Manager" --emoji "🧑‍💼"
echo -e "  ${GREEN}✓${NC} 身份已设置: 🧑‍💼 HR Manager"

# ── 查找 Agent 索引并配置 ────────────────────────

echo -e "\n${YELLOW}[4/6] 配置模型和工具权限...${NC}"

# 查找 hr agent 的索引
AGENT_INDEX=$(openclaw config get agents.list --strict-json | \
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
    echo -e "${RED}❌ 在配置中未找到 hr agent${NC}"
    exit 1
fi

openclaw config set "agents.list[$AGENT_INDEX].model" "anthropic/claude-sonnet-4-5"
echo -e "  ${GREEN}✓${NC} 模型: anthropic/claude-sonnet-4-5"

# HR 需要完整的工具权限来管理其他 agent
openclaw config set "agents.list[$AGENT_INDEX].tools.allow" \
    '["exec","read","write","edit","sessions_list","sessions_send","sessions_spawn","browser"]' \
    --strict-json
echo -e "  ${GREEN}✓${NC} 工具权限已配置"

# ── 复制工作空间文件 ──────────────────────────────

echo -e "\n${YELLOW}[5/6] 部署工作空间文件...${NC}"

# 获取 HR agent 的工作空间路径
HR_WORKSPACE=$(openclaw config get "agents.list[$AGENT_INDEX].workspace" 2>/dev/null || echo "")

if [ -z "$HR_WORKSPACE" ]; then
    HR_WORKSPACE="$HOME/.openclaw/workspace-hr"
fi

# 展开 ~ 为 $HOME
HR_WORKSPACE="${HR_WORKSPACE/#\~/$HOME}"

echo "  工作空间: $HR_WORKSPACE"

# 复制核心文件
for file in AGENTS.md SOUL.md IDENTITY.md USER.md TOOLS.md; do
    if [ -f "$WORKSPACE_SRC/$file" ]; then
        cp "$WORKSPACE_SRC/$file" "$HR_WORKSPACE/$file"
        echo -e "  ${GREEN}✓${NC} $file"
    fi
done

# 复制 skills
if [ -d "$WORKSPACE_SRC/skills" ]; then
    cp -r "$WORKSPACE_SRC/skills/" "$HR_WORKSPACE/skills/"
    echo -e "  ${GREEN}✓${NC} skills/ (5 个技能)"
fi

# 复制 templates 到工作空间（供 skills 引用）
if [ -d "$PROJECT_DIR/templates" ]; then
    mkdir -p "$HR_WORKSPACE/templates"
    cp -r "$PROJECT_DIR/templates/" "$HR_WORKSPACE/templates/"
    echo -e "  ${GREEN}✓${NC} templates/ (岗位模板)"
fi

# ── 验证 ────────────────────────────────────────

echo -e "\n${YELLOW}[6/6] 验证配置...${NC}"
if openclaw config validate &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} 配置验证通过"
else
    echo -e "  ${RED}❌ 配置验证失败，请检查 openclaw config validate 输出${NC}"
    exit 1
fi

# ── 完成 ────────────────────────────────────────

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 HR Agent 安装完成！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "后续步骤:"
echo "  1. 重启 Gateway:  openclaw gateway restart"
echo "  2. 查看 Agent:    openclaw agents list --bindings"
echo "  3. 开始使用:      在你的聊天渠道中与 HR Agent 对话"
echo ""
echo "如需将 HR Agent 绑定到特定渠道:"
echo "  openclaw agents bind --agent hr --bind feishu:main"
echo "  openclaw agents bind --agent hr --bind telegram:default"
echo ""
