# wt.sh

Small Bash wrapper around `git worktree` that makes it easy to spin up, inspect, and clean worktrees from a single directory.

## Features

- Auto-detects `.wt` markers to locate the primary repository and base directory
- Creates worktrees under the marker directory using branch-based folder names
- Falls back to sensible defaults (`origin/main`, `main`, or current branch) when creating new branches
- Provides straightforward commands for listing, adding, removing, moving, and pruning worktrees
- Strict error handling (`set -euo pipefail`) for predictable behaviour

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/silee9019/wt.sh.git
   ```
2. Enter the directory:
   ```bash
   cd wt.sh
   ```
3. Run the installer:
   ```bash
   ./install.sh
   ```

## Usage

Run `wt help` to see the built-in usage guide.

### CLI usage

```bash
wt add feature-branch
wt ls
wt move dev dev-old
wt remove dev-old
wt prune --dry-run
wt init --repo ./main
```

### Common workflows

- `wt ls` — inspect existing worktrees
- `wt add feature-branch` — create a worktree for a new branch (auto-creates branch if missing; directory defaults to the branch name)
- `wt rm release-staging` — remove a worktree by directory name
- `wt mv release-staging release-staging-old` — move/rename a worktree directory within the base
- `wt prune --dry-run` — check for stale worktree records without deleting anything
- `wt init` — mark the current directory as the worktree home (auto-detects the primary repo when possible)

## Configuration

- `wt init [dir] --repo /path/to/repo`: create or update the `.wt` marker that links a base directory to the primary repository (defaults to the current directory when `dir` is omitted; without `--repo`, the command attempts to auto-detect a repository within the base directory).
- `.wt`: YAML marker file placed in the chosen base directory; any descendant directory can run `wt` and will use the closest marker it finds.

All commands require a `.wt` marker. The marker's directory becomes the default location for new worktrees; use `--path` with `wt add` if you need a one-off destination elsewhere.

## Requirements

- Bash 4+
- Git with worktree support (Git 2.5+)
