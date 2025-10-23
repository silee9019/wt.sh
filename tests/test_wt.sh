#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WT_BIN="$ROOT_DIR/wt"
LOG_DIR="${TMPDIR:-/tmp}/wt-logs-$$"
mkdir -p "$LOG_DIR"

passes=0
failures=0
failed_tests=()

fail() {
  echo "FAIL: $*" >&2
  return 1
}

create_fixture() {
  local tmp_template="${TMPDIR:-/tmp}/wt-fixture.XXXXXX"
  FIXTURE_SANDBOX="$(mktemp -d "$tmp_template")"
  FIXTURE_BASE="$FIXTURE_SANDBOX/base"
  FIXTURE_REPO="$FIXTURE_SANDBOX/repo"

  mkdir -p "$FIXTURE_BASE" "$FIXTURE_REPO"
  FIXTURE_SANDBOX="$(cd "$FIXTURE_SANDBOX" && pwd)"
  FIXTURE_BASE="$(cd "$FIXTURE_BASE" && pwd)"
  FIXTURE_REPO="$(cd "$FIXTURE_REPO" && pwd)"

  git init "$FIXTURE_REPO" >/dev/null
  (
    cd "$FIXTURE_REPO"
    git config user.email test@example.com
    git config user.name "WT Test"
    echo "initial" >README.md
    git add README.md
    git commit -m "initial commit" >/dev/null
  )

  trap 'rm -rf "$FIXTURE_SANDBOX"' EXIT
}

run_init() {
  "$WT_BIN" init "$FIXTURE_BASE" --repo "$FIXTURE_REPO" >/dev/null
}

wt_in_base() {
  (cd "$FIXTURE_BASE" && "$WT_BIN" "$@")
}

test_init_creates_marker() (
  set -euo pipefail
  create_fixture
  run_init

  local marker="$FIXTURE_BASE/.wt"
  [[ -f "$marker" ]] || fail "marker file not created"

  local base_line repo_line
  base_line="$(grep '^base:' "$marker" | awk '{print $2}')"
  repo_line="$(grep '^repo:' "$marker" | awk '{print $2}')"

  [[ "$base_line" == "$FIXTURE_BASE" ]] || fail "expected base '$FIXTURE_BASE', got '$base_line'"
  [[ "$repo_line" == "$FIXTURE_REPO" ]] || fail "expected repo '$FIXTURE_REPO', got '$repo_line'"
)

test_add_list_move_remove_flow() (
  set -euo pipefail
  create_fixture
  run_init

  wt_in_base add "feature/foo" >/dev/null

  local worktree_dir="$FIXTURE_BASE/feature-foo"
  [[ -d "$worktree_dir" ]] || fail "worktree directory not created"
  git -C "$FIXTURE_REPO" show-ref --verify --quiet "refs/heads/feature/foo" || fail "branch feature/foo not created"

  local branch
  branch="$(git -C "$worktree_dir" rev-parse --abbrev-ref HEAD)"
  [[ "$branch" == "feature/foo" ]] || fail "expected branch feature/foo, got $branch"

  local list_output
  list_output="$(wt_in_base ls --porcelain)"
  echo "$list_output" | grep -q "$worktree_dir" || fail "worktree not listed in porcelain output"

  wt_in_base move feature-foo moved >/dev/null
  [[ -d "$FIXTURE_BASE/moved" ]] || fail "worktree not moved to target directory"
  [[ ! -d "$worktree_dir" ]] || fail "old worktree directory still present"

  wt_in_base rm moved >/dev/null
  [[ ! -d "$FIXTURE_BASE/moved" ]] || fail "worktree directory still exists after removal"
)

test_prune_dry_run() (
  set -euo pipefail
  create_fixture
  run_init

  wt_in_base prune --dry-run >/dev/null
)

test_marker_discovery_from_child() (
  set -euo pipefail
  create_fixture
  run_init

  mkdir -p "$FIXTURE_BASE/nested/deeper"
  (
    cd "$FIXTURE_BASE/nested/deeper"
    "$WT_BIN" ls >/dev/null
  )
)

run_test() {
  local name="$1"
  local fn="$2"
  local stdout_log="$LOG_DIR/$name.stdout"
  local stderr_log="$LOG_DIR/$name.stderr"

  if "$fn" >"$stdout_log" 2>"$stderr_log"; then
    echo "PASS $name"
    passes=$((passes + 1))
  else
    echo "FAIL $name"
    failures=$((failures + 1))
    failed_tests+=("$name")
    echo "--- $name stdout ---"
    cat "$stdout_log"
    echo "--- $name stderr ---"
    cat "$stderr_log"
  fi
}

run_test "init_creates_marker" test_init_creates_marker
run_test "add_list_move_remove_flow" test_add_list_move_remove_flow
run_test "prune_dry_run" test_prune_dry_run
run_test "marker_discovery_from_child" test_marker_discovery_from_child

echo
if (( failures > 0 )); then
  echo "$failures test(s) failed: ${failed_tests[*]}"
  exit 1
else
  echo "All $passes test(s) passed."
fi
