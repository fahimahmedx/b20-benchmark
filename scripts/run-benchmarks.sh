#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.benchmark-work"
PYTHON_BIN="${PYTHON_BIN:-python3.13}"
mkdir -p "$WORK_DIR"

run_one() {
  local name="$1"
  local script="$2"
  "$script" >"$WORK_DIR/$name.log" 2>&1
  local status=$?
  cat "$WORK_DIR/$name.log"
  return $status
}

native_status=0
mock_status=0
oz_status=0
run_one native "$ROOT_DIR/scripts/run-native.sh" || native_status=$?
run_one mock "$ROOT_DIR/scripts/run-mock.sh" || mock_status=$?
run_one openzeppelin "$ROOT_DIR/scripts/run-openzeppelin.sh" || oz_status=$?

"$PYTHON_BIN" "$ROOT_DIR/scripts/collect-results.py" \
  "$WORK_DIR/native.log" "$WORK_DIR/mock.log" "$WORK_DIR/openzeppelin.log"
collect_status=$?

"$PYTHON_BIN" "$ROOT_DIR/scripts/validate-results.py" || validate_status=$?
validate_status=${validate_status:-0}

if (( native_status != 0 || mock_status != 0 || oz_status != 0 || collect_status != 0 || validate_status != 0 )); then
  echo "Benchmark failed: native=$native_status mock=$mock_status openzeppelin=$oz_status collection=$collect_status validation=$validate_status" >&2
  exit 1
fi

