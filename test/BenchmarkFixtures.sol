// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {BaseTest} from "base-std-test/lib/BaseTest.sol";
import {MockB20Asset} from "base-std-test/lib/mocks/MockB20Asset.sol";
import {MockB20Factory} from "base-std-test/lib/mocks/MockB20Factory.sol";
import {B20Constants} from "base-std/lib/B20Constants.sol";
import {B20FactoryLib} from "base-std/lib/B20FactoryLib.sol";
import {IB20} from "base-std/interfaces/IB20.sol";
import {IB20Factory} from "base-std/interfaces/IB20Factory.sol";
import {StdPrecompiles} from "base-std/StdPrecompiles.sol";

import {BenchmarkERC20} from "../src/BenchmarkERC20.sol";
import {BenchmarkConfig as C} from "./BenchmarkConfig.sol";

abstract contract B20BenchmarkFixture is BaseTest {
    IB20 internal b20;

    function setUp() public virtual override {
        super.setUp();

        bytes[] memory initCalls = new bytes[](1);
        initCalls[0] = B20FactoryLib.encodeGrantRole(B20Constants.MINT_ROLE, C.ADMIN_MINTER);

        bytes memory params =
            B20FactoryLib.encodeAssetCreateParams("Benchmark Token", "BENCH", C.ADMIN_MINTER, 18);

        vm.prank(C.FACTORY_CALLER);
        b20 = IB20(
            StdPrecompiles.B20_FACTORY
                .createB20(IB20Factory.B20Variant.ASSET, C.B20_SALT, params, initCalls)
        );

        vm.label(C.ADMIN_MINTER, "admin-minter");
        vm.label(C.HOLDER, "holder");
        vm.label(C.SPENDER, "spender");
        vm.label(C.RECIPIENT, "recipient");
        vm.label(address(b20), "benchmark-b20");

        _verifyExpectedMode();
    }

    function _verifyExpectedMode() internal view {
        bool expectedLive = vm.envOr("EXPECT_LIVE_PRECOMPILES", livePrecompiles);
        assertEq(livePrecompiles, expectedLive, "unexpected B20 execution mode");
        assertTrue(StdPrecompiles.B20_FACTORY.isB20(address(b20)), "factory must recognize token");
        assertTrue(
            StdPrecompiles.B20_FACTORY.isB20Initialized(address(b20)), "token must be initialized"
        );

        if (livePrecompiles) {
            assertEq(StdPrecompiles.B20_FACTORY_ADDRESS.code, hex"ef", "native factory marker");
            assertEq(address(b20).code, hex"ef", "native token marker");
            console2.log("BENCHMARK_MODE,implementation=native_b20,verified=true");
        } else {
            assertEq(
                keccak256(StdPrecompiles.B20_FACTORY_ADDRESS.code),
                keccak256(type(MockB20Factory).runtimeCode),
                "mock factory bytecode"
            );
            assertEq(
                keccak256(address(b20).code),
                keccak256(type(MockB20Asset).runtimeCode),
                "mock token bytecode"
            );
            console2.log("BENCHMARK_MODE,implementation=mock_b20,verified=true");
        }
    }

    function _implementation() internal view returns (string memory) {
        return livePrecompiles ? "native_b20" : "mock_b20";
    }

    function _seedSupply(bool recipientNonzero) internal {
        if (recipientNonzero) {
            vm.prank(C.ADMIN_MINTER);
            b20.mint(C.HOLDER, C.INITIAL_SUPPLY - C.EXISTING_RECIPIENT_BALANCE);
            vm.prank(C.ADMIN_MINTER);
            b20.mint(C.RECIPIENT, C.EXISTING_RECIPIENT_BALANCE);
        } else {
            vm.prank(C.ADMIN_MINTER);
            b20.mint(C.HOLDER, C.INITIAL_SUPPLY);
        }
    }

    /// @dev Model a direct token transaction: involved accounts are warm, token storage is cold.
    function _prepareB20Access(address caller) internal {
        vm.cool(address(b20));
        vm.cool(StdPrecompiles.POLICY_REGISTRY_ADDRESS);

        assertGt(address(b20).code.length, 0, "warm token account");
        assertGt(StdPrecompiles.POLICY_REGISTRY_ADDRESS.code.length, 0, "warm policy registry");
        assertEq(caller.balance, 0, "warm caller");
        assertEq(C.HOLDER.balance, 0, "warm holder");
        assertEq(C.SPENDER.balance, 0, "warm spender");
        assertEq(C.RECIPIENT.balance, 0, "warm recipient");
    }
}

abstract contract OpenZeppelinBenchmarkFixture is Test {
    BenchmarkERC20 internal oz;

    function setUp() public virtual {
        vm.prank(C.FACTORY_CALLER);
        oz = new BenchmarkERC20(C.ADMIN_MINTER);

        vm.label(C.ADMIN_MINTER, "admin-minter");
        vm.label(C.HOLDER, "holder");
        vm.label(C.SPENDER, "spender");
        vm.label(C.RECIPIENT, "recipient");
        vm.label(address(oz), "benchmark-openzeppelin");
    }

    function _seedSupply(bool recipientNonzero) internal {
        if (recipientNonzero) {
            vm.prank(C.ADMIN_MINTER);
            oz.mint(C.HOLDER, C.INITIAL_SUPPLY - C.EXISTING_RECIPIENT_BALANCE);
            vm.prank(C.ADMIN_MINTER);
            oz.mint(C.RECIPIENT, C.EXISTING_RECIPIENT_BALANCE);
        } else {
            vm.prank(C.ADMIN_MINTER);
            oz.mint(C.HOLDER, C.INITIAL_SUPPLY);
        }
    }

    function _prepareOpenZeppelinAccess(address caller) internal {
        vm.cool(address(oz));

        assertGt(address(oz).code.length, 0, "warm token account");
        assertEq(caller.balance, 0, "warm caller");
        assertEq(C.HOLDER.balance, 0, "warm holder");
        assertEq(C.SPENDER.balance, 0, "warm spender");
        assertEq(C.RECIPIENT.balance, 0, "warm recipient");
    }
}
