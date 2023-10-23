// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import "lib/openzeppelin-contracts-4.7.1/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts-4.7.1/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts-4.7.1/contracts/token/ERC20/utils/SafeERC20.sol";
import {Test, console2} from "forge-std/Test.sol"; //@todo: remove

interface IBeefyVault {
    function want() external view returns (address);
    function withdrawAll() external;
}

interface IYearnVault is IERC20 {
    function token() external view returns (address);
    function deposit() external;
}

interface IRegistry {
    function stakingPool(address vault) external view returns (address);
}

interface IStakingRewards {
    function stakeFor(address recipient, uint256 amount) external;
}

interface IZap {
    function stakingPoolRegistry() external view returns (address);
    function zapIn(address _targetVault, uint256 _underlyingAmount) external returns (uint256);
}

contract MooVeloLpZapper is Ownable {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice LP tokens that the registry has added pairs for.
    address[] public lpTokens;

    /// @notice The OP boost zap contract.
    IZap public boostZapContract;

    /// @notice If a beefy-vault/yearn-vault pair exists for a given token, it will be shown here.
    mapping(address => address[2]) public pairs;

    /// @notice Check if an address can add pairs to this registry.
    mapping(address => bool) public pairEndorsers;

    /// @notice Check if an lp token exists for a given pair.
    mapping(address => bool) public isLpTokenRegistered;

    /* ========== EVENTS ========== */

    event ZapIn(address indexed user, address indexed targetVault, uint256 amount, bool isStaked);
    event PairAdded(address indexed lpToken, address beefyVault, address yearnVault);
    event Recovered(address token, uint256 amount);
    event ApprovedPairEndorser(address account, bool canEndorse);
    event UpdatedZapper(address zapper);

    /* ========== CONSTRUCTOR ========== */

    constructor(address _boostZapContract) {
        boostZapContract = IZap(_boostZapContract);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyApproved() {
        require(pairEndorsers[msg.sender], "Unauthorized");
        _;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice
     *     Add a new pair to our registry, for new or existing lp tokens.
     * @dev
     *     Throws if governance isn't set properly.
     *     Throws if sender isn't allowed to endorse.
     *     Throws if replacement is handled improperly.
     *     Emits a PairAdded event.
     * @param _lpToken The address of the new lp token.
     * @param _beefyVault The vault token from beefy.
     * @param _yearnVault The vault token from yearn.
     */
    function addPair(address _lpToken, address _beefyVault, address _yearnVault) external onlyApproved {
        // make sure the lp token is identical for both vaults
        require(IBeefyVault(_beefyVault).want() == IYearnVault(_yearnVault).token(), "lp token does not match");

        // set vault addresses for pair
        pairs[_lpToken][0] = _beefyVault;
        pairs[_lpToken][1] = _yearnVault;

        // if new token, push and set isLpTokenRegistered to true
        if (!isLpTokenRegistered[_lpToken]) {
            lpTokens.push(_lpToken);
            isLpTokenRegistered[_lpToken] = true;
        }

        emit PairAdded(_lpToken, _beefyVault, _yearnVault);
    }

    function zap(address _lpToken) external {
        // get vault tokens
        address[2] memory pair = pairs[_lpToken];

        IERC20 mooToken = IERC20(pair[0]);
        IERC20 yearnToken = IERC20(pair[1]);

        // transfer moo token to moo zapper contract
        uint256 mooBalance = mooToken.balanceOf(msg.sender);
        _checkAllowance(pair[0], address(mooToken), mooBalance);
        mooToken.transferFrom(msg.sender, address(this), mooBalance);

        // withdraw all from beefy to lp token
        IBeefyVault(pair[0]).withdrawAll();
        uint256 lpBalance = IERC20(_lpToken).balanceOf(address(this));

        // look-up OP boost registry, check if we need to stake
        address _vaultStakingPool = IRegistry(boostZapContract.stakingPoolRegistry()).stakingPool(pair[1]);

        // no need to stake
        if (_vaultStakingPool == address(0)) {
            // deposit to lp token yearn
            _checkAllowance(pair[1], address(_lpToken), lpBalance);
            IYearnVault(pair[1]).deposit();

            // transfer vault token back to msg.sender
            uint256 _toTransfer = yearnToken.balanceOf((address(this)));
            yearnToken.safeTransfer(msg.sender, _toTransfer);
            emit ZapIn(msg.sender, pair[1], _toTransfer, false);

        // the vault is boosted, need to stake
        } else {
            _checkAllowance(address(boostZapContract), _lpToken, lpBalance); // @todo: issue here with approval and delegatecall 
            (bool success, bytes memory data) = address(boostZapContract).delegatecall(abi.encodeWithSignature("zapIn(address,uint256)", pair[1], lpBalance));
            emit ZapIn(msg.sender, pair[1], lpBalance, true);
        }
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

    /**
     * @notice Set the ability of an address to endorse a pair.
     * @dev Throws if caller is not owner.
     * @param _endorser The address to approve or deny access.
     * @param _allowed Allowed to endorse
     */
    function setPairEndorser(address _endorser, bool _allowed) external onlyOwner {
        pairEndorsers[_endorser] = _allowed;
        emit ApprovedPairEndorser(_endorser, _allowed);
    }

    /**
     * @notice Set the registry for pulling our staking pools.
     * @dev Throws if caller is not owner.
     * @param _boostZapContract The address to use as pool registry.
     */
    function setZapper(address _boostZapContract) external onlyOwner {
        boostZapContract = IZap(_boostZapContract);
        emit UpdatedZapper(_boostZapContract);
    }
}
