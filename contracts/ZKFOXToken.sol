// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IRewardsToken.sol";

contract ZKFOXToken is ERC20Capped, Ownable, IRewardsToken {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply
    ) ERC20Capped(_totalSupply) ERC20(_name, _symbol) {}

    mapping(address => bool) public mintWhitelist;

    function setMintWhitelist(
        address _account,
        bool _enabled
    ) external override onlyOwner {
        mintWhitelist[_account] = _enabled;
    }

    function checkWhitelist(
        address _account
    ) external view override returns (bool) {
        return mintWhitelist[_account];
    }

    function mint(address _account, uint256 _amount) external override {
        require(mintWhitelist[msg.sender], "not allow");
        _mint(_account, _amount);
    }

    function burn(uint256 _amount) external override onlyOwner {
        _burn(msg.sender, _amount);
    }
}
