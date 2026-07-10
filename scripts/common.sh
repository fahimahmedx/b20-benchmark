#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_FORGE_BIN="${BASE_FORGE_BIN:-$HOME/.foundry/versions/base-v1.1.0/forge}"

if [[ ! -x "$BASE_FORGE_BIN" ]]; then
  echo "Base Forge binary not found at $BASE_FORGE_BIN" >&2
  echo "Install it with: base-foundryup --install v1.1.0" >&2
  exit 1
fi

