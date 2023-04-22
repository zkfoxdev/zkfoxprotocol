// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../../interfaces/uniswapv2/IUniswapV2Pair.sol";

import "../../interfaces/ICTokenInterface.sol";
import "../interfaces/ITokenOracle.sol";

contract MultiSourceOracle is OwnableUpgradeable, ITokenOracle {
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;

    struct PriceData {
        uint price;
        uint lastUpdate;
    }

    struct LPTokenData {
        address lptoken;
        bool isToken0;
        uint256 decimals0;
        uint256 decimals1;
        uint256 pooltype; // 0 = usdc 1 = weth
    }

    bool public constant isPriceOracle = true;
    mapping(address => bool) public opers;

    mapping(address => LPTokenData) public lptokens;
    mapping(address => PriceData) public baseone;
    mapping(address => uint256) public floatRate;
    uint256 public floatRateBase;
    address public USDCToken;
    address public WETHToken;

    uint256[50] private __gap;

    event PriceUpdate(address indexed _token, uint price);
    event BasePriceUpdate(address indexed _token, uint price);
    event SetTokenLPToken(address _token, address _lptokens);

    constructor() {}

    function initialize() public initializer {
        __Ownable_init();
        opers[msg.sender] = true;
        floatRateBase = 2e8;
    }

    function setPriceOperator(address _oper, bool _enable) public onlyOwner {
        opers[_oper] = _enable;
    }

    function setFloatRateBase(uint256 _floatRateBase) public onlyOwner {
        floatRateBase = _floatRateBase;
    }

    function setBaseToken(
        address _USDCToken,
        address _WETHToken
    ) public onlyOwner {
        USDCToken = _USDCToken;
        WETHToken = _WETHToken;
    }

    function setPriceFloatRate(
        address[] memory _tokens,
        uint256[] memory _rates
    ) public onlyOwner {
        require(_tokens.length == _rates.length, "bad token length");
        for (uint idx = 0; idx < _tokens.length; idx++) {
            floatRate[_tokens[idx]] = _rates[idx];
        }
    }

    function setBasePrices(
        address[] memory _tokens,
        uint[] memory _basePrices
    ) external {
        require(opers[msg.sender], "only oper");
        require(_tokens.length == _basePrices.length, "bad token length");
        for (uint idx = 0; idx < _tokens.length; idx++) {
            address token = _tokens[idx];
            uint price = _basePrices[idx];
            baseone[token] = PriceData({price: price, lastUpdate: 0});
            // emit BasePriceUpdate(token, price); // gas saved
        }
    }

    function verifyBasePrice(
        address _token,
        uint256 _price
    ) public view returns (bool) {
        PriceData memory data = baseone[_token];
        if (data.price == 0) {
            return true;
        }
        require(_price > 0, "verifyBasePrice zero _price");
        (uint256 priceA, uint256 priceB) = data.price > _price
            ? (data.price, _price)
            : (_price, data.price);
        uint256 wantRate = floatRate[_token] > 0
            ? floatRate[_token]
            : floatRateBase;
        uint256 currentRate = priceA.sub(priceB).mul(1e9).div(priceB);
        require(currentRate < wantRate, "currentRate overrate");
        return true;
    }

    function setTokenLPTokens(
        address[] memory _tokens,
        address[] memory _lptokens
    ) external onlyOwner {
        require(_tokens.length == _lptokens.length, "length error");
        for (uint256 i = 0; i < _tokens.length; i++) {
            emit SetTokenLPToken(_tokens[i], _lptokens[i]);
            address token = _tokens[i];
            LPTokenData storage lpdata = lptokens[token];
            lpdata.lptoken = _lptokens[i];
            if (lpdata.lptoken != address(0)) {
                IUniswapV2Pair pair = IUniswapV2Pair(_lptokens[i]);
                address token0 = pair.token0();
                address token1 = pair.token1();
                lpdata.decimals0 = ERC20Upgradeable(token0).decimals();
                lpdata.decimals1 = ERC20Upgradeable(token1).decimals();
                lpdata.isToken0 = token == token0;

                {
                    address tokenbase = lpdata.isToken0 ? token1 : token0;
                    if (tokenbase == USDCToken) {
                        lpdata.pooltype = 0;
                    } else if (tokenbase == WETHToken) {
                        lpdata.pooltype = 1;
                    } else {
                        require(false, "tokenbase error");
                    }

                    require(
                        lpdata.pooltype == 0 || lpdata.pooltype == 1,
                        "pooltype error"
                    );
                }
            }
        }
    }

    function getPriceFromLPToken(address _token) public view returns (int256) {
        LPTokenData storage lpdata = lptokens[_token];
        if (lpdata.lptoken == address(0)) return int256(baseone[_token].price);
        require(lpdata.lptoken != address(0), "not lptoken");

        IUniswapV2Pair pair = IUniswapV2Pair(lpdata.lptoken);
        (uint256 r0, uint256 r1, ) = pair.getReserves();
        if (lpdata.decimals0 != 18) {
            r0 = r0.mul(1e18).div(10 ** lpdata.decimals0);
        }
        if (lpdata.decimals1 != 18) {
            r1 = r1.mul(1e18).div(10 ** lpdata.decimals1);
        }
        if (lpdata.isToken0) {
            (r0, r1) = (r1, r0);
        }
        int256 price = int256(r0.mul(1e18).div(r1));
        if (lpdata.pooltype == 1) {
            price = getPriceFromLPToken(WETHToken).mul(price).div(1e18);
        }
        require(price > 0, "price error");
        return price;
    }

    function getPrice(
        address _token
    ) public view override returns (int256 price) {
        price = getPriceNoSafe(_token);
        require(price > 0, "price to lower");
        verifyBasePrice(_token, uint256(price));
        return price;
    }

    function getPriceNoSafe(address _token) public view returns (int256 price) {
        if (USDCToken == _token) {
            return int256(1e18);
        }
        price = getPriceFromLPToken(_token);
    }

    /**
     * @notice Get the underlying price of a cToken asset
     * @param cToken The cToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable.
     */
    function getUnderlyingPrice(address cToken) external view returns (uint) {
        address token = ICTokenInterface(cToken).underlying();
        int price = getPrice(token);
        return uint(price).mul(uint(1e18).div(1e8));
    }
}
