#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WT_SOURCE="$SCRIPT_DIR/wt"
BASH_COMPLETION_SOURCE="$SCRIPT_DIR/completions/wt.bash"
ZSH_COMPLETION_SOURCE="$SCRIPT_DIR/completions/_wt"

append_if_missing() {
  local file="$1"
  local marker="$2"
  local content="$3"

  touch "$file"
  if ! grep -q "$marker" "$file" 2>/dev/null; then
    printf '%s
' "$content" >>"$file"
    echo "Updated $file with $marker section."
  else
    echo "Skipped updating $file (marker already present)."
  fi
}

copy_or_link() {
  local src="$1"
  local dest="$2"

  if (( USE_SYMLINK )); then
    ln -sf "$src" "$dest"
  else
    cp -f "$src" "$dest"
  fi
}

describe_method() {
  if (( USE_SYMLINK )); then
    echo symlink
  else
    echo copy
  fi
}

expand_path() {
  local input="$1"
  case "$input" in
    ~|~/*)
      printf '%s' "${input/#\~/$HOME}"
      ;;
    *)
      printf '%s' "$input"
      ;;
  esac
}

prompt_with_default() {
  local prompt="$1"
  local default="$2"
  local value

  read -r -p "$prompt [$default]: " value || value=""
  if [[ -z "$value" ]]; then
    REPLY="$default"
  else
    REPLY="$value"
  fi
}

detect_default_shell() {
  local current="${SHELL:-}"

  if [[ "$current" == *"zsh"* ]]; then
    if [[ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}" ]]; then
      printf '%s' "oh-my-zsh"
      return
    fi
    printf '%s' "zsh"
    return
  fi

  printf '%s' "bash"
}

detect_default_install_path() {
  printf '%s' "$HOME/.local/bin/wt"
}

print_header() {
  cat <<'EOF'
=====================================
            wt setup
=====================================
Follow the prompts to install wt and configure shell completions.
EOF
}

summaries=()
USE_SYMLINK=0
DO_BASH=0
DO_ZSH=0
DO_OH_MY_ZSH=0
BASH_COMPLETION_DEST=""
ZSH_COMPLETION_DEST=""
OH_MY_COMPLETION_DEST=""
INSTALL_PATH=""
SELECTED_SHELL=""

select_shells() {
  local detected default_choice_label choice_input_raw choice_input
  detected="$(detect_default_shell)"

  case "$detected" in
    bash)
      default_choice_label="1"
      ;;
    zsh)
      default_choice_label="2"
      ;;
    oh-my-zsh)
      default_choice_label="3"
      ;;
    *)
      default_choice_label="4"
      ;;
  esac

  echo "Detected shell: $detected"
  echo "Select completion target (one per install):"
  echo "  1) bash"
  echo "  2) zsh"
  echo "  3) oh-my-zsh"
  echo "  4) skip completions"
  prompt_with_default "Enter choice (number)" "$default_choice_label"
  choice_input_raw="$(printf '%s' "$REPLY" | tr -d ' \t\r\n')"
  choice_input="$(printf '%s' "$choice_input_raw" | tr -cd '[:alnum:]-')"

  DO_BASH=0
  DO_ZSH=0
  DO_OH_MY_ZSH=0
  SELECTED_SHELL=""

  case "$choice_input" in
    1|bash)
      DO_BASH=1
      SELECTED_SHELL="bash"
      ;;
    2|zsh)
      DO_ZSH=1
      SELECTED_SHELL="zsh"
      ;;
    3|oh-my-zsh|ohmyzsh)
      DO_OH_MY_ZSH=1
      SELECTED_SHELL="oh-my-zsh"
      ;;
    4|skip|none|no)
      SELECTED_SHELL="$detected"
      ;;
    *)
      echo "Unknown choice '$choice_input', skipping completions."
      SELECTED_SHELL="$detected"
      ;;
  esac
}

configure_paths() {
  local default_bin_path
  default_bin_path="$(detect_default_install_path)"
  prompt_with_default "Install wt to" "$default_bin_path"
  INSTALL_PATH="$(expand_path "$REPLY")"
  if [[ -d "$INSTALL_PATH" ]]; then
    INSTALL_PATH="$INSTALL_PATH/wt"
  fi
  mkdir -p "$(dirname "$INSTALL_PATH")"

  if (( DO_BASH )); then
    prompt_with_default "Bash completion path" "$HOME/.bash_completion.d/wt"
    BASH_COMPLETION_DEST="$(expand_path "$REPLY")"
    if [[ -d "$BASH_COMPLETION_DEST" ]]; then
      BASH_COMPLETION_DEST="$BASH_COMPLETION_DEST/wt"
    fi
    mkdir -p "$(dirname "$BASH_COMPLETION_DEST")"
  fi

  if (( DO_ZSH )); then
    prompt_with_default "Zsh completion path" "$HOME/.zsh/completions/_wt"
    ZSH_COMPLETION_DEST="$(expand_path "$REPLY")"
    if [[ -d "$ZSH_COMPLETION_DEST" ]]; then
      ZSH_COMPLETION_DEST="$ZSH_COMPLETION_DEST/_wt"
    fi
    mkdir -p "$(dirname "$ZSH_COMPLETION_DEST")"
  fi

  if (( DO_OH_MY_ZSH )); then
    local oh_default="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/completions/_wt"
    prompt_with_default "oh-my-zsh completion path" "$oh_default"
    OH_MY_COMPLETION_DEST="$(expand_path "$REPLY")"
    if [[ -d "$OH_MY_COMPLETION_DEST" ]]; then
      OH_MY_COMPLETION_DEST="$OH_MY_COMPLETION_DEST/_wt"
    fi
    mkdir -p "$(dirname "$OH_MY_COMPLETION_DEST")"
  fi
}

choose_method() {
  local method_raw method
  echo "Select installation method:"
  echo "  1) copy"
  echo "  2) symlink"
  prompt_with_default "Enter choice (number)" "1"
  method_raw="$(printf '%s' "$REPLY" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
  method="${method_raw%% *}"
  method="${method%%)*}"
  case "$method" in
    2|symlink|s)
      USE_SYMLINK=1
      ;;
    1|copy|c|*)
      USE_SYMLINK=0
      ;;
  esac
}

install_binary() {
  copy_or_link "$WT_SOURCE" "$INSTALL_PATH"
  if (( USE_SYMLINK )); then
    echo "  wt symlinked to $INSTALL_PATH"
  else
    chmod +x "$INSTALL_PATH"
    echo "  wt copied to $INSTALL_PATH"
  fi
  summaries+=("wt => $INSTALL_PATH ($(describe_method))")
}

install_bash_completion() {
  copy_or_link "$BASH_COMPLETION_SOURCE" "$BASH_COMPLETION_DEST"
  if (( USE_SYMLINK )); then
    echo "  Bash completion symlinked at $BASH_COMPLETION_DEST"
  else
    echo "  Bash completion copied to $BASH_COMPLETION_DEST"
  fi
  append_if_missing "$HOME/.bashrc" "# wt completion" $'# wt completion\nif [[ -f ~/.bash_completion.d/wt ]]; then\n  source ~/.bash_completion.d/wt\nfi'
  summaries+=("bash completion => $BASH_COMPLETION_DEST ($(describe_method))")
}

install_zsh_completion() {
  copy_or_link "$ZSH_COMPLETION_SOURCE" "$ZSH_COMPLETION_DEST"
  if (( USE_SYMLINK )); then
    echo "  Zsh completion symlinked at $ZSH_COMPLETION_DEST"
  else
    echo "  Zsh completion copied to $ZSH_COMPLETION_DEST"
  fi
  local zsh_dir
  zsh_dir="$(dirname "$ZSH_COMPLETION_DEST")"
  printf -v zsh_snippet "# wt completion\nfpath=(%s \$fpath)\nautoload -Uz compinit && compinit" "$zsh_dir"
  append_if_missing "$HOME/.zshrc" "# wt completion" "$zsh_snippet"
  summaries+=("zsh completion => $ZSH_COMPLETION_DEST ($(describe_method))")
}

install_ohmyzsh_completion() {
  copy_or_link "$ZSH_COMPLETION_SOURCE" "$OH_MY_COMPLETION_DEST"
  if (( USE_SYMLINK )); then
    echo "  oh-my-zsh completion symlinked at $OH_MY_COMPLETION_DEST"
  else
    echo "  oh-my-zsh completion copied to $OH_MY_COMPLETION_DEST"
  fi
  local oh_dir
  oh_dir="$(dirname "$OH_MY_COMPLETION_DEST")"
  printf -v oh_snippet "# wt completion (oh-my-zsh)\nfpath=(%s \$fpath)\nautoload -Uz compinit && compinit" "$oh_dir"
  append_if_missing "$HOME/.zshrc" "# wt completion (oh-my-zsh)" "$oh_snippet"
  summaries+=("oh-my-zsh completion => $OH_MY_COMPLETION_DEST ($(describe_method))")
}

ensure_path_export() {
  local bin_dir path_snippet target_shell rc_file label
  bin_dir="$(dirname "$INSTALL_PATH")"
  printf -v path_snippet "# wt path\nif [[ \":\$PATH:\" != *\":%s:\"* ]]; then\n  export PATH=\"%s:\$PATH\"\nfi" "$bin_dir" "$bin_dir"

  target_shell="${SELECTED_SHELL:-$(detect_default_shell)}"

  case "$target_shell" in
    bash)
      rc_file="$HOME/.bashrc"
      label="$HOME/.bashrc"
      ;;
    oh-my-zsh|zsh)
      rc_file="$HOME/.zshrc"
      label="$HOME/.zshrc"
      ;;
    *)
      rc_file="$HOME/.bashrc"
      label="$HOME/.bashrc"
      ;;
  esac

  append_if_missing "$rc_file" "# wt path" "$path_snippet"
  summaries+=("PATH update => $label")
}

main() {
  print_header

  choose_method
  select_shells
  configure_paths

  echo
  echo "Installing wt..."
  install_binary

  echo
  echo "Configuring completions..."
  if (( DO_BASH )); then
    install_bash_completion
  else
    echo "  Skipped bash completion"
  fi

  if (( DO_ZSH )); then
    install_zsh_completion
  else
    echo "  Skipped zsh completion"
  fi

  if (( DO_OH_MY_ZSH )); then
    install_ohmyzsh_completion
  else
    echo "  Skipped oh-my-zsh completion"
  fi

  ensure_path_export

  echo
  echo "Installation summary:"
  for line in "${summaries[@]}"; do
    echo "  - $line"
  done

  echo
  echo "Next steps:"
  if (( DO_BASH )); then
    echo "  source ~/.bashrc"
  fi
  if (( DO_ZSH )) || (( DO_OH_MY_ZSH )); then
    echo "  source ~/.zshrc"
  fi
  echo "Re-run ./install.sh any time to update paths or switch between copy/symlink."
}

main
