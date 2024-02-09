// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC20Mintable} from "./ERC20Mintable.sol";
import {UniswapV3Pool} from "../src/UniswapV3Pool.sol";

contract UniswapV3PoolTest is Test {
  ERC20Mintable token0;
  ERC20Mintable token1;
  UniswapV3Pool pool;

  bool transferInMintCallback = true;
  bool transferInSwapCallback = true;

  struct TestCaseParams {
    uint256 wethBalance;
    uint256 usdcBalance;
    int24 currentTick;
    int24 lowerTick;
    int24 upperTick;
    uint128 liquidity;
    uint160 currentSqrtP;
    bool transferInMintCallback;
    bool transferInSwapCallback;
    bool mintLiquidity;
  }

  function setUp() public {
    token0 = new ERC20Mintable("Ether", "ETH", 18);
    token1 = new ERC20Mintable("USDC", "USDC", 18);
  }

  function setupTestCase(TestCaseParams memory params)
    internal
    returns (uint256 poolBalance0, uint256 poolBalance1)
  {
    token0.mint(address(this), params.wethBalance);
    token1.mint(address(this), params.usdcBalance);

    pool = new UniswapV3Pool(
      address(token0),
      address(token1),
      params.currentSqrtP,
      params.currentTick
    );

    // When this flag is set, we mint liquidity in the pool
    if (params.mintLiquidity) {
      token0.approve(address(this), params.wethBalance);
      token1.approve(address(this), params.usdcBalance);

      UniswapV3Pool.CallbackData memory extra = UniswapV3Pool.CallbackData({
        token0: address(token0),
        token1: address(token1),
        payer: address(this)
      });

      (poolBalance0, poolBalance1) = pool.mint(
        address(this),
        params.lowerTick,
        params.upperTick,
        params.liquidity,
        abi.encode(extra)
      );
    }

    transferInMintCallback = params.transferInMintCallback;
    transferInSwapCallback = params.transferInSwapCallback;
  }

  function uniswapV3MintCallback(
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) public {
    if (transferInMintCallback) {
      UniswapV3Pool.CallbackData memory extra = abi.decode(
        data,
        (UniswapV3Pool.CallbackData)
      );
      IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
      IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
    }
  }

  function testMintSuccess() public {
      TestCaseParams memory params = TestCaseParams({
          wethBalance: 1 ether,
          usdcBalance: 5000 ether,
          currentTick: 85176,
          lowerTick: 84222,
          upperTick: 86129,
          liquidity: 1517882343751509868544,
          currentSqrtP: 5602277097478614198912276234240,
          transferInMintCallback: true,
          transferInSwapCallback: true,
          mintLiquidity: true
      });

      // We want to ensure that the pool contract:
      //
      // 1. takes the correct amounts of tokens from us;
      // 2. creates a position with correct key and liquidity;
      // 3. initializes the upper and lower ticks we’ve specified;
      // 4. has correct sqrt(P) and L.

      // mint() function returns the amounts we provided.
      (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

      // Check the deposited amounts.
      uint256 expectedAmount0 = 0.998976618347425280 ether;
      uint256 expectedAmount1 = 5000 ether;
      assertEq(poolBalance0, expectedAmount0, "incorrect token0 deposited amount");
      assertEq(poolBalance1, expectedAmount1, "incorrect token1 deposited amount");

      // Check that these amounts were transferred to the pool.
      assertEq(token0.balanceOf(address(pool)), expectedAmount0);
      assertEq(token1.balanceOf(address(pool)), expectedAmount1);

      // Check the position that pool created for us.
      bytes32 positionKey = keccak256(
        abi.encodePacked(address(this), params.lowerTick, params.upperTick)
      );
      // Position.Info gets destructured when fetched
      uint128 positionLiquidity = pool.positions(positionKey);
      assertEq(positionLiquidity, params.liquidity);

      // Check lower tick
      (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(params.lowerTick);
      assertTrue(tickInitialized);
      assertEq(tickLiquidity, params.liquidity);

      // Check upper tick
      (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
      assertTrue(tickInitialized);
      assertEq(tickLiquidity, params.liquidity);

      (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
      assertEq(
          sqrtPriceX96,
          5602277097478614198912276234240,
          "invalid current sqrtP"
      );
      assertEq(tick, 85176, "invalid current tick");
      assertEq(
          pool.liquidity(),
          1517882343751509868544,
          "invalid current liquidity"
      );
  }

  function testSwapBuyEth() public {

  }
}
