#!/usr/bin/env bash
set -e

# ==============================================================================
# OpenClaw HR Agent 统一卸载向导
# 安全移除 HR、IT 专员及相关底层脚本
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v openclaw &> /dev/null; then
    echo -e "${RED}错误: 未检测到 openclaw 核心库。${NC}"
    exit 1
fi

cat << "EOF"
  ____                     ____ _                 
 / __ \                   / ___| | __ ___      __
| |  | |_ __   ___ _ __  | |   | |/ _` \ \ /\ / /
| |__| | '_ \ / _ \ '_ \ | |___| | (_| |\ V  V / 
 \____/| .__/ \___/_| |_| \____|_|\__,_| \_/\_/  
       | |        HR Department
       |_|        
EOF
echo -e "${CYAN}欢迎使用 OpenClaw 企业自动化后勤基座卸载向导${NC}\n"

# ==============================================================================
# 模块：卸载全局技能包 (Global Skills)
# ==============================================================================
remove_global_skills() {
    echo -e "${BLUE}[1/3] 正在移除底层全局战术包与守护进程...${NC}"
    
    if [ -d "$PROJECT_DIR/global-skills" ]; then
        for skill_path in "$PROJECT_DIR/global-skills"/*; do
            if [ -d "$skill_path" ]; then
                skill_name=$(basename "$skill_path")
                target_path="$HOME/.openclaw/skills/$skill_name"
                if [ -d "$target_path" ]; then
                    rm -rf "$target_path"
                    echo -e "  ${GREEN}✓${NC} 已移除全局技能: $skill_name"
                fi
            fi
        done
    fi

    # 移除守护脚本
    if [ -f "$HOME/.openclaw/scripts/gateway-watcher.sh" ]; then
        rm -f "$HOME/.openclaw/scripts/gateway-watcher.sh"
        echo -e "  ${GREEN}✓${NC} 已移除守护进程: gateway-watcher.sh"
    fi

    if [ -f "$HOME/.openclaw/scripts/hr-infra-warmup.sh" ]; then
        rm -f "$HOME/.openclaw/scripts/hr-infra-warmup.sh"
        echo -e "  ${GREEN}✓${NC} 已移除基础设施预热脚本: hr-infra-warmup.sh"
    fi
}

# ==============================================================================
# 模块：卸载 HR 部门 (HR Agent)
# ==============================================================================
remove_hr_agent() {
    echo -e "\n${BLUE}[2/3] 开始卸载 HR 行政与招募总监 (hr)...${NC}"
    
    # 获取 Workspace 路径
    HR_WORKSPACE=$(openclaw config get "agents.list[$(openclaw config get agents.list | jq '[.[].id] | index("hr")')].workspace" 2>/dev/null || echo "$HOME/.openclaw/workspace-hr")
    HR_WORKSPACE=$(echo "$HR_WORKSPACE" | tr -d '"')
    HR_WORKSPACE="${HR_WORKSPACE/#\~/$HOME}"
    
    set +e
    openclaw agents delete --force hr > /dev/null 2>&1
    local del_status=$?
    set -e
    
    if [ $del_status -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} 'hr' 实体档案已从 OpenClaw 门禁系统中注销"
    else
        echo -e "  ${YELLOW}ℹ️ 未在系统中侦测到 'hr' 实体注册信息${NC}"
    fi

    if [ -d "$HR_WORKSPACE" ]; then
        rm -rf "$HR_WORKSPACE"
        echo -e "  ${GREEN}✓${NC} HR 工作台档案物理销毁完毕 ($HR_WORKSPACE)"
    fi
}

# ==============================================================================
# 模块：卸载 IT 部门 (IT Agent)
# ==============================================================================
remove_it_agent() {
    echo -e "\n${BLUE}[3/3] 开始卸载 IT 后勤与极客开发 (it-support)...${NC}"
    
    IT_WORKSPACE=$(openclaw config get "agents.list[$(openclaw config get agents.list | jq '[.[].id] | index("it-support")')].workspace" 2>/dev/null || echo "$HOME/.openclaw/workspace-it")
    IT_WORKSPACE=$(echo "$IT_WORKSPACE" | tr -d '"')
    IT_WORKSPACE="${IT_WORKSPACE/#\~/$HOME}"
    
    set +e
    openclaw agents delete --force it-support > /dev/null 2>&1
    local del_status=$?
    set -e
    
    if [ $del_status -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} 'it-support' 实体档案已从 OpenClaw 门禁系统中注销"
    else
        echo -e "  ${YELLOW}ℹ️ 未在系统中侦测到 'it-support' 实体注册信息${NC}"
    fi

    if [ -d "$IT_WORKSPACE" ]; then
        rm -rf "$IT_WORKSPACE"
        echo -e "  ${GREEN}✓${NC} IT 黑客台档案物理销毁完毕 ($IT_WORKSPACE)"
    fi
}


# ==============================================================================
# 启动选项导航
# ==============================================================================

echo -e "⚠️ ${RED}注意：此操作不可逆，将删除基座数据及业务记录。${NC}"
echo -n -e "${RED}最后确认：您即将卸载 HR、IT 及其相关的全套守护环境。此操作不可逆，是否继续？[Y/n]${NC} "
read -r confirm < /dev/tty
if [[ ! -z "$confirm" && ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "\n${CYAN}已取消卸载。${NC}"
    exit 0
fi

echo ""
remove_global_skills
remove_hr_agent
remove_it_agent

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}🧹 OpenClaw 后勤基座卸载流程全部执行完毕。${NC}"
echo -e "${GREEN}====================================================${NC}\n"
