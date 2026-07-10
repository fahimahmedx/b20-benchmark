#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

cd "$ROOT_DIR"
for run in 1 2 3 4 5; do
  BENCHMARK_RUN="$run" FOUNDRY_BASE=false \
    "$BASE_FORGE_BIN" test --offline --match-contract OpenZeppelinGasTest -vv
done
