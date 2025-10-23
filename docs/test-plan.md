# WT Test Plan

## Objectives
- Validate primary workflows (`init`, `add`, `list`, `move`, `remove`, `prune`) exposed by the `wt` script.
- Confirm marker discovery logic works from descendant directories.
- Ensure path sanitisation and branch bootstrapping behave correctly when creating new worktrees.

## Assumptions
- Tests execute on macOS or Linux with Bash 4+, Git 2.5+.
- Source tree remains writable; tests may create and delete temporary directories.
- Network access is not required.

## Test Environment
- Runner: local shell using `bash`.
- Script under test: `wt` at repository root.
- Temporary fixtures: generated per test via `mktemp -d`, removed on completion.

## Test Cases

| ID | Scenario | Steps | Expected Result |
| -- | -------- | ----- | ---------------- |
| TC1 | Initialise marker with explicit repo | 1. Create git repo with initial commit. 2. Run `wt init <base> --repo <repo>`. | `.wt` file exists with absolute `base` and `repo`; console confirms setup. |
| TC2 | Add new branch worktree with default path | 1. Using TC1 fixture, run `wt add feature --id ticket-1234 --title "Fix Email BUG"`. | Worktree directory created under base with branch checked out; branch exists in repo; directory name sanitised (`feature-TICKET-1234-fix-email-bug`). |
| TC3 | List worktrees | After TC2, execute `wt ls --porcelain`. | Output contains the added worktree path. |
| TC4 | Move worktree to new relative path | 1. Using TC2 fixture, run `wt move feature-TICKET-1234-fix-email-bug moved`. | Worktree relocated to `<base>/moved`; `git worktree list` reflects new path. |
| TC5 | Remove worktree | 1. Using TC4 fixture, run `wt rm moved`. | Worktree directory deleted and `git worktree list` no longer lists the entry. |
| TC6 | Prune dry run | 1. Using TC1 fixture, run `wt prune --dry-run`. | Command exits successfully, no destructive action performed. |
| TC7 | Marker discovery from subdirectory | 1. `cd` into nested child under base. 2. Run `wt ls`. | Marker is resolved via upward search; command succeeds. |

## Exit Criteria
- All automated tests pass.
- Discovered defects are addressed or documented.
- Test summary and outcomes recorded separately.
