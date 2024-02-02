
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

library Position {
  struct Info {
    uint128 liquidity;
  }

  function get(
    mapping(bytes32 => Info) storage self,
    address owner,
    int24 lowerTick,
    int24 upperTick
  ) internal view returns (Info storage position) {
    // Each position is uniquely identified by three keys:
    // owner address, lower tick index, upper tick index.

    position = self[keccak256(abi.encodePacked(owner, lowerTick, upperTick))];

    // We hash these keys to make storing data cheaper:
    // when hashed, every key will take 32 bytes, instead of 96 bytes when
    // owner, lowerTick, and upperTick are separate keys.
  }

  // Adds new liquidity to a position.
  function update(Info storage self, uint128 liquidityDelta) internal {
    uint128 liquidityBefore = self.liquidity;
    uint128 liquidityAfter = liquidityBefore + liquidityDelta;

    self.liquidity = liquidityAfter;
  }
}
