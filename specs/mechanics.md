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

Global tmux bindings are installed on picker startup and cleaned up on exit/reset.

Spatial focus keys (QWERTY layout):
- `prefix + r` — focus session (sends `|` to picker)
- `prefix + f` — focus terminal (sends `` ` `` to picker, opens if needed)
- `prefix + t` / `prefix + Tab` — focus picker (direct `select-pane`)
- `prefix + F` — toggle terminal (sends `~` to picker)
- `prefix + j/k/↑/↓` — session navigation (sends `J`/`K` to picker)

Arrow keys and `prefix+r` are restored to tmux defaults on cleanup. `prefix+e/E` reserved for future context pane.
