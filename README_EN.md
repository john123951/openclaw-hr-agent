# 🧑‍💼 OpenClaw HR Agent

[English](README_EN.md) | [中文](README.md)

**Still manually editing JSON configs and writing lengthy prompts just to initialize a new AI Agent? Let your HR handle it!**

**OpenClaw HR Agent** is a fully automated recruitment manager built for the [OpenClaw](https://github.com/openclaw/openclaw) multi-agent framework. 
It targets the core pain point of agent management setup: just tell the HR in plain English, "I need a programmer" or "Hire me a stock monitor", and it will automatically capture your underlying requirements through a concise Socratic dialogue. Then, it autonomously handles identity creation, model allocation, tool permission routing, multi-channel binding (Feishu/Telegram/Discord), and knowledge-base initialization.

Furthermore, it arrives with a built-in Base-Ops infrastructure: an auto-healing watcher daemon and a dedicated IT support agent capable of hot-writing code tools for your new hires, completely liberating you from low-level system configuration.

## 🚀 Quick Install

Run the following command in your terminal for a fully automated, one-click installation of OpenClaw Base-Ops:

```bash
curl -sL https://raw.githubusercontent.com/john123951/openclaw-hr-agent/refs/heads/main/install.sh | bash
```
## ✨ Core Pain Points Solved

- **Zero JSON Editing** — Everything is natively orchestrated using CLI commands, completely eliminating manual config errors.
- **Socratic Rapid Recruitment** — No more rigid 10-question surveys. The HR smartly infers your needs, often finalizing a new role architecture in just 3 conversational turns.
- **Automated Channel Binding** — Effortlessly deploy your new hires directly to Feishu (Lark), Telegram, or Discord. It even handles advanced API syncs like renaming Feishu groups.
- **Sociological Onboarding** — Hires aren't just "dropped in". They arrive with an onboarding protocol, get to know their boss, learn the company structure, and dynamically "shake hands" with the IT team.
- **8 Pre-configured Workhorses** — Start instantly with predefined templates for a Weather Assistant, Stock Monitor, Programmer, Copywriter, Ops Specialist, Researcher, Product Manager, or CEO Advisor.
- **LLM-Powered Self-Healing** — The attached Watcher daemon natively protects your system. If a new hire crashes the backend config, the script summons an LLM (Claude/Gemini) to live-patch the bug and safely reload.

## 📁 Project Structure

```
hr-agent/
├── workspace/                    # HR Agent Workspace
│   ├── AGENTS.md                 # Working rules (The 3-stage recruitment flow)
│   ├── SOUL.md                   # HR Personality Definition
│   ├── IDENTITY.md               # Avatar & Identity
│   ├── USER.md                   # User context templates
│   ├── TOOLS.md                  # CLI + API Cheat sheet
│   └── skills/                   # HR-specific skills
│       ├── agent-recruitment/    # Socratic requirement gathering
│       ├── agent-provisioning/   # Automated CLI agent creation 
│       ├── agent-knowledge-setup/# Knowledge base initialization
│       ├── agent-channel-binding/# Channel routing + Feishu API rename
│       ├── agent-onboarding/     # Onboarding tour documentation
│       └── agent-dismissal/      # Agent termination & archiving
├── templates/
│   ├── new-agent/                # Templates for newly hired agents
│   │   ├── AGENTS.md.template
│   │   ├── SOUL.md.template
│   │   ├── BOOTSTRAP.md.template
│   │   └── knowledge-init.md.template
│   └── jobs/
│       └── job-profiles.json     # 8 default role configurations
├── scripts/
│   ├── install-hr-agent.sh       # One-click installation script
│   └── hr-gateway-watcher.sh     # Background Daemon for safe system restarts
└── README_EN.md
```

## 🚀 Getting Started

### Prerequisites

- [OpenClaw](https://github.com/nichochar/openclaw) installed and configured.
- `openclaw` CLI available in your PATH.
- OpenClaw Gateway running (or ready to be started).

### One-Click Installation

```bash
# Clone the repository
git clone <your-repo-url> hr-agent
cd hr-agent

# Run the installation script
./scripts/install-hr-agent.sh
```

The script will automatically:
1. ✅ Check if `openclaw` CLI is available.
2. ✅ Create the `hr` agent (`openclaw agents add hr`).
3. ✅ Set the identity (🧑‍💼 HR Manager).
4. ✅ Configure model and tool permissions dynamically.
5. ✅ Copy workspace files (skills, templates, scripts) into the `~/.openclaw/workspace-hr` directory.
6. ✅ Ask you interactively if you want to bind the HR Agent to a channel right away.
7. ✅ Restart the Gateway safely.

### Manual Channel Binding (Optional)

If you skipped channel binding during installation:

```bash
# Bind to Feishu (Lark)
openclaw agents bind --agent hr --bind feishu:main

# Bind to Telegram
openclaw agents bind --agent hr --bind telegram:default

# Bind to Discord
openclaw agents bind --agent hr --bind discord:default

# Restart gateway to apply
openclaw gateway restart
```

## 💬 Usage

Simply talk to the HR Agent in your connected channel (e.g., Feishu, Telegram).

### Example Recruitment Flow

```
You: I need someone to check the weather for me every day.

HR: I'm on it! 🌤️ Let's set up a Weather Assistant.
    Initial thought: Check weather at 8:00 AM daily and report concisely.
    One question: What city are you in?

You: Shanghai

HR: Which channel should they report to?
    A. Feishu Group (Provide Group ID)
    B. Telegram
    C. Right here

You: A, oc_abc123

HR: Confirmation ✅
    🌤️ Weather Assistant | Daily 08:00 | Shanghai | Feishu Group oc_abc123
    Say "Yes" and I'll deploy them!

You: Yes

HR: Creating... ⏳
    ✅ Your new colleague has been created! The system is restarting safely in the background. They will introduce themselves in the group shortly! 🎉
```

### What can the HR Agent do?

| Capability | Description |
|------|------|
| 🔍 Socratic Exploration | Asks exact, minimal questions to understand your actual needs without overwhelming you. |
| 📋 Dynamic Provisioning | Recommends the best local LLM dynamically using `models.providers`. |
| 🏗️ Automated Creation | Uses CLI commands to create agents. Zero JSON editing required. |
| 📚 Knowledge Base | Initializes field-specific knowledge bases and enables semantic search. |
| 🔗 Channel Binding | Binds Feishu/TG/Discord routing and can even auto-rename Feishu groups via API. |
| 📝 Onboarding | Writes onboarding docs, helping the new agent understand the company structure locally. |
| 🚪 Firing Agents | Use the `agent-dismissal` skill to cleanly fire agents, archiving their workspace first. |

### Pre-configured Role Templates

| Role | Strategy | Use Case |
|------|---------|---------|
| 🌤️ Weather Assistant | Lightweight Model (gpt-3.5/haiku) | Daily weather tracking |
| 📈 Stock Monitor | Mid-tier Model | Price monitoring and alerts |
| ✍️ Copywriter | Mid-tier Model (gpt-4o-mini/sonnet) | Content writing and editing |
| 👨‍💻 Programmer | Powerful Model (gpt-4o/opus) | Code development and debugging |
| 📣 Operations | Mid-tier+ Model | Social media and data analysis |
| 🔬 Researcher | Strong Reasoning Model | In-depth research and reporting |
| 📋 Product Manager | Mid-tier+ Model | Requirement analysis and PRDs |
| 🤖 CEO Advisor | Most Powerful Model | Strategic analysis and decision support |

## 🔧 Customization

### Adding a New Role Template

Edit `templates/jobs/job-profiles.json` to add new role setups:

```json
{
  "my-custom-role": {
    "name": "🎯 Custom Role",
    "keywords": ["keyword1", "keyword2"],
    "role": "Role description",
    "modelStrategy": "Powerful Model",
    "tools": {
      "allow": ["exec", "read"],
      "deny": ["write", "edit"]
    },
    "knowledgeFocus": "Professional domain",
    "defaultSafetyRules": "Safety guidelines",
    "soulBeliefs": "Core philosophy"
  }
}
```

### Modifying the HR Persona

Edit `workspace/SOUL.md` to adjust the HR Agent's personality, tone, and strictness.

### Modifying the New Hire Onboarding Flow

Edit `templates/new-agent/BOOTSTRAP.md.template` to heavily customize what a new agent thinks and does the moment it wakes up.

## 📖 Design Philosophy

1. **Zero Burden** — 3-stage dialogue. One question at a time. Infer whenever possible.
2. **Secure Defaults** — Principles of least privilege via role templates.
3. **The Onboarding Gift** — HR pre-installs skills and a knowledge base structure. 
4. **The Human is the Boss** — All agents report directly to the human user.
5. **Auto-Healing First** — The background Watcher script doesn't just restart; it uses an LLM fallback chain (`claudecode` -> `codex` -> `gemini`) to perform live surgery on syntax errors if configurations get corrupted.

## 📄 License

MIT
