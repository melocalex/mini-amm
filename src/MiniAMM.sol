// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

//  =====================================================================
//   EDUCATIONAL CODE — DO NOT USE IN PRODUCTION
//   No fees, no LP shares, no audit.
//   Goal: the core of an AMM (Uniswap v1/v2) in as few lines as possible.
//  =====================================================================

/// @notice Minimal ERC-20 for the demo (anyone can mint — test only!)
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
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

/// @notice A constant-product AMM (x*y = k) stripped to the bone.
/// Two pots. Price = the ratio between the pots. The product never decreases.
contract MiniAMM {
    MiniToken public immutable tokenA; // e.g. WETH
    MiniToken public immutable tokenB; // e.g. USDC

    uint256 public reserveA; // pot A
    uint256 public reserveB; // pot B

    constructor(address _tokenA, address _tokenB) {
        tokenA = MiniToken(_tokenA);
        tokenB = MiniToken(_tokenB);
    }

    /// @notice Spot price: how much B is 1 A worth (scaled by 1e18).
    /// No oracle, no magic: price is just the ratio between the pots.
    function spotPrice() public view returns (uint256) {
        require(reserveA > 0, "empty pool");
        return (reserveB * 1e18) / reserveA;
    }

    /// @notice How much comes out of the pot if you put `amountIn` in?
    /// The ONLY formula of this lecture:  out = in * rOut / (rIn + in)
    /// (falls straight out of x*y = k; no fee — educational version)
    function quote(uint256 amountIn, bool aForB) public view returns (uint256) {
        (uint256 rIn, uint256 rOut) = aForB ? (reserveA, reserveB) : (reserveB, reserveA);
        require(rIn > 0 && rOut > 0, "empty pool");
        return (amountIn * rOut) / (rIn + amountIn);
    }

    /// @notice Deposits liquidity into both pots.
    /// Educational: no LP shares — whoever deposits cannot withdraw.
    /// (Uniswap solves this with LP tokens — exercise 3 in the README.)
    function addLiquidity(uint256 amountA, uint256 amountB) external {
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);
        reserveA += amountA;
        reserveB += amountB;
    }

    /// @notice Swaps `amountIn` of one token for the other.
    /// `minOut` is the anti-sandwich defense: price moved against you? Revert.
    function swap(uint256 amountIn, bool aForB, uint256 minOut) external returns (uint256 amountOut) {
        require(amountIn > 0, "zero input");
        amountOut = quote(amountIn, aForB);
        require(amountOut >= minOut, "slippage");

        uint256 kBefore = reserveA * reserveB;

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

        // The heart of the AMM: the product of the pots NEVER decreases.
        require(reserveA * reserveB >= kBefore, "k invariant violated");
    }
}
