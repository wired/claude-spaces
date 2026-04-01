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
|                                    | ::menu  /:search             |
|                                    | Q:detach                     |
|                                    | claude-spaces v0.8.1-dev       |
+------------------------------------+------------------------------+
         left slot                    picker (30 cols default)
```

With optional terminal pane (toggled via `` prefix+` ``):
```
+------------------------------------+------------------------------+
|  Active claude session             |                              |
|                                    |  Picker pane                 |
+------------------------------------+  (full height, pinned)       |
|  Terminal pane (shell)             |                              |
+------------------------------------+------------------------------+
```

Terminal pane is per-session: each session independently tracks whether its terminal is visible. Swapping sessions preserves each session's terminal state.

Picker width and side are configurable. Width re-pins on terminal resize.

## Architecture

Each project runs on its own tmux server named `cs<sanitized-pwd>` (e.g., `cs-home-wired`), derived from `$PWD`. All tmux calls go through `_tmux()` which adds `-L $TMUX_SERVER`. For `exec` calls, use `cs_exec_tmux()`.

On launch, the user's `~/.tmux.conf` is auto-sourced on the dedicated server (configurable via `tmux_conf`).

Two modes controlled by `CS_PICKER`:
- **Launcher mode** (default): `cs_launch()` — loop: create/attach session, handle project switching
- **Picker mode** (`CS_PICKER=1`): `cs_picker_loop()` — TUI event loop

The `R` key re-execs the picker, picking up code changes instantly.

> See [specs/launch.md](specs/launch.md) for launch loop details, state management, and `--reset` behavior.

### Rendering

Paint-over (`\e[K` per line) instead of full clear. Dirty flag prevents unnecessary re-renders. Fingerprint comparison (IDs, statuses, mtimes, types, picker focus) skips identical frames. Unified render path with per-type variables (indent, color, show_age).

## Scoping

Sessions are scoped to `$PWD`. The script scans `~/.claude/projects/<sanitized-pwd>/` for session files. The sanitized path replaces `/` with `-` (e.g., `/home/wired` → `-home-wired`).

## Picker Sections

### Local sessions (top)
Current project's sessions with full interactive control. Sessions modified within `recent_threshold` minutes (default 10) sort alphabetically by name; older sessions sort by most recent first. Hidden sessions always sort in the older tier. Rescanned every 1 second.

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

claude-spaces takes full ownership of the tmux prefix key table on its dedicated
server. Stock tmux bindings are disabled. Your tmux.conf is sourced for visuals
(colors, mouse, status) but all keybindings are managed by claude-spaces and
configurable via `bind_*` keys in the config file.

### Picker pane (direct keys)

| Key              | Action                                                      |
|------------------|-------------------------------------------------------------|
| `j` / `k` / `↑` / `↓` | Move cursor (skips headers/spacers)                  |
| `1`-`9`, `0`     | Jump to Nth local session (0 = 10th) + focus                |
| `Enter`          | Load + focus session (remote/inactive: switch project)      |
| `Space`          | Load session (stay in picker)                               |
| `H` / `L`       | Load + focus session                                        |
| `h` / `l` / `←` / `→` | Move between panes (directional)                     |
| `/`              | Search/filter sessions                                      |
| `:`              | Command menu (new, rename, close, hide, delete, shutdown)   |
| `Q`              | Detach (exit claude-spaces)                                 |
| `R`              | Reload picker script in-place (`exec`)                      |

### Command menu

Press `:` in the picker to open the command menu. The display shows only the
highlighted session and a list of actions. Press the key to execute, Escape or
any non-matching key to cancel.

| Key | Action |
|-----|--------|
| `r` | Rename |
| `x` | Close (with confirm) |
| `h` | Hide (with confirm) |
| `o` | Hide this & older (with confirm) |
| `!` | Delete permanently (with confirm) |
| `c` | New session |
| `d` | Detach |
| `s` | Shutdown (kill server) |

### Prefix key bindings (from any pane)

All prefix bindings are configurable via `bind_*` keys in the config file.
Default key assignments are documented in README.md. The available actions:

| Action | Config key | Description |
|--------|-----------|-------------|
| Focus Claude | `bind_focus_claude` | Focus the Claude session pane |
| Focus toggle | `bind_focus_picker` | Toggle between picker and Claude pane |
| Terminal (smart) | `bind_terminal` | Closed→open, focused→close, unfocused→focus |
| Terminal toggle | `bind_toggle_terminal` | Unconditional show/hide |
| Nav next/prev | `bind_nav_next`, `bind_nav_prev` | Move + activate + focus session |
| Pane left/right | `bind_pane_left`, `bind_pane_right` | Directional pane movement |
| Search | `bind_search` | Focus picker + enter search mode |
| New session | `bind_new_session` | Create new Claude session |
| Close session | `bind_close` | Close with confirm prompt |
| Rename session | `bind_rename` | Rename selected session |
| Hide session | `bind_hide` | Hide with confirm prompt |
| Delete session | `bind_delete` | Delete permanently with confirm |
| Shutdown | `bind_shutdown` | Kill tmux server |
| Reload picker | `bind_reload` | Re-exec picker in-place |
| Zoom | `bind_zoom` | Zoom/maximize current pane |
| Copy mode | `bind_copy_mode` | Enter tmux copy mode |
| Paste | `bind_paste` | Paste from tmux buffer |
| Detach | `bind_detach` | Detach from tmux |
| Menu | `bind_menu` | Focus picker + open command menu |
| Refresh | `bind_refresh` | Force rescan |

Hardcoded (not configurable): arrow keys (duplicate nav/pane), PgUp (copy mode
+ scroll), 1-9/0 (jump to Nth session), M-arrows (resize), F12 (tmux command
prompt), `a` (literal grave).

> See [specs/mechanics.md](specs/mechanics.md) for pane swap sequence, bell detection, and binding lifecycle.

## Search

`/` activates search mode. A search field appears at the bottom of the picker (replacing the
footer), matching vim convention and the existing rename/confirm dialog patterns. All sections
(local, remote, inactive) are filtered by case-insensitive substring match against the
displayed name. Filter is applied immediately on each keystroke.

The search field acts as a virtual entry for navigation wrapping: `↓` from the field goes to
the first result, `↑` goes to the last. From results, wrapping past either end returns to the
field. While in the search field, `j`/`k` are literal characters; in results they navigate.

| Context | Key | Action |
|---------|-----|--------|
| Search field | printable chars | Append to search term, filter immediately |
| Search field | `Backspace` | Delete last char (empty = stay in search) |
| Search field | `Enter` (1 match) | Select it, exit search, load/focus |
| Search field | `Enter` (>1 matches) | Move to first result |
| Search field | `Escape` | Exit search, restore full list |
| Search field | `↑` / `↓` | Navigate to results |
| Results | `j`/`k`/`↑`/`↓` | Navigate (wraps through search field) |
| Results | `Enter` | Exit search, load + focus |
| Results | `Escape` | Exit search, restore full list |
| Results | `←`/`→` | Exit search, move between panes |

Section headers are only shown when they have matching children.

## Configuration

File: `~/.config/claude-spaces/config` (created on first run with commented defaults; respects `$XDG_CONFIG_HOME`).

See README.md for the full list of options and their defaults.

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
