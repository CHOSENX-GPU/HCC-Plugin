# Publishing to GitHub

The repository root **is** the Claude Code plugin root (contains `.claude-plugin/plugin.json`).

## First push

1. Create a **new empty** repository on GitHub (no README/license if you want a single clean commit).

2. In this folder:

```bash
git remote add origin https://github.com/<YOUR_USER>/<YOUR_REPO>.git
git push -u origin main
```

3. Optional tag:

```bash
git tag -a v0.1.0 -m "v0.1.0"
git push origin v0.1.0
```

## Install for others

```bash
git clone https://github.com/<YOUR_USER>/<YOUR_REPO>.git
cd <YOUR_REPO>
claude --plugin-dir "$(pwd)"
```

## CI

GitHub Actions runs `tests/test-*.sh` on Ubuntu and macOS (`.github/workflows/ci.yml`).
