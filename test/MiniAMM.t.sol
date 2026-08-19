// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MiniAMM, MiniToken} from "../src/MiniAMM.sol";

/// Tests that prove, one by one, the claims made in the slides.
/// Example pool (same as the slides): 10 WETH / 20,000 USDC.
contract MiniAMMTest is Test {
    MiniToken weth;
    MiniToken usdc;
    MiniAMM amm;

    address lp = makeAddr("lp");
    address trader = makeAddr("trader");

    function setUp() public {
        weth = new MiniToken("Wrapped Ether", "WETH");
        usdc = new MiniToken("USD Coin", "USDC");
        amm = new MiniAMM(address(weth), address(usdc));

        // The LP seeds the pool with the slide example: 10 WETH / 20,000 USDC
        weth.mint(lp, 10e18);
        usdc.mint(lp, 20_000e18);
        vm.startPrank(lp);
        weth.approve(address(amm), type(uint256).max);
        usdc.approve(address(amm), type(uint256).max);
        amm.addLiquidity(10e18, 20_000e18);
        vm.stopPrank();

        // The trader has USDC to buy WETH with
        usdc.mint(trader, 10_000e18);
        vm.prank(trader);
        usdc.approve(address(amm), type(uint256).max);
    }

    /// (1) The first deposit SETS the price: 20,000 / 10 = 2,000 USDC per WETH.
    function test_InitialPriceIsRatioOfPots() public view {
        assertEq(amm.spotPrice(), 2_000e18);
    }

    /// (2) The slide example: ~1 WETH costs ~2,222 USDC (not 2,000!).
    /// Slippage falls out of the formula itself — nobody had to "manipulate" anything.
    function test_BuyingOneEthCostsMoreThanTwoThousand() public view {
        // out = 2,222 * 10 / (20,000 + 2,222) ≈ 0.9999 WETH
        uint256 out = amm.quote(2_222e18, false);
        assertApproxEqRel(out, 1e18, 0.001e18); // ~1 WETH (0.1% tolerance)
    }

    /// (3) A swap moves the price in the right direction: buying WETH makes WETH more expensive.
    function test_SwapMovesPriceInRightDirection() public {
        uint256 priceBefore = amm.spotPrice();
        vm.prank(trader);
        amm.swap(2_222e18, false, 0); // USDC -> WETH
        assertGt(amm.spotPrice(), priceBefore);
    }

    /// (4) The invariant: k = reserveA * reserveB never decreases on a swap.
    /// (Without a fee it stays equal, save for rounding dust in the pool's favor.)
    function test_KNeverDecreases() public {
        uint256 kBefore = amm.reserveA() * amm.reserveB();
        vm.prank(trader);
        amm.swap(1_000e18, false, 0);
        assertGe(amm.reserveA() * amm.reserveB(), kBefore);
    }

    /// (5) A minOut that is too high REVERTS — the anti-sandwich defense.
    /// The bot can move the price before you, but it cannot force you to accept it.
    function test_MinOutProtectsAgainstSandwich() public {
        // quote says ~0.9999 WETH; the trader demands 1.1 WETH => revert
        vm.prank(trader);
        vm.expectRevert(bytes("slippage"));
        amm.swap(2_222e18, false, 1.1e18);
    }
}
