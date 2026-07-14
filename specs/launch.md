# Launch Loop & State Management

Details for launch behavior, re-attach, stale cleanup, reset, and runtime state.
Parent: [SPEC.md](../SPEC.md)

## Launch Behavior

`cs_launch()` runs a loop:
1. If a server is already running but its `compat_version` doesn't match `CS_COMPAT_VERSION`, print the update notice (see § Compatibility Gate) — but do not touch it
2. Create tmux session on the dedicated server (if not already running)
3. Source tmux.conf
4. Attach (blocks until detach)
5. On detach: check for `restart_required` — if present, print the restart message and exit
6. Check for `switch_target` — if present, `cd` to the target path, update `TMUX_SERVER`, and loop back to step 1 (project switching)
7. Otherwise: exit (normal detach via `Q`)

### Re-attach

Running `claude-spaces` again from the same directory attaches to the existing session on that project's server.

### Compatibility Gate

`CS_COMPAT_VERSION` is a constant in the script, bumped for **any** change a running server
cannot survive (tmux topology, state-file format). It is stamped into
`${STATE_DIR}/compat_version`. New code never migrates an old server; it detects and restarts.

`cs_init_state` stamps **exactly when there is no live picker** — i.e. only when it is the thing about to
build the topology. Keying this on "is the state dir fresh" instead causes a **boot loop**:
`picker_pane` is written by the picker itself (later), so a state dir can exist without one,
would never be stamped, and the gate would then kill every server it starts.

Two entry points can put new code in front of an old server:

- **`R` (hot reload)** re-execs the picker in place. The new picker finds the mismatch, writes
  `restart_required`, and kills the server. It prints nothing — it is a pane *inside* the server
  it is killing, so anything it wrote would die with it. It must **not** wipe the state dir
  (unlike `cs_confirm_shutdown`), or the marker would be lost and the user would be dumped to a
  bare shell with no explanation. `cs_launch` prints the message once `attach-session` returns.
- **Re-running `claude-spaces`** against a live stale server. This is **non-destructive**:
  it prints a notice pointing at `prefix+R` or `claude-spaces --restart`, then attaches to the
  still-running old picker. Silently killing a live server because the user ran the launcher
  would be a nasty surprise.

Conversations are Claude's own JSONL transcripts and are never touched by a restart; sessions
come straight back in the picker as resumable. Custom names and hidden flags live in
`CS_DATA_DIR` and also survive.

### Stale State Cleanup

On picker startup, validates all pane IDs in the state dir. Dead refs are removed automatically. No `--reset` needed after tmux restart.

### Reset and Restart

`claude-spaces --reset` kills all managed panes, clears the state dir, and starts clean.

`claude-spaces --restart` does the same and then relaunches. This is the non-interactive way to
apply an update that bumped `CS_COMPAT_VERSION`.

## Runtime State

Directory: `<state-root>/<sanitized-cwd>/`, where `<state-root>` is
`${XDG_RUNTIME_DIR}/claude-spaces`, or `/tmp/claude-spaces-${UID}` when
`XDG_RUNTIME_DIR` is unset (UID-suffixed so shared hosts don't collide).

The `state_root` config key overrides both, for hosts that reap `/tmp` while
sessions are live. It must be an absolute path (leading `~/` is expanded);
relative paths and `$HOME` itself are rejected with a warning and the default is
kept. An unusable root is a hard failure at launch, never a silent fallback —
falling back would fragment `.servers/` across two roots, making live sessions
invisible to the picker.

Ephemeral by default. Stale refs cleaned up on picker startup: `cs_init_state`
wipes the whole state dir when the recorded `picker_pane` is dead, which is what
makes a persistent `state_root` safe across reboots (a fresh tmux server restarts
pane IDs at `%0`, so stale `panes/<num>` entries must not survive). The same call
stamps `compat_version` whenever there is no live picker — see § Compatibility
Gate. Other projects' dirs and `.servers/` symlinks persist but are inert —
discovery gates on a live socket and `has-session`.

| File              | Contents                                    |
|-------------------|---------------------------------------------|
| `panes/<num>`     | Session ID for tmux pane `%<num>`           |
| `picker_pane`     | Pane ID of the picker                       |
| `compat_version`  | `CS_COMPAT_VERSION` this server's topology was built with |
| `restart_required` | Marker: picker found an incompatible server and killed it |
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
