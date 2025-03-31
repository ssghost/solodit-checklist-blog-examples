//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TokenStream {
    IERC20 public token;
    uint256 public streamDuration;
    uint256 public tokensPerSecond;

    constructor(IERC20 _token, uint256 _streamDuration, uint256 _tokensPerSecond) {
        token = _token;
        streamDuration = _streamDuration;
        tokensPerSecond = _tokensPerSecond;
    }

    function distributeTokens(address recipient) external {
        uint256 balance = token.balanceOf(address(this));
        uint256 amount = tokensPerSecond * streamDuration;

        uint256 tokensToSend = amount > balance ? balance : amount;

        require(tokensToSend > 0, "Insufficient tokens to stream");
        token.transfer(recipient, tokensToSend);
    }
}

contract LowDecimalToken is ERC20 {
    constructor() ERC20("LowDecimalToken", "LDT") {
        _mint(msg.sender, 100000 * (10 ** decimals()));
    }

    function decimals() public view virtual override returns (uint8) {
        return 10; 
    }
}

contract TokenStreamTest is Test {
    TokenStream public tokenStream;
    LowDecimalToken public lowDecimalToken;
    address public recipient;

    function setUp() public {
        recipient = address(1);
        lowDecimalToken = new LowDecimalToken();
        
        uint256 stream_duration = 1000;
        uint256 total_tokens = 10;
        uint256 tokens_per_second = total_tokens / stream_duration;

        tokenStream = new TokenStream(lowDecimalToken, stream_duration, tokens_per_second);
        lowDecimalToken.transfer(address(tokenStream), total_tokens * (10 ** lowDecimalToken.decimals()));
    }

    function testDOSWithLowDecimalTokens() public {
        vm.expectRevert("Insufficient tokens to stream");
        tokenStream.distributeTokens(recipient);
    }
}