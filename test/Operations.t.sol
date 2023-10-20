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

    // stg_usdc lp, not boosted
    address public stg_usdc_lp = 0x56770b94279539416855fe29Ef14b26438B5e421;
    address public stg_usdc_beefy = 0xD09B5a0650d68Aae6B1666eE5E770a383d29A97C;
    address public stg_usdc_yearn = 0xf6B272134A193Df5b04332e73184E5b40b8EB810;
    address public stg_usdc_moo_whale = 0xED8886F9B87F06bF7AB1a4897881bd83eCF1f52E;

    // aleth_weth lp, boosted
    address public aleth_weth_lp = 0xa1055762336F92b4B8d2eDC032A0Ce45ead6280a;
    address public aleth_weth_beefy = 0x1A1F0Db1050D1cAD52eEB72371EbFD7716b53a2f;
    address public aleth_weth_yearn = 0xf7D66b41Cd4241eae450fd9D2d6995754634D9f3;
    address public aleth_weth_moo_whale = 0xc47faE56f3702737B69ed615950c01217ec5C7C8;

    address public pool_registry = 0x8ED9F6343f057870F1DeF47AaE7CD88dfAA049A8;

    address public user = address(10);
    address public management = address(0);
    
    function setUp() public {
        zapper = new VeloLpZapper(pool_registry);
        zapper.setPairEndorser(address(this), true);

        zapper.addPair(
            stg_usdc_lp,
            stg_usdc_beefy,
            stg_usdc_yearn
        );

        zapper.addPair(
            aleth_weth_lp,
            aleth_weth_beefy,
            aleth_weth_yearn
        ); 
    }

    function test_zap_lossless_no_stake() public {
        uint256 _valueBefore = IERC20(stg_usdc_beefy).balanceOf(stg_usdc_moo_whale) * IBeefyVault(stg_usdc_beefy).getPricePerFullShare() / 1e18;
        vm.startPrank(stg_usdc_moo_whale);
        IERC20(stg_usdc_beefy).safeApprove(address(zapper), type(uint256).max);
        zapper.zap(stg_usdc_lp);
        IYearnVault(stg_usdc_yearn).withdraw();
        uint256 _valueAfter = IERC20(stg_usdc_lp).balanceOf(stg_usdc_moo_whale);
        console2.log("_valueBefore", _valueBefore);
        console2.log("_valueAfter", _valueAfter);
        assertApproxEqAbs(_valueBefore, _valueAfter, 10);
    }

    function test_zap_lossless_stake() public {
        // uint256 _valueBefore = IERC20(aleth_weth_beefy).balanceOf(aleth_weth_moo_whale) * IBeefyVault(aleth_weth_beefy).getPricePerFullShare() / 1e18;
        vm.startPrank(aleth_weth_moo_whale);
        IERC20(aleth_weth_beefy).safeApprove(address(zapper), type(uint256).max);
        zapper.zap(aleth_weth_lp);
        IYearnVault(aleth_weth_yearn).withdraw();
        // uint256 _valueAfter = IERC20(aleth_weth_lp).balanceOf(aleth_weth_moo_whale);
        // console2.log("_valueBefore", _valueBefore);
        // console2.log("_valueAfter", _valueAfter);
        // assertApproxEqAbs(_valueBefore, _valueAfter, 10);
    }

}
