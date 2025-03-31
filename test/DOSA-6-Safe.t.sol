//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract MockAggregatorV3Interface is AggregatorV3Interface {
    int256 public price = 100;
    bool public shouldRevert = false;

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        if (shouldRevert) {
            revert("Chainlink reverting");
        }
        return (1, price, block.timestamp, block.timestamp, 1);
    }

    function setRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }
}

contract PriceDependentContract {
    AggregatorV3Interface public priceFeed;

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    event Error(bytes reason); 

    function getPrice() public returns (uint256) {
        uint256 price;
        try priceFeed.latestRoundData() returns (
            uint80,
            int256 _price,
            uint256,
            uint256,
            uint80
        ) {
            require(_price > 0, "Price must be positive");
            price = uint256(_price);
        } catch (bytes memory reason) {
            emit Error(reason);
            price = 100;
        } 
        return uint256(price);
    }

    function calculateSomethingImportant() public returns (uint256) {
        uint256 price = getPrice();
        return price * 2;
    }

    function calculateSomethingImportantSafely() public returns (uint256) {
        uint256 price;
        try priceFeed.latestRoundData() returns (
            uint80,
            int256 _price,
            uint256,
            uint256,
            uint80
        ) {
            require(_price > 0, "Price must be positive");
            price = uint256(_price);
        } catch (bytes memory reason) {
            emit Error(reason);
            price = 100;
        } 

        return price * 2;
    }
}

contract PriceDependentContractTest is Test {
    PriceDependentContract public priceDependentContract;
    MockAggregatorV3Interface public mockAggregator;

    function setUp() public {
        mockAggregator = new MockAggregatorV3Interface();
        priceDependentContract = new PriceDependentContract(address(mockAggregator));
    }

    function testDoSVulnerable() public {
        assertEq(priceDependentContract.calculateSomethingImportant(), 200);

        mockAggregator.setRevert(true);

        vm.expectRevert("Chainlink reverting");
        priceDependentContract.calculateSomethingImportant();
    }

    function testDoSFixed() public {
        assertEq(priceDependentContract.calculateSomethingImportantSafely(), 200);
        mockAggregator.setRevert(true);

        assertEq(priceDependentContract.calculateSomethingImportantSafely(), 200);
    }
}