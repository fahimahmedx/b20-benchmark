// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BenchmarkConfig as C} from "./BenchmarkConfig.sol";
import {OpenZeppelinBenchmarkFixture} from "./BenchmarkFixtures.sol";

contract OpenZeppelinCorrectnessTest is OpenZeppelinBenchmarkFixture {
    function testTransferRecipientZero() public {
        _checkTransfer(false);
    }

    function testTransferRecipientNonzero() public {
        _checkTransfer(true);
    }

    function testApproveZeroToNonzero() public {
        _seedSupply(false);
        uint256 supplyBefore = oz.totalSupply();

        vm.expectEmit(true, true, false, true, address(oz));
        emit IERC20.Approval(C.HOLDER, C.SPENDER, C.NEW_ALLOWANCE);
        vm.prank(C.HOLDER);
        bool success = oz.approve(C.SPENDER, C.NEW_ALLOWANCE);

        assertTrue(success);
        assertEq(oz.allowance(C.HOLDER, C.SPENDER), C.NEW_ALLOWANCE);
        assertEq(oz.totalSupply(), supplyBefore);
    }

    function testApproveNonzeroToNonzero() public {
        _seedSupply(false);
        vm.prank(C.HOLDER);
        oz.approve(C.SPENDER, C.FINITE_ALLOWANCE);

        vm.expectEmit(true, true, false, true, address(oz));
        emit IERC20.Approval(C.HOLDER, C.SPENDER, C.NEW_ALLOWANCE);
        vm.prank(C.HOLDER);
        bool success = oz.approve(C.SPENDER, C.NEW_ALLOWANCE);

        assertTrue(success);
        assertEq(oz.allowance(C.HOLDER, C.SPENDER), C.NEW_ALLOWANCE);
    }

    function testTransferFromFiniteAllowance() public {
        _seedSupply(false);
        vm.prank(C.HOLDER);
        oz.approve(C.SPENDER, C.FINITE_ALLOWANCE);
        _checkTransferFrom(C.FINITE_ALLOWANCE, C.FINITE_ALLOWANCE - C.CALL_AMOUNT);
    }

    function testTransferFromMaximumAllowance() public {
        _seedSupply(false);
        vm.prank(C.HOLDER);
        oz.approve(C.SPENDER, type(uint256).max);
        _checkTransferFrom(type(uint256).max, type(uint256).max);
    }

    function testMintRecipientZero() public {
        _checkMint(false);
    }

    function testMintRecipientNonzero() public {
        _checkMint(true);
    }

    function _checkTransfer(bool recipientNonzero) internal {
        _seedSupply(recipientNonzero);
        uint256 holderBefore = oz.balanceOf(C.HOLDER);
        uint256 recipientBefore = oz.balanceOf(C.RECIPIENT);
        uint256 supplyBefore = oz.totalSupply();

        vm.expectEmit(true, true, false, true, address(oz));
        emit IERC20.Transfer(C.HOLDER, C.RECIPIENT, C.CALL_AMOUNT);
        vm.prank(C.HOLDER);
        bool success = oz.transfer(C.RECIPIENT, C.CALL_AMOUNT);

        assertTrue(success);
        assertEq(oz.balanceOf(C.HOLDER), holderBefore - C.CALL_AMOUNT);
        assertEq(oz.balanceOf(C.RECIPIENT), recipientBefore + C.CALL_AMOUNT);
        assertEq(oz.totalSupply(), supplyBefore);
    }

    function _checkTransferFrom(uint256 allowanceBefore, uint256 allowanceAfter) internal {
        uint256 holderBefore = oz.balanceOf(C.HOLDER);
        uint256 recipientBefore = oz.balanceOf(C.RECIPIENT);
        uint256 supplyBefore = oz.totalSupply();
        assertEq(oz.allowance(C.HOLDER, C.SPENDER), allowanceBefore);

        vm.expectEmit(true, true, false, true, address(oz));
        emit IERC20.Transfer(C.HOLDER, C.RECIPIENT, C.CALL_AMOUNT);
        vm.prank(C.SPENDER);
        bool success = oz.transferFrom(C.HOLDER, C.RECIPIENT, C.CALL_AMOUNT);

        assertTrue(success);
        assertEq(oz.balanceOf(C.HOLDER), holderBefore - C.CALL_AMOUNT);
        assertEq(oz.balanceOf(C.RECIPIENT), recipientBefore + C.CALL_AMOUNT);
        assertEq(oz.allowance(C.HOLDER, C.SPENDER), allowanceAfter);
        assertEq(oz.totalSupply(), supplyBefore);
    }

    function _checkMint(bool recipientNonzero) internal {
        _seedSupply(recipientNonzero);
        uint256 recipientBefore = oz.balanceOf(C.RECIPIENT);
        uint256 supplyBefore = oz.totalSupply();
        assertEq(oz.owner(), C.ADMIN_MINTER);

        vm.expectEmit(true, true, false, true, address(oz));
        emit IERC20.Transfer(address(0), C.RECIPIENT, C.CALL_AMOUNT);
        vm.prank(C.ADMIN_MINTER);
        oz.mint(C.RECIPIENT, C.CALL_AMOUNT);

        assertEq(oz.balanceOf(C.RECIPIENT), recipientBefore + C.CALL_AMOUNT);
        assertEq(oz.totalSupply(), supplyBefore + C.CALL_AMOUNT);
    }
}
