#!/usr/bin/env python3
"""Replace the generated results block in README.md from validated summary.csv."""

from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = ROOT / "README.md"
START = "<!-- BEGIN GENERATED RESULTS -->"
END = "<!-- END GENERATED RESULTS -->"
SCENARIOS = [
    ("transfer", "recipient_zero", "transfer: zero-balance recipient"),
    ("transfer", "recipient_nonzero", "transfer: existing-balance recipient"),
    ("approve", "zero_to_nonzero", "approve: zero → nonzero"),
    ("approve", "nonzero_to_nonzero", "approve: nonzero → nonzero"),
    ("transferFrom", "finite_allowance", "transferFrom: finite allowance"),
    ("transferFrom", "max_allowance", "transferFrom: max allowance"),
    ("mint", "recipient_zero", "mint: zero-balance recipient"),
    ("mint", "recipient_nonzero", "mint: existing-balance recipient"),
]


def main() -> None:
    with (ROOT / "results" / "summary.csv").open(newline="") as handle:
        values = {
            (row["implementation"], row["operation"], row["scenario"]): int(row["gas_used"])
            for row in csv.DictReader(handle)
        }

    lines = [
        START,
        "| Scenario | Native B20 | MockB20 (Solidity) |",
        "|---|---:|---:|",
    ]
    for operation, scenario, label in SCENARIOS:
        lines.append(
            f"| {label} | {values[('native_b20', operation, scenario)]:,} "
            f"| {values[('mock_b20', operation, scenario)]:,} |"
        )
    lines.extend(
        [
            "",
            "| Scenario | Native vs MockB20 (Solidity) |",
            "|---|---:|",
        ]
    )
    for operation, scenario, label in SCENARIOS:
        native = values[("native_b20", operation, scenario)]
        mock = values[("mock_b20", operation, scenario)]
        lines.append(f"| {label} | {(native - mock) / mock * 100:+.1f}% |")
    lines.append(END)

    text = README.read_text()
    before, remainder = text.split(START, 1)
    _, after = remainder.split(END, 1)
    README.write_text(before + "\n".join(lines) + after)
    print("updated README generated results tables")


if __name__ == "__main__":
    main()
