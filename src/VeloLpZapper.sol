// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts-4.7.1/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts-4.7.1/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts-4.7.1/contracts/token/ERC20/utils/SafeERC20.sol";
import {Test, console2} from "forge-std/Test.sol";

interface IBeefyVault {
    function want() external view returns (address);
    function withdrawAll() external;
}

interface IYearnVault {
    function token() external view returns (address);
    function deposit() external;
}

contract VeloLpZapper is Ownable {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    address[] public lpTokens;
    mapping(address => address[2]) public pairs;
    mapping(address => bool) public pairEndorsers;
    mapping(address => bool) public isLpTokenRegistered;

    /* ========== EVENTS ========== */

    event PairAdded(address indexed lpToken, address beefyVault, address yearnVault);
    event ZapIn(address indexed user, address indexed targetVault, uint256 amount);
    event Recovered(address token, uint256 amount);

    /* ========== MODIFIERS ========== */

    modifier onlyApproved() {
        require(pairEndorsers[msg.sender], "Unauthorized");
        _;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function addPair(address _lpToken, address _beefyVault, address _yearnVault) external onlyApproved {
        require(IBeefyVault(_beefyVault).want() == IYearnVault(_yearnVault).token(), "lp token does not match");
        pairs[_lpToken][0] = _beefyVault;
        pairs[_lpToken][1] = _yearnVault;

        if (!isLpTokenRegistered[_lpToken]) {
            lpTokens.push(_lpToken);
            isLpTokenRegistered[_lpToken] = true;
        }

        emit PairAdded(_lpToken, _beefyVault, _yearnVault);
    }

    function zap(address _lpToken) external {
        address[2] memory pair = pairs[_lpToken];
        IERC20 mooToken = IERC20(pair[0]);
        IERC20 yearnToken = IERC20(pair[1]);

        // transfer moo token to zap contract
        uint256 mooBalance = mooToken.balanceOf(msg.sender);
        _checkAllowance(pair[0], address(mooToken), mooBalance);
        mooToken.transferFrom(msg.sender, address(this), mooBalance);

        // withdraw all from beefy
        IBeefyVault(pair[0]).withdrawAll();

        // deposit to yearn
        uint256 lpBalance = IERC20(_lpToken).balanceOf(address(this));
        _checkAllowance(pair[1], address(_lpToken), lpBalance);
        IYearnVault(pair[1]).deposit();

        // transfer vault token back to msg.sender
        uint256 _toTransfer = yearnToken.balanceOf((address(this)));
        yearnToken.safeTransfer(msg.sender, _toTransfer);
        emit ZapIn(msg.sender, pair[1], _toTransfer);
    }

    function _checkAllowance(address _contract, address _token, uint256 _amount) internal {
        if (IERC20(_token).allowance(address(this), _contract) < _amount) {
            IERC20(_token).safeApprove(_contract, 0);
            IERC20(_token).safeApprove(_contract, type(uint256).max);
        }
    }

    /* ========== VIEWS ========== */

    function getNumLpTokens() external view returns (uint256) {
        return lpTokens.length;
    }

    /* ========== ACCESS CONTROL ========== */

    function setPairEndorser(address endorser, bool allowed) external onlyOwner {
        pairEndorsers[endorser] = allowed;
    }
}
