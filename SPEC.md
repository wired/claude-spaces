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
|                                    | claude-spaces v0.8.0       |
+------------------------------------+------------------------------+
         left slot                    picker (30 cols default)
```

Picker width and side are configurable. Width re-pins on terminal resize.

## Dedicated tmux Server

Each project runs on its own tmux server named `cs<sanitized-pwd>` (e.g., `cs-home-wired`). This isolates key bindings, bell hooks, and window state per project. The server name is derived from `$PWD` — not configurable.

All tmux calls go through a `_tmux()` wrapper that adds `-L $TMUX_SERVER`. For `exec` calls, `cs_exec_tmux()` calls the binary directly.

On launch, the user's `~/.tmux.conf` is auto-sourced on the dedicated server (configurable via `tmux_conf`).

## Launch Behavior

`cs_launch()` runs a loop:
1. Create tmux session on the dedicated server (if not already running)
2. Source tmux.conf
3. Attach (blocks until detach)
4. On detach: check for `switch_target` file — if present, `cd` to the target path, update `TMUX_SERVER`, and loop back to step 1 (project switching)
5. If no switch target: exit (normal detach via `Q`)

### Re-attach
Running `claude-spaces` again from the same directory attaches to the existing session on that project's server.

### Stale state cleanup
On picker startup, validates all pane IDs in the state dir. Dead refs are removed automatically. No `--reset` needed after tmux restart.

## Scoping

Sessions are scoped to `$PWD`. The script scans `~/.claude/projects/<sanitized-pwd>/` for session files. The sanitized path replaces `/` with `-` (e.g., `/home/wired` → `-home-wired`).

## Picker Sections

### Local sessions (top)
Current project's sessions with full interactive control. Sorted by mtime descending.

### Other projects (middle)
Discovered from running `cs-*` tmux sockets (excluding own server). For each remote server:
- Reads `project_path` from the remote server's state dir
- Scans the remote project's JSONL files for session names and mtimes
- Checks the remote server's `panes/*` files to determine managed vs dormant status
- Sessions sorted by mtime descending within each project

Selecting a remote project or session: writes `switch_target` (and optionally `pending_load` for a specific session) to the state dir, then detaches. The launch loop picks up the switch and reattaches to the target server.

### Inactive projects (bottom)
Discovered from `~/.claude/projects/*/` dirs that have JSONL files but no running `cs-*` socket. Shows project name only (leaf of path). Selecting one launches a new server for that project.

Path resolution: reads `project_path` from state dir if available, or extracts `cwd` from the first JSONL file as fallback. Projects with unresolvable or deleted paths are skipped.

### Discovery refresh
Remote and inactive discovery runs every 5 seconds (throttled). Local session scan runs every 1 second. Between remote scans, cached results are re-appended. Remote scan also runs immediately on startup.

## Session Discovery

Session data lives in `~/.claude/projects/<sanitized-path>/*.jsonl`. Metadata extracted from the first 20 lines via `head -20 | jq`:

- **First user message**: `type == "user"`, `message.content` is a string, first line extracted
- **Session ID**: UUID from the filename
- **Last activity**: file mtime via `stat -c %Y`

### Display Name Resolution (priority order)

1. Custom name from `~/.claude/claude-spaces-names.conf` (`session_id=name`)
2. First user message, cleaned:
   - First line only
   - Leading filler stripped: "I want to", "Can you", "Please", "Hey", "Hi", "Could you", "I need to", "Help me", "I would like to"
   - Truncated to fit available width with `...` suffix
3. First 8 characters of session UUID as fallback

### Active-Elsewhere Detection

Files in `~/.claude/sessions/*.json` track running Claude processes. `kill -0 $pid` verifies the process is alive. Matching sessions are marked as locked.

### Hidden Sessions

Hidden via `H`, stored in `~/.claude/claude-spaces-hidden.conf` (one ID per line). Applied globally across all projects (local and remote scans both filter against it).

### Auto-refresh

Local sessions rescanned every 1 second. Fingerprint comparison (IDs, statuses, mtimes, types, picker focus) prevents unnecessary re-renders. Selection follows sessions across re-sorts (tracked by ID).

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

Bindings are installed on picker startup and cleaned up on exit/reset (arrows restored to default pane navigation).

## Pane Swap Mechanic

Each session runs in its own tmux pane. Only one is visible at a time. Others are parked in hidden tmux windows via `break-pane -d`.

### Swap operation (atomic)
```
_tmux break-pane -d -s $OLD -t $SESSION: \;
     join-pane -h [-b] -s $NEW -t $PICKER \;
     resize-pane -t $PICKER -x $PICKER_WIDTH \;
     select-pane -t $PICKER
```

The `-t $SESSION:` ensures parked panes stay in the correct tmux session. The `resize-pane` pins the picker width. WINCH handler re-pins on terminal resize.

### Focus behavior
Swaps keep focus on the picker. User explicitly focuses via `h`/`l`/arrows or second `Enter`.

## Bell Detection

Uses tmux's `alert-bell` hook. Requires a Stop hook in `~/.claude/settings.json`:
```json
{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "printf '\\a' > /dev/tty"}]}]}}
```

The `> /dev/tty` is critical. `#{window_bell_flag}` polling does NOT work (flag is momentary).

Bell state clears when the session is brought to the foreground. The hook is installed/removed per picker lifecycle.

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

## Runtime State

Directory: `${XDG_RUNTIME_DIR:-/tmp}/claude-spaces/<sanitized-cwd>/`

Ephemeral. Stale refs cleaned up on picker startup.

| File              | Contents                                    |
|-------------------|---------------------------------------------|
| `panes/<num>`     | Session ID for tmux pane `%<num>`           |
| `picker_pane`     | Pane ID of the picker                       |
| `picker_pid`      | PID of the picker process                   |
| `current_pane`    | Pane ID currently displayed in left slot    |
| `welcome_pane`    | Pane ID of welcome screen (if showing)      |
| `new_pane`        | Pane ID of uninitialized new session        |
| `bells`           | Pane IDs that belled (written by alert-bell hook) |
| `project_path`    | Real filesystem path for this project       |
| `switch_target`   | Target path for cross-server switching      |
| `pending_load`    | Session ID to auto-load on the target server |

## Persistent Files

| File                                      | Purpose                                     |
|-------------------------------------------|---------------------------------------------|
| `~/.claude/claude-spaces.conf`          | Configuration (key=value, comments with #)  |
| `~/.claude/claude-spaces-names.conf`    | Custom session names (`session_id=name`)    |
| `~/.claude/claude-spaces-hidden.conf`   | Hidden session IDs (one per line, `H` key)  |

## Dependencies

- **bash** 4+ (associative arrays)
- **tmux** 3.0+ (`alert-bell` hook, `break-pane -d`, dedicated servers via `-L`)
- **jq** (session metadata extraction from JSONL)
- **coreutils**: `stat`, `date`, `sed`, `sort`, `head`

## Architecture

### Self-re-exec pattern

Two modes controlled by `CS_PICKER`:
- **Launcher mode** (default): `cs_launch()` — loop: create/attach session, handle project switching
- **Picker mode** (`CS_PICKER=1`): `cs_picker_loop()` — TUI event loop

The `X` key re-execs the picker, picking up code changes instantly.

### Dedicated server per project

`TMUX_SERVER="cs${PWD//\//-}"`. The `_tmux()` wrapper adds `-L` to all tmux calls. `cs_exec_tmux()` handles `exec` calls (bash functions can't be `exec`'d).

### Cross-server discovery

`cs_build_all_entries()` orchestrates:
1. Local scan (`cs_scan_sessions`) — every 1s
2. Remote discovery (`cs_discover_servers` + `cs_scan_project_sessions`) — every 5s, cached between scans
3. Inactive discovery (`cs_discover_inactive`) — every 5s, cached

Remote server detection: enumerate `cs-*` sockets in the tmux socket dir, check `has-session`, read `project_path` from state dir.

### Pane existence checking

Uses `_tmux list-panes -a -F '#{pane_id}'` with a cached result (`LIVE_PANES`). Pure bash string matching — no subprocess per check. Cache refreshed once per scan cycle. `tmux display-message -t PANE_ID` is NOT reliable for existence checks (falls back to current pane on miss).

### Paint-over rendering

`\e[K` per line instead of `\e[2J`. Dirty flag prevents unnecessary re-renders. Unified render path: one code path with per-type variables (indent, color, show_age).

## Testing

`run_tests` — 25 integration tests.

1. Runs `shellcheck` (static analysis gate)
2. Sources function definitions, installs mocks (sleep panes instead of real Claude)
3. Creates isolated tmux test server (`cs-test-$$`)
4. Exercises operations, validates state invariants after each (`cs_assert_consistent`)
5. Checks: pane liveness, pane counts, orphaned windows, state file consistency

## Future Work

- **Two-tier sort**: Active sessions (< 10m) sorted alphabetically (stable), inactive sorted by mtime
- **Unhide**: UI to restore hidden sessions
- **Session forking**: Use `claude --fork-session` to branch from an existing session
- **Search/filter**: Type to filter session list
- **Idle detection**: Show whether Claude is working or waiting for input
- **tmux capture-pane preview**: Show last few lines of a session without switching to it
