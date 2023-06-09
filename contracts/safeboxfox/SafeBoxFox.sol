// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/ISafeBox.sol";

import "./SafeBoxFoxCToken.sol";

// Distribution of Fox Compound token
contract SafeBoxFox is SafeBoxFoxCToken {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public REWARDS_TOKEN;

    uint256 public lastRewardsTokenBlock; // rewards update

    address public actionPoolRewards; // address for action pool
    uint256 public poolDepositId; // poolid of depositor s token rewards in action pool, the action pool relate boopool deposit
    uint256 public poolBorrowId; // poolid of borrower s token rewards in action pool

    uint256 public REWARDS_DEPOSIT_CALLID; // depositinfo callid for action callback
    uint256 public REWARDS_BORROW_CALLID; // borrowinfo callid for comp action callback

    event SetRewardsDepositPool(
        address _actionPoolRewards,
        uint256 _piddeposit
    );
    event SetRewardsBorrowPool(address _compActionPool, uint256 _pidborrow);

    function initialize(
        address _bank,
        address _cToken,
        address _devAddr
    ) public initializer {
        __Ownable_init();

        __SafeBoxFoxCToken_init(_bank, _cToken, _devAddr);

        REWARDS_TOKEN = IERC20Upgradeable(address(0));
        REWARDS_DEPOSIT_CALLID = 16;
        REWARDS_BORROW_CALLID = 18;
    }

    function update() public virtual override {
        _update();
        updatetoken();
    }

    // mint rewards for supplies to action pools
    function setRewardsDepositPool(
        address _actionPoolRewards,
        uint256 _piddeposit
    ) public onlyOwner {
        actionPoolRewards = _actionPoolRewards;
        poolDepositId = _piddeposit;
        emit SetRewardsDepositPool(_actionPoolRewards, _piddeposit);
    }

    // mint rewards for borrows to comp action pools
    function setRewardsBorrowPool(uint256 _pidborrow) public onlyOwner {
        _checkActionPool(compActionPool, _pidborrow, REWARDS_BORROW_CALLID);
        poolBorrowId = _pidborrow;
        emit SetRewardsBorrowPool(compActionPool, _pidborrow);
    }

    function _checkActionPool(
        address _actionPool,
        uint256 _pid,
        uint256 _rewardscallid
    ) internal view {
        (address callFrom, uint256 callId, address rewardToken) = IActionPools(
            _actionPool
        ).getPoolInfo(_pid);
        require(callFrom == address(this), "call from error");
        require(callId == _rewardscallid, "callid error");
    }

    function deposit(uint256 _value) external virtual override nonReentrant {
        update();
        IERC20Upgradeable(token).safeTransferFrom(
            msg.sender,
            address(this),
            _value
        );
        _deposit(msg.sender, _value);
    }

    function withdraw(
        uint256 _tTokenAmount
    ) external virtual override nonReentrant {
        update();
        _withdraw(msg.sender, _tTokenAmount);
    }

    function borrow(
        uint256 _bid,
        uint256 _value,
        address _to
    ) external virtual override onlyBank {
        update();
        address owner = borrowInfo[_bid].owner;
        uint256 accountBorrowPointsOld = accountBorrowPoints[owner];
        _borrow(_bid, _value, _to);

        if (compActionPool != address(0) && _value > 0) {
            IActionPools(compActionPool).onAcionIn(
                REWARDS_BORROW_CALLID,
                owner,
                accountBorrowPointsOld,
                accountBorrowPoints[owner]
            );
        }
    }

    function repay(uint256 _bid, uint256 _value) external virtual override {
        update();
        address owner = borrowInfo[_bid].owner;
        uint256 accountBorrowPointsOld = accountBorrowPoints[owner];
        _repay(_bid, _value);

        if (compActionPool != address(0) && _value > 0) {
            IActionPools(compActionPool).onAcionOut(
                REWARDS_BORROW_CALLID,
                owner,
                accountBorrowPointsOld,
                accountBorrowPoints[owner]
            );
        }
    }

    function updatetoken() public {
        if (lastRewardsTokenBlock >= block.timestamp) {
            return;
        }
        lastRewardsTokenBlock = block.timestamp;
    }

    function claim(uint256 _value) external virtual override nonReentrant {
        update();
        _claim(msg.sender, _value);
    }
}
