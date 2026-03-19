# HCC Memory Plugin

Hierarchical Cognitive Caching — project-level memory for Claude Code.

## What is this?

HCC Memory is a Claude Code plugin that gives your AI assistant persistent, structured memory across sessions. Instead of losing context when a session ends, HCC captures execution traces, distills them into validated findings, and promotes the best ones to cross-project wisdom. It follows a three-layer model (trace → findings → wisdom) with progressive validation levels.

## Install from GitHub

1. Clone this repository (plugin root = repo root):
   ```bash
   git clone https://github.com/<your-username>/<your-repo>.git
   cd <your-repo>
   ```

2. Launch Claude Code with the local plugin:
   ```bash
   claude --plugin-dir "$(pwd)"
   ```
   On Windows (PowerShell), use the full path to the cloned folder instead of `$(pwd)`.

## Quick Start

1. Initialize memory in your **project** directory (not inside the plugin repo):
   ```
   /hcc-memory:init
   ```

2. Start a task:
   ```
   /hcc-memory:plan "Run VKI LS89 cascade simulation"
   ```

3. Work normally. Every 5 tool uses, the 5-Action Rule will remind you to log progress. When you learn something valuable, use `/hcc-memory:promote`.

## Commands

| Command | Description |
|---------|-------------|
| `/hcc-memory:init` | Initialize memory system in current project |
| `/hcc-memory:plan` | Start a new task with description |
| `/hcc-memory:log` | Log a trace entry (usually automatic via 5-Action Rule) |
| `/hcc-memory:promote` | Distill trace entries into structured findings |
| `/hcc-memory:complete` | Complete current task, archive trace, review for upgrades |
| `/hcc-memory:recover` | Recover context after a session break |
| `/hcc-memory:search` | Search memory for relevant findings and wisdom |
| `/hcc-memory:status` | Show current memory system status |
| `/hcc-memory:compact` | Audit memory for redundancy and staleness |
| `/hcc-memory:export` | Export domain-scoped findings for knowledge sharing |

## Core Concepts

### Three-Layer Memory

- **L1 — Trace**: Rolling execution log. Captures what the agent did, in real-time. Auto-archived when full.
- **L2 — Findings**: Structured learnings distilled from traces. Each has a type (EF, CP, PI, WF, EV), validation level, and confidence rating.
- **L3 — Wisdom**: Findings promoted after verification across multiple cases. Highest authority.

### Validation Levels

Findings are validated progressively:

| Level | Meaning | Confidence |
|-------|---------|------------|
| syntax | Program ran without crashing | Low |
| numerical | Solution converged (⚠ not physics) | Medium |
| physical | Compared against experimental/analytical data | High |
| methodology | Validated across multiple case types | Highest |

**Important**: A `numerical` validation means "it converged" — not "it's correct." Always verify physical plausibility before trusting a numerically-validated finding.

### 5-Action Rule

After every 5 tool uses, the plugin reminds the agent to log its recent work. This ensures continuous trace capture and prevents context loss.

## File Structure

```
project/
├── memory/
│   ├── trace.md              # Rolling execution log
│   ├── findings/             # L2 structured learnings
│   │   ├── _index.md         # Auto-generated index
│   │   └── F-OF-EF-a1b2c3.md # Individual finding
│   ├── wisdom/               # L3 verified knowledge
│   │   ├── _index.md
│   │   └── W-OF-EF-a1b2c3.md
│   ├── tasks/                # Task tracking
│   │   └── _active.md
│   ├── sessions/             # Archived trace sessions
│   └── _export/              # Sanitized exports
├── .hcc/
│   ├── config.yaml           # Plugin configuration
│   └── state.json            # Runtime state
└── .gitignore                # Auto-updated
```

## Finding Types

| Code | Type | Example |
|------|------|---------|
| EF | Error Fix | "simpleFoam FPE with zero initial field" |
| CP | Configuration Pattern | "k-omega SST settings for LS89" |
| PI | Physical Insight | "Shock position sensitivity to outlet pressure" |
| WF | Workflow Pattern | "Mesh independence study procedure" |
| EV | Environment Setup | "ParaView remote rendering with EGL" |
| CN | Constraint/Note | "Maximum CFL for explicit solver" |

## ChatCFD Integration

This plugin is designed for CFD simulation workflows but works with any project type. For ChatCFD-specific documentation and multi-agent architecture details, see the `docs/` directory.

## Requirements

- Bash >= 4.0
- jq >= 1.6 (required for promote and compact commands)
- Standard coreutils (sed, awk, grep, date)
- Claude Code with plugin support

## Contributing

See `docs/` for design philosophy and architecture details.

## License

MIT — see [LICENSE](LICENSE)
