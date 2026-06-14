# wt-herdr — Worktrunk ↔ herdr bridge

> **Worktrunk** manages your git worktrees. **Herdr** manages your terminal workspaces.  
> `wt-herdr` makes them talk to each other.

`wt-herdr` is a [worktrunk custom subcommand](https://worktrunk.dev/extending/#custom-subcommands) — drop `wt-herdr` on your `PATH` and it becomes **`wt herdr`**. It syncs worktrees as herdr workspaces, with status badges, auto-focus, lifecycle hooks, and notifications.

## How it works

Each git worktree managed by `wt` becomes a herdr workspace in a **per-repo session**:

```
wt list                  ──→   herdr workspace list
┌─────────────────┐            ┌─────────────────────────────┐
│ main            │            │ my-repo / main  ?^|         │
│ feature-a  !↕|  │            │ my-repo / feature-a  !↕|    │
│ feature-b    ↑  │            │ my-repo / feature-b    ↑    │
└─────────────────┘            └─────────────────────────────┘
```

Workspace labels show the repo name, branch name, and status symbols from `wt list` at a glance.

### Sessions

Every `wt herdr` subcommand auto-targets a herdr session named after the repo (e.g. `my-repo` for `repos/my-repo`). The session server starts automatically if not already running. This keeps each repo's workspaces isolated — switch between `herdr --session repo-a` and `herdr --session repo-b` to see only that repo's workspaces.

Override with `--session <name>` or `HERDR_SESSION` env var.

## Install

### Manual install

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/mattarau/wt-herdr/main/wt-herdr -o /usr/local/bin/wt-herdr
chmod +x /usr/local/bin/wt-herdr
```

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/mattarau/wt-herdr/main/install.sh | sh
```

### Verify

```bash
wt herdr health
```

## Requirements

- [`wt` (worktrunk)](https://worktrunk.dev) — v0.10+ or newer
- [`herdr`](https://herdr.dev) — v0.6+ or newer, server running
- [`jq`](https://jqlang.github.io/jq/) — v1.6+ or newer

## Subcommands

| Command | Description |
|---------|-------------|
| `wt herdr sync` | Sync all worktrees as herdr workspaces. Creates missing workspaces, updates labels with current status symbols. |
| `wt herdr sync --dry-run` | Preview sync without making changes. |
| `wt herdr clean` | Close herdr workspaces that no longer have a matching worktree. |
| `wt herdr clean --dry-run` | Preview cleanup without making changes. |
| `wt herdr focus` | Focus the herdr workspace for the current worktree. |
| `wt herdr status` | Show the mapping between worktrees and herdr workspaces, highlighting missing and orphan entries. |
| `wt herdr update-labels` | Refresh status badges in workspace labels without recreating workspaces. |
| `wt herdr event <type>` | Handle a worktree lifecycle event (used by hooks). Types: `worktree-created`, `worktree-removed`, `worktree-switched`. |
| `wt herdr init` | Set up lifecycle hooks and run the initial sync. |
| `wt herdr health` | Check that all dependencies are available and herdr server is running. |
| `wt herdr manifest` | Print the plugin manifest JSON. |

### Global options

| Option | Description |
|--------|-------------|
| `--session <name>` | Target a specific herdr session (default: auto-detected from repo name) |

## Setup hooks (auto-sync)

Run `wt herdr init` in your repository to generate `.config/wt.toml` with lifecycle hooks:

```toml
[post-start]
herdr = "wt herdr event worktree-created"

[post-remove]
herdr = "wt herdr event worktree-removed"

[post-switch]
herdr = "wt herdr event worktree-switched"
```

Once hooks are set up:

- **`wt switch --create feature-x`** → automatically creates a herdr workspace for the new worktree
- **`wt remove`** → automatically closes the matching herdr workspace
- **`wt switch feature-x`** → automatically focuses the corresponding herdr workspace

After the first run, you'll need to approve the repo hooks:

```
▲ repo needs approval to execute 1 command:
○ post-start herdr:
  wt herdr event worktree-created
```

Use `wt -y herdr init` to auto-approve in CI.

## Notifications

`wt-herdr` sends herdr toast notifications on key events:

| Event | Notification |
|-------|-------------|
| Worktree created | `wt-herdr: created` (with sound) |
| Worktree removed | `wt-herdr: removed` |
| Worktree switched / focused | `wt-herdr: focus` |
| Sync complete | `wt-herdr: sync complete` (with summary) |

Enable notifications in herdr's config:

```toml
[ui.toast]
delivery = "herdr"
```

## Workspace labels

Labels follow the format: **`{repo} / {branch}  {symbols}`**

The symbols come from `wt list --format=json`'s `.symbols` field, showing:

- `!` — modified files
- `?` — untracked files  
- `+` — staged files
- `↑` / `↓` — ahead/behind default branch
- `↕` — diverged
- `✗` — would conflict
- And all other [worktrunk status symbols](https://worktrunk.dev/list/#status-symbols)

## Uninstall

```bash
# Manual
rm /usr/local/bin/wt-herdr

# Remove hooks from your repo
rm .config/wt.toml

# Close herdr workspaces + delete the per-repo session (optional)
wt herdr clean
herdr session delete <repo-name>
herdr --session <repo-name> server stop
```

## Development

```bash
git clone https://github.com/mattarau/wt-herdr.git
cd wt-herdr

# Syntax check
bash -n wt-herdr

# Link for testing
ln -sf "$PWD/wt-herdr" /usr/local/bin/

# Run tests
bats tests/test_plugin.bats
```

## License

MIT
