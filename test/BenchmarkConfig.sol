// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library BenchmarkConfig {
    address internal constant ADMIN_MINTER = address(0xA11CE);
    address internal constant HOLDER = address(0xB0B);
    address internal constant SPENDER = address(0x5EED);
    address internal constant RECIPIENT = address(0xCAFE);
    address internal constant FACTORY_CALLER = address(0xFACADE);

    uint256 internal constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 internal constant EXISTING_RECIPIENT_BALANCE = 1_000e18;
    uint256 internal constant CALL_AMOUNT = 100e18;
    uint256 internal constant FINITE_ALLOWANCE = 1_000e18;
    uint256 internal constant NEW_ALLOWANCE = 2_000e18;
    uint256 internal constant RUNS = 5;

    bytes32 internal constant B20_SALT = keccak256("b20-gas-benchmark-v1");
}
