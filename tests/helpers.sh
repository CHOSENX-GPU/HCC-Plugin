#!/usr/bin/env bash
# Test helper functions for HCC Memory Plugin tests

PASS=0
FAIL=0
ERRORS=""
PLUGIN_ROOT=""
TEMP_DIR=""

setup_test() {
  PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
  TEMP_DIR=$(mktemp -d)
}

cleanup_test() {
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}

assert_equals() {
  local expected="$1" actual="$2" msg="${3:-assert_equals}"
  if [[ "$expected" == "$actual" ]]; then
    ((PASS++))
  else
    ((FAIL++))
    ERRORS+="  FAIL: $msg (expected='$expected', actual='$actual')\n"
  fi
}

assert_true() {
  local condition="$1" msg="${2:-assert_true}"
  if eval "$condition"; then
    ((PASS++))
  else
    ((FAIL++))
    ERRORS+="  FAIL: $msg (condition='$condition')\n"
  fi
}

assert_match() {
  local pattern="$1" actual="$2" msg="${3:-assert_match}"
  if [[ "$actual" =~ $pattern ]]; then
    ((PASS++))
  else
    ((FAIL++))
    ERRORS+="  FAIL: $msg (pattern='$pattern', actual='$actual')\n"
  fi
}

assert_file_exists() {
  local path="$1" msg="${2:-File should exist: $path}"
  if [[ -f "$path" ]]; then
    ((PASS++))
  else
    ((FAIL++))
    ERRORS+="  FAIL: $msg\n"
  fi
}

assert_dir_exists() {
  local path="$1" msg="${2:-Dir should exist: $path}"
  if [[ -d "$path" ]]; then
    ((PASS++))
  else
    ((FAIL++))
    ERRORS+="  FAIL: $msg\n"
  fi
}

assert_file_contains() {
  local path="$1" pattern="$2" msg="${3:-File should contain pattern}"
  if grep -q "$pattern" "$path" 2>/dev/null; then
    ((PASS++))
  else
    ((FAIL++))
    ERRORS+="  FAIL: $msg (pattern='$pattern' not in '$path')\n"
  fi
}

assert_file_not_contains() {
  local path="$1" pattern="$2" msg="${3:-File should not contain pattern}"
  if ! grep -q "$pattern" "$path" 2>/dev/null; then
    ((PASS++))
  else
    ((FAIL++))
    ERRORS+="  FAIL: $msg\n"
  fi
}

assert_exit_code() {
  local expected="$1" actual="$2" msg="${3:-Exit code mismatch}"
  assert_equals "$expected" "$actual" "$msg"
}

run_tests() {
  local test_name
  local caller_file="${BASH_SOURCE[1]}"
  echo "=== Running: $(basename "$caller_file") ==="
  for test_name in "$@"; do
    echo -n "  $test_name ... "
    if $test_name; then
      echo "ok"
    else
      echo "FAIL"
    fi
  done
  echo "---"
  echo "Passed: $PASS  Failed: $FAIL"
  if [[ $FAIL -gt 0 ]]; then
    echo -e "Failures:\n$ERRORS"
    exit 1
  fi
}
