// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IEACAggregatorProxy {
    function aggregator(  ) external view returns (address ) ;
    function decimals(  ) external view returns (uint8 ) ;
    function latestAnswer(  ) external view returns (int256 ) ;
    function latestRound(  ) external view returns (uint256 ) ;
    function latestRoundData(  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) ;
    function latestTimestamp(  ) external view returns (uint256 ) ;
}

interface IPriceOracle {
    function getUnderlyingPrice(address cToken) external view returns (int256);
}

enum PriceSource {
    FIXED_USD,
    REPORTER
}

struct ChainlinkTokenConfig {
    address cToken;
    address underlying;
    bytes32 symbolHash;
    int256 baseUnit;
    address ChainlinkPair;
    PriceSource priceSource;
}

contract ChainlinkAnchoredView is IPriceOracle {

    mapping(bytes32 => ChainlinkTokenConfig) CTokenConfigs;
    mapping(address => bytes32) cTokenSymbolHash;

    constructor(ChainlinkTokenConfig[] memory configs) {
        for (uint i = 0; i < configs.length; i++) {
            ChainlinkTokenConfig memory config = configs[i];
            require(config.baseUnit > 0, "baseUnit must be greater than zero");
            CTokenConfigs[config.symbolHash] = config;
            cTokenSymbolHash[config.cToken] = config.symbolHash;
        }
    }

    function price(string memory symbol) external view returns (int256) {
        ChainlinkTokenConfig memory config = getTokenConfigBySymbol(symbol);
        return priceInternal(config);
    }

    function priceInternal(ChainlinkTokenConfig memory config) internal view returns (int256) {
        require(config.cToken != address(0), "config not found");
        if (config.priceSource == PriceSource.FIXED_USD) {
            return 1e8;
        }
        return IEACAggregatorProxy(config.ChainlinkPair).latestAnswer();
    }

    function getUnderlyingPrice(address cToken) external override view returns (int256) {
        ChainlinkTokenConfig memory config = getTokenConfigByCToken(cToken);
         // Comptroller needs prices in the format: ${raw price} * 1e(36 - baseUnit)
         // Since the prices in this view have 6 decimals, we must scale them by 1e(36 - 6 - baseUnit)
        return 1e28 * priceInternal(config) / config.baseUnit;
    }

    function getTokenConfigBySymbol(string memory symbol) public view returns (ChainlinkTokenConfig memory) {
        return getTokenConfigBySymbolHash(keccak256(abi.encodePacked(symbol)));
    }

    function getTokenConfigBySymbolHash(bytes32 symbolHash) public view returns (ChainlinkTokenConfig memory) {
        return CTokenConfigs[symbolHash];
    }

    function getTokenConfigByCToken(address cToken) public view returns (ChainlinkTokenConfig memory) {
        bytes32 hash = cTokenSymbolHash[cToken];
        require(hash > 0, "config not exist");
        return CTokenConfigs[hash];
    }

}
