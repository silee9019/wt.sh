# wt.sh

Small Bash wrapper around `git worktree` that makes it easy to spin up, inspect, and clean worktrees from a single directory.

## Features

- Auto-detects `.wt` markers to locate the primary repository and base directory
- Creates worktrees under the marker directory using branch-based folder names
- Falls back to sensible defaults (`origin/main`, `main`, or current branch) when creating new branches
- Provides straightforward commands for listing, adding, removing, moving, and pruning worktrees
- Strict error handling (`set -euo pipefail`) for predictable behaviour

## Installation

1. Clone or download this repository.
2. Add the directory to your `PATH`, or symlink the script somewhere already on your `PATH`:
   ```bash
   ln -s /path/to/wt.sh/wt /usr/local/bin/wt
   ```

## Usage

Run `wt help` to see the built-in usage guide.

```bash
Usage: wt <command> [options]

Commands:
  list|ls [--porcelain]           List registered worktrees.
  add <branch> [--path DIR] [--from REF] [--force]
                                  Create a worktree (new branch if missing).
  remove|rm <dir> [--force]
                                  Remove a worktree directory.
  move|mv <dir> <new-path>
                                  Move/rename a worktree directory.
  prune [--dry-run]               Prune stale worktree metadata.
  init [dir] [--repo PATH]        Mark a directory for new worktrees; supply --repo when outside the repo.
  help|-h|--help                  Show this help message.
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

## Shell completion

### Bash

1. Copy or symlink `completions/wt.bash` somewhere on disk (for example `~/.bash_completion.d/wt`):
   ```bash
   ln -s /path/to/wt.sh/completions/wt.bash ~/.bash_completion.d/wt
   ```
2. Source the script from your `~/.bashrc` (create the directory if needed):
   ```bash
   mkdir -p ~/.bash_completion.d
   grep -q wt.bash ~/.bashrc || echo 'source ~/.bash_completion.d/wt' >> ~/.bashrc
   ```
3. Reload your shell (or `source ~/.bashrc`) to activate the completion.

### Zsh

1. Copy or symlink `completions/_wt` into a directory listed in your `fpath` (for example `~/.zsh/completions/_wt`):
   ```bash
   ln -s /path/to/wt.sh/completions/_wt ~/.zsh/completions/_wt
   ```
2. Ensure that directory is in `fpath`, then reload completions:
   ```zsh
   fpath=(~/.zsh/completions $fpath)
   autoload -Uz compinit && compinit
   ```
3. Restart your shell (or `exec zsh`) and `wt` will offer completions for commands, options, branches, and worktree directories.

### oh-my-zsh

1. Place the zsh completion in `$ZSH_CUSTOM/completions` (create it if it does not exist):
   ```bash
   ln -s /path/to/wt.sh/completions/_wt ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/completions/_wt
   ```
2. Ensure the directory is in `fpath` (oh-my-zsh adds `$ZSH_CUSTOM/completions` automatically when it exists). Reload completions:
   ```zsh
   autoload -Uz compinit && compinit
   ```
3. Restart your shell or run `exec zsh`.
