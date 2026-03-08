#!/usr/bin/env bash
set -e

# ==============================================================================
# OpenClaw Base-Ops (后勤基座守护进程) 统一安装向导
# 让您的主服务器一键武装 HR总监 与 IT大牛 双子星后勤兵团
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 前置检查
if ! command -v openclaw &> /dev/null; then
    echo -e "${RED}错误: 未检测到 openclaw 核心库。请先安装: npm install -g @openclaw/cli${NC}"
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo -e "${RED}错误: 未检测到依赖 jq。请先安装 jq。${NC}"
    exit 1
fi

cat << "EOF"
  ____                     ____ _                 
 / __ \                   / ___| | __ ___      __
| |  | |_ __   ___ _ __  | |   | |/ _` \ \ /\ / /
| |__| | '_ \ / _ \ '_ \ | |___| | (_| |\ V  V / 
 \____/| .__/ \___/_| |_| \____|_|\__,_| \_/\_/  
       | |        Base-Ops Department
       |_|        
EOF
echo -e "${CYAN}欢迎使用 OpenClaw 企业自动化后勤基座安装向导${NC}\n"

# ==============================================================================
# 模块：部署全局技能包 (Global Skills)
# ==============================================================================
deploy_global_skills() {
    echo -e "${BLUE}[1/3] 正在挂载底层全局战术包 (Global Skills)...${NC}"
    if [ -d "$PROJECT_DIR/global-skills" ]; then
        mkdir -p "$HOME/.openclaw/skills"
        for skill_path in "$PROJECT_DIR/global-skills"/*; do
            if [ -d "$skill_path" ]; then
                skill_name=$(basename "$skill_path")
                target_path="$HOME/.openclaw/skills/$skill_name"
                if [ -d "$target_path" ]; then
                    echo -n -e "  ${YELLOW}⚠️ 全局技能 '$skill_name' 已存在，是否强制覆盖升级? [y/N]${NC} "
                    read -r overwrite
                    if [[ "$overwrite" =~ ^[Yy]$ ]]; then
                        cp -r "$skill_path" "$HOME/.openclaw/skills/"
                        echo -e "  ${GREEN}✓${NC} global-skills/$skill_name (安全覆盖完成)"
                    else
                        echo -e "  ${YELLOW}⏸${NC} global-skills/$skill_name (跳过安装)"
                    fi
                else
                    cp -r "$skill_path" "$HOME/.openclaw/skills/"
                    echo -e "  ${GREEN}✓${NC} global-skills/$skill_name (全新挂载)"
                fi
            fi
        done
    fi
    
    if [ -d "$PROJECT_DIR/scripts" ]; then
        echo -e "  ${BLUE}[+] 正在挂载底层守护进程 (Global Scripts)...${NC}"
        mkdir -p "$HOME/.openclaw/scripts"
        cp "$PROJECT_DIR/scripts/"* "$HOME/.openclaw/scripts/"
        echo -e "  ${GREEN}✓${NC} global-scripts/ (守护程序已全系统部署)"
    fi
}

# ==============================================================================
# 模块：安装 HR 部门 (HR Agent)
# ==============================================================================
deploy_hr_agent() {
    echo -e "\n${BLUE}[2/3] 开始部署 HR 行政与招募总监 (hr)...${NC}"
    
    # 检查是否存在
    agent_exists=$(openclaw config get agents.list | jq -r '.[] | select(.id == "hr") | .id')
    if [ -n "$agent_exists" ]; then
        echo -e "  ${YELLOW}ℹ️ 系统中已存在 ID 为 'hr' 的角色。${NC}"
        echo -n -e "    是否跳过底层初始化，仅热更其大脑(Workspace)文件？（强烈推荐） [Y/n] "
        read -r merely_update
        if [[ -z "$merely_update" || "$merely_update" =~ ^[Yy]$ ]]; then
            echo -e "  ${GREEN}✓${NC} 保留了现有的渠道绑定与密钥生态。"
            skip_init="true"
        else
            echo -e "  ${YELLOW}⚠️ 正在深度覆盖并重建 'hr' 引擎...${NC}"
            skip_init="false"
        fi
    else
        skip_init="false"
    fi

    if [ "$skip_init" == "false" ]; then
        echo "  正在注册 openclaw agent实体..."
        openclaw agents add hr
        openclaw agents set-identity --agent hr --name "HR 大管家" --emoji "👩‍💼"
        
        # 获取索引并设置工具锁
        AGENT_INDEX=$(openclaw config get agents.list | jq '[.[].id] | index("hr")')
        # HR 绝不应该有危险的 write 和 browser 权限
        openclaw config set "agents.list[$AGENT_INDEX].tools.allow" '["read","exec","cron"]' --strict-json
        openclaw config set "agents.list[$AGENT_INDEX].tools.deny" '["write","edit","browser","canvas","nodes"]' --strict-json
    fi
    
    # 始终同步文件
    HR_WORKSPACE=$(openclaw config get "agents.list[$(openclaw config get agents.list | jq '[.[].id] | index("hr")')].workspace" 2>/dev/null || echo "$HOME/.openclaw/workspace-hr")
    HR_WORKSPACE=$(echo "$HR_WORKSPACE" | tr -d '"')
    HR_WORKSPACE="${HR_WORKSPACE/#\~/$HOME}"
    
    mkdir -p "$HR_WORKSPACE"
    cp -r "$PROJECT_DIR/workspace-hr/"* "$HR_WORKSPACE/"
    # 同步共享模板
    cp -r "$PROJECT_DIR/shared-templates/" "$HR_WORKSPACE/templates/"
    
    echo -e "  ${GREEN}✓${NC} HR 工作台档案部署完毕 ($HR_WORKSPACE)"
    
    if [ "$skip_init" == "false" ]; then
        echo -e "  ${YELLOW}💡 为激活 HR 职能，请先使用系统监控 Watcher 进行安全重启：${NC}"
        echo -e "     nohup $HOME/.openclaw/scripts/gateway-watcher.sh hr provision > /tmp/watcher.log 2>&1 &"
    fi
}

# ==============================================================================
# 模块：安装 IT 部门 (IT Agent)
# ==============================================================================
deploy_it_agent() {
    echo -e "\n${BLUE}[3/3] 开始部署 IT 后勤与极客开发 (it-support)...${NC}"
    
    agent_exists=$(openclaw config get agents.list | jq -r '.[] | select(.id == "it-support") | .id')
    if [ -n "$agent_exists" ]; then
        echo -e "  ${YELLOW}ℹ️ 系统中已存在 ID 为 'it-support' 的角色。正在实施热同步文件...${NC}"
        skip_init="true"
    else
        skip_init="false"
    fi

    if [ "$skip_init" == "false" ]; then
        echo "  正在注册 openclaw agent实体..."
        openclaw agents add it-support
        openclaw agents set-identity --agent it-support --name "IT 极客大牛" --emoji "💻"
        
        AGENT_INDEX=$(openclaw config get agents.list | jq '[.[].id] | index("it-support")')
        # IT 必须拥有最高文件写入权和外围执行权！
        openclaw config set "agents.list[$AGENT_INDEX].tools.allow" '["read","write","edit","exec","cron"]' --strict-json
        openclaw config set "agents.list[$AGENT_INDEX].tools.deny" '["browser","canvas","nodes"]' --strict-json
    fi
    
    IT_WORKSPACE=$(openclaw config get "agents.list[$(openclaw config get agents.list | jq '[.[].id] | index("it-support")')].workspace" 2>/dev/null || echo "$HOME/.openclaw/workspace-it")
    IT_WORKSPACE=$(echo "$IT_WORKSPACE" | tr -d '"')
    IT_WORKSPACE="${IT_WORKSPACE/#\~/$HOME}"
    
    mkdir -p "$IT_WORKSPACE"
    cp -r "$PROJECT_DIR/workspace-it/"* "$IT_WORKSPACE/"
    
    echo -e "  ${GREEN}✓${NC} IT 黑客台档案部署完毕 ($IT_WORKSPACE)"
    
    # 动态挂载外部核心工具 (如 skill-creator)
    echo -e "  ${BLUE}[+] 正在通过 npx 挂载外部依赖技能 (skill-creator)...${NC}"
    set +e
    npx skills add https://github.com/anthropics/skills --skill skill-creator --agent openclaw --global --yes
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} skill-creator 外部技能安装成功"
    else
        echo -e "  ${YELLOW}⚠️ skill-creator 安装异常。请稍后手动执行: npx skills add https://github.com/anthropics/skills --skill skill-creator --agent openclaw --global --yes${NC}"
    fi
    set -e
}


# ==============================================================================
# 启动选项导航
# ==============================================================================

echo -e "请选择安装模块 (直接回车默认全选 = 1/2/3):"
echo -e "  [1] 全局能力包 (推荐，赋能所有终端员工的高阶兵器库)"
echo -e "  [2] HR 后勤节点 (人力招募/业务监控守护程序)"
echo -e "  [3] IT 后勤节点 (技术支援/全局脚本热开发引擎)"
echo -n -e "您的选择 (例如: 1 2 3 或 2 3): "
read -r sel
if [ -z "$sel" ]; then
    sel="1 2 3"
fi

echo ""
if [[ "$sel" == *"1"* ]]; then deploy_global_skills; fi
if [[ "$sel" == *"2"* ]]; then deploy_hr_agent; fi
if [[ "$sel" == *"3"* ]]; then deploy_it_agent; fi

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}🎉 恭喜！OpenClaw 后勤基座部署流程全部执行完毕。${NC}"
echo -e "   新部门接入后，请切记使用 \`openclaw gateway restart\` 激活网络。"
echo -e "${GREEN}====================================================${NC}\n"
