// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

//  =====================================================================
//   CÓDIGO DIDÁTICO — NÃO USE EM PRODUÇÃO
//   Sem fee, sem shares de LP, sem auditoria.
//   Objetivo: o núcleo de um AMM (Uniswap v1/v2) no mínimo de linhas.
//  =====================================================================

/// @notice ERC-20 mínimo para a demo (qualquer um pode mintar — só teste!)
contract MiniToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "allowance");
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "saldo");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

/// @notice AMM de produto constante (x*y = k) reduzido ao osso.
/// Dois potes. Preço = razão entre os potes. O produto nunca diminui.
contract MiniAMM {
    MiniToken public immutable tokenA; // ex.: WETH
    MiniToken public immutable tokenB; // ex.: USDC

    uint256 public reserveA; // pote A
    uint256 public reserveB; // pote B

    constructor(address _tokenA, address _tokenB) {
        tokenA = MiniToken(_tokenA);
        tokenB = MiniToken(_tokenB);
    }

    /// @notice Preço à vista: quantos B vale 1 A (escalado por 1e18).
    /// Não tem oráculo, não tem mágica: preço é a razão entre os potes.
    function spotPrice() public view returns (uint256) {
        require(reserveA > 0, "pool vazio");
        return (reserveB * 1e18) / reserveA;
    }

    /// @notice Quanto sai do pote se você colocar `amountIn`?
    /// A ÚNICA conta da aula:  out = in * rOut / (rIn + in)
    /// (vem direto de x*y = k; sem fee — versão didática)
    function quote(uint256 amountIn, bool aForB) public view returns (uint256) {
        (uint256 rIn, uint256 rOut) = aForB ? (reserveA, reserveB) : (reserveB, reserveA);
        require(rIn > 0 && rOut > 0, "pool vazio");
        return (amountIn * rOut) / (rIn + amountIn);
    }

    /// @notice Deposita liquidez nos dois potes.
    /// Didático: sem shares de LP — quem deposita não saca de volta.
    /// (A Uniswap resolve isso com tokens de LP — exercício 3 do README.)
    function addLiquidity(uint256 amountA, uint256 amountB) external {
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);
        reserveA += amountA;
        reserveB += amountB;
    }

    /// @notice Troca `amountIn` de um token pelo outro.
    /// `minOut` é a defesa anti-sandwich: preço mexeu contra você? Reverte.
    function swap(uint256 amountIn, bool aForB, uint256 minOut) external returns (uint256 amountOut) {
        require(amountIn > 0, "input zero");
        amountOut = quote(amountIn, aForB);
        require(amountOut >= minOut, "slippage");

        uint256 kAntes = reserveA * reserveB;

        (MiniToken tIn, MiniToken tOut) = aForB ? (tokenA, tokenB) : (tokenB, tokenA);
        tIn.transferFrom(msg.sender, address(this), amountIn);
        tOut.transfer(msg.sender, amountOut);

        if (aForB) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // O coração do AMM: o produto dos potes NUNCA diminui.
        require(reserveA * reserveB >= kAntes, "invariante k violado");
    }
}
