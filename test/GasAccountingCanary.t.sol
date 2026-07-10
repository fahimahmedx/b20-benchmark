// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {console2} from "forge-std/console2.sol";

import {BenchmarkConfig as C} from "./BenchmarkConfig.sol";
import {OpenZeppelinBenchmarkFixture} from "./BenchmarkFixtures.sol";

contract GasAccountingCanaryTest is OpenZeppelinBenchmarkFixture {
    function testGasAccountingCanary() public {
        _seedSupply(false);
        _prepareOpenZeppelinAccess(C.HOLDER);
        vm.prank(C.HOLDER);
        uint256 gasBefore = gasleft();
        bool success = oz.transfer(C.RECIPIENT, C.CALL_AMOUNT);
        uint256 gasUsed = gasBefore - gasleft();
        assertTrue(success);
        console2.log(string.concat("GAS_ACCOUNTING_CANARY,gas_used=", vm.toString(gasUsed)));
    }
}
