SHELL := /bin/bash
.DEFAULT_GOAL := all

BASE_FORGE_BIN ?= $(HOME)/.foundry/versions/base-v1.1.0/forge
PYTHON_BIN ?= python3.13
VENV_PYTHON := .venv/bin/python

.PHONY: deps python-deps check correctness canary validate test benchmark plots all clean-results

deps:
	./scripts/setup-deps.sh

python-deps:
	$(PYTHON_BIN) -m venv .venv
	$(VENV_PYTHON) -m pip install --disable-pip-version-check -r requirements.lock

check:
	BASE_FORGE_BIN="$(BASE_FORGE_BIN)" PYTHON_BIN="$(PYTHON_BIN)" ./scripts/check-tooling.sh

correctness: check
	EXPECT_LIVE_PRECOMPILES=true FOUNDRY_BASE=true "$(BASE_FORGE_BIN)" test --offline --match-contract B20CorrectnessTest -vv
	EXPECT_LIVE_PRECOMPILES=false FOUNDRY_BASE=false "$(BASE_FORGE_BIN)" test --offline --match-contract B20CorrectnessTest -vv
	FOUNDRY_BASE=false "$(BASE_FORGE_BIN)" test --offline --match-contract OpenZeppelinCorrectnessTest -vv

canary: check
	BASE_FORGE_BIN="$(BASE_FORGE_BIN)" ./scripts/check-gas-accounting.sh

validate:
	$(PYTHON_BIN) scripts/validate-results.py

test: correctness canary validate

benchmark: correctness
	BASE_FORGE_BIN="$(BASE_FORGE_BIN)" PYTHON_BIN="$(PYTHON_BIN)" ./scripts/run-benchmarks.sh

plots: python-deps validate
	$(VENV_PYTHON) analysis/plot.py
	$(VENV_PYTHON) scripts/render-readme-results.py

all: benchmark plots

clean-results:
	rm -f results/raw.csv results/raw.json results/summary.csv
	rm -f figures/absolute-gas.png figures/absolute-gas.svg
	rm -f figures/absolute-gas-no-openzeppelin.png figures/absolute-gas-no-openzeppelin.svg
	rm -f figures/native-percentage-difference.png figures/native-percentage-difference.svg
	rm -f figures/native-percentage-difference-no-openzeppelin.png figures/native-percentage-difference-no-openzeppelin.svg
