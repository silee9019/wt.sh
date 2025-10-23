# bash completion for wt

__wt_marker_cache_dir=""
__wt_marker_cache_repo=""

__wt_trim_whitespace() {
  local str="$1"
  str="${str#"${str%%[![:space:]]*}"}"
  str="${str%"${str##*[![:space:]]}"}"
  REPLY="$str"
}

__wt_marker_base() {
  local dir="$PWD"
  while :; do
    if [[ -f "$dir/.wt" ]]; then
      REPLY="$dir"
      return 0
    fi
    if [[ "$dir" == "/" ]]; then
      break
    fi
    dir="${dir%/*}"
    [[ -n "$dir" ]] || dir="/"
  done
  return 1
}

__wt_marker_value() {
  local key="$1"
  local marker
  if ! __wt_marker_base; then
    return 1
  fi
  marker="$REPLY/.wt"
  local value
  value=$(
    awk -v KEY="$key" '
      /^[[:space:]]*#/ { next }
      /^[[:space:]]*$/ { next }
      {
        sub(/\r$/, "", $0)
      }
      $0 ~ "^[[:space:]]*" KEY ":" {
        sub("^[[:space:]]*" KEY ":[[:space:]]*", "", $0)
        print
        exit
      }
    ' "$marker" 2>/dev/null
  )
  [[ -n "$value" ]] || return 1
  REPLY="$value"
  return 0
}

__wt_repo_dir() {
  if [[ -n "$__wt_marker_cache_dir" && -n "$__wt_marker_cache_repo" ]]; then
    case "$PWD" in
      "$__wt_marker_cache_dir"*) REPLY="$__wt_marker_cache_repo"; return 0 ;;
    esac
  fi

  local base repo
  if ! __wt_marker_base; then
    return 1
  fi
  base="$REPLY"

  local resolved_base
  if ! resolved_base="$(cd "$base" 2>/dev/null && pwd)"; then
    return 1
  fi

  if ! __wt_marker_value repo; then
    return 1
  fi
  repo="$REPLY"
  __wt_trim_whitespace "$repo"
  repo="$REPLY"

  case "$repo" in
    "~")
      repo="$HOME"
      ;;
    "~/"*)
      repo="$HOME/${repo#~/}"
      ;;
    "~"*)
      local user_part remainder user user_home
      user_part="${repo%%/*}"
      user="${user_part#~}"
      remainder=""
      if [[ "$repo" == */* ]]; then
        remainder="${repo#*/}"
      fi
      if command -v python3 >/dev/null 2>&1; then
        user_home="$(USER_NAME="$user" python3 - <<'PY'
import os
import pwd
import sys

username = os.environ.get("USER_NAME")
try:
    print(pwd.getpwnam(username).pw_dir)
except (KeyError, TypeError):
    sys.exit(1)
PY
)" || return 1
      else
        if [[ "$user" =~ [^A-Za-z0-9._-] ]]; then
          return 1
        fi
        user_home="$(eval printf '%s\n' ~"$user")" || return 1
      fi
      if [[ -n "$remainder" ]]; then
        repo="$user_home/$remainder"
      else
        repo="$user_home"
      fi
      ;;
  esac

  if [[ "$repo" != /* ]]; then
    repo="$resolved_base/$repo"
  fi

  local resolved_repo
  if ! resolved_repo="$(cd "$repo" 2>/dev/null && pwd)"; then
    return 1
  fi

  __wt_marker_cache_dir="$resolved_base"
  __wt_marker_cache_repo="$resolved_repo"
  REPLY="$resolved_repo"
  return 0
}

__wt_relative_dirs() {
  local prefix="$1"
  local base
  if [[ "$prefix" == /* ]]; then
    COMPREPLY=( $(compgen -d -- "$prefix") )
    return
  fi
  if __wt_marker_base; then
    base="$REPLY"
  else
    base="$PWD"
  fi

  local oldpwd="$PWD"
  builtin pushd "$base" >/dev/null 2>&1 || return 1
  COMPREPLY=( $(compgen -d -- "$prefix") )
  builtin popd >/dev/null 2>&1
}

__wt_worktree_dirs() {
  local prefix="$1"
  local base
  if ! __wt_marker_base; then
    return 1
  fi
  base="$REPLY"

  local IFS=$'\n'
  local paths=()
  local path rel
  for path in $(wt list --porcelain 2>/dev/null | awk '/^worktree /{print $2}'); do
    if [[ "$path" == "$base" ]]; then
      continue
    elif [[ "$path" == "$base/"* ]]; then
      rel="${path#$base/}"
    else
      rel="$path"
    fi
    paths+=("$rel")
  done

  (( ${#paths[@]} )) || return 1
  COMPREPLY=( $(compgen -W "${paths[*]}" -- "$prefix") )
}

__wt_git_refs() {
  local prefix="$1"
  local repo
  if ! __wt_repo_dir; then
    return 1
  fi
  repo="$REPLY"
  local IFS=$'\n'
  local refs=($(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null))
  (( ${#refs[@]} )) || return 1
  COMPREPLY=( $(compgen -W "${refs[*]}" -- "$prefix") )
}

_wt_complete() {
  local cur prev words cword

  if declare -F _init_completion >/dev/null 2>&1; then
    _init_completion -n : || return
  else
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
  fi

  local commands="list ls add remove rm move mv prune init help --help -h"

  if (( cword == 1 )); then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return
  fi

  local cmd="${words[1]}"
  case "$cmd" in
    list|ls)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--porcelain --help" -- "$cur") )
      fi
      ;;
    add)
      case "$prev" in
        --base)
          __wt_git_refs "$cur" && return
          ;;
        --id|--title)
          COMPREPLY=()
          return
          ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id --title --base --help" -- "$cur") )
      else
        COMPREPLY=()
      fi
      ;;
    remove|rm)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help" -- "$cur") )
      else
        __wt_worktree_dirs "$cur" || COMPREPLY=()
      fi
      ;;
    move|mv)
      case "$prev" in
        move|mv)
          __wt_worktree_dirs "$cur" || COMPREPLY=()
          return
          ;;
        --help)
          COMPREPLY=()
          return
          ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help" -- "$cur") )
      else
        __wt_relative_dirs "$cur" || COMPREPLY=()
      fi
      ;;
    prune)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dry-run --help" -- "$cur") )
      fi
      ;;
    init)
      case "$prev" in
        --repo)
          __wt_relative_dirs "$cur"
          return
          ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--repo --help" -- "$cur") )
      else
        __wt_relative_dirs "$cur" || COMPREPLY=( $(compgen -d -- "$cur") )
      fi
      ;;
    help|--help|-h)
      COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
      ;;
    *)
      COMPREPLY=()
      ;;
  esac
}

complete -o bashdefault -o default -F _wt_complete wt
