// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../interfaces/poolproxy/ISyncSwapPool.sol";

contract WrapperSyncPair {
    address public pair;

    constructor(address _pair) {
        pair = _pair;
    }

    function name() external view returns (string memory) {
        return
            string(
                abi.encodePacked("Wrapper", " ", ISyncSwapPool(pair).name())
            );
    }

    function symbol() external view returns (string memory) {
        return ISyncSwapPool(pair).symbol();
    }

    function decimals() external view returns (uint8) {
        return ISyncSwapPool(pair).decimals();
    }

    function totalSupply() external view returns (uint) {
        return ISyncSwapPool(pair).totalSupply();
    }

    function token0() external view returns (address) {
        return ISyncSwapPool(pair).token0();
    }

    function token1() external view returns (address) {
        return ISyncSwapPool(pair).token1();
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        (uint256 r0, uint256 r1) = ISyncSwapPool(pair).getReserves();
        return (uint112(r0), uint112(r1), 0);
    }
}
