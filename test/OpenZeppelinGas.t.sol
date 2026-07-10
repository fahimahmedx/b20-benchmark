// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {console2} from "forge-std/console2.sol";

import {BenchmarkConfig as C} from "./BenchmarkConfig.sol";
import {OpenZeppelinBenchmarkFixture} from "./BenchmarkFixtures.sol";

contract OpenZeppelinGasTest is OpenZeppelinBenchmarkFixture {
    function testGasTransferRecipientZero() public {
        _seedSupply(false);
        _benchmarkTransfer("recipient_zero");
    }

    function testGasTransferRecipientNonzero() public {
        _seedSupply(true);
        _benchmarkTransfer("recipient_nonzero");
    }

    function testGasApproveZeroToNonzero() public {
        _seedSupply(false);
        _benchmarkApprove("zero_to_nonzero");
    }

    function testGasApproveNonzeroToNonzero() public {
        _seedSupply(false);
        vm.prank(C.HOLDER);
        oz.approve(C.SPENDER, C.FINITE_ALLOWANCE);
        _benchmarkApprove("nonzero_to_nonzero");
    }

    function testGasTransferFromFiniteAllowance() public {
        _seedSupply(false);
        vm.prank(C.HOLDER);
        oz.approve(C.SPENDER, C.FINITE_ALLOWANCE);
        _benchmarkTransferFrom("finite_allowance");
    }

    function testGasTransferFromMaximumAllowance() public {
        _seedSupply(false);
        vm.prank(C.HOLDER);
        oz.approve(C.SPENDER, type(uint256).max);
        _benchmarkTransferFrom("max_allowance");
    }

    function testGasMintRecipientZero() public {
        _seedSupply(false);
        _benchmarkMint("recipient_zero");
    }

    function testGasMintRecipientNonzero() public {
        _seedSupply(true);
        _benchmarkMint("recipient_nonzero");
    }

    function _benchmarkTransfer(string memory scenario) internal {
        _prepareOpenZeppelinAccess(C.HOLDER);
        vm.prank(C.HOLDER);
        uint256 gasBefore = gasleft();
        bool success = oz.transfer(C.RECIPIENT, C.CALL_AMOUNT);
        uint256 gasUsed = gasBefore - gasleft();
        assertTrue(success);
        _log("transfer", scenario, _run(), gasUsed);
    }

    function _benchmarkApprove(string memory scenario) internal {
        _prepareOpenZeppelinAccess(C.HOLDER);
        vm.prank(C.HOLDER);
        uint256 gasBefore = gasleft();
        bool success = oz.approve(C.SPENDER, C.NEW_ALLOWANCE);
        uint256 gasUsed = gasBefore - gasleft();
        assertTrue(success);
        _log("approve", scenario, _run(), gasUsed);
    }

    function _benchmarkTransferFrom(string memory scenario) internal {
        _prepareOpenZeppelinAccess(C.SPENDER);
        vm.prank(C.SPENDER);
        uint256 gasBefore = gasleft();
        bool success = oz.transferFrom(C.HOLDER, C.RECIPIENT, C.CALL_AMOUNT);
        uint256 gasUsed = gasBefore - gasleft();
        assertTrue(success);
        _log("transferFrom", scenario, _run(), gasUsed);
    }

    function _benchmarkMint(string memory scenario) internal {
        _prepareOpenZeppelinAccess(C.ADMIN_MINTER);
        vm.prank(C.ADMIN_MINTER);
        uint256 gasBefore = gasleft();
        oz.mint(C.RECIPIENT, C.CALL_AMOUNT);
        uint256 gasUsed = gasBefore - gasleft();
        _log("mint", scenario, _run(), gasUsed);
    }

    function _run() internal view returns (uint256 run) {
        run = vm.envUint("BENCHMARK_RUN");
        assertGe(run, 1);
        assertLe(run, C.RUNS);
    }

    function _log(string memory operation, string memory scenario, uint256 run, uint256 gasUsed)
        internal
        pure
    {
        console2.log(
            string.concat(
                "BENCHMARK,implementation=openzeppelin,operation=",
                operation,
                ",scenario=",
                scenario,
                ",run=",
                vm.toString(run),
                ",gas_used=",
                vm.toString(gasUsed)
            )
        );
    }
}
