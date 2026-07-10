#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/versions.env"
mkdir -p "$ROOT_DIR/lib"

install_repo() {
  local url="$1"
  local commit="$2"
  local destination="$3"

  if [[ ! -d "$destination/.git" ]]; then
    git clone --filter=blob:none "$url" "$destination"
  fi
  git -C "$destination" fetch --depth 1 origin "$commit"
  git -C "$destination" checkout --detach "$commit"
  test "$(git -C "$destination" rev-parse HEAD)" = "$commit"
}

install_repo https://github.com/base/base-std.git "$BASE_STD_COMMIT" "$ROOT_DIR/lib/base-std"
install_repo https://github.com/foundry-rs/forge-std.git "$FORGE_STD_COMMIT" "$ROOT_DIR/lib/forge-std"
install_repo https://github.com/OpenZeppelin/openzeppelin-contracts.git \
  "$OPENZEPPELIN_COMMIT" "$ROOT_DIR/lib/openzeppelin-contracts"

