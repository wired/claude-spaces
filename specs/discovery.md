# Discovery & Cross-Server Switching

Details for session scanning, name resolution, remote/inactive discovery, and cross-server switching.
Parent: [SPEC.md](../SPEC.md)

## Session Discovery

Session data lives in `~/.claude/projects/<sanitized-path>/*.jsonl`. Metadata extracted from the first 20 lines via `head -20 | jq`:

- **First user message**: `type == "user"`, `message.content` is a string, first line extracted
- **Session ID**: UUID from the filename
- **Last activity**: file mtime via `stat -c %Y`

### Display Name Resolution (priority order)

1. Custom name from `~/.local/share/claude-spaces/names` (`session_id=name`)
2. First user message, cleaned:
   - First line only
   - Leading filler stripped: "I want to", "Can you", "Please", "Hey", "Hi", "Could you", "I need to", "Help me", "I would like to"
   - Truncated to fit available width with `...` suffix
3. First 8 characters of session UUID as fallback

### Active-Elsewhere Detection

Files in `~/.claude/sessions/*.json` track running Claude processes. `kill -0 $pid` verifies the process is alive. Matching sessions are marked as locked.

### Hidden Sessions

Hidden via `H`, stored in `~/.local/share/claude-spaces/hidden` (one ID per line). Applied globally across all projects (local and remote scans both filter against it).

## Scan Orchestration

`cs_build_all_entries()` orchestrates:
1. Local scan (`cs_scan_sessions`) — every 1s
2. Remote discovery (`cs_discover_servers` + `cs_scan_project_sessions`) — every 5s, cached between scans
3. Inactive discovery (`cs_discover_inactive`) — every 5s, cached

### Auto-refresh

Local sessions rescanned every 1 second. Fingerprint comparison (IDs, statuses, mtimes, types, picker focus) prevents unnecessary re-renders. Selection follows sessions across re-sorts (tracked by ID).

### Pane Existence Checking

Uses `_tmux list-panes -a -F '#{pane_id}'` with a cached result (`LIVE_PANES`). Pure bash string matching — no subprocess per check. Cache refreshed once per scan cycle. `tmux display-message -t PANE_ID` is NOT reliable for existence checks (falls back to current pane on miss).

## Remote Discovery

Remote server detection: enumerate `cs-*` sockets in the tmux socket dir, check `has-session`, read `project_path` from state dir.

For each remote server:
- Reads `project_path` from the remote server's state dir
- Scans the remote project's JSONL files for session names and mtimes
- Checks the remote server's `panes/*` files to determine managed vs dormant status
- Sessions sorted by mtime descending within each project

## Inactive Discovery

Discovered from `~/.claude/projects/*/` dirs that have JSONL files but no running `cs-*` socket. Shows project name only (leaf of path).

Path resolution: reads `project_path` from state dir if available, or extracts `cwd` from the first JSONL file as fallback. Projects with unresolvable or deleted paths are skipped.

## Cross-Server Switching

Selecting a remote project or session: writes `switch_target` (and optionally `pending_load` for a specific session) to the state dir, then detaches. The launch loop picks up the switch and reattaches to the target server.

See [launch.md](launch.md) for the launch loop that consumes `switch_target`.
