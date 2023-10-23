// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {MooVeloLpZapper} from "src/MooVeloLpZapper.sol";
import {Test, console2} from "forge-std/Test.sol";
import "lib/openzeppelin-contracts-4.7.1/contracts/token/ERC20/IERC20.sol";

contract StrategyFixture is Test {

    struct AssetFixture {
        address _lpTokenAddress;
        address _beefyVaultAddress;
        address _yearnVaultAddress;
        address _mooWhaleAddress;
        bool _isBoostedBool;
    }

    AssetFixture[] public assetFixtures;

    mapping(string => address) public lpToken;
    mapping(string => address) public beefyVault;
    mapping(string => address) public yearnVault;
    mapping(string => address) public mooWhale;
    mapping(string => bool) public isBoosted;

    address public gov = address(0);
    address public user = address(1);
    address public whale;

    address public boost_zap_contract = 0x498d9dCBB1708e135bdc76Ef007f08CBa4477BE2;
    address public staking_rewards_contract = 0xf8126EF025651E1B313a6893Fcf4034F4F4bD2aA;

    MooVeloLpZapper public zapper;

    function setUp() public virtual {
        _setLpToken();
        _setBeefyVault();
        _setYearnVault();
        _setMooWhale();
        _setIsBoosted();
        
        string[3] memory _pairsToTest = ["aleth_weth", "stg_usdc", "susd-usdc"];

        zapper = new MooVeloLpZapper(boost_zap_contract);
        zapper.setPairEndorser(gov, true);

        for (uint8 i = 0; i < _pairsToTest.length; ++i) {
            string memory _pairToTest = _pairsToTest[i];
            assetFixtures.push(AssetFixture(lpToken[_pairToTest], beefyVault[_pairToTest], yearnVault[_pairToTest], mooWhale[_pairToTest], isBoosted[_pairToTest]));
            vm.startPrank(gov);
            zapper.addPair(lpToken[_pairToTest], beefyVault[_pairToTest], yearnVault[_pairToTest]);
        }

        vm.label(gov, "Gov");
        vm.label(user, "User");
        vm.label(whale, "Whale");
    }

    function _setLpToken() internal {
        lpToken["aleth_weth"] = 0xa1055762336F92b4B8d2eDC032A0Ce45ead6280a;
        lpToken["stg_usdc"] = 0x56770b94279539416855fe29Ef14b26438B5e421;
        lpToken["susd-usdc"] = 0x6d5BA400640226e24b50214d2bBb3D4Db8e6e15a;
        // lpToken[""] = ;
        // lpToken[""] = ;
    }

    function _setBeefyVault() internal {
        beefyVault["aleth_weth"] = 0x1A1F0Db1050D1cAD52eEB72371EbFD7716b53a2f;
        beefyVault["stg_usdc"] = 0xD09B5a0650d68Aae6B1666eE5E770a383d29A97C;
        beefyVault["susd-usdc"] = 0x182fe51442C7D65360eD1511f30be6261c2C20C1;
        // beefyVault[""] = ;
        // beefyVault[""] = ;
    }

    function _setYearnVault() internal {
        yearnVault["aleth_weth"] = 0xf7D66b41Cd4241eae450fd9D2d6995754634D9f3;
        yearnVault["stg_usdc"] = 0xf6B272134A193Df5b04332e73184E5b40b8EB810;
        yearnVault["susd-usdc"] = 0x1B1d2EfB6045851F8ccdE24369003e0fF157980b;
        // yearnVault[""] = ;
        // yearnVault[""] = ;
    }

    function _setMooWhale() internal {
        mooWhale["aleth_weth"] = 0xc47faE56f3702737B69ed615950c01217ec5C7C8;
        mooWhale["stg_usdc"] = 0xED8886F9B87F06bF7AB1a4897881bd83eCF1f52E;   
        mooWhale["susd-usdc"] = 0x008a74d96d799b0fcfae8462BfFF8C37C7ccc611;
        // mooWhale[""] = ;   
        // mooWhale[""] = ;
    }

    function _setIsBoosted() internal {
        isBoosted["aleth_weth"] = true;
        isBoosted["stg_usdc"] = true;   
        isBoosted["susd-usdc"] = false;
        // mooWhale[""] = ;   
        // mooWhale[""] = ;
    }
}