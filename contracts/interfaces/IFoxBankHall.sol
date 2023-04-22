// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IFoxBankHall {
    function makeBorrowFrom(
        uint256 _pid,
        address _account,
        address _debtFrom,
        uint256 _value
    ) external returns (uint256 bid);
}
