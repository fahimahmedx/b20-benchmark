#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/versions.env"
BASE_FORGE_BIN="${BASE_FORGE_BIN:-$HOME/.foundry/versions/base-v1.1.0/forge}"
PYTHON_BIN="${PYTHON_BIN:-python3.13}"

check_commit() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(git -C "$path" rev-parse HEAD)"
  if [[ "$actual" != "$expected" ]]; then
    echo "$path is at $actual; expected $expected" >&2
    exit 1
  fi
}

check_commit "$ROOT_DIR/lib/base-std" "$BASE_STD_COMMIT"
check_commit "$ROOT_DIR/lib/forge-std" "$FORGE_STD_COMMIT"
check_commit "$ROOT_DIR/lib/openzeppelin-contracts" "$OPENZEPPELIN_COMMIT"

base_version="$($BASE_FORGE_BIN --version)"
grep -q "1.6.0-v1.1.0" <<<"$base_version"
grep -q "$BASE_FOUNDRY_COMMIT" <<<"$base_version"

foundry_version="$(forge --version)"
grep -q "$FOUNDRY_VERSION" <<<"$foundry_version"
grep -q "$FOUNDRY_COMMIT" <<<"$foundry_version"

python_version="$($PYTHON_BIN --version 2>&1)"
grep -q "Python $PYTHON_VERSION" <<<"$python_version"

echo "Pinned dependencies and tool binaries verified."

