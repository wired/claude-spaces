# Testing

Details for the test infrastructure.
Parent: [SPEC.md](../SPEC.md)

## Overview

`run_tests` — integration tests.

1. Runs `shellcheck` (static analysis gate)
2. Sources function definitions (up to the `# ── Entrypoint` marker), installs mocks (sleep panes instead of real Claude)
3. Creates isolated tmux test server (`cs-test-$$`)
4. Exercises operations, validates state invariants after each (`cs_assert_consistent`)
5. Checks: pane liveness, pane counts, orphaned windows, state file consistency, and the **slot invariant**

Requires a real tmux — nothing is mocked at the tmux level.

## The slot invariant

Every session window must hold exactly one slot occupant: the **picker** if that session is
shown, otherwise exactly one **tagged filler**. A parked session with no filler is unreachable
(`cs_show_pane` has nothing to swap into); one with two has lost columns permanently.

Because the mocks create session panes directly, they must also call `cs_make_filler` — a mocked
session born without a filler would land in a window `cs_show_pane` cannot swap into.

The "orphaned windows" check doubles as the reaper's test: a lone-filler window is tracked by
nothing, so any window the reaper fails to collect shows up as untracked.
