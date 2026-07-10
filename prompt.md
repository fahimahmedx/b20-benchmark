Build a small, reproducible gas benchmark comparing:

1. Native B20 Asset execution using Base’s B20 precompiles.
2. Base’s official Solidity `MockB20` / `MockB20Asset` reference implementation from `base/base-std`.
3. A minimal OpenZeppelin ERC-20 implementation.

Use these sources as authoritative references:

* https://docs.base.org/get-started/launch-b20-token
* https://docs.base.org/base-chain/specs/upgrades/beryl/b20
* https://github.com/base/base-std/tree/main/docs/B20
* The relevant B20 interfaces, mocks, libraries and tests in `base/base-std`

The goal is to produce accurate, reproducible gas results that can be shared publicly in a technical X/Twitter post.

Do not expand this into a full research paper or a comprehensive B20 benchmark suite. Prioritize correctness, clear methodology and a small number of trustworthy results.

## Main research question

How much execution gas does native B20 use for common ERC-20 operations compared with:

* Base’s official Solidity B20 reference implementation; and
* a conventional OpenZeppelin ERC-20?

## Important terminology

Use the following descriptions consistently:

* **Native B20:** B20 Asset functionality executed through Base’s Rust precompiles.
* **MockB20:** Base’s official Solidity reference or conformance implementation.
* **OpenZeppelin ERC-20:** a conventional Solidity ERC-20 baseline.

Do not describe `MockB20` as an optimized production Solidity implementation.

Do not describe OpenZeppelin ERC-20 as fully feature-equivalent to B20.

Do not claim that lower gas necessarily means proportionally lower CPU execution time. Gas is protocol-defined execution accounting.

## MVP benchmark scope

Benchmark only these four operations:

1. `transfer`
2. `approve`
3. `transferFrom`
4. `mint`

Use the B20 Asset variant with:

* the default transfer policy;
* no custom policies;
* no pausing;
* no permit;
* no memo functionality;
* no batch operations;
* no supply multiplier changes beyond the default configuration.

Create the smallest reasonable OpenZeppelin ERC-20 wrapper required to expose controlled `mint`.

Do not benchmark:

* token creation or deployment;
* `MockB20Factory` creation gas;
* L1 data fees;
* live-network dollar costs;
* permit;
* pausing;
* custom policies;
* batch minting;
* failed transactions;
* optimized custom ERC-20 implementations.

## Required scenarios

Benchmark these eight scenarios.

### Transfer

1. Transfer to a recipient whose initial balance is zero.
2. Transfer to a recipient whose initial balance is nonzero.

### Approve

3. Change allowance from zero to a nonzero value.
4. Change allowance from one nonzero value to another nonzero value.

### transferFrom

5. Use a finite allowance that is decremented.
6. Use the maximum allowance, where the implementation does not decrement it.

Confirm that maximum-allowance behavior is equivalent across implementations before including this scenario. If it is not equivalent, document the difference and omit the comparison.

### Mint

7. Mint to an account whose initial balance is zero.
8. Mint to an account whose initial balance is nonzero.

Use the same:

* account addresses;
* token amounts;
* initial balances;
* allowances;
* total supply;
* role configuration;

across all implementations wherever semantically possible.

## Preliminary investigation

Before writing the benchmark, inspect the linked documentation and source code.

Determine and document:

1. How native B20 precompiles are executed locally.
2. How `BaseTest` switches between native-precompile mode and Solidity-mock mode.
3. Which commands are required to run each mode.
4. Whether standard Forge and Base Forge use compatible gas accounting.
5. How to verify that a test actually used the native precompile rather than the Solidity mock.
6. Whether `MockB20` requires Foundry cheatcodes or special setup.
7. The exact `base-std` commit being benchmarked.

Do not assume commands or repository paths are correct without verifying them.

## Measurement methodology

The primary metric is:

> Gas consumed by the target token call, excluding test setup, deployment, correctness assertions, event assertions, logging and result serialization.

Measure the target call using an explicit gas boundary such as:

```solidity
uint256 gasBefore = gasleft();
bool success = token.transfer(recipient, amount);
uint256 gasUsed = gasBefore - gasleft();
```

Account for any fixed measurement overhead. Either:

* measure and subtract a carefully validated control overhead; or
* retain the overhead and state clearly that it is identical across implementations.

Prefer retaining a small identical measurement overhead over applying an unreliable correction.

Do not rely solely on Foundry’s test-level gas report because it may include unrelated test harness overhead.

For every result, print a machine-readable line with this form:

```text
BENCHMARK,implementation=native_b20,operation=transfer,scenario=recipient_zero,run=1,gas_used=12345
```

Use implementation identifiers:

* `native_b20`
* `mock_b20`
* `openzeppelin`

## State isolation

Every measurement must begin from a clean and equivalent state.

Use one of these approaches:

* deploy and initialize fresh instances before each measurement; or
* create an EVM snapshot after setup and revert to it before each run.

Do not perform multiple state-changing benchmark calls sequentially without resetting state.

Avoid unintentionally warming storage or accounts before the timed call.

Queries used for correctness validation should occur after the timed call, not before it, unless they are part of the required initial setup.

Explicitly document whether the target token address, sender, recipient and allowance-related storage are cold or warm at the beginning of the measured call.

For the MVP, use one consistent and reproducible access condition rather than building a full cold-versus-warm matrix.

## Correctness requirements

Write correctness tests separately from gas-measurement tests.

Before accepting a gas result, verify equivalent observable behavior across the three implementations.

### Transfer correctness

Verify:

* the sender balance decreases by the transfer amount;
* the recipient balance increases by the transfer amount;
* total supply is unchanged;
* the call returns the expected value;
* the standard `Transfer` event is emitted.

### Approve correctness

Verify:

* the resulting allowance equals the approved amount;
* the call returns the expected value;
* the standard `Approval` event is emitted.

### transferFrom correctness

Verify:

* the owner balance decreases;
* the recipient balance increases;
* total supply is unchanged;
* finite allowance is reduced correctly;
* maximum allowance behavior matches the implementation’s documented behavior;
* the standard `Transfer` event is emitted.

### Mint correctness

Verify:

* the recipient balance increases;
* total supply increases by the mint amount;
* the expected `Transfer` event from the zero address is emitted;
* the caller has the required mint authorization.

The benchmark process must fail before producing graphs if correctness tests fail.

## Repetitions

Run every benchmark scenario five times from an identical reset state.

The purpose is to detect accidental state contamination or nondeterminism.

For deterministic local execution, all five gas values should normally be identical.

If they differ:

1. do not average them silently;
2. investigate the cause;
3. report all values;
4. explain the source of variability;
5. do not generate final claims until the discrepancy is resolved.

## Version pinning

Pin and report exact versions or commit hashes for:

* `base/base-std`;
* Base Forge or Base’s Foundry fork;
* Foundry;
* OpenZeppelin Contracts;
* Solidity;
* Python;
* plotting dependencies.

Also report:

* optimizer enabled or disabled;
* optimizer runs;
* `via_ir`;
* EVM version;
* relevant Base Foundry configuration.

Use the same Solidity compiler settings for `MockB20` and OpenZeppelin unless the official Base test setup requires otherwise. Document any unavoidable difference.

Do not modify the official `MockB20` implementation for optimization.

## Raw data

Export all measurements to:

* `results/raw.csv`
* `results/raw.json`

The CSV should contain at least:

```text
implementation
operation
scenario
run
gas_used
base_std_commit
solidity_version
optimizer_enabled
optimizer_runs
via_ir
evm_version
execution_environment
```

Also create:

* `results/summary.csv`

The summary should contain one row per implementation, operation and scenario with:

* gas used;
* minimum;
* maximum;
* number of observations;
* whether all repeated measurements were identical.

Do not add standard deviations or error bars when all observations are identical.

## Graphs

Create a reproducible Python script that reads `results/raw.csv` or `results/summary.csv`.

Generate two graphs.

### Figure 1: Absolute gas

Create a grouped bar chart showing gas used for all eight scenarios.

Each scenario should contain bars for:

* Native B20
* MockB20
* OpenZeppelin ERC-20

Use clear labels such as:

* `transfer: zero-balance recipient`
* `transfer: existing-balance recipient`
* `approve: zero → nonzero`
* `approve: nonzero → nonzero`
* `transferFrom: finite allowance`
* `transferFrom: max allowance`
* `mint: zero-balance recipient`
* `mint: existing-balance recipient`

### Figure 2: Native B20 percentage difference

For every scenario, calculate:

```text
Difference vs MockB20 =
(native B20 gas - MockB20 gas) / MockB20 gas × 100
```

and:

```text
Difference vs OpenZeppelin =
(native B20 gas - OpenZeppelin gas) / OpenZeppelin gas × 100
```

Negative values indicate that native B20 used less gas.

The graph title and labels must use “percentage difference” or “gas reduction,” not “performance improvement.”

Export both figures as:

* PNG
* SVG

## README requirements

Create a detailed `README.md` that explains:

1. The benchmark’s research question.
2. What B20 is.
3. How Base’s B20 precompiles differ from Solidity token execution.
4. The three implementations.
5. Why `MockB20` is a reference implementation rather than an optimized production implementation.
6. Why OpenZeppelin ERC-20 is not fully feature-equivalent to B20.
7. The eight benchmark scenarios.
8. Exact initial balances, allowances and token amounts.
9. How gas is measured.
10. What setup and overhead are excluded.
11. How state is reset.
12. How native-precompile mode is verified.
13. Exact dependency versions.
14. Commands to reproduce the benchmark.
15. Results tables.
16. Generated graphs.
17. Interpretation of the results.
18. Limitations and threats to validity.

The limitations section must explicitly mention:

* `MockB20` is not gas-optimized;
* OpenZeppelin ERC-20 has fewer built-in features;
* deployment and creation gas are excluded;
* Base L1 data fees are excluded;
* gas is protocol pricing and not a direct CPU benchmark;
* native B20 and MockB20 may run through different Foundry binaries;
* results apply only to the pinned software versions;
* storage state and warm/cold access affect gas;
* the benchmark does not prove that B20 is cheaper for every possible operation or configuration.

## Repository structure

Use a structure similar to:

```text
b20-gas-benchmark/
├── src/
│   └── BenchmarkERC20.sol
├── test/
│   ├── B20Correctness.t.sol
│   ├── B20Gas.t.sol
│   ├── OpenZeppelinCorrectness.t.sol
│   └── OpenZeppelinGas.t.sol
├── scripts/
│   ├── run-native.sh
│   ├── run-mock.sh
│   ├── run-openzeppelin.sh
│   ├── collect-results.py
│   └── validate-results.py
├── analysis/
│   └── plot.py
├── results/
│   ├── raw.csv
│   ├── raw.json
│   └── summary.csv
├── figures/
├── foundry.toml
├── Makefile
└── README.md
```

The exact structure may change if Base’s tooling requires it, but keep the repository simple.

## One-command workflow

Provide these commands:

```bash
make test
make benchmark
make plots
make all
```

Expected behavior:

### `make test`

* runs all correctness tests;
* verifies native and mock execution modes;
* fails if semantic checks fail.

### `make benchmark`

* runs all three implementations;
* collects five observations for every scenario;
* writes raw CSV and JSON;
* validates that all expected observations exist.

### `make plots`

* reads the raw data;
* generates the summary table;
* generates both figures.

### `make all`

Runs:

```text
correctness tests
→ benchmark collection
→ result validation
→ summary generation
→ graph generation
```

## Validation script

Add a validation script that fails if:

* any of the 24 implementation/scenario combinations is missing;
* any combination has fewer than five observations;
* an implementation is mislabeled;
* gas values are zero or negative;
* repeated deterministic results unexpectedly differ;
* native mode was not verified;
* mock mode was not verified;
* dependency versions are missing;
* the raw dataset contains duplicate observation identifiers.

There should be:

```text
3 implementations × 8 scenarios × 5 runs = 120 raw observations
```

## Final deliverables

Produce:

1. A complete runnable repository.
2. Correctness tests.
3. Gas benchmark tests.
4. Raw CSV and JSON output.
5. A summary CSV.
6. Two graphs in PNG and SVG formats.
7. A detailed README.
8. Exact reproduction commands.
9. A concise section describing unresolved methodological limitations.

Do not invent gas results.

If native B20 execution cannot be reliably run or measured in the available environment:

* explain the exact blocker;
* complete the MockB20 and OpenZeppelin portions where possible;
* leave native B20 results absent;
* do not substitute estimates or simulated values;
* do not generate comparative claims using missing data.
