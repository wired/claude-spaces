# Launch Loop & State Management

Details for launch behavior, re-attach, stale cleanup, reset, and runtime state.
Parent: [SPEC.md](../SPEC.md)

## Launch Behavior

`cs_launch()` runs a loop:
1. Create tmux session on the dedicated server (if not already running)
2. Source tmux.conf
3. Attach (blocks until detach)
4. On detach: check for `switch_target` file — if present, `cd` to the target path, update `TMUX_SERVER`, and loop back to step 1 (project switching)
5. If no switch target: exit (normal detach via `Q`)

### Re-attach

Running `claude-spaces` again from the same directory attaches to the existing session on that project's server.

### Stale State Cleanup

On picker startup, validates all pane IDs in the state dir. Dead refs are removed automatically. No `--reset` needed after tmux restart.

### Reset

`claude-spaces --reset` kills all managed panes, clears the state dir, and starts clean.

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
| `new_pane_auto_name` | Auto-name for forked session (presence = fork) |
| `bells`           | Pane IDs that belled (written by alert-bell hook) |
| `project_path`    | Real filesystem path for this project       |
| `switch_target`   | Target path for cross-server switching      |
| `pending_load`    | Session ID to auto-load on the target server |
| `term/<num>`       | Terminal pane ID for session pane `%<num>`  |
| `term/<num>.shown`  | Presence = terminal should be visible      |
| `term/<num>.height` | Runtime height override (percentage)       |
| `term/<num>.width`  | Runtime width override (percentage)        |
| `term/<num>.orient` | Orientation: `bottom` or `side`            |

See [discovery.md](discovery.md) for how `switch_target` and `pending_load` are written.

## Persistent Files

| File                                      | Purpose                                     |
|-------------------------------------------|---------------------------------------------|
| `~/.config/claude-spaces/config`         | Configuration (key=value, comments with #)  |
| `~/.local/share/claude-spaces/names`     | Custom session names (`session_id=name`)    |
| `~/.local/share/claude-spaces/hidden`    | Hidden session IDs (one per line, `H` key)  |

Paths respect `$XDG_CONFIG_HOME` and `$XDG_DATA_HOME`.
