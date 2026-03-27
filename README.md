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
|                                    | claude-spaces v0.8.0         |
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

### Picker pane

| Key | Action |
|-----|--------|
| `j` / `↓` | Move cursor down (skips headers) |
| `k` / `↑` | Move cursor up (skips headers) |
| `Enter` | Local: load session (press again to focus). Remote/inactive: switch project. |
| `h` / `l` / `←` / `→` | Load + focus session immediately (local only) |
| `N` | New session |
| `C` | Close running pane (keeps session on disk) |
| `H` | Hide session (with confirm) |
| `D` | Delete session permanently (with confirm) |
| `R` | Rename session |
| `r` | Refresh (force remote rescan) |
| `F` | Toggle auto-focus mode |
| `Q` | Detach (exit) |
| `X` | Reload picker in-place (picks up code changes) |

### Global tmux bindings

| Key | Action |
|-----|--------|
| `prefix + j` / `prefix + ↓` | Next local session + focus |
| `prefix + k` / `prefix + ↑` | Prev local session + focus |
| `prefix + Tab` | Toggle focus between session and picker |

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

Config file: `~/.claude/claude-spaces.conf` (created on first run with commented defaults).

```ini
# Picker pane width: characters (e.g. 30) or percentage (e.g. 20%)
# picker_width=30

# Picker pane position: "right" (default) or "left"
# picker_side=right

# Sort order: bell = belled first, mtime = most recent first
# sort_by=bell,mtime

# Enter key focuses session immediately: 0 (default, load only) or 1 (load + focus)
# enter_focuses=0

# Max length for tmux window names
# window_name_len=12

# Path to tmux.conf to source on dedicated server (empty = don't source)
# tmux_conf=~/.tmux.conf
```

Custom session names: `~/.claude/claude-spaces-names.conf` (`session_id=name`)
Hidden sessions: `~/.claude/claude-spaces-hidden.conf` (one ID per line)

## License

[MIT](LICENSE)
