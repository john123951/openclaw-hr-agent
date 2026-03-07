# 🧑‍💼 HR Agent — OpenClaw AI 员工招聘系统

基于 [OpenClaw](https://github.com/nichochar/openclaw) 多 agent 框架的 AI 人力资源经理，帮你通过自然对话"招聘"新的 AI agent 员工。

## ✨ 特性

- **苏格拉底式招聘** — 三段式渐进对话，最快 3 轮完成招聘
- **脚本化配置** — 全程使用 `openclaw` CLI，不手动编辑 JSON
- **多渠道绑定** — 支持飞书、Telegram、Discord，含飞书 API 自动改群名
- **知识库搭建** — 为每个新 agent 建立专属知识管理体系
- **环境感知入职** — 新 agent 自动认识同事、熟悉工具、了解公司环境
- **8 种预设岗位** — 天气助手、股票监控、程序员、文案、运营、研究员、产品经理、CEO 顾问

## 📁 项目结构

```
hr-agent/
├── workspace/                    # HR Agent 工作空间文件
│   ├── AGENTS.md                 # 工作规则（三段式招聘流程）
│   ├── SOUL.md                   # HR 人格定义
│   ├── IDENTITY.md               # 身份标识
│   ├── USER.md                   # 用户信息模板
│   ├── TOOLS.md                  # CLI + API 备忘录
│   └── skills/                   # HR 专属技能
│       ├── agent-recruitment/    # 苏格拉底式需求探索
│       ├── agent-provisioning/   # CLI 自动化创建 agent
│       ├── agent-knowledge-setup/# 知识库初始化
│       ├── agent-channel-binding/# 渠道绑定 + 飞书 API
│       └── agent-onboarding/     # 入职巡视文档生成
├── templates/
│   ├── new-agent/                # 新 agent 的文件模板
│   │   ├── AGENTS.md.template
│   │   ├── SOUL.md.template
│   │   ├── BOOTSTRAP.md.template
│   │   └── knowledge-init.md.template
│   └── jobs/
│       └── job-profiles.json     # 8 种岗位预设配置
├── scripts/
│   └── install-hr-agent.sh       # 一键安装脚本
└── README.md
```

## 🚀 安装

### 前置条件

- [OpenClaw](https://github.com/nichochar/openclaw) 已安装并配置
- `openclaw` CLI 可用
- Gateway 已启动（或安装后启动）

### 一键安装

```bash
# 克隆项目
git clone <your-repo-url> hr-agent
cd hr-agent

# 运行安装脚本
./scripts/install-hr-agent.sh
```

安装脚本会自动完成：
1. ✅ 检查 `openclaw` CLI 是否可用
2. ✅ 创建 `hr` agent（`openclaw agents add hr`）
3. ✅ 设置身份（🧑‍💼 HR Manager）
4. ✅ 配置模型（claude-sonnet-4-5）和工具权限
5. ✅ 复制工作空间文件（skills、templates 等）
6. ✅ 验证配置（`openclaw config validate`）

### 安装后

```bash
# 重启 Gateway 使配置生效
openclaw gateway restart

# 验证 HR Agent 已添加
openclaw agents list --bindings
```

### 绑定通信渠道（可选）

```bash
# 绑定到飞书
openclaw agents bind --agent hr --bind feishu:main

# 绑定到 Telegram
openclaw agents bind --agent hr --bind telegram:default

# 绑定到 Discord
openclaw agents bind --agent hr --bind discord:default

# 重启生效
openclaw gateway restart
```

## 💬 使用方式

在绑定的渠道中与 HR Agent 对话即可开始招聘。

### 招聘示例

```
你：我需要一个人帮我每天看看天气

HR：好嘞！🌤️ 帮你安排一个天气助手。
    我初步设想：每天早上 8:00 查询天气，简洁播报。
    一个问题：你在哪个城市？

你：上海

HR：推送到哪个渠道？
    A. 飞书群（告诉我群 ID）
    B. Telegram
    C. 就在这里

你：A，oc_abc123

HR：方案确认 ✅
    🌤️ 天气助手 | 每天 08:00 | 上海 | 飞书群 oc_abc123
    说"好"我就开始！

你：好

HR：开始创建中... ⏳
    ✅ 天气助手已入职！你可以在飞书群里和他聊了 🎉
```

### HR Agent 能做什么

| 功能 | 说明 |
|------|------|
| 🔍 需求探索 | 苏格拉底式对话，帮你搞清楚到底需要什么 |
| 📋 方案生成 | 自动推荐模型、工具权限、渠道配置 |
| 🏗️ 自动创建 | 通过 CLI 命令创建 agent，不碰 JSON |
| 📚 知识库搭建 | 初始化领域知识库 + 启用语义搜索 |
| 🔗 渠道绑定 | 绑定飞书/TG/Discord，飞书自动改群名 |
| 📝 入职培训 | 编写入职文档，帮新 agent 认识环境 |
| ✅ 测试验证 | 自动测试新 agent 是否正常工作 |

### 预设岗位模板

| 岗位 | 推荐模型 | 适用场景 |
|------|---------|---------|
| 🌤️ 天气助手 | claude-haiku | 每日天气播报 |
| 📈 股票盯盘 | claude-haiku | 价格监控与告警 |
| ✍️ 文案创作 | claude-sonnet | 内容撰写与编辑 |
| 👨‍💻 程序员 | claude-sonnet | 代码开发与调试 |
| 📣 运营专员 | claude-sonnet | 社交媒体与数据分析 |
| 🔬 研究员 | claude-opus | 深度调研与报告 |
| 📋 产品经理 | claude-sonnet | 需求分析与 PRD |
| 🤖 CEO 顾问 | claude-opus | 战略分析与决策支持 |

## 🔧 自定义

### 添加新岗位模板

编辑 `templates/jobs/job-profiles.json`，添加新的岗位配置：

```json
{
  "my-custom-role": {
    "name": "🎯 自定义岗位",
    "keywords": ["关键词1", "关键词2"],
    "role": "岗位职责描述",
    "model": "anthropic/claude-sonnet-4-5",
    "tools": {
      "allow": ["exec", "read"],
      "deny": ["write", "edit"]
    },
    "knowledgeFocus": "专业领域",
    "defaultSafetyRules": "安全规则",
    "soulBeliefs": "核心信念"
  }
}
```

### 修改 HR 的对话风格

编辑 `workspace/SOUL.md` 调整 HR Agent 的性格和语气。

### 修改新 agent 的入职流程

编辑 `templates/new-agent/BOOTSTRAP.md.template` 自定义入职巡视协议。

## 📖 设计文档

详细的设计思路请参考 `references/` 目录下的 OpenClaw 文档。

### 核心设计原则

1. **无负担** — 三段式对话，一轮一个问题，能推断就不问
2. **安全默认** — 岗位模板预设权限，最小权限原则
3. **入职大礼包** — HR 预设 skills + 知识库，新 agent 可微调
4. **人类是老板** — 所有 agent 直接汇报人类用户
5. **扁平结构** — 现阶段所有 agent 平等协作
6. **聚焦招聘** — HR 只做招聘，做到极致

## 📄 License

MIT
