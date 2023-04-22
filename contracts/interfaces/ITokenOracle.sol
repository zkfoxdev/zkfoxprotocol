// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface ITokenOracle {
    function getPrice(address _token) external view returns (int);
}
