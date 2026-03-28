# claude-spaces Specification

tmux-based session picker for Claude Code. Provides a persistent side panel listing all sessions for the current project, with cross-server discovery of other projects and seamless switching between them.

## Usage

```
claude-spaces          # Launch (inside or outside tmux)
claude-spaces --reset  # Kill all managed panes, clear state, clean restart
claude-spaces --help   # Show help
```

## Layout

```
+------------------------------------+------------------------------+
|                                    | ~wired/                      |
|  Active claude session             | write a wrapper...       5m  |
|  or welcome screen                 | sessions                14h |
|                                    | configure verbose...     4h  |
|                                    |                              |
|                                    | ─ other projects ─           |
|                                    | on-point-camera              |
|                                    |   test-framework          2h |
|                                    |   camera firmware          3h|
|                                    |                              |
|                                    | ─ inactive ─                 |
|                                    | old-project                  |
|                                    |                              |
|                                    | N:new C:cls H:hide D:DEL    |
|                                    | F:manual-focus Q:detach      |
|                                    | claude-spaces v0.8.1-dev       |
+------------------------------------+------------------------------+
         left slot                    picker (30 cols default)
```

Picker width and side are configurable. Width re-pins on terminal resize.

## Architecture

Each project runs on its own tmux server named `cs<sanitized-pwd>` (e.g., `cs-home-wired`), derived from `$PWD`. All tmux calls go through `_tmux()` which adds `-L $TMUX_SERVER`. For `exec` calls, use `cs_exec_tmux()`.

On launch, the user's `~/.tmux.conf` is auto-sourced on the dedicated server (configurable via `tmux_conf`).

Two modes controlled by `CS_PICKER`:
- **Launcher mode** (default): `cs_launch()` — loop: create/attach session, handle project switching
- **Picker mode** (`CS_PICKER=1`): `cs_picker_loop()` — TUI event loop

The `X` key re-execs the picker, picking up code changes instantly.

> See [specs/launch.md](specs/launch.md) for launch loop details, state management, and `--reset` behavior.

### Rendering

Paint-over (`\e[K` per line) instead of full clear. Dirty flag prevents unnecessary re-renders. Fingerprint comparison (IDs, statuses, mtimes, types, picker focus) skips identical frames. Unified render path with per-type variables (indent, color, show_age).

## Scoping

Sessions are scoped to `$PWD`. The script scans `~/.claude/projects/<sanitized-pwd>/` for session files. The sanitized path replaces `/` with `-` (e.g., `/home/wired` → `-home-wired`).

## Picker Sections

### Local sessions (top)
Current project's sessions with full interactive control. Sorted by mtime descending. Rescanned every 1 second.

### Other projects (middle)
Discovered from running `cs-*` tmux sockets (excluding own server). Shows sessions grouped by project, with managed vs dormant status. Rescanned every 5 seconds (cached between scans).

### Inactive projects (bottom)
Discovered from `~/.claude/projects/*/` dirs that have JSONL files but no running `cs-*` socket. Shows project name only.

> See [specs/discovery.md](specs/discovery.md) for scan mechanics, name resolution, path resolution, and cross-server switching.

## Session States

### Local sessions

| State    | Style                 | Selectable | Description                              |
|----------|-----------------------|------------|------------------------------------------|
| Focused  | `> ` prefix, bold green | yes      | Displayed in left slot, session has focus |
| Active   | bold green            | yes        | Displayed in left slot, picker has focus  |
| Bell     | red text              | yes        | Background session rang the bell         |
| Running  | white text            | yes        | Running in hidden tmux window            |
| Dormant  | dim/gray text         | yes        | On disk, not running, resumable          |
| Locked   | strikethrough + dim   | no         | Running in another Claude instance       |

### Remote sessions

| State    | Style          | Selectable | Description                     |
|----------|----------------|------------|---------------------------------|
| Managed  | white, indented | yes       | Running on remote server         |
| Dormant  | dim, indented  | yes        | Not running on remote server     |

### Other entry types

| Type     | Style              | Selectable | Description                     |
|----------|--------------------|------------|---------------------------------|
| Header   | bold dim + rules   | no (skipped) | Section divider               |
| Spacer   | blank line         | no (skipped) | Gap before headers            |
| Project  | white text         | yes        | Remote project name             |
| Inactive | dim text           | yes        | Inactive project name           |

Focused state detected at render time via `_tmux display-message -t $PICKER_PANE -p '#{pane_active}'`.

## Keybinds

### Picker pane

| Key              | Action                                                      |
|------------------|-------------------------------------------------------------|
| `j` / `↓`       | Move cursor down (skips headers/spacers)                    |
| `k` / `↑`       | Move cursor up (skips headers/spacers)                      |
| `Enter`          | Local: first press loads, second press focuses. Remote/project/inactive: switch to that server. |
| `h` / `l` / `←` / `→` | Load/resume session AND focus it immediately. Local only. |
| `N`              | Create new `claude` session (always focuses it)             |
| `C`              | Close managed pane (keeps session on disk). Local only.     |
| `H`              | Hide session with `y/N` confirm. Local only.                |
| `D`              | Permanent delete with `y/N` confirm. Local only.            |
| `r`              | Refresh session list (forces remote rescan)                 |
| `R`              | Rename session. Local only.                                 |
| `F`              | Toggle auto-focus mode                                      |
| `Q`              | Detach (exit claude-spaces)                               |
| `X`              | Reload picker script in-place (`exec`)                      |

### Global tmux bindings (work from any pane)

| Key              | Action                                                    |
|------------------|-----------------------------------------------------------|
| `prefix + j / ↓` | Next local session + focus (skips remote/inactive)       |
| `prefix + k / ↑` | Prev local session + focus (skips remote/inactive)       |
| `prefix + Tab`   | Toggle focus between session and picker                   |

> See [specs/mechanics.md](specs/mechanics.md) for pane swap sequence, bell detection, and binding lifecycle.

## Configuration

File: `~/.claude/claude-spaces.conf` (created on first run with commented defaults).

```ini
# Picker pane width: characters (e.g. 30) or percentage (e.g. 20%)
# picker_width=30

# Sort order: bell = belled first, mtime = most recent first
# sort_by=bell,mtime

# Group sessions by project (for future use)
# group_by=project

# Picker pane position: "right" (default) or "left"
# picker_side=right

# Enter key focuses session immediately: 0 (default, load only) or 1 (load + focus)
# enter_focuses=0

# Max length for tmux window names
# window_name_len=12

# Path to tmux.conf to source on dedicated server (empty = don't source)
# tmux_conf=~/.tmux.conf
```

## Dependencies

- **bash** 4+ (associative arrays)
- **tmux** 3.0+ (`alert-bell` hook, `break-pane -d`, dedicated servers via `-L`)
- **jq** (session metadata extraction from JSONL)
- **coreutils**: `stat`, `date`, `sed`, `sort`, `head`

## Detailed Specs

| File | Coverage |
|------|----------|
| [specs/discovery.md](specs/discovery.md) | Session scanning, name resolution, remote/inactive discovery, cross-server switching |
| [specs/launch.md](specs/launch.md) | Launch loop, re-attach, stale cleanup, reset, runtime/persistent state files |
| [specs/mechanics.md](specs/mechanics.md) | Atomic pane swap, bell detection, binding lifecycle |
| [specs/testing.md](specs/testing.md) | Test infrastructure, shellcheck, invariant checks |
| [specs/future.md](specs/future.md) | Planned features |
