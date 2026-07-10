#!/usr/bin/env python3
"""Generate deterministic absolute-gas and percentage-difference figures."""

from __future__ import annotations

import csv
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
os.environ.setdefault("MPLCONFIGDIR", str(ROOT / ".benchmark-work" / "matplotlib"))
os.environ.setdefault("XDG_CACHE_HOME", str(ROOT / ".benchmark-work" / "cache"))
Path(os.environ["MPLCONFIGDIR"]).mkdir(parents=True, exist_ok=True)
Path(os.environ["XDG_CACHE_HOME"]).mkdir(parents=True, exist_ok=True)

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from matplotlib.ticker import FuncFormatter  # noqa: E402

SUMMARY = ROOT / "results" / "summary.csv"
FIGURES = ROOT / "figures"

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
IMPLEMENTATIONS = [
    ("native_b20", "Native B20", "#0052FF"),
    ("mock_b20", "MockB20", "#8B5CF6"),
    ("openzeppelin", "OpenZeppelin ERC-20", "#14B8A6"),
]

BACKGROUND = "#F7F9FC"
TEXT = "#172033"
MUTED_TEXT = "#526078"
GRID = "#DDE4EE"


def load() -> dict[tuple[str, str, str], int]:
    with SUMMARY.open(newline="") as handle:
        return {
            (row["implementation"], row["operation"], row["scenario"]): int(row["gas_used"])
            for row in csv.DictReader(handle)
        }


def save(fig: plt.Figure, stem: str) -> None:
    metadata = {"Creator": "b20-gas-benchmark", "Date": None}
    fig.savefig(FIGURES / f"{stem}.png", dpi=200, bbox_inches="tight", metadata=metadata)
    fig.savefig(FIGURES / f"{stem}.svg", bbox_inches="tight", metadata=metadata)
    plt.close(fig)


def absolute_figure(data: dict[tuple[str, str, str], int]) -> None:
    labels = [label for _, _, label in SCENARIOS]
    x = np.arange(len(labels))
    width = 0.25
    fig, ax = plt.subplots(figsize=(16, 8), facecolor=BACKGROUND)
    ax.set_facecolor(BACKGROUND)
    series_values = {
        identifier: [
            data[(identifier, operation, scenario)] for operation, scenario, _ in SCENARIOS
        ]
        for identifier, _, _ in IMPLEMENTATIONS
    }
    for offset, (identifier, display, color) in enumerate(IMPLEMENTATIONS):
        values = series_values[identifier]
        bars = ax.bar(
            x + (offset - 1) * width,
            values,
            width,
            label=display,
            color=color,
            edgecolor=BACKGROUND,
            linewidth=1.2,
            zorder=3,
        )
        for index, (bar, value) in enumerate(zip(bars, values, strict=True)):
            group = [series_values[item[0]][index] for item in IMPLEMENTATIONS]
            padding = 5 + offset * 10 if max(group) - min(group) < 2_500 else 5
            ax.annotate(
                f"{value:,}",
                xy=(bar.get_x() + bar.get_width() / 2, bar.get_height()),
                xytext=(0, padding),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=8.5,
                color=TEXT,
                fontweight="bold",
            )
    ax.set_title(
        "Execution gas by token implementation and scenario",
        fontsize=19,
        fontweight="bold",
        color=TEXT,
        pad=24,
    )
    ax.set_ylabel("Gas used by measured token call", color=MUTED_TEXT, labelpad=12)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=28, ha="right", rotation_mode="anchor")
    ax.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:,.0f}"))
    ax.set_axisbelow(True)
    ax.grid(axis="y", color=GRID, linewidth=1.0)
    ax.legend(
        frameon=True,
        facecolor="white",
        edgecolor=GRID,
        framealpha=1,
        ncols=3,
        loc="upper center",
        bbox_to_anchor=(0.5, 1.02),
        borderpad=0.7,
        columnspacing=1.8,
    )
    ax.margins(y=0.2)
    fig.tight_layout()
    save(fig, "absolute-gas")


def percentage_figure(data: dict[tuple[str, str, str], int]) -> None:
    labels = [label for _, _, label in SCENARIOS]
    versus_mock: list[float] = []
    versus_oz: list[float] = []
    for operation, scenario, _ in SCENARIOS:
        native = data[("native_b20", operation, scenario)]
        mock = data[("mock_b20", operation, scenario)]
        oz = data[("openzeppelin", operation, scenario)]
        versus_mock.append((native - mock) / mock * 100)
        versus_oz.append((native - oz) / oz * 100)

    x = np.arange(len(labels))
    width = 0.36
    fig, ax = plt.subplots(figsize=(16, 8), facecolor=BACKGROUND)
    ax.set_facecolor(BACKGROUND)
    mock_bars = ax.bar(
        x - width / 2,
        versus_mock,
        width,
        label="vs MockB20",
        color="#8B5CF6",
        edgecolor=BACKGROUND,
        linewidth=1.2,
        zorder=3,
    )
    oz_bars = ax.bar(
        x + width / 2,
        versus_oz,
        width,
        label="vs OpenZeppelin ERC-20",
        color="#14B8A6",
        edgecolor=BACKGROUND,
        linewidth=1.2,
        zorder=3,
    )
    ax.bar_label(mock_bars, fmt="%.1f%%", padding=4, fontsize=9, color=TEXT, fontweight="bold")
    ax.bar_label(oz_bars, fmt="%.1f%%", padding=4, fontsize=9, color=TEXT, fontweight="bold")
    ax.axhline(0, color=TEXT, linewidth=1.15, zorder=2)
    ax.set_title(
        "Native B20 gas percentage difference",
        fontsize=19,
        fontweight="bold",
        color=TEXT,
        pad=24,
    )
    ax.set_ylabel("Percentage difference in gas used (%)", color=MUTED_TEXT, labelpad=12)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=28, ha="right", rotation_mode="anchor")
    ax.set_axisbelow(True)
    ax.grid(axis="y", color=GRID, linewidth=1.0)
    ax.legend(
        frameon=True,
        facecolor="white",
        edgecolor=GRID,
        framealpha=1,
        ncols=2,
        loc="upper center",
        bbox_to_anchor=(0.5, 1.02),
        borderpad=0.7,
        columnspacing=1.8,
    )
    ax.margins(y=0.2)
    fig.tight_layout()
    save(fig, "native-percentage-difference")


def main() -> None:
    matplotlib.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 11,
            "axes.spines.top": False,
            "axes.spines.right": False,
            "axes.edgecolor": GRID,
            "axes.labelcolor": MUTED_TEXT,
            "xtick.color": MUTED_TEXT,
            "ytick.color": MUTED_TEXT,
            "svg.hashsalt": "b20-gas-benchmark-v1",
        }
    )
    FIGURES.mkdir(parents=True, exist_ok=True)
    data = load()
    absolute_figure(data)
    percentage_figure(data)
    print("wrote absolute and percentage-difference figures as PNG and SVG")


if __name__ == "__main__":
    main()
