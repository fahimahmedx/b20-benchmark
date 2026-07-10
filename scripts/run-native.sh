#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

cd "$ROOT_DIR"
for run in 1 2 3 4 5; do
  BENCHMARK_RUN="$run" EXPECT_LIVE_PRECOMPILES=true FOUNDRY_BASE=true \
    "$BASE_FORGE_BIN" test --offline --match-contract B20GasTest -vv
done
