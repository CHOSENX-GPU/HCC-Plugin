# Publishing to GitHub

The repository root **is** the Claude Code plugin root (contains `.claude-plugin/plugin.json`).

This repo also includes **`.claude-plugin/marketplace.json`** so users can install with the standard flow:

```text
/plugin marketplace add CHOSENX-GPU/HCC-Plugin
/plugin install hcc-memory@hcc-plugin
/reload-plugins
```

- **Marketplace id** (`@…`): `hcc-plugin` — the `name` field in `marketplace.json`
- **Plugin id**: `hcc-memory` — must match `plugin.json` `name` and the plugin entry in `marketplace.json`

See [Discover and install plugins](https://code.claude.com/docs/en/discover-plugins) and [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces).

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

## End-user install (summary)

- **Marketplace + `/plugin install`:** see README “Install (Claude Code — recommended)”.
- **Dev / no install:** `git clone …` then `claude --plugin-dir /path/to/HCC-Plugin`.

## CI

GitHub Actions runs `tests/test-*.sh` on Ubuntu and macOS (`.github/workflows/ci.yml`).
