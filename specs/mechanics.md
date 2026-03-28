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

Global tmux bindings (`prefix + j/k/↑/↓/Tab`) are installed on picker startup and cleaned up on exit/reset. Arrow keys are restored to their default pane navigation behavior on cleanup.
