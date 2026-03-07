# 🧑‍💼 HR Agent — OpenClaw AI 员工招聘系统

[中文](README.md) | [English](README_EN.md)

基于 [OpenClaw](https://github.com/nichochar/openclaw) 多 Agent 框架的 AI 人力资源经理。能够通过纯自然语言对话，自动帮你完成新 AI Agent 员工的探索、招聘、档案建立以及入职配置。

## ✨ 特性

- **苏格拉底式招聘** — 渐进式对话机制，最快 3 轮交互摸清你的真实需求，避免“连环十问”。
- **脚本原生操作** — 全程通过调用 `openclaw` CLI 部署新员工，告别手动编辑复杂的 JSON 配置文件。
- **多渠道跨平台** — 支持将员工无缝外派到飞书（Lark）、Telegram、Discord，并支持自动修改飞书群名等高级 API 联动。
- **随身知识库** — 招聘时不仅建人，连带生成针对所属岗位的领域知识库及语义搜索架构。
- **环境感知式入职** — 新 Agent 在首次运行前，即可通过初始化文件（Bootstrap），认识人类老板和其他同事，掌握公司制度。
- **8 种开箱即用的热门岗位** — 天气助手、股票盯盘、程序员、文案写手、运营专员、研究员、产品经理及 CEO 专属顾问。
- **智能守护神 (Auto-Healing Watcher)** — 由于创建 Agent 涉及到底层的 Gateway 重启，附带的智能后台守护脚本会自动接管。如果重启时遇到配置文件报错，它会主动唤醒大模型（`claudecode`, `codex`, `gemini`）自动修补配置并完成二次急救，甚至失败后会自动做物理快照回滚。
- **好聚好散 (Graceful Dismissal)** — 不仅管招还管辞！内置辞退技能，一键安全卸载并清空对应 Agent 的所有系统权限，走之前还会温馨地把它的工作台打包成压缩包存入垃圾站档案室。

## 📁 项目结构

```
hr-agent/
├── workspace/                    # HR Agent 自身的脑区与工作空间
│   ├── AGENTS.md                 # 工作规则（三段式招聘引导流程）
│   ├── SOUL.md                   # HR 的人格定义（专业、热情、果断）
│   ├── IDENTITY.md               # 身份标识与系统展示参数
│   ├── USER.md                   # 用户画像上下文模板
│   ├── TOOLS.md                  # CLI 与外部 API 操作备忘录
│   └── skills/                   # HR 的硬核谋生技能库
│       ├── agent-recruitment/    # 需求探索与方案生成
│       ├── agent-provisioning/   # CLI 自动化生成档案与部署
│       ├── agent-knowledge-setup/# 预装领域知识库
│       ├── agent-channel-binding/# 通信渠道路由绑定与调优
│       ├── agent-onboarding/     # 拟定迎新致辞与上岗指导
│       └── agent-dismissal/      # 离职存档、剥夺权限与清理空间
├── templates/
│   ├── new-agent/                # 发给新员工的标准配置模板
│   │   ├── AGENTS.md.template
│   │   ├── SOUL.md.template
│   │   ├── BOOTSTRAP.md.template
│   │   └── knowledge-init.md.template
│   └── jobs/
│       └── job-profiles.json     # 预设的 8 种岗位配置文件
├── scripts/
│   ├── install-hr-agent.sh       # 安装引导脚本：建立 HR
│   └── hr-gateway-watcher.sh   # 守护神守护脚本：后台安全重启与大模型抢救
└── README_EN.md
```

## 🚀 极速安装

### 前置要求

- 最新版本的 [OpenClaw](https://github.com/nichochar/openclaw) 系统已正常运转
- 全局终端可以呼出 `openclaw` CLI，并配有至少一种可用的大模型
- Gateway（系统网关）守护进程处于活动状态

### 一键脚本

```bash
# 获取源码
git clone <your-repo-url> hr-agent
cd hr-agent

# 运行初始化安装引导
./scripts/install-hr-agent.sh
```

此安装脚本执行时，会自动帮你在本地环境中：
1. ✅ 检查依赖环境并在 OpenClaw 系统注册名为 `hr` 的新助手
2. ✅ 将本项目中预设好的身份数据（🧑‍💼 HR Manager）导入
3. ✅ 根据你本地已有模型环境，智能分配最合理的语言模型给 HR
4. ✅ 将精妙打包好的工作空间目录（Skills、Templates 甚至 Watcher）同步至 `~/.openclaw/workspace-hr` 并赋权
5. ✅ 给出一个通道绑定向导，让你决定是在终端、飞书还是 Discord 里和 HR 聊天
6. ✅ 安全延迟重启网关，无缝热更新

### 手动绑定终端/IM（可选）

如果在安装过程中选择了暂不绑定，你也可以随时通过命令行调遣 HR：

```bash
# 派去飞书对接
openclaw agents bind --agent hr --bind feishu:main

# 派去 Telegram
openclaw agents bind --agent hr --bind telegram:default

# 绑定到 Discord
openclaw agents bind --agent hr --bind discord:default


# 重启使新通道入口生效
openclaw gateway restart
```

## 💬 体验工作流

你可以回到你绑定的通信软件（或终端）直接对 HR 发起聊天：

### 招聘录用演示

```
你：我需要一个人帮我每天看看天气。

HR：好嘞！🌥️ 让我帮您安排一个【天气助手】。
    我初步的想法是：每天早上 8:00 查询指定城市的天气状况，用活泼简练的口吻进行提醒。
    为了精准安排，我只有一个问题需要首先向您确认：
    **请问您在哪个城市？**

你：上海

HR：关于这位天气助手的办公地点，请问您希望将他部署推送到哪个渠道？
    A. 飞书指定群（请直接回复群号/ID）
    B. Telegram
    C. 不需要推送，让他在 OpenClaw 系统里待命就好

你：A，oc_abc123

HR：方案已最终确认 ✅
    👨‍💻 新员工：天气助手 
    📍 办公地：飞书群 oc_abc123
    ⏰ 工作纪律：每日 08:00 定时向用户推送上海天气
    如果您觉得这个安排很妥当，请对我说一句“同意”或者“入职吧”，我就按此方案正式开始办理权限！

你：入职吧

HR：档案创立中... ⏳
    ✅ 新同事的档案已建好！系统正由 Watcher 接管在后台进行安全校验与重启... 苏醒后新同事会亲自向您报告！
    (片刻后，新员工出现在飞书中发言接管战场)
```

### HR 的业务能力一览表

| 专业技能 | 底层逻辑说明 |
|------|------|
| 🔍 需求捕捉 | 高级苏格拉底提问策略，能够自行推断大量潜台词，只问核心盲点 |
| 📋 选型匹配 | 根据预设岗位，自动匹配适合的模型深度（支持动态识别你本地已经配好的可用模型并择优录用） |
| 🏗️ 系统注册 | 生成标准 shell 命令直接配置物理档案，摒弃了危险也容易产生幻觉的 JSON 原生拼装方案 |
| 📚 脑库构建 | 为新员工建立独立的本地 Embedding 库和 Workspace 工作夹架构 |
| 🔗 权限发放 | 把系统层面的飞书、Discord 钩子权限挂载给子 Agent |
| 📝 迎新指导 | 在新员工启动的第一秒注入欢迎信协议（Bootstrap），让他知道自己是谁和身在何处 |
| 🚪 员工辞退 | "好聚好散" — 安全清理所有遗留权限，并将桌面数据全部归组打包送入系统的 Trash 回收站存档 |

## 🔧 高阶自定义

### 新建你独有的岗位模板

如果预设的 8 种员工无法满足，你可以修改 `templates/jobs/job-profiles.json` 以添加新的模型岗位画像：

```json
{
  "my-custom-role": {
    "name": "🎯 自定义岗位",
    "keywords": ["关键词1", "关键词2"],
    "role": "岗位职责描述",
    "modelStrategy": "最强模型",
    "tools": {
      "allow": ["exec", "read"],
      "deny": ["write", "edit"]
    },
    "knowledgeFocus": "专业领域指引",
    "defaultSafetyRules": "不该做的事情列表",
    "soulBeliefs": "该扮演的核心价值观"
  }
}
```

### 微调 HR 的行事风格

在这个架构下，你才是真正意义上的上帝。只需要编辑项目根目录中的 `workspace/SOUL.md`，你就可以将热心助人的 HR 变成极其冷酷刻薄的系统主管。

### 调校底层自动回滚大模型机制 (Watcher Daemon)

打开 `scripts/hr-gateway-watcher.sh`，内部包含了完整的 `claudecode -> codex -> gemini` 三重降落伞容错机制逻辑。当 OpenClaw 底层配置文件面临威胁时，它可以依靠纯命令行进行全自动原地修复。你可以自由拓展里面关于 AI 抢救时的自定义 prompt。

## 📖 架构与设计准则

1. **“无感是最佳的交互体验”** — 将用户从枯燥配置中彻底解放，三轮问答内必须成军。
2. **安全左移** — 使用基于 `openclaw` 原生命令行的脚手架构建技术代替 AI 在 JSON 内自行涂鸦，避免配置污染导致的网关崩溃综合症。
3. **“人类中心主义”架构** — 所有产出的 Agent 必须且只对创建者（人类使用者）本人汇报，即使他们拥有独立的飞书账号。
4. **自监督容错闭环** — 系统级操作绝不可成为黑盒。任何因创建 Agent 触发的核心系统重启动作，均通过挂载专门的 Linux/Unix Bash 守护进程 (Watcher) 进行多层验证与熔断恢复。

## 📄 License

MIT
