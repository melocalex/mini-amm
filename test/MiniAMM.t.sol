// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MiniAMM, MiniToken} from "../src/MiniAMM.sol";

/// Testes que provam, um por um, os fatos ditos nos slides.
/// Pool de exemplo (igual aos slides): 10 WETH / 20.000 USDC.
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

        // LP semeia o pool com o exemplo dos slides: 10 WETH / 20.000 USDC
        weth.mint(lp, 10e18);
        usdc.mint(lp, 20_000e18);
        vm.startPrank(lp);
        weth.approve(address(amm), type(uint256).max);
        usdc.approve(address(amm), type(uint256).max);
        amm.addLiquidity(10e18, 20_000e18);
        vm.stopPrank();

        // Trader tem USDC para comprar WETH
        usdc.mint(trader, 10_000e18);
        vm.prank(trader);
        usdc.approve(address(amm), type(uint256).max);
    }

    /// (1) O primeiro depósito DEFINE o preço: 20.000 / 10 = 2.000 USDC por WETH.
    function test_PrecoInicialEhRazaoDosPotes() public view {
        assertEq(amm.spotPrice(), 2_000e18);
    }

    /// (2) O exemplo dos slides: ~1 WETH custa ~2.222 USDC (e não 2.000!).
    /// Slippage nasce da própria fórmula — ninguém precisou "manipular" nada.
    function test_ComprarUmEthCustaMaisQueDoisMil() public view {
        // out = 2.222 * 10 / (20.000 + 2.222) ≈ 0,9999 WETH
        uint256 out = amm.quote(2_222e18, false);
        assertApproxEqRel(out, 1e18, 0.001e18); // ~1 WETH (tolerância 0,1%)
    }

    /// (3) Swap move o preço na direção certa: comprar WETH deixa WETH mais caro.
    function test_SwapMovePrecoNaDirecaoCerta() public {
        uint256 precoAntes = amm.spotPrice();
        vm.prank(trader);
        amm.swap(2_222e18, false, 0); // USDC -> WETH
        assertGt(amm.spotPrice(), precoAntes);
    }

    /// (4) O invariante: k = reserveA * reserveB nunca diminui num swap.
    /// (Sem fee fica igual, salvo poeira de arredondamento a favor do pool.)
    function test_KNuncaDiminui() public {
        uint256 kAntes = amm.reserveA() * amm.reserveB();
        vm.prank(trader);
        amm.swap(1_000e18, false, 0);
        assertGe(amm.reserveA() * amm.reserveB(), kAntes);
    }

    /// (5) minOut alto demais REVERTE — a defesa anti-sandwich.
    /// O bot pode mexer o preço antes de você, mas não pode te forçar a aceitar.
    function test_MinOutProtegeContraSandwich() public {
        // quote diz ~0,9999 WETH; trader exige 1,1 WETH => reverte
        vm.prank(trader);
        vm.expectRevert(bytes("slippage"));
        amm.swap(2_222e18, false, 1.1e18);
    }
}
