// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {MooVeloLpZapper} from "../src/MooVeloLpZapper.sol";
import "lib/openzeppelin-contracts-4.7.1/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts-4.7.1/contracts/token/ERC20/utils/SafeERC20.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";


interface IBeefyVault {
    function want() external view returns (address);
    function getPricePerFullShare() external view returns (uint256);
}

interface IYearnVault {
    function withdraw() external;
}

interface IStakingRewards {
    function exit() external;
}

contract StrategyOperationsTest is StrategyFixture {
    using SafeERC20 for IERC20;
    function setUp() public override {
        super.setUp();
    }
    
    function test_zap_setup() public view {
        for (uint8 i = 0; i < assetFixtures.length; ++i) {
            AssetFixture memory _assetFixture = assetFixtures[i];
            address lpToken = _assetFixture._lpTokenAddress;
            console2.log("Testing for:", lpToken);
        }
    }

    function test_zap_lossless() public {
        for (uint8 i = 0; i < assetFixtures.length; ++i) {
            AssetFixture memory _assetFixture = assetFixtures[i];
            address _lpToken = _assetFixture._lpTokenAddress;
            address _beefyVault = _assetFixture._beefyVaultAddress;
            address _yearnVault = _assetFixture._yearnVaultAddress;
            address _mooWhale = _assetFixture._mooWhaleAddress;
            bool _isBoosted = _assetFixture._isBoostedBool;

            uint256 _valueBefore = IERC20(_beefyVault).balanceOf(_mooWhale) * IBeefyVault(_beefyVault).getPricePerFullShare() / 1e18;
            vm.startPrank(_mooWhale);
            IERC20(_beefyVault).safeApprove(address(zapper), type(uint256).max);
            zapper.zap(_lpToken);

            if (_isBoosted) {
                IStakingRewards(staking_rewards_contract).exit();
            }

            IYearnVault(_yearnVault).withdraw();
            // uint256 _valueAfter = IERC20(aleth_weth_lp).balanceOf(aleth_weth_moo_whale);
            // console2.log("_valueBefore", _valueBefore);
            // console2.log("_valueAfter", _valueAfter);
            // assertApproxEqAbs(_valueBefore, _valueAfter, 10);
        }
    }
}
