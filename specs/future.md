# Future Work

Parent: [SPEC.md](../SPEC.md)

- **Two-tier sort**: Active sessions (< 10m) sorted alphabetically (stable), inactive sorted by mtime
- **Unhide**: UI to restore hidden sessions
- **Session forking**: Use `claude --fork-session` to branch from an existing session
- **Search/filter**: Type to filter session list
- **Idle detection**: Show whether Claude is working or waiting for input
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
