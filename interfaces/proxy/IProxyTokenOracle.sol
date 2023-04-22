// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IProxyTokenOracle {
    function owner() external view returns (address);

    function setFeed(address _token, address _feed) external;

    function setFeeds(address[] memory _token, address[] memory _feed) external;

    function getPrice(address _token) external view returns (int);
}
