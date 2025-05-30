// SPDX-Lincense-Identifier: MIT

pragma solidity 0.8.26;


import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";


import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";


import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointsHook is BaseHook, ERC1155 {

    constructor(IPoolManager _manager) BaseHook(_manager) {}

    // set up hook permissions to return true 
    // for the two hook functions we are using

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
        });
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }
 
	// Stub implementation of `afterSwap`
	// function _afterSwap(
    //     address,
    //     PoolKey calldata key,
    //     SwapParams calldata swapParams,
    //     BalanceDelta delta,
    //     bytes calldata hookData
    // ) internal override returns (bytes4, int128) {
	// 	// We'll add more code here shortly
	// 	return (this.afterSwap.selector, 0);
    // }

    function _assignPoints(
        PoolId poolId,
        bytes calldata hookData,
        uint256 points
    ) internal {
        //  if no hookData is passed in, no points will be assigned to anyone
        if(hookData.length == 0) return;

        // Extract user address from the hookData
        address user = abi.decode(hookData, (address));

        // if there is hookData, but in the format we're expecting and user address is zero
        // nobody get any point
        if(user == address(0)) return;

        // mint the points to the user
        uint256 poolIdUnit = uint256(PoolId.unwrap(poolId));
        _mint(user, poolIdUnit, points, "");

    }

    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        // if this is not an ETH-TOKEN pool with this hook attached, ignore
        if(!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);

        // we only mint point if user is buying TOKEN with ETH
        if(!swapParams.zeroForOne) return (this.afterSwap.selector, 0);

        // Min points equal to 20% of the amount of ETH they spent
        // since its a zeroForOne swap;
        // if amountSpecified < 0:
            // this an "exact input for output" swap
            // amount of ETH they spent is equal to |amountSpecified|
        // if amountSpecified > 0;
            // this is an "exact output for input" swap
            // amount of ETH they spent is eqaul to BalanceDelta.amount0()

        // uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
        uint256 ethSpendAmount = swapParams.amountSpecified < 0
        ? uint256(uint256(-swapParams.amountSpecified))
        : uint256(int256(-delta.amount0()));

        uint256 pointsForSwap = ethSpendAmount / 5;

        // mint the point 
        _assignPoints(key.toId(), hookData, pointsForSwap);
        return (this.afterSwap.selector, 0);
    }
}