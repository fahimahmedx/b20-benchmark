# Native B20 Gas Benchmark

  ## Summary

  Build the requested compact Foundry benchmark using the verified local execution
  path from the B20 launch guide
  (https://docs.base.org/get-started/launch-b20-token), Beryl specification
  (https://docs.base.org/base-chain/specs/upgrades/beryl/b20), and pinned base-std
  (https://github.com/base/base-std/tree/4658f1b7b54ccc61b036adc32830594018ea507e).

  Measure only transfer, approve, transferFrom, and mint across eight scenarios.
  Results will compare Native B20, the unmodified official MockB20 reference
  implementation, and a conventional OpenZeppelin ERC-20 without making CPU-
  performance or feature-equivalence claims.

  ## Implementation and Methodology

  - Pin:
      - base-std: 4658f1b7b54ccc61b036adc32830594018ea507e
      - Base Forge/Base Anvil v1.1.0: 6130ccf6af0b3399777aee3876486e2ba9ebb38f
      - Embedded Base Rust precompiles: a3c3011b16dae73aaea455ec0a5ff614e65b7d0a
      - Foundry: 1.4.1-stable, commit cf7746048646f2ecff48246dd61e265e49ab16f0
      - forge-std: 620536fa5277db4e3fd46772d5cbc1ea0696fb43
      - OpenZeppelin Contracts v5.6.1: 5fd1781b1454fd1ef8e722282f86f9293cacf256
      - Solidity 0.8.30, optimizer enabled with 200 runs, via_ir=false, EVM osaka
      - Python 3.13.12, Matplotlib 3.11.0, with all transitive plotting packages
        locked.

  - Use the underlying Base Forge v1.1.0 binary for all final measurements:
      - Native: FOUNDRY_BASE=true
      - MockB20 and OpenZeppelin: FOUNDRY_BASE=false
      - Stock Forge is used only for a fixed Solidity gas-accounting canary, not
        final results.

  - Import MockB20, MockB20Asset, factory, storage helpers, and BaseTest directly
    from pinned base-std; do not modify or optimize them. Document that
    MockB20Factory depends on vm.etch/vm.store cheatcodes.

  - Add BenchmarkERC20, inheriting OpenZeppelin ERC20 and Ownable, with
    mint(address,uint256) external onlyOwner.

  - Use identical compiler settings, name Benchmark Token, symbol BENCH, 18
    decimals, and these actors:
      - admin/minter/Ownable owner: address(0xA11CE)
      - holder/allowance owner: address(0xB0B)
      - spender: address(0x5EED)
      - recipient: address(0xCAFE)
      - B20 factory caller: address(0xFACADE)

  - B20 uses Asset variant, keccak256("b20-gas-benchmark-v1") salt, default
    policies, default multiplier and supply cap, no pausing or optional features,
    and only grants MINT_ROLE to the admin/minter.

  - Use these exact baseline values:
      - initial total supply: 1,000,000e18
      - transfer/mint/spend amount: 100e18
      - existing recipient balance: 1,000e18
      - initial finite/nonzero allowance: 1,000e18
      - new approved allowance: 2,000e18
      - finite allowance after transferFrom: 900e18

  - Keep total supply constant before every scenario. Allocate the existing
    recipient balance from the holder’s initial balance where necessary.

  - After scenario setup, snapshot state. Before each of five runs, revert to the
    snapshot, cool the token and its loaded storage, then explicitly warm the
    token, caller, owner/spender, recipient, and B20 Policy Registry account as
    applicable. The measured call therefore starts with warm accounts and cold
    token storage.

  - Measure only:

    uint256 gasBefore = gasleft();
    // target token call
    uint256 gasUsed = gasBefore - gasleft();
    Retain and document the identical external-call, ABI, return-decoding, and
    final gasleft() overhead. Do not apply an estimated correction. Chosen states
    avoid storage-clearing refunds.

  - Print exactly five machine-readable observations per implementation/scenario
    using the required BENCHMARK,... format.

  ## Tests, Modes, and Workflow

  - B20Correctness.t.sol runs unchanged in both modes and covers all eight
    scenarios, required balances/supply/allowances, return values, Transfer/
    Approval events, mint authorization, and max-allowance preservation.

  - OpenZeppelinCorrectness.t.sol applies the same checks and confirms the pinned
    OpenZeppelin implementation also preserves maximum allowance.

  - Native verification requires:
      - BaseTest’s behavioral ActivationRegistry.admin() probe to report live
        mode;

      - the B20 factory and token to respond as precompiles;
      - the token’s native initialization marker and factory registration to be
        present.

  - Mock verification requires:
      - the pre-etch probe to report reference mode;
      - factory/token runtime code hashes to match the official compiled mocks.

  - B20Gas.t.sol produces Native B20 or MockB20 observations according to the
    verified mode; OpenZeppelinGas.t.sol produces the baseline observations.

  - Add a fixed-call canary comparing stock Forge and Base Forge with Base
    disabled. Document exact agreement or disagreement for that canary without
    claiming general binary equivalence.

  - Make targets:
      - make test: verify dependencies, run native/mock/OpenZeppelin correctness
        and mode tests, run the gas-accounting canary, and strictly validate
        committed raw results.

      - make benchmark: run correctness first, execute all three gas modes,
        collect outputs, validate them, and create the summary.

      - make plots: validate raw data, regenerate the summary, figures, and README
        result tables.

      - make all: dependencies → correctness → benchmarks → validation → summary →
        figures.

  - Run all three benchmark modes even if one fails. If native execution fails,
    retain only successful MockB20/OpenZeppelin raw observations, fail strict
    validation, skip/remove comparative summaries and figures, and report the
    exact blocker.

  ## Results and Public Interfaces

  - Preserve the proposed repository layout, adding only small version/
    requirements files and tooling checks.

  - collect-results.py parses logs and atomically writes:
      - results/raw.csv
      - results/raw.json
      - results/summary.csv

  - Raw rows include the required columns plus Base Forge, Foundry, OpenZeppelin,
    Python, Matplotlib and embedded Base-precompile versions, and verified
    execution-mode metadata.

  - The validator enforces:
      - the exact 24 implementation/scenario combinations and 120 observations;
      - run IDs 1–5 exactly once;
      - valid identifiers and operation/scenario pairings;
      - positive integer gas;
      - identical repeats;
      - native and mock mode verification;
      - complete, consistent version metadata;
      - CSV/JSON equivalence and no duplicate observation identifiers.

  - Summary columns are implementation, operation, scenario, gas_used, minimum,
    maximum, observations, and identical.

  - Generate deterministic Matplotlib outputs with a fixed backend, style, colors,
    SVG hash salt, dimensions, and scenario order:
      - figures/absolute-gas.png and .svg
      - figures/native-percentage-difference.png and .svg

  - Figure 2 uses the requested formulas, zero reference line, and “percentage
    difference” terminology. No error bars or standard deviations are added.

  - Generate README tables from validated data rather than hand-entering values.
    Do not populate results or interpretation until the benchmark has run
    successfully.

  ## README and Acceptance Criteria

    conditions, mode verification, exact commands, versions, tables, figures,
    interpretation, and concise unresolved limitations.

  - Explicitly state that MockB20 is a reference/conformance implementation rather
    than an optimized production implementation, and OpenZeppelin ERC-20 is not
    feature-equivalent to B20.

  - Include every required limitation, including protocol gas versus CPU time,
    excluded deployment/L1 costs, version and warm/cold sensitivity, possible
    cross-binary reproduction differences, and the benchmark’s limited operation/
    configuration coverage.

  - Acceptance requires passing correctness tests before collection, 120 validated
    deterministic observations, reproducible CSV/JSON/summary outputs, four figure
    files, and no estimated or invented Native B20 values.
