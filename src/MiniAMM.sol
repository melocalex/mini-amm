// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

//  =====================================================================
//   EDUCATIONAL CODE — DO NOT USE IN PRODUCTION
//
//   This is the core of an AMM (Uniswap v1/v2 style) in ~100 lines.
//   On purpose, it has: no fees, no LP shares, no audit, no mercy.
//
//   The whole idea fits in one sentence:
//   "Two pots of tokens. The price is the ratio between the pots.
//    Every trade must keep the product of the pots from decreasing."
//  =====================================================================

/// @notice A minimal ERC-20 so the demo has something to trade.
/// @dev Anyone can mint — that is obviously insane outside a classroom.
contract MiniToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    // Who owns how many tokens.
    mapping(address => uint256) public balanceOf;

    // allowance[owner][spender] = how much `spender` may pull from `owner`.
    // This two-step (approve, then transferFrom) is why every DeFi app
    // asks you to "Approve" before it can touch your tokens.
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /// @notice Prints money. Test-only superpower.
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /// @notice Lets `spender` (e.g. the AMM) pull up to `amount` from your balance.
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice How contracts move your tokens: they spend your allowance.
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

/// @notice A constant-product AMM (x * y = k) stripped to the bone.
///
/// There is no order book, no counterparty, no "seller" on the other side.
/// You trade against two pots of tokens sitting in this contract, and a
/// formula decides the price. That's it. That's the trillion-dollar idea.
contract MiniAMM {
    // The two tokens of the pair. `immutable` = set once in the constructor,
    // then baked into the bytecode. A pool can never change its pair.
    MiniToken public immutable tokenA; // e.g. WETH
    MiniToken public immutable tokenB; // e.g. USDC

    // The two pots. We track them in storage instead of reading
    // balanceOf(address(this)) so nobody can skew the price by
    // donating tokens directly to the contract.
    uint256 public reserveA; // pot A
    uint256 public reserveB; // pot B

    constructor(address _tokenA, address _tokenB) {
        tokenA = MiniToken(_tokenA);
        tokenB = MiniToken(_tokenB);
    }

    /// @notice Spot price: how much B is 1 A worth right now?
    ///
    /// Example: 10 WETH and 20,000 USDC in the pots
    ///          => 1 WETH = 20,000 / 10 = 2,000 USDC.
    ///
    /// No oracle, no admin, no magic: the price IS the ratio of the pots.
    /// @dev Scaled by 1e18 because Solidity has no decimals.
    ///      (This spot price is only valid for an infinitesimal trade —
    ///       any real trade gets a worse price. See `quote`.)
    function spotPrice() public view returns (uint256) {
        require(reserveA > 0, "empty pool");
        return (reserveB * 1e18) / reserveA;
    }

    /// @notice How much comes out of one pot if you put `amountIn` into the other?
    ///
    /// The ONLY formula of this lecture:
    ///
    ///     out = in * rOut / (rIn + in)
    ///
    /// Where does it come from? The rule "the product never changes":
    ///     (rIn + in) * (rOut - out) = rIn * rOut        // k stays the same
    /// Solve for `out` and you get the line of code below. Done.
    ///
    /// Sanity checks you can do in your head:
    ///  - tiny `in`  => out ≈ in * (rOut / rIn)  = spot price. Fair.
    ///  - huge `in`  => out approaches rOut but NEVER reaches it.
    ///    You cannot drain the pot, you just get worse and worse prices.
    ///    That "worse and worse" is slippage — it lives in the formula itself.
    ///
    /// @param aForB true  = you give A, you get B
    ///              false = you give B, you get A
    /// @dev No fee here (educational). Uniswap v2 multiplies `in` by 997/1000
    ///      first — that 0.3% haircut is exactly what pays the LPs.
    function quote(uint256 amountIn, bool aForB) public view returns (uint256) {
        (uint256 rIn, uint256 rOut) = aForB ? (reserveA, reserveB) : (reserveB, reserveA);
        require(rIn > 0 && rOut > 0, "empty pool");
        return (amountIn * rOut) / (rIn + amountIn);
    }

    /// @notice Deposits liquidity into both pots.
    ///
    /// The FIRST deposit sets the initial price: seed 10 WETH + 20,000 USDC
    /// and you just declared "1 WETH = 2,000 USDC". If that's off from the
    /// rest of the world, arbitrage bots will happily correct you (for a profit).
    ///
    /// @dev Educational shortcut: no LP shares are minted, so whoever deposits
    ///      cannot withdraw — the money is stuck in the pool forever.
    ///      Real AMMs mint LP tokens as a receipt for your % of the pool
    ///      (that receipt is what earns fees). Exercise 3 in the README.
    function addLiquidity(uint256 amountA, uint256 amountB) external {
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);
        reserveA += amountA;
        reserveB += amountB;
    }

    /// @notice Swaps `amountIn` of one token for the other.
    ///
    /// Flow: quote the output, check the user's minimum, pull the input,
    /// pay the output, update the pots, verify the invariant. Six steps.
    ///
    /// @param minOut The anti-sandwich defense. A bot can front-run you and
    ///        move the price before your transaction lands — but it cannot
    ///        force you to accept the worse price. If the output drops below
    ///        `minOut`, the whole swap reverts and you keep your tokens.
    ///        (minOut = 0 means "I accept literally any price". The mempool
    ///        eats people who do that for breakfast.)
    function swap(uint256 amountIn, bool aForB, uint256 minOut) external returns (uint256 amountOut) {
        require(amountIn > 0, "zero input");

        // 1. Price the trade with the formula above.
        amountOut = quote(amountIn, aForB);

        // 2. Slippage check — the user's only shield in a public mempool.
        require(amountOut >= minOut, "slippage");

        // 3. Remember k before touching anything.
        uint256 kBefore = reserveA * reserveB;

        // 4. Pull the input token in, pay the output token out.
        (MiniToken tIn, MiniToken tOut) = aForB ? (tokenA, tokenB) : (tokenB, tokenA);
        tIn.transferFrom(msg.sender, address(this), amountIn);
        tOut.transfer(msg.sender, amountOut);

        // 5. Update the pots.
        if (aForB) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // 6. The heart of the AMM: the product of the pots NEVER decreases.
        //    Whatever rounding dust exists must land in the pool's favor.
        //    If any bug in the math above tries to give too much out,
        //    this single line kills the trade.
        require(reserveA * reserveB >= kBefore, "k invariant violated");
    }
}
