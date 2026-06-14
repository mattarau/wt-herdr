#!/usr/bin/env bats

# wt-herdr test suite
# Tests against real herdr (must be running) and real wt (must be installed).
# Creates temporary git repos with worktrees for testing.

setup() {
  export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export BIN="$REPO_ROOT/wt-herdr"

  # Create a temporary git repo with worktrees
  export TEST_REPO="$BATS_TEST_TMPDIR/test-repo"
  mkdir -p "$TEST_REPO"
  cd "$TEST_REPO"
  git init -b main 2>/dev/null
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "readme" > README.md
  git add . && git commit -m "init" 2>/dev/null
  git branch feature-a 2>/dev/null || true
  git branch feature-b 2>/dev/null || true
  mkdir -p "$BATS_TEST_TMPDIR/wt-feature-a" "$BATS_TEST_TMPDIR/wt-feature-b"
  git worktree add "$BATS_TEST_TMPDIR/wt-feature-a" feature-a 2>/dev/null || true
  git worktree add "$BATS_TEST_TMPDIR/wt-feature-b" feature-b 2>/dev/null || true

  # Use default session for tests (avoids creating per-repo sessions)
  export HERDR_SESSION=default

  # Record original workspace IDs so we can clean up
  export SAVED_WS_IDS=""
}

teardown() {
  # Clean up any workspaces we created during tests
  if [[ -n "$SAVED_WS_IDS" ]]; then
    for wid in $SAVED_WS_IDS; do
      herdr workspace close "$wid" 2>/dev/null || true
    done
  fi
}

# Helper: find workspace IDs created by our sync (matching our label pattern)
_find_our_ws_ids() {
  herdr workspace list 2>/dev/null | jq -r '.result.workspaces[] | select(.label | startswith("test-repo / ")) | .workspace_id'
}

_save_ws_ids() {
  SAVED_WS_IDS="$SAVED_WS_IDS $(_find_our_ws_ids)"
}

# ── Tests ────────────────────────────────────────────────────────────

@test "bash syntax is clean" {
  run bash -n "$BIN"
  [ "$status" -eq 0 ]
}

@test "manifest prints valid JSON" {
  run "$BIN" manifest
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.name' >/dev/null
  echo "$output" | jq -e '.executable' >/dev/null
  echo "$output" | jq -e '.version' >/dev/null
}

@test "manifest executable is wt-herdr" {
  run "$BIN" manifest
  [ "$(echo "$output" | jq -r '.executable')" = "wt-herdr" ]
}

@test "health reports ok" {
  run "$BIN" health
  echo "output=$output"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.ok')" = "true" ]
}

@test "sync creates workspaces" {
  cd "$TEST_REPO"
  run "$BIN" sync
  echo "output=$output"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "ok" ]
  local total
  total=$(echo "$output" | jq -r '.created + .updated')
  [ "$total" -ge 2 ]
  _save_ws_ids
}

@test "sync is idempotent" {
  cd "$TEST_REPO"
  run "$BIN" sync
  [ "$status" -eq 0 ]
  _save_ws_ids
  local created1
  created1=$(echo "$output" | jq -r '.created')
  run "$BIN" sync
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.created')" -eq 0 ]
}

@test "sync --dry-run succeeds" {
  cd "$TEST_REPO"
  run "$BIN" sync --dry-run
  echo "output=$output"
  [ "$status" -eq 0 ]
  _save_ws_ids
}

@test "focus works for current branch" {
  cd "$TEST_REPO"
  run "$BIN" sync
  [ "$status" -eq 0 ]
  _save_ws_ids
  run "$BIN" focus
  echo "output=$output"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "ok" ]
}

@test "status shows mapping" {
  cd "$TEST_REPO"
  run "$BIN" sync
  [ "$status" -eq 0 ]
  _save_ws_ids
  run "$BIN" status
  echo "output=$output"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.worktree_count')" -ge 2 ]
}

@test "clean --dry-run succeeds" {
  cd "$TEST_REPO"
  run "$BIN" sync
  [ "$status" -eq 0 ]
  _save_ws_ids
  run "$BIN" clean --dry-run
  echo "output=$output"
  [ "$status" -eq 0 ]
}

@test "update-labels works" {
  cd "$TEST_REPO"
  run "$BIN" sync
  [ "$status" -eq 0 ]
  _save_ws_ids
  run "$BIN" update-labels
  echo "output=$output"
  [ "$status" -eq 0 ]
}

@test "event worktree-created" {
  cd "$TEST_REPO"
  printf '{"branch":"test-event-%s","worktree_path":"%s/test-event","repo":"test-repo"}' "$RANDOM" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/evt.json"
  run "$BIN" event worktree-created < "$BATS_TEST_TMPDIR/evt.json"
  echo "output=$output"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "ok" ]
  # Save the created workspace ID for cleanup
  local wid
  wid=$(echo "$output" | jq -r '.workspace_id // ""')
  [[ -n "$wid" ]] && SAVED_WS_IDS="$SAVED_WS_IDS $wid"
}

@test "event worktree-removed noop for missing" {
  cd "$TEST_REPO"
  printf '{"branch":"nonexistent-%s","worktree_path":"/tmp/nonexistent","repo":"test-repo"}' "$RANDOM" > "$BATS_TEST_TMPDIR/evt2.json"
  run "$BIN" event worktree-removed < "$BATS_TEST_TMPDIR/evt2.json"
  echo "output=$output"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "noop" ]
}
