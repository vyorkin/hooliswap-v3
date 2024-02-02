
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

library Tick {
  struct Info {
    bool initialized;
    uint128 liquidity;
  }

  // Initializes a tick if it has 0 liquidity and adds new liquidity to it.
  function update(
    mapping(int24 => Info) storage self,
    int24 tick,
    uint128 liquidityDelta
  ) internal {
    Tick.Info storage tickInfo = self[tick];
    uint128 liquidityBefore = tickInfo.liquidity;
    uint128 liquidityAfter = liquidityBefore + liquidityDelta;

    if (liquidityBefore == 0) {
      tickInfo.initialized = true;
    }

    tickInfo.liquidity = liquidityAfter;
  }
}

