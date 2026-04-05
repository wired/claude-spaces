# Future Work

Parent: [SPEC.md](../SPEC.md)

- **Session forking**: Use `claude --fork-session` to branch from an existing session
- **tmux capture-pane preview**: Show last few lines of a session without switching to it

### Context Pane

Per-session pane to the side of the Claude session. Displays plans, code, or other
context pushed by a Claude skill.

**Decided:**
- Per-session (same as terminal — travels with session on swap, parked in hidden windows)
- Layout: `[ context | session | picker ]` top, `[ terminal ]` below context+session
- Keybinds: `prefix+e` focus (open if needed), `prefix+E` toggle visibility
- Side configurable (left of session default, option for right)
- State: `context/<session_pane_num>`, `.shown`, mirroring `term/` pattern
- Swap chain: extends the same break/join pattern as terminal

**Open:**
- Content delivery: how the Claude skill gets content into the pane
  - File watcher (`tail -f` on state file)?
  - Process replacement (skill kills old process, starts `bat`/`glow` with new content)?
  - Named pipe / FIFO?
- What viewer runs in the pane (plain cat, bat for syntax, glow for markdown)
- Whether the pane should clear on session switch or show last content

### Jump Index Priority Mode

Currently, jump shortcuts (1-0) prioritize active sessions (local managed/active_elsewhere,
remote managed/bell), then fill remaining slots with dormant in display order. This works
well in practice but can let one remote project hog slots when many projects are discovered.

Evaluate whether a `jump_priority=local` config option is needed — it would assign all local
sessions first (regardless of status), then fill remaining slots with active remote sessions.
Simpler mental model, avoids cross-project fairness issues, but loses the "active first"
guarantee that makes the current default useful.

### Shared Per-Project Terminal

One shell shared across all sessions in a project, instead of per-session terminals.
Visibility is global (open/closed applies to all sessions). Controlled by `terminal_shared=1`
config option.

**Approach:** Add a `cs_term_state_key` helper that redirects all `STATE_DIR/term/` file paths
from per-session keys to a fixed `shared` key. The atomic swap chain in `cs_show_pane` is
unchanged — it already parks the terminal if shown and reattaches after swap. `cs_term_kill`
becomes a no-op in shared mode (terminal only dies via `cs_reset`). ~15-20 lines of changes.

**Why not yet:** Per-session terminals work fine. Only implement if testing shows a shared
shell is actually needed.

### Worktree-Aware Session Isolation

**Problem:** Multiple concurrent Claude sessions in the same project can step on each other's files.

**Approach:** Leverage git worktrees. Users create worktrees themselves (`git worktree add ../project-feat`), then run `claude-spaces` from inside. Each worktree gets its own tmux server, state dir, and Claude project dir — full isolation with zero code changes (works today).

**Enhancement (v1):** The picker detects it's inside a worktree via `git worktree list`, discovers sibling worktrees and the main checkout by looking for matching `cs-*` tmux sockets, and groups them under a shared header:

```
─ worktrees: claude-spaces ─
main
  refactor picker              2h
  fix bell detection           5m
feat-hierarchical-view
  implement grouping           1h
  write tests                 30m
```

This reuses the existing cross-project discovery and server-switching machinery. The only new code is a worktree discovery source in the scan logic (~15-20 lines) and a grouping header in the renderer.

**Why not yet:** No immediate need. The zero-change version already works for users who want isolation. The picker enhancement is low-effort when the time comes.

**Key design decisions:**
- Each worktree is its own project (own tmux server, own state dir) — no session-discovery hacks
- Switching between worktrees uses the existing detach/reattach server-switch mechanism
- Worktree siblings get a dedicated section with nesting (repo name → worktree → sessions)
