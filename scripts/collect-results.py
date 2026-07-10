#!/usr/bin/env python3
"""Parse Forge benchmark logs into reproducible CSV and JSON datasets."""

from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"

BENCHMARK_RE = re.compile(
    r"^BENCHMARK,implementation=(native_b20|mock_b20|openzeppelin),"
    r"operation=(transfer|approve|transferFrom|mint),"
    r"scenario=([a-z0-9_]+),run=([1-9][0-9]*),gas_used=([1-9][0-9]*)$"
)
MODE_RE = re.compile(
    r"^BENCHMARK_MODE,implementation=(native_b20|mock_b20),verified=true$"
)

FIELDS = [
    "implementation",
    "operation",
    "scenario",
    "run",
    "gas_used",
    "base_std_commit",
    "base_forge_version",
    "base_forge_commit",
    "base_precompiles_commit",
    "foundry_version",
    "foundry_commit",
    "openzeppelin_version",
    "openzeppelin_commit",
    "solidity_version",
    "optimizer_enabled",
    "optimizer_runs",
    "via_ir",
    "evm_version",
    "execution_environment",
    "python_version",
    "matplotlib_version",
    "mode_verified",
]

ENVIRONMENT = {
    "native_b20": "base-forge-v1.1.0-in-process-native",
    "mock_b20": "base-forge-v1.1.0-solidity-reference",
    "openzeppelin": "base-forge-v1.1.0-solidity",
}

EXPECTED_LOG_IMPLEMENTATION = {
    "native.log": "native_b20",
    "mock.log": "mock_b20",
    "openzeppelin.log": "openzeppelin",
}


def read_versions() -> dict[str, str]:
    versions: dict[str, str] = {}
    for raw in (ROOT / "versions.env").read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        key, value = line.split("=", 1)
        versions[key] = value
    return versions


def parse_log(path: Path, versions: dict[str, str]) -> list[dict[str, object]]:
    expected = EXPECTED_LOG_IMPLEMENTATION.get(path.name)
    if expected is None:
        raise ValueError(f"unrecognized benchmark log name: {path.name}")
    text = path.read_text(errors="replace") if path.exists() else ""
    modes = {match.group(1) for line in text.splitlines() if (match := MODE_RE.fullmatch(line.strip()))}
    if expected in {"native_b20", "mock_b20"} and expected not in modes:
        print(f"warning: {path.name} has no verified {expected} mode marker", file=sys.stderr)

    rows: list[dict[str, object]] = []
    for raw in text.splitlines():
        match = BENCHMARK_RE.fullmatch(raw.strip())
        if not match:
            continue
        implementation, operation, scenario, run, gas_used = match.groups()
        if implementation != expected:
            raise ValueError(
                f"{path.name} emitted {implementation}; expected only {expected} observations"
            )
        mode_verified = implementation == "openzeppelin" or implementation in modes
        rows.append(
            {
                "implementation": implementation,
                "operation": operation,
                "scenario": scenario,
                "run": int(run),
                "gas_used": int(gas_used),
                "base_std_commit": versions["BASE_STD_COMMIT"],
                "base_forge_version": versions["BASE_FOUNDRY_VERSION"],
                "base_forge_commit": versions["BASE_FOUNDRY_COMMIT"],
                "base_precompiles_commit": versions["BASE_PRECOMPILES_COMMIT"],
                "foundry_version": versions["FOUNDRY_VERSION"],
                "foundry_commit": versions["FOUNDRY_COMMIT"],
                "openzeppelin_version": versions["OPENZEPPELIN_VERSION"],
                "openzeppelin_commit": versions["OPENZEPPELIN_COMMIT"],
                "solidity_version": versions["SOLIDITY_VERSION"],
                "optimizer_enabled": versions["OPTIMIZER_ENABLED"],
                "optimizer_runs": int(versions["OPTIMIZER_RUNS"]),
                "via_ir": versions["VIA_IR"],
                "evm_version": versions["EVM_VERSION"],
                "execution_environment": ENVIRONMENT[implementation],
                "python_version": versions["PYTHON_VERSION"],
                "matplotlib_version": versions["MATPLOTLIB_VERSION"],
                "mode_verified": str(mode_verified).lower(),
            }
        )
    return rows


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: collect-results.py native.log mock.log openzeppelin.log", file=sys.stderr)
        return 2

    versions = read_versions()
    rows: list[dict[str, object]] = []
    for argument in sys.argv[1:]:
        rows.extend(parse_log(Path(argument), versions))

    implementation_order = {"native_b20": 0, "mock_b20": 1, "openzeppelin": 2}
    scenario_order = {
        ("transfer", "recipient_zero"): 0,
        ("transfer", "recipient_nonzero"): 1,
        ("approve", "zero_to_nonzero"): 2,
        ("approve", "nonzero_to_nonzero"): 3,
        ("transferFrom", "finite_allowance"): 4,
        ("transferFrom", "max_allowance"): 5,
        ("mint", "recipient_zero"): 6,
        ("mint", "recipient_nonzero"): 7,
    }
    rows.sort(
        key=lambda row: (
            scenario_order.get((str(row["operation"]), str(row["scenario"])), 999),
            implementation_order[str(row["implementation"])],
            int(row["run"]),
        )
    )

    RESULTS.mkdir(parents=True, exist_ok=True)
    csv_tmp = RESULTS / "raw.csv.tmp"
    json_tmp = RESULTS / "raw.json.tmp"
    with csv_tmp.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    json_tmp.write_text(
        json.dumps({"metadata": versions, "observations": rows}, indent=2, sort_keys=True) + "\n"
    )
    csv_tmp.replace(RESULTS / "raw.csv")
    json_tmp.replace(RESULTS / "raw.json")
    print(f"collected {len(rows)} observations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
