# Pane Swap, Bell Detection & Binding Lifecycle

Low-level tmux plumbing details.
Parent: [SPEC.md](../SPEC.md)

## Pane Swap

**The picker travels; Claude never moves.**

Every session permanently owns one tmux window, laid out `[claude (+ its terminal) | slot]`.
The slot is `PICKER_WIDTH` wide and holds either the picker pane or a **filler** pane — a
`sleep` placeholder tagged with the tmux pane option `@cs_filler`. Exactly one window holds
the picker; every other session window holds exactly one filler.

### Swap operation (atomic)

```
_tmux swap-pane -d -s $PICKER -t $TARGET_FILLER \;
     select-window -t $TARGET_WIN \;
     select-pane -t $PICKER
```

`$TARGET_FILLER` is the tagged pane currently in the target session's window, resolved by
`cs_filler_for`. The picker and the filler are identical geometry, so **nothing resizes**.
A `resize-pane -x $PICKER_WIDTH` follows outside the chain, in case the slot drifted while
that session was parked (see § Drift).

### Why: zero SIGWINCH

tmux reflows a pane's scrollback whenever its **width** changes, and Claude's renderer repaints.
The previous design parked the outgoing session with `break-pane -d`, which put it alone in a
new window at full width — so the Claude pane oscillated `169 → 200` on park and `200 → 169` on
unpark: **two reflows per swap**, four for a session with a side terminal.

Swapping the narrow picker instead costs zero. Measured with a real Node/libuv resize consumer:

| swap | outgoing claude | incoming claude | terminals | picker |
|---|---|---|---|---|
| plain → plain           | 0 | 0 | — | 0 |
| plain → bottom-terminal | 0 | 0 | 0 | 0 |
| bottom-term → side-term | 0 | 0 | 0 | 0 |

This is also the only arrangement that keeps a terminal glued to its session. Swapping the
*Claude* panes instead breaks: a side terminal splits Claude's cell (e.g. to 119 columns), so the
incoming Claude lands in a mis-sized cell and the outgoing terminal is stranded beside the wrong
session.

### Terminal panes

Terminals **stay in their session's window** across a swap — there is no park/reattach at all.
`cs_show_pane` still calls `cs_term_save_size` for the outgoing session (it moves no panes, so it
costs no winch); without it, `cs_handle_winch` would revert a manually-resized terminal to the
stored ratio on the next SIGWINCH.

`cs_term_hide` still breaks a hidden terminal out into its own `cs:term` window. Those windows are
untagged, so the reaper spares them.

### Fillers permute

`swap-pane` deposits the target's filler into the picker's *previous* window. Fillers are
therefore fungible and move between windows — there is no stable "session X's filler". It must
be resolved dynamically at swap time (`cs_filler_for`); a cached mapping strands the picker in a
hidden window after two swaps.

### Reaping

A window whose panes are **all** tagged `@cs_filler` is garbage and is killed by
`cs_reap_fillers`. This happens after a swap (`cs_show_pane`), after a close/hide
(`cs_after_remove`), and when the welcome pane is torn down (`cs_kill_welcome`).

Conservative by construction: a live Claude pane is never tagged, so a window holding one can
never be all-tagged. The reaper also skips the picker's own window. Orphan filler windows are
inert between reaps — invisible (`window-status-format` is blank), never targeted, and with no
effect on any other window's geometry.

**Reap after the swap, never before**: beforehand, the window about to be orphaned still holds
the picker and does not look like garbage.

### Drift

Under `window-size latest`, resizing the outer terminal resizes *every* window, including parked
ones, so their slots drift off `PICKER_WIDTH`. The next show re-pins the picker, which costs that
session one winch — the same cost as the old design paid on every swap — and it self-heals
permanently.

### Empty targets are a hazard

`kill-pane -t ""`, `swap-pane -t ""`, `swap-pane -s ""`, `split-window -t ""` and
`kill-window -t ""` all silently act on the **active** pane/window and exit 0. `kill-window -t ""`
destroys the picker and the live Claude beside it. `display-message -t ""` also resolves to the
active pane and returns a non-empty window id, so it cannot be used as a guard. Every target in
the swap path is explicitly guarded non-empty.

### Focus behavior

Swaps keep focus on the picker. User explicitly focuses via `hjkl`/arrows or second `Enter`.

## Bell Detection

Uses tmux's `alert-bell` hook. Requires a Stop hook in `~/.claude/settings.json`:
```json
{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "printf '\\a' | jq -Rsc '{terminalSequence: .}'"}]}]}}
```

Claude Code hooks run without a controlling terminal (v2.1.139+), so `> /dev/tty` fails with
`No such device or address`. The bell must be returned in the `terminalSequence` field (v2.1.141+),
which Claude Code emits through its own terminal write path — landing on the pane's tty, where tmux
sees it. `jq` does the JSON encoding because a raw BEL byte is not valid inside a JSON string; it
must be escaped as `\u0007`. `#{window_bell_flag}` polling does NOT work (flag is momentary).

Bell state clears when the session is brought to the foreground, or when the terminal window regains focus (via `client-focus-in` hook, requires `focus-events on` which the picker sets automatically). Switching away from the active pane also clears its bell (outgoing clear in `cs_show_pane`). The bell hook is installed on picker startup and removed on exit/reset.

### Cross-project bells

When a bell fires, the owning picker writes `${STATE_DIR}/bells_active` — a list of session UUIDs with active bells, derived from the in-memory `BELL_SET` (pane-keyed) via `cs_sync_bells_active()`. Remote pickers read this file during `cs_scan_project_sessions()` and set `status="bell"` on matching entries, rendering them in the bell color. The file is updated on bell add and bell clear only (not per-cycle).

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
