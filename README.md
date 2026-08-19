# mini-amm

An AMM (Automated Market Maker) in ~100 lines of Solidity.
It is the Uniswap engine stripped to the bone: **two pots, one division, one product that never decreases.**

> ⚠️ **Educational code. No fees, no LP shares, no audit. DO NOT USE IN PRODUCTION.**

## What's inside

| File | What it is |
|---|---|
| `src/MiniAMM.sol` | Minimal ERC-20 token + x·y=k AMM: `spotPrice`, `quote`, `addLiquidity`, `swap` with `minOut` protection |
| `test/MiniAMM.t.sol` | 5 tests that prove the behavior (example pool: 10 WETH / 20,000 USDC) |

## 1. Install Foundry

**Mac / Linux:**

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Then close and reopen your terminal (or `source ~/.zshenv` / `~/.bashrc`) and run:

```bash
foundryup
```

**Windows:** use WSL. In PowerShell **as administrator**:

```powershell
wsl --install
```

Reboot, open Ubuntu, and run the two Mac/Linux commands above.

**Verify:**

```bash
forge --version
```

## 2. Clone and run

```bash
git clone --recursive https://github.com/melocalex/mini-amm
cd mini-amm
forge test -vvv
```

(Forgot `--recursive`? Run `git submodule update --init` inside the folder.)

## 3. How to read the output

- `[PASS] test_...` — the test passed; the number in parentheses is the gas used.
- `-vvv` shows the *trace*: every contract call with arguments and return values. This is how you debug Solidity.
- Break something on purpose (change `>=` to `>` in the invariant) and run again to watch a test fail.

## 4. Exercises

1. **0.3% fee** — in `quote`, the input becomes worth `997/1000` of what came in (this is exactly what Uniswap v2 does). Adjust the tests: with a fee, k now **grows** on every swap — that is where LP yield comes from.
2. **Simulate a sandwich attack** — write a test with 3 swaps in sequence: bot buys, victim buys (paying more), bot sells (profit). Print the bot's profit with `console.log`. Then protect the victim with a fair `minOut` and watch the attack revert.
3. **LP shares** — our `addLiquidity` returns nothing (the money is stuck!). Add `totalShares`, `shares[msg.sender]` and `removeLiquidity`. Reference: the `UniswapV2Pair` contract.
4. **(Bonus) Measure slippage** — write a test that swaps 1%, 5%, 10% and 50% of the pool and prints the effective price of each trade. Compare with the rule of thumb: *slippage ≈ the fraction of the pool your trade represents*.

## Final warning

This contract deliberately omits: fees, LP shares, reentrancy protection, fee-on-transfer tokens, TWAP oracles, and a thousand other things that make a real AMM safe. The goal is to fit on one screen and be understood in 20 minutes.
