// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IUniswapV3SwapCallback} from "./interfaces/IUniswapV3SwapCallback.sol";
import {IUniswapV3MintCallback} from "./interfaces/IUniswapV3MintCallback.sol";
import {Tick} from "./lib/Tick.sol";
import {Position} from "./lib/Position.sol";

contract UniswapV3Pool {
  using Tick for mapping(int24 => Tick.Info);
  using Position for mapping(bytes32 => Position.Info);
  using Position for Position.Info;

  error InsufficientInputAmount();
  error InvalidTickRange();
  error ZeroLiquidity();

  event Mint(
    address sender,
    address indexed owner,
    int24 indexed tickLower,
    int24 indexed tickUpper,
    uint128 amount,
    uint256 amount0,
    uint256 amount1
  );

  event Swap(
    address indexed sender,
    address indexed recipient,
    int256 amount0,
    int256 amount1,
    uint160 sqrtPriceX96,
    uint128 liquidity,
    int24 tick
  );

  int24 internal constant MIN_TICK = -887272;
  int24 internal constant MAX_TICK = -MIN_TICK;

  address public immutable token0;
  address public immutable token1;

  // Packing variables that are used together.
  struct Slot0 {
    // Current sqrt(P).
    uint160 sqrtPriceX96; // sqrt(P) = sqrt(x / y)
    // Current tick.
    int24 tick;
  }

  struct CallbackData {
    address token0;
    address token1;
    address payer;
  }

  Slot0 public slot0;

  // L - amount of liquidity currently available.
  //
  // Sum of liquidity of all the price ranges that include the current price.
  // It gets updated when the price is leaving and
  // entering price ranges (crossing a tick) during swapping (swapping changes price).
  uint128 public liquidity;

  mapping(int24 => Tick.Info) public ticks;
  mapping(bytes32 => Position.Info) public positions;

  constructor(
    address token0_,
    address token1_,
    uint160 sqrtPriceX96,
    int24 tick
  ) {
    token0 = token0_;
    token1 = token1_;
    slot0 = Slot0({ sqrtPriceX96: sqrtPriceX96, tick: tick });
  }

  // The process of providing liquidity in UniswapV2 is called minting.
  // UniswapV3 just uses the same name.
  function mint(
    address owner,
    int24 lowerTick,
    int24 upperTick,
    uint128 amount, // L = sqrt(x * y)
    bytes calldata data
  ) external returns (uint256 amount0, uint256 amount1) {
    if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK)  revert InvalidTickRange();
    if (amount == 0) revert ZeroLiquidity();

    // Add liquidity to upper & lower ticks and initializes them if needed.
    ticks.update(lowerTick, amount);
    ticks.update(upperTick, amount);

    Position.Info storage position = positions.get(owner, lowerTick, upperTick);
    position.update(amount);

    // TODO: Calculate the amounts that user must deposit.
    amount0 = 0.998976618347425280 ether;
    amount1 = 5000 ether;

    // Update the total liquidity amount.
    liquidity += uint128(amount);

    // Record current token balances.
    uint256 balance0Before;
    uint256 balance1Before;

    if (amount0 > 0) balance0Before = balance0();
    if (amount1 > 0) balance1Before = balance1();

    // The caller is expected to:
    // - be a contract
    // - transfer tokens to the UniswapV3Pool contract
    IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);

    // Balances in our UniswapV3Pool contract should be increased by
    // at least amount0 and amount1, which means that the caller has transferred tokens to the pool.
    if (amount0 > 0 && balance0Before + amount0 > balance0()) revert InsufficientInputAmount();
    if (amount1 > 0 && balance1Before + amount1 > balance1()) revert InsufficientInputAmount();

    emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
  }

  function swap(address recipient, bytes calldata data)
    public
    returns (int256 amount0, int256 amount1)
  {
    // TODO: Calculate the next tick & price.
    int24 nextTick = 85184;
    uint160 nextPrice = 5604469350942327889444743441197;

    // TODO: Use input amount parameter.
    // TODO: Calculate how many tokens we'll get int exchange.
    amount0 = -0.008396714242162444 ether;
    amount1 = 42 ether;

    // Update the current tick and sqrtP since trading affects the current price.
    (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

    // Send tokens to the recipient and let the caller transfer input amount into the contract.
    IERC20(token0).transfer(recipient, uint256(-amount0));

    uint256 balance1Before = balance1();
    // We're using a callback to pass the control to the caller and let it transfer the tokens.
    IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
    // After that, we check that the pool's balance is correct and includes the input amount.
    if (balance1Before + uint256(amount1) > balance1()) revert InsufficientInputAmount();

    emit Swap(
      msg.sender,
      recipient,
      amount0,
      amount1,
      slot0.sqrtPriceX96,
      liquidity,
      slot0.tick
    );
  }

  function balance0() internal view returns (uint256 balance) {
    balance = IERC20(token0).balanceOf(address(this));
  }

  function balance1() internal view returns (uint256 balance) {
    balance = IERC20(token1).balanceOf(address(this));
  }
}
