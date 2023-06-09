// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./IFoxBankHall.sol";

interface IFoxBankHallV2 is IFoxBankHall {
    function boxInfo(uint256 _boxid) external view returns (address);

    function boxIndex(address _boxaddr) external view returns (uint256);

    function boxlisted(address _boxaddr) external view returns (bool);

    function strategyInfo(
        uint256 _sid
    ) external view returns (bool, address, uint256);

    function strategyIndex(
        address _strategy,
        uint256 _sid
    ) external view returns (uint256);
}
