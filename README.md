# claude-spaces

tmux-based session picker for Claude Code. Persistent side panel listing all sessions for the current project, with cross-server discovery of other projects and seamless switching between them.

Claude Code has no built-in session management — no way to list, switch between, or revisit past sessions without manually tracking IDs. claude-spaces fills that gap: persistent session tracking, background activity alerts, and multi-project switching, all without leaving the terminal.

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
|                                    |   camera firmware         3h |
|                                    |                              |
|                                    | ─ inactive ─                 |
|                                    | old-project                  |
|                                    |                              |
|                                    | N:new C:cls H:hide D:DEL     |
|                                    | F:manual-focus Q:detach      |
|                                    | claude-spaces v0.8.1-dev         |
+------------------------------------+------------------------------+
         left slot                    picker (30 cols default)
```

## Features

- Dedicated tmux server per project — isolated keybindings, bell hooks, window state
- Cross-server discovery — see and switch to sessions in other projects
- Inactive project discovery — resume projects that aren't currently running
- Bell detection — background sessions that finish are highlighted in red
- Custom session names, hide/delete, rename
- Auto-refresh with fingerprint-based dirty checking

## Requirements

- bash 4+
- tmux 3.0+
- jq

## Install

```
make install
```

Or to a custom location:

```
PREFIX=~/.local make install
```

### Development

Symlink to `~/.local/bin` so edits are live:

```
make dev
```

## Usage

```
claude-spaces          # Launch picker (inside or outside tmux)
claude-spaces --reset  # Kill all managed panes, clear state
claude-spaces --help   # Show help
```

## Keybinds

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
| `h` / `l` / `←` / `→` | Move between panes |
| `/` | Search/filter sessions |
| `:` | Command menu (new, rename, close, hide, delete, shutdown) |
| `Q` | Detach (exit) |
| `R` | Reload picker in-place (picks up code changes) |

### Prefix key bindings (from any pane)

| Key | Action |
|-----|--------|
| `prefix + Enter` | Focus Claude pane |
| `prefix + Space` | Toggle picker / Claude pane |
| `` prefix + ` `` | Smart terminal (open/close/focus) |
| `prefix + t` | Toggle terminal on/off (unconditional) |
| `prefix + a` | Literal grave (`` ` ``) |
| `prefix + j` / `prefix + ↓` | Next session + focus |
| `prefix + k` / `prefix + ↑` | Prev session + focus |
| `prefix + 1`-`9`, `0` | Jump to Nth local session (0 = 10th) + focus |
| `prefix + h` / `prefix + ←` | Select pane left |
| `prefix + l` / `prefix + →` | Select pane right |
| `prefix + /` | Focus picker + search |
| `prefix + c` | New session (create) |
| `prefix + x` | Close session (with confirm) |
| `prefix + r` | Reload picker |
| `prefix + z` | Zoom/maximize pane |
| `prefix + [` | Copy mode |
| `prefix + ]` | Paste buffer |
| `prefix + PgUp` | Copy mode + scroll up |
| `prefix + d` | Detach |
| `prefix + :` | Command menu (focus picker + open) |
| `prefix + Tab` | Refresh/rescan |
| `prefix + F12` | tmux command prompt (escape hatch) |
| `prefix + M-↑/↓` | Resize pane vertically |
| `prefix + M-←/→` | Resize pane horizontally |

## Bell Detection

Background sessions that finish can ring the terminal bell, highlighting them in red in the picker. This requires a Claude Code Stop hook.

Add to `~/.claude/settings.json`:

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

The `> /dev/tty` is critical — without it the bell doesn't reach tmux. Bell state clears when the session is brought to the foreground.

## Configuration

Config file: `~/.config/claude-spaces/config` (created on first run with commented defaults; respects `$XDG_CONFIG_HOME`).

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

# Terminal pane height: characters (e.g. 15) or percentage (e.g. 40%)
# terminal_height=40%

# Show jump index next to first 10 local sessions
# show_index=1

# Override tmux prefix key (default: inherited from tmux.conf)
# prefix=C-a

# Keybinding overrides (comma-separated for multiple keys)
# bind_terminal=`
# bind_toggle_terminal=t
# bind_focus_claude=Enter
# bind_nav_next=j
# bind_nav_prev=k
# bind_pane_left=h
# bind_pane_right=l
# bind_focus_picker=Space
# bind_detach=d
# bind_zoom=z
# bind_copy_mode=[
# bind_paste=]
# bind_search=/
# bind_new_session=c
# bind_close=x
# bind_reload=r
# bind_refresh=Tab
# bind_menu=:
```

Custom session names: `~/.local/share/claude-spaces/names` (`session_id=name`; respects `$XDG_DATA_HOME`)
Hidden sessions: `~/.local/share/claude-spaces/hidden` (one ID per line; respects `$XDG_DATA_HOME`)

## License

[MIT](LICENSE)
