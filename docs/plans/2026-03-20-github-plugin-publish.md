# HCC Memory Plugin — GitHub Publish Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship the HCC Memory Claude Code plugin as a clean GitHub repository that users can install with `claude --plugin-dir` or marketplace-style clone.

**Architecture:** Plugin root = repo root. Required manifest at `.claude-plugin/plugin.json`. Commands in `commands/`, hooks in `hooks/`, scripts in `scripts/`, skill in `skills/`. No build step — Bash + Markdown only.

**Tech Stack:** Git, GitHub, Claude Code plugin layout (see Anthropic Claude Code plugin docs).

---

### Task 1: Repository hygiene

**Files:**
- Create: `.gitignore` (exclude `.claude/`, OS junk, editor temp)
- Do not commit: `.claude/settings.local.json` or any secrets

**Step 1:** Add `.gitignore` at repo root.

**Step 2:** Verify `git status` does not list `.claude/`.

**Step 3:** Commit.

---

### Task 2: Manifest and docs check

**Files:**
- Verify: `.claude-plugin/plugin.json` (name, description, version, author)
- Verify: `README.md` install path (`claude --plugin-dir …`)
- Verify: `LICENSE` (MIT)

**Step 1:** Open `plugin.json` — bump version if needed for release.

**Step 2:** README Quick Start uses a real clone URL placeholder `your-org/REPO`.

**Step 3:** Commit doc tweaks if any.

---

### Task 3: Full plugin tree in Git

**Files:**
- Stage: `.claude-plugin/`, `commands/`, `hooks/`, `scripts/`, `skills/`, `templates/`, `tests/`, `.github/workflows/ci.yml`
- Stage: `README.md`, `LICENSE`, `CHANGELOG.md`, `docs/` (optional design docs)

**Step 1:** `git add` all intended files.

**Step 2:** `git commit -m "feat: HCC Memory plugin v0.1.0 for Claude Code"`

**Step 3:** Default branch `main` (GitHub convention):  
`git branch -M main` (if first commit on master)

---

### Task 4: Push to GitHub

**Step 1:** Create empty repo on GitHub (no README/license if avoiding merge conflict).

**Step 2:** Add remote:
```bash
git remote add origin https://github.com/<YOUR_USER>/<YOUR_REPO>.git
```

**Step 3:** Push:
```bash
git push -u origin main
```

**Expected:** GitHub shows full tree; CI workflow runs on push.

---

### Task 5: User install smoke test

**Step 1:** Clone fresh:
```bash
git clone https://github.com/<YOUR_USER>/<YOUR_REPO>.git
cd <YOUR_REPO>
```

**Step 2:** Run tests:
```bash
bash tests/test-platform.sh
# … or all tests/test-*.sh
```

**Step 3:** In a throwaway project:
```bash
claude --plugin-dir /path/to/<YOUR_REPO>
```
Run `/hcc-memory:init` (or your command names) once.

**Step 4:** Tag release (optional):
```bash
git tag -a v0.1.0 -m "v0.1.0"
git push origin v0.1.0
```

---

## Execution handoff

**Plan complete and saved to `docs/plans/2026-03-20-github-plugin-publish.md`.**

**Two execution options:**

1. **Subagent-Driven (this session)** — apply `.gitignore`, commit, branch rename, print exact `git remote` / `git push` for your GitHub URL.

2. **Parallel Session** — open new session with executing-plans and run Tasks 1–5 there.

**Which approach?** (Default: complete packaging in this session + you run `git push` with your credentials.)
