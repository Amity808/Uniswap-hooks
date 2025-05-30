// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";

import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAMounts.sol";

import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";
import "forge-std/console.sol";

import {PointsHook} from "../src/PointsHook.sol";


contract TestPointsHook is Test, Deployers, ERC1155TokenReceiver {

    MockERC20 token; // our token to use in the ETH-Token pool

    // Native tokens are represented by address(0)
    Currency ethCurrency = Currency.wrap(address(0));
    Currency tokenCurrency;

    PointsHook hook;

    function setUp() public {
        // TODO
        // deploy a poolmanager and router contracts 
        deployFreshManagerAndRouters();

        // deploy out Token contract
        token = new MockERC20("Test Token", "TT", 18);
        tokenCurrency = Currency.wrap(address(token));

        // mint a bunch of token to overselves and to address(1)
        token.mint(address(this), 1000 ether);
        token.mint(address(1), 1000 ether);

        // Deploy hook to an address that has the proper flags set 
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo("PointsHook.sol", abi.encode(manager), address(flags));
        
        // Initialize the hook 
        hook = PointsHook(address(flags));

        // approve our token for spending on the swap router and modify liquidity router
        // these variable are coming from the `Deployers` contract
        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);

        // intialize a pool
        (key, ) = initPool(
            ethCurrency, // currency 0 = ETH 
        tokenCurrency, // Currency 1 = TOKEN
        hook, // Hook Contract
        3000, // SWAP Fees
        SQRT_PRICE_1_1 // the initail SQRT(P) value = 1
        );

        uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
        uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

        uint256 ethToAdd = 0.003 ether;
        uint128 liquidityDelta = uint128( LiquidityAmounts.getAmount0ForLiquidity(
            SQRT_PRICE_1_1,
            sqrtPriceAtTickUpper, 
            uint128(ethToAdd)
            ));

        uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
            sqrtPriceAtTickLower,
            SQRT_PRICE_1_1, 
            liquidityDelta); 

            modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(uint256(liquidityDelta)),
                salt: bytes32(0)
            }), ZERO_BYTES);
    }

    function test_swap() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointBalanceoriginal = hook.balanceOf(address(this), poolIdUint);

        // set the user address in hook data 
        bytes memory hookData = abi.encode(address(this));

        // now we swap
        // we will swap 0.001 ether for tokens 
        // we should get 20% of 0.001 * 10**18
        // = 2 * 10**14
        swapRouter.swap{value: 0.001 ether}(
            key, 
            SwapParams({
                zeroForOne: true, // ETH -> TOKEN
                amountSpecified: -0.001 ether, // negative means exact input
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
        uint256 pointsBalanceAfterSwap = hook.balanceOf(
        address(this), poolIdUint);
        // we should have 2 * 10**14 points
        assertEq(pointsBalanceAfterSwap - pointBalanceoriginal, 2 * 10**14, "Points balance after swap should be 2 * 10**14");
    }
}