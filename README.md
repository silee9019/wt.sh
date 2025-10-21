# wt.sh

Small Bash wrapper around `git worktree` that makes it easy to spin up, inspect, and clean worktrees from a single directory.

## Features
- Auto-detects the primary repository or respects `WORKTREE_REPO`
- Creates worktrees in the script directory using branch-based folder names
- Falls back to sensible defaults (`origin/main`, `main`, or current branch) when creating new branches
- Supports listing, creating, removing, moving, and pruning worktrees with friendly aliases
- Strict error handling (`set -euo pipefail`) for predictable behaviour

## Installation
1. Clone or download this repository.
2. Make the script executable: `chmod +x wt`.
3. (Optional) Add the directory to your `PATH`, or symlink the script somewhere already on your `PATH`:
   ```bash
   ln -s /path/to/wt.sh/wt /usr/local/bin/worktree
   ```

## Usage
Run `wt help` (or `worktree help` if you renamed the script) to see the built-in usage guide.

```bash
Usage: worktree <command> [options]

Commands:
  list|ls|l [--porcelain]         List registered worktrees.
  create|add|new|c <branch> [--path DIR] [--from REF] [--force]
                                  Create a worktree (new branch if missing).
  remove|rm|delete|del|r <path|branch> [--force]
                                  Remove a worktree by path or branch name.
  move|mv|update|m <path|branch> <new-path>
                                  Move/rename a worktree directory.
  prune|p [--dry-run]             Prune stale worktree metadata.
  help|-h|--help                  Show this help message.
```

### Common workflows
- `wt ls` — inspect existing worktrees
- `wt new feature/login` — create a worktree for a new branch (auto-creates branch if missing)
- `wt rm feature/login` — remove a worktree by branch name or path
- `wt mv feature/login ~/src/login-worktree` — move a worktree to a new location
- `wt prune --dry-run` — check for stale worktree records without deleting anything

## Configuration
- `WORKTREE_REPO`: explicitly set the primary repository if auto-detection from the script location is not sufficient.

By default, new worktrees are created under the script directory using a sanitized version of the branch name. Pass `--path` to place the worktree anywhere else.

## Requirements
- Bash 4+
- Git with worktree support (Git 2.5+)

