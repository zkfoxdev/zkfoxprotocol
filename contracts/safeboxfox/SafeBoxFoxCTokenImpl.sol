// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "../../interfaces/IErc20Interface.sol";
import "../../interfaces/ICTokenInterface.sol";
import "../interfaces/ISafeBox.sol";

// Safebox vault, deposit, withdrawal, borrowing, repayment
contract SafeBoxFoxCTokenImpl is ERC20Upgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IErc20Interface public eToken;
    ICTokenInterface public cToken;

    uint8 _decimals;

    function __SafeBoxFoxCTokenImpl__init(address _cToken) public initializer {
        __ERC20_init(
            string(
                abi.encodePacked(
                    "fox ",
                    ERC20Upgradeable(IErc20Interface(_cToken).underlying())
                        .name()
                )
            ),
            string(
                abi.encodePacked(
                    "f",
                    ERC20Upgradeable(IErc20Interface(_cToken).underlying())
                        .symbol()
                )
            )
        );

        _decimals = ERC20Upgradeable(_cToken).decimals();
        // _setupDecimals(ERC20Upgradeable(_cToken).decimals());
        eToken = IErc20Interface(_cToken);
        cToken = ICTokenInterface(_cToken);
        require(cToken.isCToken(), "not ctoken address");
        IERC20Upgradeable(baseToken()).approve(_cToken, type(uint256).max);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function baseToken() public view virtual returns (address) {
        return eToken.underlying();
    }

    function ctokenSupplyRatePerBlock() public view virtual returns (uint256) {
        return cToken.supplyRatePerBlock();
    }

    function ctokenBorrowRatePerBlock() public view virtual returns (uint256) {
        return cToken.borrowRatePerBlock();
    }

    function call_balanceOf(
        address _token,
        address _account
    ) public view virtual returns (uint256 balance) {
        balance = IERC20Upgradeable(_token).balanceOf(_account);
    }

    function call_balanceOfCToken_this()
        public
        view
        virtual
        returns (uint256 balance)
    {
        balance = call_balanceOf(address(cToken), address(this));
    }

    function call_balanceOfBaseToken_this() public virtual returns (uint256) {
        return
            call_balanceOfCToken_this().mul(cToken.exchangeRateCurrent()).div(
                1e18
            );
    }

    function call_borrowBalanceCurrent_this() public virtual returns (uint256) {
        return cToken.borrowBalanceCurrent(address(this));
    }

    function getBaseTokenPerCToken() public view virtual returns (uint256) {
        return cToken.exchangeRateStored();
    }

    // deposit
    function ctokenDeposit(
        uint256 _value
    ) internal virtual returns (uint256 lpAmount) {
        uint256 cBalanceBefore = call_balanceOf(address(cToken), address(this));
        require(eToken.mint(uint256(_value)) == 0, "deposit token error");
        uint256 cBalanceAfter = call_balanceOf(address(cToken), address(this));
        lpAmount = cBalanceAfter.sub(cBalanceBefore);
    }

    function ctokenWithdraw(
        uint256 _lpAmount
    ) internal virtual returns (uint256 value) {
        uint256 cBalanceBefore = call_balanceOf(baseToken(), address(this));
        require(eToken.redeem(_lpAmount) == 0, "withdraw supply ctoken error");
        uint256 cBalanceAfter = call_balanceOf(baseToken(), address(this));
        value = cBalanceAfter.sub(cBalanceBefore);
    }

    function ctokenClaim(
        uint256 _lpAmount
    ) internal virtual returns (uint256 value) {
        value = ctokenWithdraw(_lpAmount);
    }

    function ctokenBorrow(
        uint256 _value
    ) internal virtual returns (uint256 value) {
        uint256 cBalanceBefore = call_balanceOf(baseToken(), address(this));
        require(eToken.borrow(_value) == 0, "borrow ubalance error");
        uint256 cBalanceAfter = call_balanceOf(baseToken(), address(this));
        value = cBalanceAfter.sub(cBalanceBefore);
    }

    function ctokenRepayBorrow(uint256 _value) internal virtual {
        require(eToken.repayBorrow(_value) == 0, "repayBorrow ubalance error");
    }
}
