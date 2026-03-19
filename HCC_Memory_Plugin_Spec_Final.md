# HCC Memory — Claude Code Plugin (Updated Spec)

> **这是什么**: 一个 Claude Code 插件，为任意项目提供三层记忆系统 + 可选知识库接入。
> **安装方式**: `/plugin install hcc-memory` 或 `claude --plugin-dir ./hcc-memory`
> **版本**: v0.1 MVP Spec (Updated) — 2026-03-20
> **配套文档**: [HCC 设计哲学](./HCC_Design_Philosophy.md)

---

## 1  核心概念：知识 vs 记忆

本 plugin 处理两种不同性质的信息，它们的来源、生命周期和管理方式完全不同。
在阅读后续章节之前，请确保理解这个区分。

### 知识（Knowledge）—— 只读参考资料，来自社区

知识是已经被验证、整理、抽象过的经验总结，去掉了个人和项目的痕迹。
它按两层组织：

**Foundation（通用知识）**：与具体仿真场景无关的底层知识。
例如"OpenFOAM 中 simpleFoam 初场全零会导致 FPE"、
"k-omega SST 在逆压梯度下优于 k-epsilon"。
只要你用某个求解器，就可能用到。

**Specialist（专项知识）**：绑定在特定应用领域上的知识。
例如"叶栅尾缘的 O-grid 需要至少 30 层 spanwise 分辨率"。
只对从事该领域仿真的人有价值。

知识库在 MVP 中不实现。它是 Phase 2+ 的功能（通过 `hcc pull` 安装预置知识包）。
但 MVP 的数据格式已为此预留了 `layer` 和 `specialist_area` 字段。

### 记忆（Memory）—— 读写工作产物，来自个人工作

记忆是 Agent 在具体工作过程中产生的、带有个人和项目特征的经验。
它是 HCC 三层架构的主体：

- **L1（trace）**：工作流水账，会话级，自动记录，无需整理
- **L2（findings）**：从流水账中提炼出的结构化经验，项目级
- **L3（wisdom）**：经过多案例验证的可靠知识，可能上升为社区知识

**关键认识：大部分记忆永远留在本地。** 这是正常的。
一个人在一个项目中的大量操作记录和调试经验，
对那个人在那个项目中很有价值，但对别人价值很低。
只有少数经过充分验证、具有通用性的记忆，才值得共享。

### 两者的交互

```
Cloud Knowledge Base (Phase 2+)
  ├── Foundation (通用知识包)
  └── Specialist (专项知识包)
        │
        │  hcc pull (下载，只读)
        │  hcc push (贡献，需审核)
        ▼
Local Project
  ├── knowledge/           ← 安装的知识包（只读参考，Phase 2+）
  │   ├── foundation/
  │   └── specialist/
  │
  └── memory/              ← 本地记忆（读写，MVP 核心）
      ├── trace.md         (L1: 工作记忆 → 大量，个人化)
      ├── findings/        (L2: 提炼经验 → 较少，初步验证)
      └── wisdom/          (L3: 验证知识 → 极少，高质量)
                                    ↓
                           少数 L3 条目可 export
                           脱敏后贡献到知识库
```

---

## 2  设计目标（MVP 范围）

**G1 通用化。** `hcc-memory:init` 在任意项目目录可用，与 ChatCFD 或任何特定 Skill 零耦合。

**G2 记忆闭环。** 完整的 plan → log → promote → complete → recover → search 本地工作流。

**G3 项目隔离。** 每个项目独立的 memory/ 目录，不同项目互不干扰。

**G4 冗余控制。** L1 滚动窗口、L2 promote 去重、compact 审计。

**G5 格式预留。** 记忆条目格式兼容未来的知识库共享（layer/specialist_area 字段），
但 MVP 不实现 push/pull/知识库安装。

---

## 3  Plugin 目录结构

```
hcc-memory/                              ← GitHub 仓库 = Plugin 根目录
│
├── .claude-plugin/
│   └── plugin.json                      ← Plugin 元数据
│
├── commands/                            ← 斜杠命令（用户接口）
│   ├── init.md                          ← /hcc-memory:init
│   ├── plan.md                          ← /hcc-memory:plan
│   ├── promote.md                       ← /hcc-memory:promote
│   ├── complete.md                      ← /hcc-memory:complete
│   ├── recover.md                       ← /hcc-memory:recover
│   ├── search.md                        ← /hcc-memory:search
│   ├── status.md                        ← /hcc-memory:status
│   ├── compact.md                       ← /hcc-memory:compact
│   └── export.md                        ← /hcc-memory:export
│
├── skills/
│   └── memory-workflow/
│       └── SKILL.md                     ← 教 Claude 何时/如何使用记忆
│
├── hooks/
│   └── hooks.json                       ← 5-Action Rule 自动提醒
│
├── scripts/                             ← Bash 实现层
│   ├── init-memory.sh
│   ├── plan.sh
│   ├── log-trace.sh
│   ├── promote.sh
│   ├── complete.sh
│   ├── recover.sh
│   ├── search.sh
│   ├── status.sh
│   ├── compact.sh
│   ├── export.sh
│   ├── touch.sh
│   ├── doctor.sh
│   ├── validate.sh
│   ├── hooks/
│   │   ├── action-counter.sh
│   │   └── session-start.sh
│   └── util/
│       ├── platform.sh                  ← 跨平台兼容层
│       ├── frontmatter.sh              ← front matter 读写（受限 YAML 子集）
│       ├── fingerprint.sh              ← ID 生成
│       ├── dedup.sh                     ← 去重检测
│       ├── sanitize.sh                  ← 脱敏处理
│       ├── archive.sh                   ← 归档操作
│       └── index-rebuild.sh            ← _index.md 重建
│
├── templates/                           ← 文件模板
│   ├── finding-entry.md.tmpl
│   ├── wisdom-entry.md.tmpl
│   ├── trace-header.md.tmpl
│   └── task-active.md.tmpl
│
├── tests/
│   ├── test-init.sh
│   ├── test-plan-log.sh
│   ├── test-promote.sh
│   ├── test-complete.sh
│   ├── test-search.sh
│   └── helpers.sh
│
├── README.md
├── LICENSE                              ← MIT
├── CHANGELOG.md
└── .github/
    └── workflows/
        └── ci.yml
```

---

## 4  Plugin Manifest

```json
{
  "name": "hcc-memory",
  "description": "Hierarchical Cognitive Caching — project-level memory system for Claude Code. Tracks work, distills experience, builds verified knowledge across sessions.",
  "version": "0.1.0",
  "author": "wei"
}
```

---

## 5  项目中生成的文件结构

执行 `/hcc-memory:init` 后，项目目录增加：

```
project-root/
├── memory/
│   ├── trace.md                 ← L1: 工作记忆（滚动窗口）
│   ├── findings/                ← L2: 提炼经验（单条目单文件）
│   │   └── _index.md            ← 自动生成的摘要索引
│   ├── tasks/                   ← 任务管理
│   │   └── _active.md           ← 当前活跃任务（仅一个）
│   ├── wisdom/                  ← L3: 验证知识
│   │   └── _index.md
│   ├── sessions/                ← L1 归档
│   ├── _export/                 ← export 输出
│   └── knowledge/               ← Phase 2+ 预留（安装的知识包，只读）
│       └── .gitkeep
│
├── .hcc/
│   ├── config.yaml              ← 项目配置
│   └── state.json               ← 运行时状态
│
└── (项目原有文件不受影响)
```

### .gitignore 追加

```
# HCC Memory
memory/trace.md
memory/sessions/
memory/_export/
memory/knowledge/
.hcc/state.json
```

**进入 Git 的**：findings/、wisdom/、tasks/、config.yaml（项目知识资产）。
**不进入 Git 的**：trace.md、sessions/、state.json、_export/、knowledge/（个人/运行时/缓存）。

---

## 6  记忆条目 Schema

### 6.1  Finding 条目（L2）

文件名：`F-{DOMAIN}-{TYPE}-{HASH6}.md`

```yaml
---
schema_version: 1
id: F-OF-EF-a13f2c
title: "simpleFoam 初场全零导致浮点异常"
scope: domain                    # session | project | domain
type: EF                         # EF | CP | PI | WF | EV | CN
layer: foundation                # foundation | specialist
specialist_area: ""              # 当 layer=specialist 时填写
domain: openfoam
tags: [simpleFoam, divergence, initial-conditions]
status: active                   # active | stale | archived | deprecated
created_at: "2026-03-15"
updated_at: "2026-03-15"
confidence: medium               # low | medium | high
validation_level: numerical      # syntax | numerical | physical | methodology
related_to: []
supersedes: []
valid_solver: "OpenFOAM"
valid_versions: ""
valid_regime: []
valid_models: []
valid_geometry: []
verified_by: ["wei"]
verified_in: ["VKI-LS89"]
known_failures: []
---

## Problem
（必填。触发条件和现象。EF 类型含 error signature。）

## Action
（必填。解决方案或关键做法。）

## Root Cause
（推荐。）

## Evidence
（推荐。导出到知识库前必须有。）

## Validation
（推荐。标注当前验证到了哪个层次及具体证据。每个层次填实际情况或留空。）

- **Syntax**: (程序是否运行完成，无报错)
- **Numerical**: (残差收敛情况，守恒误差)
- **Physical**: (与外部基准对比结果——对比了什么量，误差范围，基准数据来源)
- **Methodology**: (在哪些不同类型的案例中验证过)

## Applicability
（可选。适用工况范围。）

## Failure Boundary
（可选。导出到知识库前必须有。已知不适用的场景。）
```

### 6.2  Scope/Type/Layer 三维分类

这三个字段分别回答不同的问题：

**Scope**（作用域）回答"谁需要这条信息"：
- `@session`：仅当前会话（只存在于 L1 trace 中，不成为独立条目）
- `@project`：当前项目有用，但不具通用性
- `@domain`：对同一领域的所有人都有价值，是导出到知识库的前提

**Type**（类型）回答"这是什么性质的经验"：
- `EF`：错误-修复对。共享价值最高。
- `CP`：配置模式。需要含验证条件。
- `PI`：物理洞察。需要最强验证证据。
- `WF`：工作流模式。
- `EV`：环境问题。只有广泛适用时才标 @domain。
- `CN`：算例笔记。通常是 @project，很少共享。

**Layer**（层级）回答"这条知识的通用程度"：
- `foundation`：去掉应用场景上下文后仍然成立的通用知识。
  例："relaxationFactors 过高会导致发散"。不管你仿真什么东西，这都成立。
- `specialist`：只在特定应用场景下才成立的知识。
  例："叶栅前缘 O-grid 需要至少 30 层"。只对叶轮机械有意义。

**判断 layer 的简单方法**：
问自己——"如果把这条经验告诉一个做完全不同领域仿真的人，他能用上吗？"
如果能，就是 foundation。如果不能，就是 specialist。

**Validation Level**（验证深度）回答"这条经验被验证到了什么程度"：
- `syntax`：程序不报错了。反馈信号明确（FOAM FATAL ERROR 消失），置信度高，迁移性好。
- `numerical`：解收敛了。残差下降到合理水平，守恒误差可接受。**⚠️ 收敛不等于正确——这条经验只保证了数值稳定性，不保证物理正确性。**
- `physical`：结果经过物理验证。已与实验数据、解析解或高保真计算做过对比，关键物理量吻合合理。Evidence 和 Validation 区块中必须记录具体对比信息。
- `methodology`：跨案例验证的方法论。在 3 个或更多不同类型的案例中确认有效。迁移价值最高，但验证门槛也最高。

**四个级别是递进关系**：syntax → numerical → physical → methodology。每一层都建立在前一层基础上。大多数 finding 在首次 promote 时停在 syntax 或 numerical，随着后续验证逐步升级。

**"收敛≠正确"认知陷阱警告**：一个只积累了大量 numerical 级别记忆但缺少 physical 级别记忆的 Agent，会变成一个"擅长让错误的解收敛"的系统。这比没有记忆更危险，因为它给用户虚假的信心。所以 numerical 级别的记忆在搜索结果中必须附带警告标记。

### 6.3  Front Matter 约束

所有字段都是单层 key-value 或单层数组 `[a, b, c]`。
不允许嵌套 YAML 对象。原因是 scripts/ 使用 sed/awk 解析 front matter，
嵌套结构无法可靠处理。

`schema_version: 1` 从第一个版本起强制包含，确保未来升级时的向后兼容。

### 6.4  ID 生成

```
ID = "{PREFIX}-{DOMAIN_CODE}-{TYPE}-{HASH6}"

PREFIX    = F (finding) | W (wisdom)
DOMAIN    = OF | SU2 | FL | GCFD | GEN | ...
TYPE      = EF | CP | PI | WF | EV | CN
HASH6     = sha256(lowercase(domain + "|" + type + "|" + title))[0:6]
```

冲突时追加 `-2`、`-3`。

### 6.5  状态机

```
active ──(超过 stale_threshold_days 未使用)──→ stale ──(人工确认)──→ archived
  ↑                                              │
  └──(被 touch/search 命中使用)──────────────────┘

active ──(被新条目 supersedes)──→ deprecated
```

---

## 7  config.yaml

```yaml
version: 1
project:
  name: ""                      # 由目录名填充
  domain: "general"             # 求解器/工具：openfoam | su2 | fluent | general
  specialist: []                # 专项领域：turbomachinery | chip-cooling | external-aero | ...
  tags: []                      # 自由标签

memory:
  flush_interval: 5             # 5-Action Rule 间隔
  trace_max_entries: 30         # L1 滚动窗口条目上限
  trace_max_bytes: 12288        # L1 滚动窗口字节上限
  stale_threshold_days: 180     # 标记 stale 的天数
  recover_budget_bytes: 8192    # recover 上下文预算

# Phase 2+ 预留
hub:
  remote: ""
  contributor: ""
  telemetry: false
```

---

## 8  Commands 详细规格

### 8.1  /hcc-memory:init

```markdown
---
description: Initialize HCC memory system in the current project. Creates memory/ directory and configuration.
---

Initialize the HCC memory system for this project.

If the user provided arguments like a domain name, use them. Otherwise ask:
1. What solver/tool does this project use? (openfoam / su2 / fluent / general)
2. What specialist area, if any? (turbomachinery / chip-cooling / external-aero / none)

Then run:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh" "$(pwd)" "<domain>" "<specialist>"
```

If memory/ already exists, warn the user and ask to confirm before reinitializing.

After initialization, explain the workflow briefly:
- I'll automatically track every 5 tool uses (5-Action Rule)
- Use /hcc-memory:plan to start a task
- Use /hcc-memory:promote when you discover something worth remembering
- Use /hcc-memory:complete when done
- Use /hcc-memory:recover to resume after a break
```

### 8.2  /hcc-memory:plan

```markdown
---
description: Start a new task. Usage: /hcc-memory:plan <task description>
---

Start a new task: $ARGUMENTS

Run:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/plan.sh" "$(pwd)" "$ARGUMENTS"
```

If an active task exists, ask the user to complete it first or force-start.
After creating the task, display the plan and remind about the 5-Action Rule.
```

### 8.3  /hcc-memory:promote

```markdown
---
description: Distill valuable learnings from execution trace into structured findings.
---

Promote learnings from the current execution trace.

1. Read memory/trace.md. If empty, say there's nothing to promote.

2. Analyze the trace. Identify entries that contain:
   - Error encounters and solutions → type EF
   - Configuration decisions that worked → type CP
   - Physical insights → type PI
   - Workflow efficiency improvements → type WF
   - Environment/setup fixes → type EV

3. For each learning, propose a structured finding with:
   - Title, Scope (@project or @domain), Type
   - Layer: Is this foundation (applies regardless of application domain)
     or specialist (only applies to a specific application area)?
     Ask yourself: "Would this be useful to someone doing a completely different
     type of simulation?" If yes → foundation. If no → specialist.
   - Validation Level: Ask four progressive questions:
     (a) Did the program run without crashing? → syntax
     (b) Did the solution converge? (residuals, conservation) → numerical
         ⚠️ Always note: "convergence does not guarantee correctness"
     (c) Was result compared against experimental/analytical data? → physical
         Record: what quantity, error range, data source
     (d) Validated across multiple different case types? → methodology
     Most findings start at syntax or numerical. This is normal.
   - Confidence: low/medium/high

4. Ask the user to confirm, modify, or skip each proposal.

5. For confirmed findings, check for duplicates:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/promote.sh" "$(pwd)" --check-dedup "<title>" "<tags>"
   ```
   If duplicates found, present: merge_into / supersede / keep_both / skip.

6. Create the finding:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/promote.sh" "$(pwd)" --create "<json_payload>"
   ```

7. Rebuild index:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/util/index-rebuild.sh" "$(pwd)/memory/findings"
   ```
```

### 8.4  /hcc-memory:complete

```markdown
---
description: Complete the current task. Archives trace, reviews findings for wisdom upgrade. Usage: /hcc-memory:complete <summary>
---

Complete the current task: $ARGUMENTS

1. Run:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/complete.sh" "$(pwd)" "$ARGUMENTS"
   ```

2. Scan findings/ for L3 upgrade candidates. A finding qualifies if ANY:
   - verified_in has ≥ 2 different cases
   - verified_in ≥ 1 case AND Evidence cites external reference
   - Type WF, used multiple times, no known_failures
   - Type PI, has simulation + literature dual evidence

   ADDITIONALLY, the finding must meet the minimum validation_level for its type:
   - EF (error-fix): minimum syntax (error gone = fix works)
   - CP (config pattern): minimum numerical, strongly recommended physical
     ⚠️ A config that "only converges but isn't verified correct" should NOT
     enter wisdom — it creates false confidence for future users
   - PI (physical insight): MUST be physical (no physical validation = just a guess)
   - WF (workflow): minimum numerical
   - EV (environment): minimum syntax

3. For each candidate, ask user to confirm upgrade.

4. Execute confirmed upgrades:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/complete.sh" "$(pwd)" --upgrade "<finding_id>"
   ```

5. Display summary: tasks completed, findings created this session, wisdom entries added.
```

### 8.5  /hcc-memory:recover

```markdown
---
description: Recover context after a session break.
---

Recover context for the current project.

Run:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/recover.sh" "$(pwd)"
```

The script outputs (within configured token budget):
1. Current task plan (tasks/_active.md)
2. Last 10 trace entries
3. findings/_index.md summary
4. wisdom/_index.md summary (if exists)

Present this as a structured briefing. Then ask: "Ready to continue?"
```

### 8.6  /hcc-memory:search

```markdown
---
description: Search memory for relevant findings and wisdom. Usage: /hcc-memory:search <keywords>
---

Search project memory for: $ARGUMENTS

Run:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/search.sh" "$(pwd)" "$ARGUMENTS"
```

Display results (max 5). Priority order:
1. wisdom/ active entries
2. findings/ active entries
3. stale entries (marked [stale])

For each result, show: ID, status, validation_level, title, tags, confidence, file path.
Use these markers for validation_level:
- syntax: [syntax]
- numerical: [numerical⚠️] — append note: "convergence verified, physics unverified"
- physical: [physical✓]
- methodology: [methodology✓✓]

If a finding was useful and applied, update its timestamp:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/touch.sh" "$(pwd)" "<id>"
```
```

### 8.7  /hcc-memory:status

```markdown
---
description: Show current memory system status.
---

Run:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh" "$(pwd)"
```

Display the output showing: active task, action count, trace stats,
findings count by status, wisdom count, sessions archived.
```

### 8.8  /hcc-memory:compact

```markdown
---
description: Audit memory for redundancy. Generates report. Does NOT auto-modify.
---

Run:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/compact.sh" "$(pwd)"
```

Display the audit report. For each suggested action, ask user to confirm.
Execute confirmed actions:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/compact.sh" "$(pwd)" --apply "<action_json>"
```

CRITICAL: compact NEVER rewrites entry body content. Only modifies front matter.
```

### 8.9  /hcc-memory:export

```markdown
---
description: Export domain-scoped findings for potential knowledge base contribution.
---

Run:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/export.sh" "$(pwd)" $ARGUMENTS
```

Filters: scope=domain, status=active.
Checks: Evidence and Failure Boundary must exist.
Sanitizes: removes paths, usernames, hostnames.
Outputs to memory/_export/.

Show what was exported and what was skipped with reasons.
```

---

## 9  Skill

### skills/memory-workflow/SKILL.md

```markdown
---
name: memory-workflow
description: "Manages project-level memory using HCC. Activates when: project has memory/ directory,
  encountering errors, making configuration decisions, discovering insights, completing tasks,
  or resuming after a break."
---

# HCC Memory Workflow

You are working in a project with the HCC memory system (memory/ directory exists).

## 5-Action Rule (MANDATORY)
After every 5 tool uses, update the trace:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/log-trace.sh" "$(pwd)" "<brief summary>"
```
This is not optional. Forgetting causes permanent context loss.

## When You Encounter an Error
BEFORE trying to fix it yourself:
1. Search memory:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/search.sh" "$(pwd)" "<error keywords>"
   ```
2. If match found, read and apply it. Then mark usage:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/touch.sh" "$(pwd)" "<id>"
   ```
3. If no match, solve it yourself. Then suggest /hcc-memory:promote.

## Memory Priority (when multiple results)
1. wisdom/ entries (triple-verified, highest authority)
2. findings/ active entries (project experience)
3. findings/ stale entries (may be outdated)
Prefer the entry with more specific applicability matching current situation.

## Validation Level Awareness (CRITICAL)
When you search memory and find a result, CHECK its validation_level:
- `syntax`: This fix stopped an error. Safe to apply for the same error.
- `numerical`: This config achieved convergence. ⚠️ ALWAYS tell the user:
  "This configuration was verified for numerical convergence only, not for
  physical correctness. Consider comparing results against experimental data
  or a known benchmark after applying."
- `physical`: This was validated against external data. Higher confidence.
- `methodology`: Cross-case validated approach. Highest confidence.

NEVER treat a numerical-level finding as if it were physical-level.
The most dangerous Agent is one that confidently applies configurations
that "converge nicely" but produce wrong physics.

## After a Simulation Completes
Do NOT just check "did it finish without error." Also evaluate:
1. **Convergence quality**: Are residuals truly converged or just oscillating?
   Are conservation errors acceptable? Did any monitors plateau?
2. **Physical plausibility**: Do the results make qualitative sense?
   Is there flow where expected? Are magnitudes reasonable?
3. **Quantitative validation** (if reference data available):
   Compare key quantities against experimental/analytical benchmarks.
   Record what was compared, the error range, and the data source.

These post-run evaluations are the raw material for physical-level memories.
Suggest /hcc-memory:promote if any significant findings emerge from this evaluation.

## When to Suggest /hcc-memory:promote
After solving a non-trivial error, making a configuration choice that required experimentation,
discovering something about physical behavior, or finding a workflow improvement.
ALSO after completing a post-run evaluation that revealed insights about result quality.

## Layer Judgment (during promote)
- Foundation: would this help someone doing a COMPLETELY DIFFERENT type of simulation?
  If yes → foundation.
- Specialist: is this specific to a particular application domain (e.g., turbomachinery,
  chip cooling, external aero)? If yes → specialist, and note the specialist_area.
```

---

## 10  Hooks

### hooks/hooks.json

```json
{
  "PostToolUse": [
    {
      "matcher": "Write|Edit|Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hooks/action-counter.sh",
          "timeout": 5
        }
      ]
    }
  ],
  "SessionStart": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh",
          "timeout": 5
        }
      ]
    }
  ]
}
```

**action-counter.sh**: Checks for memory/ dir → increments state.json counter → if count % 5 == 0, outputs reminder to stdout.

**session-start.sh**: Checks for memory/ and tasks/_active.md → if found, outputs recovery prompt.

---

## 11  Scripts Implementation Notes

### 11.1  Cross-platform (scripts/util/platform.sh)

```bash
_sed_inplace() {
  if sed --version 2>/dev/null | grep -q GNU; then sed -i "$@"
  else sed -i '' "$@"; fi
}

_sha256() {
  if command -v sha256sum &>/dev/null; then echo -n "$1" | sha256sum | cut -c1-6
  else echo -n "$1" | shasum -a 256 | cut -c1-6; fi
}

_date_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
```

### 11.2  Front Matter (scripts/util/frontmatter.sh)

Only handles restricted YAML: single-line `key: value` and `key: [a, b, c]`.
No nested objects. No multi-line values.

### 11.3  Dependencies

Required: Bash ≥ 4.0, coreutils (sed, awk, grep, date), jq ≥ 1.6.
If jq unavailable, state.json falls back to plain text key=value format.

---

## 12  Templates

### templates/finding-entry.md.tmpl

```markdown
---
schema_version: 1
id: {{ID}}
title: "{{TITLE}}"
scope: {{SCOPE}}
type: {{TYPE}}
layer: {{LAYER}}
specialist_area: "{{SPECIALIST_AREA}}"
domain: {{DOMAIN}}
tags: [{{TAGS}}]
status: active
created_at: "{{DATE}}"
updated_at: "{{DATE}}"
confidence: {{CONFIDENCE}}
validation_level: {{VALIDATION_LEVEL}}
related_to: []
supersedes: []
valid_solver: "{{SOLVER}}"
valid_versions: ""
valid_regime: []
valid_models: []
valid_geometry: []
verified_by: ["{{CONTRIBUTOR}}"]
verified_in: ["{{CASE_NAME}}"]
known_failures: []
---

## Problem
{{PROBLEM}}

## Action
{{ACTION}}

## Root Cause


## Evidence


## Validation

- **Syntax**:
- **Numerical**:
- **Physical**:
- **Methodology**:

## Applicability


## Failure Boundary

```

---

## 13  Development & Testing Workflow

### For Wei (developer)

```bash
# 1. Develop the plugin locally
mkdir hcc-memory && cd hcc-memory
# ... create files per this spec

# 2. Test with Claude Code
cd /path/to/test-project
claude --plugin-dir /path/to/hcc-memory
# Then: /hcc-memory:init → /hcc-memory:plan → work → /hcc-memory:promote → /hcc-memory:complete

# 3. Push to GitHub
cd /path/to/hcc-memory
git init && git add . && git commit -m "v0.1.0"
git push

# 4. Test installation
# In Claude Code: /plugin install hcc-memory
```

### Automated Tests

Each test creates a temp directory, runs scripts, asserts file existence and content.
CI runs on Ubuntu + macOS.

---

## 14  Implementation Roadmap

### Round 1: Skeleton + Basic Flow (init → plan → log → status)

1. Create plugin structure: `.claude-plugin/plugin.json`, directory layout
2. Implement `scripts/util/platform.sh`
3. Implement `scripts/util/frontmatter.sh`
4. Implement `scripts/init-memory.sh` + `commands/init.md`
5. Implement `scripts/plan.sh` + `commands/plan.md`
6. Implement `scripts/log-trace.sh` (with rolling window)
7. Implement `hooks/hooks.json` + `scripts/hooks/action-counter.sh` + `session-start.sh`
8. Implement `scripts/status.sh` + `commands/status.md`
9. Create all `templates/*.tmpl`
10. Write `tests/test-init.sh` + `tests/test-plan-log.sh`
11. End-to-end test with `claude --plugin-dir`

### Round 2: Memory Loop (promote → complete → search → recover)

12. Implement `scripts/util/fingerprint.sh`
13. Implement `scripts/util/dedup.sh`
14. Implement `scripts/promote.sh` + `commands/promote.md`
15. Implement `scripts/util/index-rebuild.sh`
16. Implement `scripts/complete.sh` + `commands/complete.md`
17. Implement `scripts/search.sh` + `commands/search.md`
18. Implement `scripts/touch.sh`
19. Implement `scripts/recover.sh` + `commands/recover.md`
20. Create `skills/memory-workflow/SKILL.md`
21. Write remaining tests
22. End-to-end full workflow test

### Round 3: Governance + Export + Ship

23. Implement `scripts/doctor.sh`
24. Implement `scripts/compact.sh` + `commands/compact.md`
25. Implement `scripts/util/sanitize.sh`
26. Implement `scripts/export.sh` + `commands/export.md`
27. Implement `scripts/validate.sh`
28. Write `README.md`
29. Add `LICENSE` (MIT)
30. Configure `.github/workflows/ci.yml`
31. Push to GitHub, test installation

### Phase 2+ (out of MVP scope)

- Knowledge base packages (foundation + specialist)
- `hcc pull` to install knowledge packages into `memory/knowledge/`
- `hcc push` to contribute validated wisdom to community
- Search integration: search knowledge/ alongside findings/ and wisdom/
- Adapter layers for Cursor (.cursorrules), Codex (AGENTS.md), etc.
