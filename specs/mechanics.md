# Pane Swap, Bell Detection & Binding Lifecycle

Low-level tmux plumbing details.
Parent: [SPEC.md](../SPEC.md)

## Pane Swap

Each session runs in its own tmux pane. Only one is visible at a time. Others are parked in hidden tmux windows via `break-pane -d`.

### Swap operation (atomic)

```
_tmux break-pane -d -s $OLD -t $SESSION: \;
     join-pane -h [-b] -s $NEW -t $PICKER \;
     resize-pane -t $PICKER -x $PICKER_WIDTH \;
     select-pane -t $PICKER
```

The `-t $SESSION:` ensures parked panes stay in the correct tmux session. The `resize-pane` pins the picker width. WINCH handler re-pins on terminal resize.

### Swap with terminal pane

When the old session has a visible terminal, the terminal is parked first (extended chain):

```
_tmux break-pane -d -s $OLD_TERM -t $SESSION: \;
     break-pane -d -s $OLD -t $SESSION: \;
     join-pane -h [-b] -s $NEW -t $PICKER \;
     resize-pane -t $PICKER -x $PICKER_WIDTH \;
     select-pane -t $PICKER
```

After the main swap, if the new session has `term/<num>.shown`, its terminal is attached:
- Parked terminal exists: `join-pane -v -d -s $TERM -t $SESSION -l $HEIGHT`
- No terminal yet: `split-window -v -d -t $SESSION -l $HEIGHT`

Terminal height is saved per-session before parking (`term/<num>.height`).

### Focus behavior

Swaps keep focus on the picker. User explicitly focuses via `h`/`l`/arrows or second `Enter`.

## Bell Detection

Uses tmux's `alert-bell` hook. Requires a Stop hook in `~/.claude/settings.json`:
```json
{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "printf '\\a' > /dev/tty"}]}]}}
```

The `> /dev/tty` is critical. `#{window_bell_flag}` polling does NOT work (flag is momentary).

Bell state clears when the session is brought to the foreground. The bell hook is installed on picker startup and removed on exit/reset.

## Binding Lifecycle

claude-spaces takes full ownership of the tmux prefix key table. After sourcing
the user's tmux.conf (for visuals/mouse), the picker:

1. Captures the user's prefix via `show-options -gv prefix`
2. Optionally overrides it from the config file (`prefix=` key)
3. Wipes the entire prefix table: `unbind-key -a -T prefix`
4. Re-binds `send-prefix` for the captured prefix key
5. Installs all claude-spaces bindings via `cs_install_keybindings`

Only the prefix table (`-T prefix`) is wiped — root bindings (mouse, etc.)
and copy-mode bindings are preserved.

On cleanup (exit/reset/re-exec), `cs_remove_keybindings` wipes the prefix
table. Since the server is ephemeral, this is mainly for the `X` re-exec case.

All prefix bindings are configurable via `bind_*` keys in the config file.
The `cs_bind` helper resolves overrides and supports comma-separated multi-key
bindings. Compound bindings (focus picker + send trigger) bypass `cs_bind` and
use direct `_tmux` calls with `\;` chaining.

See SPEC.md § Keybinds for the full binding table.
