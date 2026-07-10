#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"
WORK_DIR="$ROOT_DIR/.benchmark-work"
mkdir -p "$WORK_DIR"

cd "$ROOT_DIR"
FOUNDRY_BASE=false forge test --offline --match-contract GasAccountingCanaryTest -vv \
  >"$WORK_DIR/canary-stock.log" 2>&1
FOUNDRY_BASE=false "$BASE_FORGE_BIN" test --offline --match-contract GasAccountingCanaryTest -vv \
  >"$WORK_DIR/canary-base.log" 2>&1

stock="$(rg -o 'GAS_ACCOUNTING_CANARY,gas_used=[0-9]+' "$WORK_DIR/canary-stock.log" | tail -1)"
base="$(rg -o 'GAS_ACCOUNTING_CANARY,gas_used=[0-9]+' "$WORK_DIR/canary-base.log" | tail -1)"

if [[ -z "$stock" || -z "$base" ]]; then
  echo "Gas-accounting canary output was missing" >&2
  exit 1
fi
stock_gas="${stock##*=}"
base_gas="${base##*=}"
if [[ "$stock" == "$base" ]]; then
  compatible=true
  echo "Gas-accounting canary agrees for the fixed Solidity call: $stock"
else
  compatible=false
  echo "Gas-accounting canary differs: stock=$stock_gas base=$base_gas"
  echo "Final benchmark measurements therefore use the Base Forge binary for every implementation."
fi

printf '{\n  "stock_foundry_gas": %s,\n  "base_forge_gas": %s,\n  "identical": %s\n}\n' \
  "$stock_gas" "$base_gas" "$compatible" >"$ROOT_DIR/results/tooling-canary.json"
