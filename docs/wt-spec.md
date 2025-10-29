# wt CLI Specification

## Overview

This document specifies the behaviour of the `wt` Bash script, which serves as a wrapper around `git worktree` to facilitate managing Git worktrees in a structured manner. It outlines the expected functionality, configuration, and error handling for users and developers interacting with the `wt` command-line interface.

## Conventions

- Anchor explanations in this specification; only reference implementation specifics when they clarify or highlight divergence from the documented contract.
- Treat `.wt` marker invariants as non-negotiable: both `marker_base_dir` and `primary_repo_dir` keys must exist, and `marker_base_dir` must equal the containing marker directory.
- When discussing derived directories, prefer the spec identifiers `WT_MARKER_BASE_DIR` and `WT_PRIMARY_REPO_DIR`, while cross-referencing the current script variables (`WORKTREE_BASE_DIR`, `REPO_DIR`) where helpful.
- Distinguish paths, branch names, and sanitized filesystem names explicitly, describing how user input maps to on-disk directories.
- Cover marker discovery, validation, and error handling with the same level of precision the script enforces.
- Apply general documentation practices: use concise American English, backticks for commands and flags, and fenced code blocks with info strings for multi-line snippets.

## Scope

- Defines the behaviour of the `wt` Bash entrypoint that wraps `git worktree`.
- Covers runtime prerequisites, configuration markers, command contract, and failure conditions.
- Applies to invocations executed from any directory within or below a `.wt` marker directory.

## Terminology

- **Marker directory**: Directory that contains `.wt`. New worktrees are created as children here.
- **Repository directory**: Absolute path recorded in `.wt` under `primary_repo_dir:`. All Git commands run with `git -C <primary_repo_dir>`.
- **Marker file (`.wt`)**: Two required key/value entries:
  ```
  # wt base marker
  marker_base_dir: <absolute path of marker directory>
  primary_repo_dir: <absolute path of primary repository>
  ```
  `marker_base_dir:` must match the marker directory. `primary_repo_dir:` must resolve to a path whose `.git` exists.

## Marker Discovery and Validation

- On every command (except `init` without an existing marker), `wt` searches from `$PWD` upward for the nearest `.wt`.
- The marker is parsed; whitespace is trimmed; comment fragments (`# ...`) and blank lines are ignored.
- Relative `marker_base_dir:` or `primary_repo_dir:` entries are resolved based on the marker location.
- The resolved `marker_base_dir:` must equal the directory holding `.wt`; otherwise the command aborts.
- The resolved `primary_repo_dir:` must exist and contain `.git`; otherwise the command aborts.
- After validation, the script captures:
  - `WT_MARKER_BASE_DIR`: absolute path of the marker directory
  - `WT_PRIMARY_REPO_DIR`: repository path used for all Git commands

## Repository Auto-Detection (for `init`)

- If `wt init` omits `--repo`, the script attempts:
  1. `git rev-parse --show-toplevel` from the current shell. Success short-circuits detection.
  2. Scan the candidate base directory and its first-level children for entries containing `.git`.
- If exactly one candidate has a dedicated `.git/` directory, it is selected automatically.
- If multiple repositories are discovered (or none), the command aborts and the user must supply `--repo`.

## Path Naming Rules

- Target worktree directory path is `WT_MARKER_BASE_DIR/` plus a sanitized copy of the full branch name available on file system.

## Default Base Branch Resolution

- When `wt add` omits `<base-branch>`, the script chooses in order:
  1. `origin/main` if the ref exists.
  2. `main` (local).
  3. Current branch (`git rev-parse --abbrev-ref HEAD`).

## Command Contracts

The CLI only implements the commands documented below.

### `wt list | wt ls [--porcelain]`

- Requires a validated marker.
- Runs `git worktree list` with optional flags passed through verbatim.
- Exit status mirrors the underlying Git command.

### `wt branch <new-branch> <base-branch>`

- Requires a validated marker.
- Both parameters are required and trimmed.
- Runs `git branch <new-branch> <base-branch>` in the repository with --no-track.

### `wt add <branch>`

- Requires a validated marker.
- Decides target directory as described in "Path Naming Rules".
- Rejects if the target directory already exists.
- Runs `git worktree add '$WORKTREE_BASE_DIR/<sanitized-branch-name>' <branch>`.

### `wt remove | wt rm <dir>`

- Accepts either an absolute path or a directory name relative to the marker base.
- Resolves the directory:
  - Directories that already exist on disk are accepted as-is.
  - Otherwise the script checks `<base>/<dir>`.
- Delegates to `git worktree remove <resolved-path>`.

### `wt init [dir] [--repo PATH]`

- `dir` defaults to `$PWD` and may be relative; it is created if missing.
- Resolves both `dir` and `PATH` (when present) to absolute paths.
- When `--repo` is omitted, uses repository auto-detection as described earlier.
- Validates that the target repository path contains `.git`.
- Writes (or overwrites) `<dir>/.wt` with the canonicalized marker and repository paths.
- Prints a one-line confirmation: `Marked <marker_base_dir> for new worktrees (repo: <primary_repo_dir>).`

### `wt -h | wt --help`

- Prints the usage block defined in the script and exits with status `0`.

## Error Handling Guarantees

- The script runs with `set -euo pipefail`; any unset variables, failed commands, or pipeline errors abort execution.
- `die()` reports errors to `stderr` prefixed with the script name and exits with code `1`.
- Unexpected command-line flags or missing required parameters cause immediate termination with a descriptive message.
- Marker discovery failure instructs the user to run `wt init` before issuing other commands.

## Dependencies and Environment

- Requires Bash (invoked via `#!/usr/bin/env bash`) and Git with worktree support.
- All Git operations execute with `git -C "$REPO_DIR"` ensuring consistent repository context.
- The script is self-contained and does not rely on external configuration beyond the `.wt` marker.
