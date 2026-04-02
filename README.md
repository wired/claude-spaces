# claude-spaces

Session management for Claude Code.

![claude-spaces-v0 9 0](https://github.com/user-attachments/assets/f58f3c2e-81c9-4f42-8d8e-96619755e88a)

Claude Code tracks sessions but gives you no way to see them. No list, no
switching, no way to tell what's running in the background. claude-spaces adds
all of that — a persistent tmux side panel that shows every session across
every project, with instant switching and background activity alerts.

```
+------------------------------------+------------------------------+
|                                    | ~wired/                      |
|  Active claude session             | write a wrapper...       5m  |
|  or welcome screen                 | sessions                14h  |
|                                    | configure verbose...     4h  |
|                                    |                              |
|                                    | ─ other projects ─           |
|                                    | on-point-camera              |
|                                    |   test-framework          2h |
|                                    |   camera firmware         3h |
|                                    |                              |
|                                    | ─ inactive ─                 |
|                                    | old-project                  |
|                                    |                              |
|                                    | : menu  / search             |
|                                    | Q:detach                     |
|                                    | claude-spaces v0.9.3-dev     |
+------------------------------------+------------------------------+
         left slot                    picker (30 cols default)
```

## Install

```
brew tap wired/tap && brew install claude-spaces   # macOS / Homebrew
yay -S claude-spaces                                # Arch (AUR)
make install                                        # /usr/local/bin (may need sudo)
PREFIX=~/.local make install                        # ~/.local/bin
```

Requires bash 4+, tmux 3.0+, jq.

## Quick Start

```
claude-spaces              # launch
claude-spaces --reset      # kill all managed panes, clear state
claude-spaces --help
```

Run it from any project directory. It creates a dedicated tmux server, opens a
session picker on the right, and launches Claude Code on the left.

## Features

**Session picker** — all sessions for the current project in a persistent side
panel. Navigate with `j`/`k`, jump with `1`-`0`, search with `/`. You can also
use the tmux prefix for even faster navigation

**Cross-project discovery** — sessions from other running projects appear
automatically. Hit Enter to switch. Inactive projects (not currently running)
are discovered and can be resumed.

This allows you to use claude-spaces with worktrees as well, you just have to
create them yourself.

**Bell detection** — when Claude finishes in a background session, the picker
highlights it in red. Never miss a completed task again.

**Per-session terminal** — each session gets its own shell pane below it.
`` prefix + ` `` opens the terminal and toggles focus between it and the Claude
pane (it never closes it). `prefix + t` toggles terminal visibility on/off.
Resize freely — height is saved per-session.

**Search and filter** — type `/` to filter sessions by name across all
sections. Matches update as you type.

**Isolated per-project servers** — each project gets its own tmux server. No
cross-contamination of keybindings, window state, or bell hooks.

<details>
<summary><strong>Keybinds</strong></summary>

claude-spaces takes full ownership of the tmux prefix key table on its dedicated
server. Stock tmux bindings are disabled. Your tmux.conf is sourced for visuals
(colors, mouse, status) but all keybindings are managed by claude-spaces.

### Picker pane (direct keys)

| Key | Action |
|-----|--------|
| `j` / `k` / `↑` / `↓` | Move cursor (skips headers) |
| `1`-`9`, `0` | Jump to Nth local session (0 = 10th) + focus |
| `Enter` | Load + focus session (remote/inactive: switch project) |
| `Space` | Load session (stay in picker) |
| `H` / `L` | Load + focus session |
| `a` / `i` | Focus Claude pane |
| `h` / `l` / `←` / `→` | Move between panes |
| `/` | Search/filter sessions |
| `:` | Command menu (new, rename, close, hide, shutdown) |
| `Q` | Detach (exit) |
| `R` | Reload picker in-place (picks up code changes) |

### Prefix key bindings (from any pane)

| Key | Action |
|-----|--------|
| `prefix + Enter` / `prefix + i` | Focus Claude pane |
| `prefix + Space` | Toggle picker / Claude pane |
| `` prefix + ` `` | Smart terminal (open/focus toggle) |
| `prefix + t` | Toggle terminal on/off (unconditional) |
| `prefix + a` | Literal grave (`` ` ``) |
| `prefix + h` / `prefix + ←` / `prefix + S-←` | Select pane left |
| `prefix + j` / `prefix + ↓` | Select pane down |
| `prefix + k` / `prefix + ↑` | Select pane up |
| `prefix + l` / `prefix + →` / `prefix + S-→` | Select pane right |
| `prefix + J` / `prefix + S-↓` | Next session + focus |
| `prefix + K` / `prefix + S-↑` | Prev session + focus |
| `prefix + 1`-`9`, `0` | Jump to Nth local session + focus |
| `prefix + /` | Focus picker + search |
| `prefix + c` | New session |
| `prefix + x` | Close session (with confirm) |
| `prefix + r` | Rename session |
| `prefix + H` | Hide session (with confirm) |
| `prefix + s` | Shutdown (kill server) |
| `prefix + R` | Reload picker |
| `prefix + z` | Zoom/maximize pane |
| `prefix + [` | Copy mode |
| `prefix + ]` | Paste buffer |
| `prefix + PgUp` | Copy mode + scroll up |
| `prefix + d` | Detach |
| `prefix + :` | Command menu |
| `prefix + Tab` | Refresh/rescan |
| `prefix + F12` | tmux command prompt (escape hatch) |
| `prefix + M-↑/↓` | Resize pane vertically |
| `prefix + M-←/→` | Resize pane horizontally |

</details>

<details>
<summary><strong>Bell Detection</strong></summary>

Background sessions that finish can ring the terminal bell, highlighting them
in red in the picker. Add a Claude Code Stop hook to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "printf '\\a' > /dev/tty"
          }
        ]
      }
    ]
  }
}
```

The `> /dev/tty` is critical — without it the bell doesn't reach tmux. Bell
state clears when the session is brought to the foreground.

</details>

<details>
<summary><strong>Configuration</strong></summary>

Config file: `~/.config/claude-spaces/config` (created on first run with
commented defaults; respects `$XDG_CONFIG_HOME`).

```ini
# Picker pane width: characters (e.g. 30) or percentage (e.g. 20%)
# picker_width=30

# Picker pane position: "right" (default) or "left"
# picker_side=right

# Sessions modified within this many minutes sort by name at the top;
# older sessions sort by most recent first below them.
# recent_threshold=10

# Max length for tmux window names
# window_name_len=12

# Path to tmux.conf to source on dedicated server (empty = don't source)
# tmux_conf=~/.tmux.conf

# Terminal pane height: characters (e.g. 15) or percentage (e.g. 35%)
# terminal_height=35%

# Show jump index next to first 10 local sessions
# show_index=1

# Override tmux prefix key (default: inherited from tmux.conf)
# prefix=C-a

# Keybinding overrides (comma-separated for multiple keys)
# bind_terminal=`
# bind_toggle_terminal=t
# bind_focus_claude=Enter,i
# bind_nav_next=J,S-Down
# bind_nav_prev=K,S-Up
# bind_pane_left=h,Left,S-Left
# bind_pane_right=l,Right,S-Right
# bind_pane_up=k,Up
# bind_pane_down=j,Down
# bind_focus_picker=Space
# bind_detach=d
# bind_zoom=z
# bind_copy_mode=[
# bind_paste=]
# bind_search=/
# bind_new_session=c
# bind_close=x
# bind_rename=r
# bind_hide=H
# bind_shutdown=s
# bind_reload=R
# bind_refresh=Tab
# bind_menu=:
```

Custom session names: `~/.local/share/claude-spaces/names` (`session_id=name`;
respects `$XDG_DATA_HOME`)
Hidden sessions: `~/.local/share/claude-spaces/hidden` (one ID per line;
respects `$XDG_DATA_HOME`)

</details>

## License

[MIT](LICENSE)
