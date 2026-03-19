# ChatCFD HCC Memory System

基于 HCC（Hierarchical Cognitive Caching）三层记忆架构的项目级记忆系统，专为 ChatCFD 仿真工作流设计。**Agent 无关**：核心记忆机制通过 Markdown + Bash 实现，适用于 Claude Code、Cursor、Codex 及任何能读文件、跑终端的编程智能体。

---

## 架构总览

```
                    ┌─────────────────────────────────┐
                    │         CLAUDE.md                │
                    │   (项目上下文 — 自动加载)         │
                    │   • 当前目标 & 状态               │
                    │   • ChatCFD Skill 入口            │
                    │   • 记忆文件指针                   │
                    │   • 5-Action Rule                 │
                    └──────────┬──────────────────────┘
                               │ Agent 启动时读取
                    ┌──────────▼──────────────────────┐
                    │        Memory Layers             │
                    │                                  │
                    │  L1 execution_trace.md           │
                    │  ──────────────────────          │
                    │  实时动作日志、错误记录、会话摘要     │
                    │  更新频率: 每5次工具调用             │
                    │           │                      │
                    │           │ promote (P1)         │
                    │           ▼                      │
                    │  L2 findings.md + task_plan.md   │
                    │  ──────────────────────          │
                    │  验证过的错误修复对、收敛模式、       │
                    │  物理洞察、验证过的配置方案          │
                    │  更新频率: 关键突破时               │
                    │           │                      │
                    │           │ complete (P2)        │
                    │           ▼                      │
                    │  L3 wisdom/ 目录                  │
                    │  ──────────────────────          │
                    │  通过三角验证的永久知识              │
                    │  更新频率: 任务完成时               │
                    └─────────────────────────────────┘
```

### 核心设计原则

| 原则 | 实现方式 |
|------|---------|
| 防止信息丢失 | 5-Action Rule 强制定期外化 L1 |
| 空间换时间 | CLAUDE.md 不检测需求，直接提供全部指针 |
| 知识质量保障 | L3 需三角验证（物理机制 + 权威参考 + 自有验证） |
| 轻量可维护 | 纯 Markdown + Bash，无数据库依赖 |
| Agent 无关 | 记忆脚本是普通 Bash，任何 Agent 都能调用 |

---

## 文件结构

```
project-root/
├── CLAUDE.md                        # 项目上下文（Claude Code / 通用）
├── .cursorrules                     # Cursor 自动读取（由 setup.sh 生成）
├── AGENTS.md                        # Codex 自动读取（由 setup.sh 生成）
│
├── skills/                          # 项目级 Skills（与项目一起版本管理）
│   └── chatcfd/
│       ├── SKILL.md                 # Skill 文档（Agent 读此文件了解如何调用）
│       ├── scripts/                 # run_cli.sh, check_env.sh
│       ├── src/                     # runner.py, mesh_utils.py, ...
│       └── database_OFv24/          # 求解器/湍流模型知识库 JSON
│
├── memory/                          # HCC 三层记忆（Agent 无关）
│   ├── execution_trace.md           # L1: 工作记忆（实时日志）
│   ├── findings.md                  # L2: 提炼知识（验证过的经验）
│   ├── task_plan.md                 # L2: 战略记忆（目标与计划）
│   └── wisdom/                      # L3: 永久智慧
│       ├── README.md                # L3 格式模板与三角验证说明
│       └── W-001_xxx.md             # (由 complete 命令生成)
│
├── scripts/                         # 记忆管理脚本（Agent 无关的 Bash）
│   ├── setup.sh                     # 安装验证 + 多 Agent 配置生成
│   ├── init-session.sh              # plan 后端
│   ├── promote.sh                   # promote 后端
│   ├── task-complete.sh             # complete 后端
│   └── recover.sh                   # recover 后端
│
└── .claude/                         # Claude Code 专用（可选）
    ├── settings.json                # Hooks（5-Action Rule 自动提醒）
    └── commands/                    # 斜杠命令 /plan /promote /complete /recover /status
```

**关键设计决策：Skills 放在项目内部（`skills/`）而非全局位置（`~/.openclaw/`）。** 这意味着 Skill 跟随项目版本管理，不同项目可以有不同版本的 Skill，且在 Codex/Cursor 等没有全局 Skill 概念的 Agent 中同样可用。

---

## 安装

### Step 1：将文件放入项目根目录

```bash
cd /path/to/your/project
tar xzf chatcfd-hcc-memory.tar.gz --strip-components=1
```

### Step 2：将 ChatCFD Skill 实现复制到项目内

```bash
# 如果你之前的 Skill 在全局位置：
cp -r ~/.openclaw/skills/chatcfd/scripts skills/chatcfd/
cp -r ~/.openclaw/skills/chatcfd/src skills/chatcfd/
cp -r ~/.openclaw/skills/chatcfd/database_OFv24 skills/chatcfd/

# 或者如果你有 ChatCFD 的 Git 仓库：
# cp -r /path/to/chatcfd-repo/{scripts,src,database_OFv24} skills/chatcfd/
```

### Step 3：运行安装检查

```bash
bash scripts/setup.sh          # 默认：为所有 Agent 生成配置
bash scripts/setup.sh claude   # 仅检查 Claude Code
bash scripts/setup.sh cursor   # 仅生成 .cursorrules
bash scripts/setup.sh codex    # 仅生成 AGENTS.md
```

---

## 多 Agent 支持

### Claude Code

开箱即用。CLAUDE.md 自动加载，`.claude/commands/` 提供斜杠命令，`.claude/settings.json` 中的 Hook 实现 5-Action Rule 自动提醒。

```
/plan "Run VKI LS89 cascade"     ← 斜杠命令（Claude Code 专属）
```

### Cursor

运行 `bash scripts/setup.sh cursor` 生成 `.cursorrules`。Cursor 会自动读取该文件。记忆命令通过终端手动调用：

```bash
bash scripts/init-session.sh . "Run VKI LS89 cascade"   # 等价于 /plan
bash scripts/promote.sh .                                 # 等价于 /promote
bash scripts/task-complete.sh . "LS89 done"              # 等价于 /complete
bash scripts/recover.sh .                                 # 等价于 /recover
```

Cursor 没有 Hook 机制，5-Action Rule 需要在 `.cursorrules` 的提示词中靠 Agent 自律执行。

### OpenAI Codex

运行 `bash scripts/setup.sh codex` 生成 `AGENTS.md`。Codex 会自动读取该文件。记忆命令与 Cursor 相同——通过终端调用 Bash 脚本。

### 其他 Agent

任何能读取项目文件并执行 Bash 命令的 Agent 都可以使用本系统。只需让 Agent 在启动时读取 `CLAUDE.md`（作为项目上下文的通用约定文件名），然后按其中的规则行事即可。

---

## 使用工作流

### 开始新任务

```bash
bash scripts/init-session.sh . "Run VKI LS89 turbine cascade: mesh generation, OpenFOAM solve, validate against experimental data"
```

### 工作过程中

Agent 遵循 CLAUDE.md 中的规则：5-Action Rule 定期更新 L1，遇到错误先搜索 L2 已知修复方案。

### 关键突破时

```bash
bash scripts/promote.sh .
```

Agent 审查 L1 内容，将验证过的经验分类（T/N/P/R）写入 findings.md（L2）。

### 会话中断后恢复

```bash
bash scripts/recover.sh .
```

### 任务完成时

```bash
bash scripts/task-complete.sh . "VKI LS89 benchmark case completed"
```

归档 L1，对 L2 中每条记忆做三角验证，够格的提升到 wisdom/（L3）。

---

## 与 ChatCFD Skill 的集成

Skill 和 Memory 是两个独立但协作的系统：

```
skills/chatcfd/（项目级 Skill）
├── 提供: 网格转换、边界提取、CFL设置、错误诊断、必需文件查找
├── 输出: 结构化 JSON（边界信息、错误分析）
└── 角色: 确定性操作的执行引擎

memory/（HCC 记忆）
├── 消费: ChatCFD 输出的结构化数据作为 L1 素材
├── 积累: 跨会话的错误修复经验、收敛模式、物理洞察
└── 角色: 跨会话的认知积累与经验复用

CLAUDE.md
└── 连接两者: 指向 Skill 入口 + 指向 Memory 文件
```

典型协作流程：Agent 调用 `skills/chatcfd/scripts/run_cli.sh` → 报错 → 调用 `--analyze-error-log` 获取结构化诊断 → 搜索 `memory/findings.md` 匹配已知修复 → 命中则直接应用（记忆复用），否则推理修复后 promote 到 L2（学习闭环）。

---

## 自定义与扩展

### 修改 5-Action Rule 频率

编辑 `.claude/settings.json` 中的 `COUNT % 5` 为其他数字。对于 Cursor/Codex，修改 `.cursorrules` 或 `AGENTS.md` 中的提示文本。

### 添加新的 Skills

在 `skills/` 下创建新目录（如 `skills/su2-runner/`），包含 `SKILL.md` 和实现文件。在 `CLAUDE.md` 的 Skill 段落中添加指针。

### 添加 Claude Code 斜杠命令

在 `.claude/commands/` 下创建 `.md` 文件。文件名即命令名，内容是给 Agent 的指令。

### 扩展到其他求解器

findings.md 的 Tags 系统支持按求解器过滤。添加 SU2 相关记忆时使用 `#su2` tag，OpenFOAM 使用 `#openfoam`。

---

## 已知局限

1. **CLAUDE.md 大小**：内容在每次 context window 中占用固定 token。保持简洁（当前约 40 行），只放指针不放详细内容。

2. **findings.md 增长**：条目超过 50 条时，建议将低频旧条目归档到 `memory/archive/`。

3. **无自动 Context Hit**：采用"空间换时间"策略——CLAUDE.md 告诉 Agent 所有文件在哪里，让 Agent 自己决定读什么。

4. **Hook 仅限 Claude Code**：`.claude/settings.json` 中的 5-Action Rule Hook 是 Claude Code 专属能力。Cursor/Codex 中需靠提示词让 Agent 自律执行。

5. **L3 提升需人工审核**：三角验证的判断由 Agent（在人的监督下）完成，不完全自动化。这是有意设计——错误的 L3 知识会导致级联错误。
