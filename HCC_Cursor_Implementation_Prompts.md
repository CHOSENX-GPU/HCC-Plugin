# HCC Memory Plugin — Cursor 实施提示词

> 使用方式：将每个 Round 的提示词完整复制到 Cursor 的对话框中执行。
> 每个 Round 完成后，手动测试确认无误，再执行下一个 Round。
> 测试方法：`cd /path/to/test-project && claude --plugin-dir /path/to/HCC-Plugin`

---

## Round 1 提示词：骨架 + 基础流程（init → plan → log → status）

```
请阅读本项目中的 HCC_Memory_Plugin_Spec_Final.md 文件，这是完整的设计规格文档。
你的任务是实现 Round 1：Plugin 骨架和基础工作流。

本项目就是 Plugin 本身（根目录 = Plugin 根目录）。请严格按照 Spec 中第 3 节的目录结构创建所有文件和目录。以下是 Round 1 需要完成的全部任务，请按顺序逐一实现。

### 任务 1：创建 Plugin 基础结构

创建 .claude-plugin/plugin.json，内容见 Spec 第 4 节。
创建所有需要的目录：commands/、skills/、hooks/、scripts/、scripts/hooks/、scripts/util/、templates/、tests/。
创建 LICENSE 文件（MIT 协议）。
创建空的 CHANGELOG.md。

### 任务 2：实现 scripts/util/platform.sh

这是跨平台兼容层，所有其他脚本都会 source 它。需要实现三个函数：

_sed_inplace()：处理 GNU sed（Linux）和 BSD sed（macOS）的 -i 参数差异。
_sha256()：处理 sha256sum（Linux）和 shasum -a 256（macOS）的差异，输出前 6 位十六进制。
_date_iso()：输出 UTC ISO 格式时间戳。

另外添加一个 _project_root() 函数：从传入的路径向上查找包含 memory/ 或 .hcc/ 的目录，找到即返回，找不到则返回空。

### 任务 3：实现 scripts/util/frontmatter.sh

处理受限的 YAML front matter 子集（只支持单行 key: value 和单行数组 key: [a, b, c]，不支持嵌套）。需要实现：

_fm_get "$file" "$key"：从文件的 front matter（两个 --- 之间）中读取指定 key 的值并输出。
_fm_set "$file" "$key" "$value"：更新 front matter 中指定 key 的值。如果 key 不存在，在结束的 --- 之前插入新行。
_fm_keys "$file"：列出 front matter 中所有 key。

注意：front matter 的范围是文件开头的第一个 --- 和第二个 --- 之间。文件可能在 front matter 之后有正文内容，不能被破坏。

### 任务 4：实现 scripts/init-memory.sh

接收参数：$1 = 项目路径，$2 = domain（默认 "general"），$3 = specialist（默认 ""）。

行为：
- 检查 $1/memory/ 是否已存在。如果存在，输出警告 "HCC memory already initialized in this project" 到 stderr 并以非零状态退出。
- 创建完整的目录结构：memory/findings/、memory/wisdom/、memory/tasks/、memory/sessions/、memory/_export/、memory/knowledge/（含 .gitkeep）。
- 创建 memory/findings/_index.md 和 memory/wisdom/_index.md（空索引，只含标题和 auto-generated 注释）。
- 创建 .hcc/config.yaml（使用 Spec 第 7 节的模板，将 project.name 设为目录名，domain 和 specialist 用传入参数填充）。
- 创建 .hcc/state.json：{"action_count": 0, "active_task": null, "last_promote": null}
- 如果 .gitignore 存在，追加 Spec 第 5 节中列出的 gitignore 条目（先检查是否已存在，避免重复追加）。
- 输出成功信息到 stdout。

### 任务 5：实现 commands/init.md

这是斜杠命令定义文件。请严格按照 Spec 第 8.1 节的内容创建。注意：
- 文件开头必须有 YAML front matter（--- 包围），包含 description 字段。
- 正文是给 Claude 看的自然语言指令，告诉它调用哪个脚本、怎么和用户交互。
- 脚本路径使用 ${CLAUDE_PLUGIN_ROOT} 变量。

### 任务 6：实现 scripts/plan.sh

接收参数：$1 = 项目路径，$2 = 任务描述。

行为：
- source platform.sh。
- 检查 memory/tasks/_active.md 是否存在且非空。如果存在，输出 "Active task already exists: <任务标题>" 到 stderr 并退出（退出码 1）。如果传入了 --force 作为第三个参数，则将当前 _active.md 归档到 tasks/T-{YYYY-MM-DD}-{简化描述}.md 后继续。
- 创建 memory/tasks/_active.md，内容参照 Spec 中 templates/task-active.md.tmpl。
- 初始化（或清空并重写）memory/trace.md，写入 trace 头部（Task 描述 + Session started 时间戳）。
- 更新 .hcc/state.json：action_count 归零，active_task 设为任务描述。
- 输出成功信息。

### 任务 7：实现 commands/plan.md

按 Spec 第 8.2 节创建。

### 任务 8：实现 scripts/log-trace.sh

接收参数：$1 = 项目路径，$2 = 简述文本。可选地从 stdin 读取详细内容。

行为：
- source platform.sh。
- 读取 .hcc/state.json 中的 action_count 并加 1，写回。
- 在 memory/trace.md 末尾追加一个 Action 块：## [{HH:MM}] Action-{N} — {简述}\n{stdin内容如果有}
- 检查 trace.md 是否超出滚动窗口阈值（从 .hcc/config.yaml 中读取 trace_max_entries 和 trace_max_bytes，默认 30 条和 12288 字节）。如果超出，将最早的 Action 块切出，归档到 memory/sessions/S-{YYYY-MM-DD-HHMM}.md。重复此操作直到文件回到阈值以内。
- 实现切分逻辑时注意：每个 Action 块以 "## [" 开头，直到下一个 "## [" 或文件末尾。trace.md 开头的 header（# Execution Trace + > Task: + > Session started:）不计入 Action 块数量，也不应被归档。

### 任务 9：实现 hooks/hooks.json 和 scripts/hooks/action-counter.sh、session-start.sh

hooks.json 内容见 Spec 第 10 节。

action-counter.sh：
- 检查当前工作目录下是否有 memory/ 目录，没有则静默退出（exit 0）。
- 读取 .hcc/state.json 的 action_count，加 1，写回。
- 如果 action_count 能被 flush_interval（从 config.yaml 读取，默认 5）整除且 > 0，输出到 stdout："⚠️ [HCC] 5-Action Rule: Time to update trace. Describe your recent work or run /hcc-memory:log."
- 注意：这个脚本需要非常快（timeout 5 秒），不要做任何耗时操作。

session-start.sh：
- 检查当前工作目录下是否有 memory/ 目录，没有则静默退出。
- 如果 memory/tasks/_active.md 存在且非空，输出："📋 [HCC] Active task detected. Run /hcc-memory:recover to restore context."

### 任务 10：实现 scripts/status.sh 和 commands/status.md

status.sh 接收 $1 = 项目路径。输出格式见 Spec 第 8.7 节。需要统计：
- active_task：从 .hcc/state.json 或 memory/tasks/_active.md 读取。
- action_count：从 state.json 读取，以及 flush_interval 的对比。
- trace 统计：trace.md 中 Action 块数量和文件大小。
- findings 统计：memory/findings/ 下 .md 文件数量（排除 _index.md），按 status 分组统计（需要读取每个文件的 front matter status 字段）。
- wisdom 统计：memory/wisdom/ 下 .md 文件数量（排除 _index.md）。
- sessions 统计：memory/sessions/ 下文件数量。

### 任务 11：创建 templates/

创建四个模板文件：
- finding-entry.md.tmpl：内容见 Spec 第 12 节，用 {{PLACEHOLDER}} 占位符。
- wisdom-entry.md.tmpl：与 finding-entry.md.tmpl 相同，但 ID 前缀为 W- 而非 F-。
- trace-header.md.tmpl：trace.md 的初始头部内容。
- task-active.md.tmpl：_active.md 的模板内容。

### 任务 12：创建 tests/helpers.sh 和 tests/test-init.sh、tests/test-plan-log.sh

helpers.sh 提供测试辅助函数：
- setup_test()：创建临时目录，设置 PLUGIN_ROOT 指向项目根目录，设置 TEMP_DIR。
- cleanup_test()：删除临时目录。
- assert_file_exists "$path"：检查文件存在，不存在则报错并退出。
- assert_dir_exists "$path"：检查目录存在。
- assert_file_contains "$path" "$string"：检查文件包含指定字符串。
- assert_exit_code "$expected" "$actual"：检查退出码。

test-init.sh：
- 测试正常初始化：在空目录中运行 init-memory.sh，验证所有目录和文件被创建。
- 测试重复初始化：第二次运行应失败并输出警告。
- 测试 config.yaml 内容：domain 和 specialist 应与传入参数匹配。

test-plan-log.sh：
- 先运行 init-memory.sh 初始化。
- 运行 plan.sh，验证 _active.md 和 trace.md 被创建。
- 运行 log-trace.sh 多次，验证 trace.md 内容正确追加。
- 运行 log-trace.sh 超过 30 次（或设置较小的 trace_max_entries 来测试），验证滚动窗口归档到 sessions/ 的逻辑。

### 完成标准

所有上述文件创建完毕后，请运行 tests/ 中的测试脚本确认通过。然后给我一个总结，列出所有创建的文件和它们的职责。

### 重要注意事项

- 所有 Bash 脚本开头必须有 #!/usr/bin/env bash 和 set -euo pipefail。
- 所有脚本中引用其他脚本时使用 ${CLAUDE_PLUGIN_ROOT} 或通过相对于脚本自身位置的路径计算（SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"）。在非 plugin 环境下测试时，CLAUDE_PLUGIN_ROOT 可能未设置，脚本应能从自身位置推断出 plugin 根目录。
- jq 用于读写 state.json。如果 jq 不可用，可以暂时用简单的 grep/sed 处理 JSON（但在注释中标注 "TODO: proper jq fallback"）。
- 不要使用 GNU-specific 的 sed/awk/grep 特性。所有文件操作通过 platform.sh 中的兼容函数进行。
```

---

## Round 2 提示词：记忆闭环（promote → complete → search → recover → skill）

```
请阅读本项目中的 HCC_Memory_Plugin_Spec_Final.md 文件（特别是第 6 节 Schema、第 8.3-8.6 节 Commands、第 9 节 Skill）。
Round 1 已经完成，项目中已有可用的 init、plan、log、status 命令和基础 scripts/util/ 工具。
你的任务是实现 Round 2：记忆提炼、搜索、恢复的完整闭环。

### 任务 12：实现 scripts/util/fingerprint.sh

提供 _generate_id() 函数。接收参数：prefix（F 或 W）、domain_code（OF/SU2/FL/GEN 等）、type（EF/CP/PI 等）、title（标题文本）。

算法：
1. 构造原始字符串：lowercase(domain + "|" + type + "|" + title)
2. 计算 SHA256 并截取前 6 位十六进制字符（调用 platform.sh 中的 _sha256）
3. 组合 ID：{prefix}-{domain_code}-{type}-{hash6}
4. 返回生成的 ID

同时提供 _domain_to_code() 函数，将 config.yaml 中的 domain 值映射为 ID 中的短代码：
openfoam → OF，su2 → SU2，fluent → FL，general → GEN。其他值取前 3 个字母大写。

另外提供 _check_id_collision() 函数：接收 directory 和 id，检查目录下是否已有同名文件。如果有，自动追加 -2、-3 后缀直到不冲突，返回最终的唯一 ID。

### 任务 13：实现 scripts/util/dedup.sh

提供 _find_similar_entries() 函数。接收参数：search_dir（findings/ 或 wisdom/ 目录路径）、type、tags（逗号分隔的标签列表）。

算法：
1. 遍历 search_dir 中所有 .md 文件（排除 _index.md）
2. 对每个文件，读取 front matter 中的 type 和 tags
3. 如果 type 完全匹配，且 tags 交集 ≥ 2 个，则视为"疑似重复"
4. 输出所有疑似重复条目的 ID 和 title（每行一个，格式：ID|title|tags）

tags 交集的计算：将两组 tags 都转为小写，逐一比较。

### 任务 14：实现 scripts/promote.sh

这是最复杂的脚本，支持两种模式。

模式一：--check-dedup "$title" "$tags"
调用 dedup.sh 的 _find_similar_entries()，在 findings/ 和 wisdom/ 中查找疑似重复。
将结果输出到 stdout（格式：每行一个 ID|title|tags），如果没有重复则输出空。

模式二：--create "$json_payload"
json_payload 是一个 JSON 字符串（或临时文件路径），包含所有 finding 字段值。
脚本的职责是：
1. 从 json_payload 中提取所有字段（用 jq 解析）。
2. 调用 fingerprint.sh 生成 ID。
3. 检查 ID 冲突（调用 _check_id_collision）。
4. 读取 templates/finding-entry.md.tmpl，将所有 {{PLACEHOLDER}} 替换为实际值。
5. 将生成的文件写入 memory/findings/{ID}.md。
6. 输出成功信息和文件路径。

关于 json_payload 的格式，至少包含这些字段：
title, scope, type, layer, specialist_area, domain, tags, validation_level, confidence, problem, action, contributor, case_name

对于 tags 字段，在 JSON 中是数组，写入 YAML front matter 时转为 [tag1, tag2, tag3] 格式。

### 任务 15：实现 commands/promote.md

严格按 Spec 第 8.3 节创建。这个命令的核心逻辑是由 Claude 自己执行的（分析 trace、提议 finding、判断 scope/type/layer/validation_level），脚本只负责去重检查和文件创建。
注意 Spec 中 promote 命令包含 validation_level 的四个递进问题判断流程，这些必须完整写入 command 定义中。

### 任务 16：实现 scripts/util/index-rebuild.sh

接收参数：$1 = 要重建索引的目录路径（如 memory/findings/ 或 memory/wisdom/）。

行为：
1. 遍历目录中所有 .md 文件（排除 _index.md）
2. 对每个文件读取 front matter 中的 id、status、type、title、tags、confidence、validation_level
3. 按 type 分组
4. 每组内按 status 排序：active > stale > deprecated > archived
5. 生成 _index.md，格式参照 Spec 第 13 节。每条记录包含 validation_level 标记（⚠️ 或 ✓）。
6. 写入 _index.md（覆盖旧内容）

### 任务 17：实现 scripts/complete.sh

接收参数：$1 = 项目路径，$2 = 任务总结文本。支持 --upgrade "$finding_id" 模式。

默认模式（无 --upgrade）：
1. 检查 memory/tasks/_active.md 是否存在，不存在则报错退出。
2. 将 memory/trace.md 归档到 memory/sessions/S-{YYYY-MM-DD-HHMM}.md。
3. 重新初始化一个空的 trace.md（只含头部）。
4. 将 memory/tasks/_active.md 重命名为 memory/tasks/T-{YYYY-MM-DD}-{简化描述}.md，并追加完成信息（时间戳 + 总结文本）。
5. 扫描 memory/findings/ 中所有 active 条目，对每个条目输出其 id、type、validation_level、verified_in 列表长度。这个输出供 Claude 读取后判断是否够格升级 L3（判断逻辑在 commands/complete.md 中由 Claude 执行，不在脚本中硬编码）。
6. 更新 .hcc/state.json：清空 active_task，归零 action_count。

--upgrade "$finding_id" 模式：
1. 在 memory/findings/ 中找到该 ID 对应的文件。
2. 将文件复制到 memory/wisdom/，文件名前缀从 F- 改为 W-，front matter 中的 id 也相应修改。
3. 将 findings/ 中的原文件 status 改为 deprecated，添加 supersedes_by 信息（指向新的 wisdom ID）。或者更简单：在原文件 front matter 中将 status 设为 deprecated。
4. 重建 findings/_index.md 和 wisdom/_index.md。

### 任务 18：实现 commands/complete.md

严格按 Spec 第 8.4 节创建。注意其中包含 type-specific validation requirements 矩阵：
EF→syntax, CP→numerical(建议physical), PI→physical(必须), WF→numerical, EV→syntax。
当 finding 满足广度条件但不满足深度条件时，要输出警告而非直接拒绝。

### 任务 19：实现 scripts/search.sh

接收参数：$1 = 项目路径，$2 = 搜索关键词。

行为：
1. 在 memory/findings/ 和 memory/wisdom/ 中搜索。
2. 对每个 .md 文件（排除 _index.md），在 front matter 的 tags 和 title 中搜索关键词，以及在正文的 ## Problem 和 ## Action 区块中搜索关键词。
3. 搜索方式：grep -i（不区分大小写），关键词可以是空格分隔的多个词，任意一个命中即算匹配。
4. 对命中的条目，读取 id、status、title、tags、confidence、validation_level。
5. 排序：wisdom active > findings active > stale。同级别内 validation_level 高的排前面（methodology > physical > numerical > syntax）。
6. 最多输出 5 条。
7. 输出格式参照 Spec 第 8.6 节，包含 validation_level 标记。

### 任务 20：实现 scripts/touch.sh

接收参数：$1 = 项目路径，$2 = entry ID。

行为：
1. 在 memory/findings/ 和 memory/wisdom/ 中查找 ID 匹配的文件（文件名包含 ID）。
2. 更新该文件 front matter 中的 updated_at 为当前时间戳。
3. 如果该条目 status 为 stale，将其恢复为 active。
4. 输出确认信息。

### 任务 21：实现 commands/search.md

按 Spec 第 8.6 节创建。

### 任务 22：实现 scripts/recover.sh 和 commands/recover.md

recover.sh 接收 $1 = 项目路径。

行为：
1. 读取 recover_budget_bytes（默认 8192）from config.yaml。
2. 按优先级依次读取并输出以下内容，一旦总字节数接近预算就停止：
   a. memory/tasks/_active.md 全文（如果存在）
   b. memory/trace.md 的最后 10 个 Action 块
   c. memory/findings/_index.md 全文
   d. memory/wisdom/_index.md 全文（如果存在且预算允许）
3. 每个部分之间用 --- 分隔，开头标注来源文件路径。
4. 将全部内容输出到 stdout。

commands/recover.md 按 Spec 第 8.5 节创建。

### 任务 23：创建 skills/memory-workflow/SKILL.md

严格按照 Spec 第 9 节的完整内容创建。这是整个 plugin 中最重要的文件之一——
它教会 Claude 何时自动使用记忆系统、5-Action Rule 的强制规则、
遇到错误时的搜索-应用流程、仿真完成后的主动结果评估流程、
"收敛≠正确"的警示规则、以及 promote 时的验证层级判断方法。
请完整复制 Spec 中的内容，不要省略任何部分。

### 任务 24：创建 tests/test-promote.sh、test-complete.sh、test-search.sh

test-promote.sh：
- 初始化项目 + plan + 写几条 trace 内容
- 调用 promote.sh --create 创建一个 finding（构造一个 json payload）
- 验证 finding 文件被创建、front matter 字段正确、_index.md 被更新
- 调用 promote.sh --check-dedup 验证去重检测逻辑

test-complete.sh：
- 初始化 + plan + 写 trace + 创建 finding
- 调用 complete.sh
- 验证 trace 被归档到 sessions/、_active.md 被归档到 tasks/、state.json 被重置
- 调用 complete.sh --upgrade 验证 L3 升级逻辑（finding 被复制到 wisdom/，原文件标记 deprecated）

test-search.sh：
- 初始化 + 创建几个不同 type/tags/validation_level 的 findings
- 调用 search.sh 验证搜索命中和排序逻辑
- 验证 touch.sh 更新 updated_at

### 完成标准

所有测试通过后，请给我一个总结。然后我会在一个真实项目中用 claude --plugin-dir 测试完整的 init → plan → (work) → promote → complete → search → recover 流程。
```

---

## Round 3 提示词：治理 + 导出 + 发布准备

```
请阅读 HCC_Memory_Plugin_Spec_Final.md 中第 8.8、8.9 节以及第 11 节的脱敏规则。
Round 1 和 Round 2 已完成，项目中有完整的记忆闭环（init → plan → log → promote → complete → search → recover）。
你的任务是实现 Round 3：治理工具、导出能力、以及发布到 GitHub 所需的一切。

### 任务 25：实现 scripts/doctor.sh

接收参数：$1 = 项目路径。

行为：
1. 检查 Bash 版本 ≥ 4.0、jq 是否可用、必要的 coreutils 命令是否存在。报告缺失的依赖。
2. 检查 memory/ 目录结构完整性（所有预期子目录是否存在）。
3. 遍历 memory/findings/ 和 memory/wisdom/ 中所有 .md 文件：
   a. 验证 front matter 格式（两个 ---、必填字段 id/title/scope/type/status/validation_level/schema_version 是否存在）
   b. 验证必填正文区块（## Problem 和 ## Action 是否存在）
   c. 检查 status 为 active 的条目：如果 updated_at 距今超过 stale_threshold_days（从 config.yaml 读取），将 status 改为 stale 并更新文件
   d. 检查 supersedes 字段引用的 ID 是否在 findings/ 或 wisdom/ 中存在
4. 检查 _index.md 与实际文件列表是否一致。如果不一致，自动重建（调用 index-rebuild.sh）。
5. 检查 .hcc/config.yaml 格式是否合法。
6. 输出报告：N 个文件检查通过，M 个问题发现，K 个条目标记为 stale，索引是否重建。

### 任务 26：实现 scripts/compact.sh 和 commands/compact.md

compact.sh 接收参数：$1 = 项目路径。支持 --apply "$action_json" 模式。

默认模式（审计报告）：
1. 调用 dedup.sh 扫描所有 active findings，找出疑似重复对。
2. 列出所有 stale 条目及其最后使用时间。
3. 列出所有 deprecated 条目及其替代者 ID。
4. 将报告输出到 stdout，格式见 Spec 第 8.8 节。

--apply "$action_json" 模式：
action_json 格式为 {"action": "archive|merge_into|skip", "target_id": "...", "source_id": "..."}
- archive：将 target_id 的 status 设为 archived
- merge_into：将 source_id 的 verified_by/verified_in 合并到 target_id（追加不重复的值），然后将 source_id 标记为 deprecated
- 注意：绝不修改正文内容，只修改 front matter 字段
- 操作完成后重建 _index.md

commands/compact.md 按 Spec 第 8.8 节创建。强调 compact 只生成报告，所有修改需要人工确认。

### 任务 27：实现 scripts/util/sanitize.sh

提供 _sanitize_file() 函数。接收参数：$1 = 源文件路径，$2 = 输出文件路径。

行为（对输出文件执行，不修改源文件）：
1. 第一层——确定性替换：
   - Unix 家目录路径 /home/xxx/ 和 /Users/xxx/ → $HOME/
   - Windows 路径 C:\Users\xxx\ → %USERPROFILE%\
   - 当前主机名 → <hostname>
   - 当前用户名 → <user>
2. 第二层——敏感模式扫描（不替换，只报告行号和匹配内容）：
   - 邮箱地址模式
   - IP 地址模式
   - 内网域名模式（.internal, .local, .corp, .lan）
   - 许可证路径模式
3. 将第一层替换的结果写入输出文件。
4. 将第二层扫描结果输出到 stderr（作为警告）。
5. 返回值：0 = 无敏感模式警告，1 = 有警告需要人工检查。

### 任务 28：实现 scripts/export.sh 和 commands/export.md

export.sh 接收参数：$1 = 项目路径。可选 --id "$id" 指定单个条目导出，否则导出所有符合条件的。

行为：
1. 扫描 memory/findings/ 和 memory/wisdom/ 中的条目。
2. 筛选条件：scope 为 domain，status 为 active。
3. 检查导出门槛（见 Spec 第 8.9 节的 type-specific validation_level 要求）：
   - EF → validation_level ≥ numerical
   - CP → validation_level ≥ physical
   - PI → validation_level ≥ physical
   - WF → validation_level ≥ methodology
   - EV → validation_level ≥ syntax
   不满足的条目跳过，输出跳过原因。
4. 检查 Evidence 和 Failure Boundary 正文区块是否存在且非空。不满足的跳过。
5. 对每个通过筛选的条目：
   a. 复制到临时文件
   b. 调用 sanitize.sh 脱敏
   c. 将脱敏后的文件移到 memory/_export/
6. 输出总结：导出了 N 条，跳过了 M 条（附原因）。

commands/export.md 按 Spec 第 8.9 节创建。

### 任务 29：实现 scripts/validate.sh

接收参数：$1 = 项目路径，可选 $2 = 文件路径或 ID（不指定则检查所有条目）。

行为：
1. 对指定的文件（或 findings/ + wisdom/ 中的所有文件）进行检查：
   a. front matter 是否存在且格式正确（两个 ---）
   b. schema_version 字段是否存在
   c. 必填字段是否存在：id, title, scope, type, status, validation_level
   d. scope 值是否合法（session | project | domain）
   e. type 值是否合法（EF | CP | PI | WF | EV | CN）
   f. status 值是否合法（active | stale | archived | deprecated）
   g. validation_level 值是否合法（syntax | numerical | physical | methodology）
   h. 必填正文区块 ## Problem 和 ## Action 是否存在
2. 对每个问题输出：文件路径、字段名、问题描述。
3. 最后输出总结：N 个文件通过，M 个文件有问题。

### 任务 30：编写 README.md

这是面向 GitHub 用户的项目说明文件，而不是开发者 spec。内容结构应该是：

1. 项目标题和一句话描述
2. 一个清晰的 "What is this?" 段落（3-4 句话解释 HCC 是什么、解决什么问题）
3. Quick Start（安装 → init → 基本使用流程，5 步以内）
4. 完整命令列表（每个命令一行描述）
5. 核心概念简介（三层记忆、验证层次——各用 2-3 句话，不要复制 spec 全文）
6. 项目中生成的文件结构说明
7. 配合 ChatCFD 使用的说明（简要，指向 docs/ 获取详情）
8. Contributing 指引（指向 docs/）
9. License (MIT)

语言：英文（GitHub 项目面向国际社区）。README 中可以用少量中文注释说明 CFD 术语。
总长度控制在 200 行以内——简洁是 README 的首要品质。

### 任务 31：创建 .github/workflows/ci.yml

GitHub Actions 配置：
- 触发条件：push 和 pull_request
- 矩阵策略：ubuntu-latest + macos-latest
- 步骤：checkout → 安装 jq → 运行所有 tests/test-*.sh
- 使用 CLAUDE_PLUGIN_ROOT 环境变量指向仓库根目录

### 任务 32：最终检查

1. 确认所有文件都已创建，没有遗漏。
2. 运行所有测试，确认全部通过。
3. 检查所有 .sh 文件都有正确的 shebang（#!/usr/bin/env bash）和 set -euo pipefail。
4. 检查所有 commands/*.md 文件都有正确的 YAML front matter（--- 包围的 description 字段）。
5. 检查 hooks/hooks.json 格式正确。
6. 检查 skills/memory-workflow/SKILL.md 有正确的 YAML front matter。
7. 确认 .claude-plugin/plugin.json 存在且格式正确。
8. 给我一个完整的文件清单和每个文件的职责总结。

### 完成标准

所有文件就位、所有测试通过后，这个 plugin 应该可以直接 push 到 GitHub，
然后任何人通过 /plugin install 或 claude --plugin-dir 安装使用。
请确认项目处于可发布状态，并列出任何你认为需要我手动检查的事项。
```
