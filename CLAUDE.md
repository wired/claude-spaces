# CLAUDE.md

## What is this

claude-spaces is a single-file bash script — a tmux-based session picker for Claude Code.
It provides a persistent side panel listing all sessions for the current project,
with cross-server discovery and seamless project switching.

## Files

- `claude-spaces` — the entire tool
- `run_tests` — integration tests (evals function definitions up to the `# ── Entrypoint` marker, mocks Claude with sleep panes)
- `SPEC.md` — specification overview (layout, keybinds, state machine, config, architecture)
- `specs/` — detailed specs (discovery, launch, mechanics, testing, future work)
- `Makefile` — `make install`, `make dev` (symlink), `make test`

## Architecture

### Dual-mode self-re-exec

Controlled by `CS_PICKER` and `CS_STATE_DIR` env vars:
- **Launcher mode** (default): `cs_launch()` — create/attach tmux session, loop for project switching
- **Picker mode** (`CS_PICKER=1`): `cs_picker_loop()` — TUI event loop

The `X` key re-execs the picker in-place, picking up code changes instantly.

### Dedicated tmux server per project

`TMUX_SERVER="cs${PWD//\//-}"`. ALL tmux calls go through `_tmux()` which adds `-L $TMUX_SERVER`.
For `exec` calls, use `cs_exec_tmux()` (bash functions can't be exec'd). Never call `tmux` directly.

### Entry arrays (parallel arrays, not structs)

Session list is stored as parallel arrays: `ENTRIES_ID`, `ENTRIES_NAME`, `ENTRIES_MTIME`,
`ENTRIES_STATUS`, `ENTRIES_PANE`, `ENTRIES_TYPE`, `ENTRIES_PATH`. Always use `cs_entry_append`,
`cs_entry_prepend`, `cs_entry_clear` — all expect exactly 7 args (enforced in test mode).

### State dir is ephemeral

`${XDG_RUNTIME_DIR:-/tmp}/claude-spaces/<sanitized-cwd>/` — runtime only, wiped on reboot.
Stale pane refs are cleaned up automatically on picker startup.

### Pane existence checking

Uses cached `_tmux list-panes -a` result (`LIVE_PANES`), refreshed once per scan cycle.
Pure bash string matching. Do NOT use `tmux display-message -t PANE_ID` — it silently
falls back to the current pane on miss.

## Things that are easy to break

- **Atomic pane swap**: the break-pane + join-pane + resize-pane sequence must be a single
  `_tmux` call (semicolon-chained). Splitting it causes flicker and race conditions.
- **Bell detection**: requires a Claude Code Stop hook with `> /dev/tty`. The `#{window_bell_flag}`
  approach does NOT work (flag is momentary). See specs/mechanics.md § Bell Detection.
- **`~/.claude/sessions/`**: this is Claude Code's own session tracking dir, not ours. Don't rename it.

## Testing

```
make test
```

Tests create an isolated tmux server (`cs-test-$$`), source the script's functions, and mock
`cs_new_session`/`cs_resume_session` with sleep panes. They validate state invariants after
each operation. Requires a real tmux — nothing is mocked at the tmux level.

## Conventions

- All functions prefixed `cs_`
- `_tmux` for all tmux calls (never bare `tmux`)
- Config in `~/.claude/claude-spaces.conf`, names in `claude-spaces-names.conf`, hidden in `claude-spaces-hidden.conf`
- Bash 4+ required (associative arrays)

## Versioning

Version string lives in four places: `claude-spaces` (header comment + `VERSION=`), `README.md`
(layout diagram), `SPEC.md` (layout diagram). All four must stay in sync.

Strategy: **bump-on-open, default patch.**

- After tagging a release (e.g. `v0.8.0`), immediately bump master to `0.8.1-dev`.
- Default next version is always a patch (Z) bump. Y and X bumps are intentional choices
  for significant features or stability milestones.
- To release: drop the `-dev` suffix, commit, tag, then bump to next patch-dev.
- No CHANGELOG file — `git log` is the changelog.

## Documentation

README.md documents keybinds, configuration options, and bell detection setup.
When changing keybinds, config keys, or user-facing features in the source, update
README.md to match. SPEC.md is the authoritative overview; specs/ subfiles have detailed
mechanics. When updating spec content, check both SPEC.md and the relevant subfile for drift.
