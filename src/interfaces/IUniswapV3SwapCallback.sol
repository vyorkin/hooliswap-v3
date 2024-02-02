// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

interface IUniswapV3SwapCallback {
  function uniswapV3SwapCallback(
    int256 amount0,
    int256 amount1,
    bytes calldata data
  ) external;
}
