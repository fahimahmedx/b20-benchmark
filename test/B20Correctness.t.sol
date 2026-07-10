// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {B20Constants} from "base-std/lib/B20Constants.sol";
import {IB20} from "base-std/interfaces/IB20.sol";

import {BenchmarkConfig as C} from "./BenchmarkConfig.sol";
import {B20BenchmarkFixture} from "./BenchmarkFixtures.sol";

contract B20CorrectnessTest is B20BenchmarkFixture {
    function testTransferRecipientZero() public {
        _checkTransfer(false);
    }

    function testTransferRecipientNonzero() public {
        _checkTransfer(true);
    }

    function testApproveZeroToNonzero() public {
        _seedSupply(false);
        uint256 supplyBefore = b20.totalSupply();

        vm.expectEmit(true, true, false, true, address(b20));
        emit IB20.Approval(C.HOLDER, C.SPENDER, C.NEW_ALLOWANCE);
        vm.prank(C.HOLDER);
        bool success = b20.approve(C.SPENDER, C.NEW_ALLOWANCE);

        assertTrue(success);
        assertEq(b20.allowance(C.HOLDER, C.SPENDER), C.NEW_ALLOWANCE);
        assertEq(b20.totalSupply(), supplyBefore);
    }

    function testApproveNonzeroToNonzero() public {
        _seedSupply(false);
        vm.prank(C.HOLDER);
        b20.approve(C.SPENDER, C.FINITE_ALLOWANCE);

        vm.expectEmit(true, true, false, true, address(b20));
        emit IB20.Approval(C.HOLDER, C.SPENDER, C.NEW_ALLOWANCE);
        vm.prank(C.HOLDER);
        bool success = b20.approve(C.SPENDER, C.NEW_ALLOWANCE);

        assertTrue(success);
        assertEq(b20.allowance(C.HOLDER, C.SPENDER), C.NEW_ALLOWANCE);
    }

    function testTransferFromFiniteAllowance() public {
        _seedSupply(false);
        vm.prank(C.HOLDER);
        b20.approve(C.SPENDER, C.FINITE_ALLOWANCE);
        _checkTransferFrom(C.FINITE_ALLOWANCE, C.FINITE_ALLOWANCE - C.CALL_AMOUNT);
    }

    function testTransferFromMaximumAllowance() public {
        _seedSupply(false);
        vm.prank(C.HOLDER);
        b20.approve(C.SPENDER, type(uint256).max);
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
        uint256 holderBefore = b20.balanceOf(C.HOLDER);
        uint256 recipientBefore = b20.balanceOf(C.RECIPIENT);
        uint256 supplyBefore = b20.totalSupply();

        vm.expectEmit(true, true, false, true, address(b20));
        emit IB20.Transfer(C.HOLDER, C.RECIPIENT, C.CALL_AMOUNT);
        vm.prank(C.HOLDER);
        bool success = b20.transfer(C.RECIPIENT, C.CALL_AMOUNT);

        assertTrue(success);
        assertEq(b20.balanceOf(C.HOLDER), holderBefore - C.CALL_AMOUNT);
        assertEq(b20.balanceOf(C.RECIPIENT), recipientBefore + C.CALL_AMOUNT);
        assertEq(b20.totalSupply(), supplyBefore);
    }

    function _checkTransferFrom(uint256 allowanceBefore, uint256 allowanceAfter) internal {
        uint256 holderBefore = b20.balanceOf(C.HOLDER);
        uint256 recipientBefore = b20.balanceOf(C.RECIPIENT);
        uint256 supplyBefore = b20.totalSupply();
        assertEq(b20.allowance(C.HOLDER, C.SPENDER), allowanceBefore);

        vm.expectEmit(true, true, false, true, address(b20));
        emit IB20.Transfer(C.HOLDER, C.RECIPIENT, C.CALL_AMOUNT);
        vm.prank(C.SPENDER);
        bool success = b20.transferFrom(C.HOLDER, C.RECIPIENT, C.CALL_AMOUNT);

        assertTrue(success);
        assertEq(b20.balanceOf(C.HOLDER), holderBefore - C.CALL_AMOUNT);
        assertEq(b20.balanceOf(C.RECIPIENT), recipientBefore + C.CALL_AMOUNT);
        assertEq(b20.allowance(C.HOLDER, C.SPENDER), allowanceAfter);
        assertEq(b20.totalSupply(), supplyBefore);
    }

    function _checkMint(bool recipientNonzero) internal {
        _seedSupply(recipientNonzero);
        uint256 recipientBefore = b20.balanceOf(C.RECIPIENT);
        uint256 supplyBefore = b20.totalSupply();
        assertTrue(b20.hasRole(B20Constants.MINT_ROLE, C.ADMIN_MINTER));

        vm.expectEmit(true, true, false, true, address(b20));
        emit IB20.Transfer(address(0), C.RECIPIENT, C.CALL_AMOUNT);
        vm.prank(C.ADMIN_MINTER);
        b20.mint(C.RECIPIENT, C.CALL_AMOUNT);

        assertEq(b20.balanceOf(C.RECIPIENT), recipientBefore + C.CALL_AMOUNT);
        assertEq(b20.totalSupply(), supplyBefore + C.CALL_AMOUNT);
    }
}
