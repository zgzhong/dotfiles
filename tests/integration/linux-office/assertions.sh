#!/usr/bin/env bash
set -euo pipefail

phase() {
  printf '\n==> %s\n' "$*"
}

fail() {
  local message="$1"
  echo "[FAIL] ${message}" >&2
  return 1
}

assert_file_exists() {
  local file="$1"
  [[ -f "$file" ]] || fail "Expected file to exist: $file"
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"

  assert_file_exists "$file"
  if ! grep -Fq -- "$pattern" "$file"; then
    echo "[DEBUG] File content from $file:" >&2
    sed -n '1,200p' "$file" >&2 || true
    fail "Expected '$pattern' in $file"
  fi
}

assert_file_not_contains() {
  local file="$1"
  local pattern="$2"

  assert_file_exists "$file"
  if grep -Fq -- "$pattern" "$file"; then
    echo "[DEBUG] File content from $file:" >&2
    sed -n '1,200p' "$file" >&2 || true
    fail "Did not expect '$pattern' in $file"
  fi
}

assert_empty_file() {
  local file="$1"
  assert_file_exists "$file"
  if [[ -s "$file" ]]; then
    echo "[DEBUG] Expected empty file, got content in $file:" >&2
    sed -n '1,200p' "$file" >&2 || true
    fail "Expected empty file: $file"
  fi
}
