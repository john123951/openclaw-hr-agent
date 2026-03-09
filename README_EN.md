# 🧑‍💼 OpenClaw HR Agent

[English](README_EN.md) | [中文](README.md)

**Your Large Language Model 🦞 Lobster team needs a professional HR.**

Let your dedicated **HR Director** and **IT Geek** autonomously hire AI agents, configure permissions, and route cross-channel APIs (Feishu/TG) for you via simple chat.



## 🚀 True One-Liner Install

The easiest way to install is to simply tell your OpenClaw assistant:
> "Please install this Operations ecosystem for me: https://github.com/john123951/openclaw-hr-agent"

Alternatively, run the following command in your terminal to silently orchestrate the entire baseline and deploy both operation managers:

```bash
curl -sL https://raw.githubusercontent.com/john123951/openclaw-hr-agent/refs/heads/main/install.sh | bash
```

> **Uninstaller**: Need to revert? Clone the original repo and execute `./uninstall.sh` for an irreversible but completely clean physical sweep.

---

## ✨ Core Pain Points Solved

- **Zero JSON Editing** — Everything is natively orchestrated using CLI commands (`openclaw agents add`), completely eliminating catastrophic formatting errors in `openclaw.json`.
- **Socratic Rapid Recruitment** — No more rigid 10-question surveys. The HR smartly infers your needs, often finalizing a new role architecture in just 3 conversational turns.
- **Dynamic IT Tool Smith** — If your Copywriter AI needs a specific web scraper, you don't write code. Just tell them to escalate to the IT Department (`it-support`), who will write, package, and install it as a system-wide Skill dynamically.
- **Automated Channel Binding** — Effortlessly deploy your new hires directly to Feishu (Lark), Telegram, or Discord. It even handles advanced API syncs like renaming Feishu groups.
- **Sociological Onboarding** — Hires aren't just "dropped in". They arrive with an onboarding protocol, get to know their boss, and must complete verified HR / IT handshakes before HR marks them fully onboarded.
- **LLM-Powered Self-Healing** — The attached OS Watcher daemon physically protects your gateway. If a new agent crashes the backend config, the script summons an LLM (Claude/Gemini) to live-patch the JSON bug and safely reboot.

---

## 📁 Architecture Layout

```
openclaw-hr-agent/
├── install.sh                  # The unified one-click deployment gateway
├── uninstall.sh                # The rigorous physical sweeper
├── global-scripts/             # Baseline background daemons
│   └── gateway-watcher.sh      # Deployed to ~/.openclaw/scripts/ for restart/self-healing
├── global-skills/              # Arsenal of extreme skills mapped at root level
│   └── openclaw-mastery/       # Grants agents control over OpenClaw system paths
├── workspace-hr/               # Isolated workspace for the HR Director
│   ├── AGENTS.md / SOUL.md     # Recruitment protocols and decisive persona
│   └── skills/                 # Core administrative toolchain
│       ├── agent-recruitment/  # Scope gathering & Socratic profiling
│       ├── agent-provisioning/ # Autonomous CLI file builder
│       ├── agent-knowledge-setup/# Knowledge graph bootstrapping
│       ├── agent-channel-binding/# Telegram/Feishu routing + APIs
│       └── agent-onboarding/   # Welcome speech and system rule briefing
├── workspace-it/               # Core tech bunker for IT Operations
│   ├── AGENTS.md / SOUL.md     # Code safety boundaries and Geek persona
│   └── skills/                 # (skill-creator is injected here at runtime)
└── shared-templates/           # The public assets pool
    ├── new-agent/              # Universal configurations handed to new hires
    └── jobs/                   # Pre-bundled templates (Stock/Programmer/etc.)
```

---

## 💬 Usage Flow Example

Once installed, simply chat directly with the HR Agent from your bonded communication app or CLI:

```
You: I need someone to check the weather for me every day.

HR: I'm on it! 🌤️ Let's set up a Weather Assistant.
    Initial thought: Check the forecasted weather at 8:00 AM daily and report concisely. 
    To make it precise, I only have one question for you:
    **What city are you in?**

You: Shanghai

HR: Regarding the office location, which channel should this assistant report to?
    A. Feishu Group (Provide Group ID)
    B. Telegram
    C. Keep them waiting in OpenClaw system background

You: A, oc_abc123

HR: Profile Confirmed ✅
    👨‍💻 Hire: Weather Assistant
    📍 Office: Feishu Group oc_abc123
    ⏰ Workflow: Auto push Shanghai weather at 08:00
    If you approve this structure, just say "Yes" or "Let's hire" and I will physically file the configs!

You: Let's hire

HR: Processing files... ⏳
    ✅ Your new colleague has been filed! The Watcher subsystem is now taking over to securely validate and reboot the gateway... they'll introduce themselves when they wake up!

(Moments later, a brand new agent pops into the Feishu group)
Weather Assistant: 🎉 Hello boss! I'm your new weather broadcaster. I'm actively monitoring Shanghai clouds—let me know if you need any adjustments!
```

---

## 📖 Key Design Philosophies

1. **Zero Burden** — A strict 3-stage Socratic dialogue. One question at a time. The AI must infer whenever possible rather than pushing a lengthy form to the human.
2. **Shift Left Security** — The usage of CLI architectures eliminates dangerous AI sandbox splicing inside raw `openclaw.json` objects.
3. **Human as the Absolute Apex** — Every compiled Agent serves the human direct-supervisor singularly.
4. **Biological Self-Correction Loop** — Server reboots shouldn't trigger black box collapses. If a config creation process triggers a fatal error on startup, an asynchronous uncoupled Bash daemon assumes monitoring dominance, using secondary AI tools to cut through JSON crashes.

## 📄 License

MIT
