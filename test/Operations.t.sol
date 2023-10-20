// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VeloLpZapper} from "../src/VeloLpZapper.sol";
import "lib/openzeppelin-contracts-4.7.1/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts-4.7.1/contracts/token/ERC20/utils/SafeERC20.sol";

interface IBeefyVault {
    function want() external view returns (address);
    function getPricePerFullShare() external view returns (uint256);
}

interface IYearnVault {
    function withdraw() external;
}

contract CounterTest is Test {
    using SafeERC20 for IERC20;
    VeloLpZapper public zapper;

    address public stg_usdc_lp = 0x56770b94279539416855fe29Ef14b26438B5e421;
    address public stg_usdc_beefy = 0xD09B5a0650d68Aae6B1666eE5E770a383d29A97C;
    address public stg_usdc_yearn = 0xf6B272134A193Df5b04332e73184E5b40b8EB810;
    address public moo_whale = 0xED8886F9B87F06bF7AB1a4897881bd83eCF1f52E;

    address public user = address(10);
    address public management = address(0);
    
    function setUp() public {
        zapper = new VeloLpZapper();
        zapper.setPairEndorser(address(this), true);

        zapper.addPair(
            stg_usdc_lp,
            stg_usdc_beefy,
            stg_usdc_yearn
        );
    }

    function test_zap_lossless() public {
        uint256 _valueBefore = IERC20(stg_usdc_beefy).balanceOf(moo_whale) * IBeefyVault(stg_usdc_beefy).getPricePerFullShare() / 1e18;
        vm.startPrank(moo_whale);
        IERC20(stg_usdc_beefy).safeApprove(address(zapper), type(uint256).max);
        zapper.zap(stg_usdc_lp);
        IYearnVault(stg_usdc_yearn).withdraw();
        uint256 _valueAfter = IERC20(stg_usdc_lp).balanceOf(moo_whale);
        console2.log("_valueBefore", _valueBefore);
        console2.log("_valueAfter", _valueAfter);
        assertApproxEqAbs(_valueBefore, _valueAfter, 10);
    }
}
