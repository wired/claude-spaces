# Testing

Details for the test infrastructure.
Parent: [SPEC.md](../SPEC.md)

## Overview

`run_tests` — integration tests.

1. Runs `shellcheck` (static analysis gate)
2. Sources function definitions (up to the `# ── Entrypoint` marker), installs mocks (sleep panes instead of real Claude)
3. Creates isolated tmux test server (`cs-test-$$`)
4. Exercises operations, validates state invariants after each (`cs_assert_consistent`)
5. Checks: pane liveness, pane counts, orphaned windows, state file consistency

Requires a real tmux — nothing is mocked at the tmux level.
