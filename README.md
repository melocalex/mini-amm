# mini-amm

Um AMM (Automated Market Maker) em ~100 linhas de Solidity.
É o motor da Uniswap reduzido ao osso: **dois potes, uma divisão, um produto que não diminui.**

> ⚠️ **Código didático. Sem fee, sem shares de LP, sem auditoria. NÃO USE EM PRODUÇÃO.**

## O que tem aqui

| Arquivo | O que é |
|---|---|
| `src/MiniAMM.sol` | Token ERC-20 mínimo + AMM x·y=k: `spotPrice`, `quote`, `addLiquidity`, `swap` com proteção `minOut` |
| `test/MiniAMM.t.sol` | 5 testes que provam o comportamento (pool de exemplo: 10 WETH / 20.000 USDC) |

## 1. Instalar o Foundry

**Mac / Linux:**

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Depois feche e abra o terminal (ou `source ~/.zshenv` / `~/.bashrc`) e rode:

```bash
foundryup
```

**Windows:** use o WSL. No PowerShell **como administrador**:

```powershell
wsl --install
```

Reinicie, abra o Ubuntu e rode os dois comandos de Mac/Linux acima.

**Verificar:**

```bash
forge --version
```

## 2. Clonar e rodar

```bash
git clone --recursive https://github.com/Mis4nthr0pic/mini-amm
cd mini-amm
forge test -vvv
```

(Esqueceu o `--recursive`? Rode `git submodule update --init` dentro da pasta.)

## 3. Como ler a saída

- `[PASS] test_...` — o teste passou; o número entre parênteses é o gás consumido.
- `-vvv` mostra o *trace*: cada chamada de contrato, com argumentos e retornos. É assim que se debuga Solidity.
- Quebre algo de propósito (mude `>=` para `>` no invariante) e rode de novo para ver um teste falhar.

## 4. Exercícios

1. **Fee de 0,3%** — no `quote`, o input passa a valer `997/1000` do que entrou (é exatamente o que a Uniswap v2 faz). Ajuste os testes: com fee, o k passa a **crescer** a cada swap — é daí que vem o rendimento dos LPs.
2. **Simule um sandwich attack** — escreva um teste com 3 swaps em sequência: bot compra, vítima compra (mais caro), bot vende (lucro). Imprima o lucro do bot com `console.log`. Depois proteja a vítima com um `minOut` justo e veja o ataque reverter.
3. **Shares de LP** — nosso `addLiquidity` não devolve nada (o dinheiro fica preso!). Adicione `totalShares`, `shares[msg.sender]` e `removeLiquidity`. Referência: contrato `UniswapV2Pair`.
4. **(Bônus) Meça o slippage** — faça um teste que troca 1%, 5%, 10% e 50% do pool e imprima o preço efetivo de cada trade. Compare com a regra de bolso: *slippage ≈ fração do pool que o trade representa*.

## Aviso final

Este contrato omite de propósito: fees, shares de LP, proteção de reentrância, tokens com fee-on-transfer, oráculos TWAP e mil outras coisas que fazem um AMM real ser seguro. O objetivo é caber numa tela e ser entendido em 20 minutos.
