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
   ln -s /path/to/wt.sh/wt /usr/local/bin/wt
   ```

## Usage

Run `wt help` to see the built-in usage guide.

```bash
Usage: wt <command> [options]

Commands:
  list|ls|l [--porcelain]         List registered worktrees.
  create|add|new|c <branch> [--path DIR] [--from REF] [--force]
                                  Create a worktree (new branch if missing).
  remove|rm|delete|del|r <dir> [--force]
                                  Remove a worktree directory.
  move|mv|update|m <dir> <new-path>
                                  Move/rename a worktree directory.
  prune|p [--dry-run]             Prune stale worktree metadata.
  init [dir] [--repo PATH]        Mark a directory for new worktrees; supply --repo when outside the repo.
  help|-h|--help                  Show this help message.
```

### Common workflows

- `wt ls` — inspect existing worktrees
- `wt new feature/login` — create a worktree for a new branch (auto-creates branch if missing; directory defaults to the branch name)
- `wt rm release-hub-p001` — remove a worktree by directory name
- `wt mv release-hub-p001 hub-p001` — move/rename a worktree directory within the base
- `wt prune --dry-run` — check for stale worktree records without deleting anything
- `wt init` — mark the current directory as the worktree home (auto-detects the primary repo when possible)

## Configuration

- `wt init [dir] --repo /path/to/repo`: create or update the `.wt` marker that links a base directory to the primary repository (defaults to the current directory when `dir` is omitted; without `--repo`, the command attempts to auto-detect a repository within the base directory).
- `.wt`: YAML marker file placed in the chosen base directory; any descendant directory can run `wt` and will use the closest marker it finds.

All commands require a `.wt` marker. The marker's directory becomes the default location for new worktrees; use `--path` with `wt new` if you need a one-off destination elsewhere.

## Requirements

- Bash 4+
- Git with worktree support (Git 2.5+)

## Shell completion

### zsh

1. Copy or symlink `completions/_wt` into a directory listed in your `fpath` (e.g. `~/.zsh/completions/_wt`).
2. Ensure that directory is in `fpath`, for example:
   ```zsh
   fpath=(~/.zsh/completions $fpath)
   ```
3. Reload completion definitions:
   ```zsh
   autoload -Uz compinit && compinit
   ```
4. Restart your shell (or `exec zsh`) and tab-completion for `wt` should now offer commands, options, branches, and worktree directories.
