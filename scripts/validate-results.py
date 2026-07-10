#!/usr/bin/env python3
"""Strictly validate raw benchmark observations and write summary.csv."""

from __future__ import annotations

import csv
import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
RAW_CSV = RESULTS / "raw.csv"
RAW_JSON = RESULTS / "raw.json"

IMPLEMENTATIONS = {"native_b20", "mock_b20", "openzeppelin"}
SCENARIOS = [
    ("transfer", "recipient_zero"),
    ("transfer", "recipient_nonzero"),
    ("approve", "zero_to_nonzero"),
    ("approve", "nonzero_to_nonzero"),
    ("transferFrom", "finite_allowance"),
    ("transferFrom", "max_allowance"),
    ("mint", "recipient_zero"),
    ("mint", "recipient_nonzero"),
]
REQUIRED_METADATA = {
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
}


def fail(errors: list[str]) -> int:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    return 1


def main() -> int:
    errors: list[str] = []
    if not RAW_CSV.exists() or not RAW_JSON.exists():
        return fail(["results/raw.csv and results/raw.json must both exist"])

    with RAW_CSV.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    payload = json.loads(RAW_JSON.read_text())
    json_rows = payload.get("observations")
    if not isinstance(json_rows, list):
        return fail(["raw.json observations must be an array"])

    if len(rows) != 120:
        errors.append(f"expected 120 raw observations, found {len(rows)}")
    if len(json_rows) != len(rows):
        errors.append("raw CSV and JSON observation counts differ")

    identifiers: set[tuple[str, str, str, int]] = set()
    grouped: dict[tuple[str, str, str], list[tuple[int, int]]] = defaultdict(list)
    expected_pairs = set(SCENARIOS)
    metadata_values: dict[str, set[str]] = defaultdict(set)

    for index, row in enumerate(rows, start=2):
        implementation = row.get("implementation", "")
        operation = row.get("operation", "")
        scenario = row.get("scenario", "")
        if implementation not in IMPLEMENTATIONS:
            errors.append(f"row {index}: invalid implementation {implementation!r}")
        if (operation, scenario) not in expected_pairs:
            errors.append(f"row {index}: invalid operation/scenario {operation}/{scenario}")

        try:
            run = int(row.get("run", ""))
            gas = int(row.get("gas_used", ""))
        except ValueError:
            errors.append(f"row {index}: run and gas_used must be integers")
            continue
        if gas <= 0:
            errors.append(f"row {index}: gas_used must be positive")

        identifier = (implementation, operation, scenario, run)
        if identifier in identifiers:
            errors.append(f"duplicate observation identifier: {identifier}")
        identifiers.add(identifier)
        grouped[(implementation, operation, scenario)].append((run, gas))

        for field in REQUIRED_METADATA:
            if not row.get(field, "").strip():
                errors.append(f"row {index}: missing dependency metadata {field}")
            elif field != "execution_environment":
                metadata_values[field].add(row[field])
        if row.get("mode_verified") != "true":
            errors.append(f"row {index}: execution mode is not verified")

        if index - 2 < len(json_rows):
            json_row = json_rows[index - 2]
            for field, csv_value in row.items():
                json_value = json_row.get(field)
                if field in {"run", "gas_used", "optimizer_runs"}:
                    try:
                        csv_value = int(csv_value)
                    except ValueError:
                        pass
                if json_value != csv_value:
                    errors.append(f"row {index}: CSV/JSON mismatch for {field}")
                    break

    expected_groups = {
        (implementation, operation, scenario)
        for implementation in IMPLEMENTATIONS
        for operation, scenario in SCENARIOS
    }
    missing = expected_groups - set(grouped)
    extra = set(grouped) - expected_groups
    if missing:
        errors.append(f"missing implementation/scenario combinations: {sorted(missing)}")
    if extra:
        errors.append(f"unexpected implementation/scenario combinations: {sorted(extra)}")

    for key, observations in sorted(grouped.items()):
        runs = sorted(run for run, _ in observations)
        values = [gas for _, gas in observations]
        if runs != [1, 2, 3, 4, 5]:
            errors.append(f"{key}: expected run IDs 1..5, found {runs}")
        if len(set(values)) != 1:
            errors.append(f"{key}: repeated measurements differ: {values}")

    for field, values in sorted(metadata_values.items()):
        if len(values) != 1:
            errors.append(f"dependency metadata {field} is inconsistent: {sorted(values)}")

    if errors:
        return fail(errors)

    implementation_order = ["native_b20", "mock_b20", "openzeppelin"]
    summary_fields = [
        "implementation",
        "operation",
        "scenario",
        "gas_used",
        "minimum",
        "maximum",
        "observations",
        "identical",
    ]
    summary_rows: list[dict[str, object]] = []
    for operation, scenario in SCENARIOS:
        for implementation in implementation_order:
            values = [gas for _, gas in grouped[(implementation, operation, scenario)]]
            summary_rows.append(
                {
                    "implementation": implementation,
                    "operation": operation,
                    "scenario": scenario,
                    "gas_used": values[0],
                    "minimum": min(values),
                    "maximum": max(values),
                    "observations": len(values),
                    "identical": "true",
                }
            )

    with (RESULTS / "summary.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=summary_fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(summary_rows)
    print("validated 120 observations; all five-run groups are identical")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
