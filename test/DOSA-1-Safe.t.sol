//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract RevertingReceiver {
    receive() external payable {
        revert("Reverting ETH Receiver");
    }

    fallback() external payable {
        revert("Reverting ETH Receiver");
    }
}

contract VulnerableETHWithdrawal is Ownable {
    mapping(address => uint256) public balances;

    constructor() Ownable(msg.sender) {}

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        uint256 fee = amount / 10; 
        uint256 userAmount = amount - fee;

        (bool feeSuccess, ) = owner().call{value: fee}("");
        require(feeSuccess, "Fee transfer failed");

        (bool success, ) = msg.sender.call{value: userAmount}("");
        require(success, "User transfer failed");
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract VulnerableETHWithdrawalTest is Test {
    VulnerableETHWithdrawal public vulnerableContract;
    RevertingReceiver public revertingContract;
    address public user = address(1);

    function setUp() public {
        vulnerableContract = new VulnerableETHWithdrawal();
        revertingContract = new RevertingReceiver();
        vm.deal(user, 10 ether);

        vm.startPrank(user);
        vulnerableContract.deposit{value: 10 ether}();
        vm.stopPrank();

        vulnerableContract.transferOwnership(address(revertingContract));
    }

    function testWithdrawalFailsDueToRevertingOwner() public {
        vm.startPrank(user);
        assertEq(vulnerableContract.balances(user), 10 ether);

        vm.expectRevert("Fee transfer failed");
        vulnerableContract.withdraw(5 ether);

        assertEq(vulnerableContract.balances(user), 10 ether);
        vm.stopPrank();
    }

    receive() external payable {}
}
