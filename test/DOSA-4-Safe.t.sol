// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract WithdrawalQueue is Ownable {
    constructor() Ownable(msg.sender) {}
    struct Withdrawal {
        address user;
        uint256 amount;
    }
    Withdrawal[] public withdrawalQueue;
    mapping(address => bool) public withdrawalRequested;
    mapping(address => uint256) public balances;
    uint256 public currentIndex;
    uint256 public minWithdraw = 0.001 ether;

    fallback() external {}

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function requestWithdrawal(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(!withdrawalRequested[msg.sender], "Withdrawal already requested");
        require(amount >= minWithdraw, "Amount below minimum value");

        withdrawalQueue.push(Withdrawal({
            user: msg.sender,
            amount: amount
        }));

        withdrawalRequested[msg.sender] = true;
    }

    function resetUserStatus() external onlyOwner {
        withdrawalRequested[msg.sender] = false;
    }

    function processNextWithdrawal() external {
        require(withdrawalQueue.length > currentIndex, "No withdrawals to process");
        Withdrawal memory withdrawal = withdrawalQueue[currentIndex];

        require(withdrawalRequested[withdrawal.user], "Withdrawal no longer requested");
        uint256 amount = withdrawal.amount;

        require(balances[withdrawal.user] >= amount, "Insufficient balance");
        balances[withdrawal.user] -= amount;
        withdrawalRequested[withdrawal.user] = false;

        (bool success, ) = payable(withdrawal.user).call{value:amount}("");
        require(success, "Failed to send funds");

        currentIndex++;
    }

    function getQueueLength() external view returns (uint256) {
        return withdrawalQueue.length;
    }
}

contract WithdrawalQueueTest is Test {
    WithdrawalQueue public queue;
    address public user1;
    address public user2;
    address public attacker;

    function setUp() public {
        queue = new WithdrawalQueue();

        user1 = address(0x1);
        user2 = address(0x2);
        attacker = address(0x3);

        vm.deal(user1, 5 ether);
        vm.deal(user2, 5 ether);
        vm.deal(attacker, 5 ether);

        vm.prank(user1);
        queue.deposit{value: 2 ether}();

        vm.prank(user2);
        queue.deposit{value: 2 ether}();

        vm.prank(attacker);
        queue.deposit{value: 1 ether}();
    }

    function testDOSAttack() public {
        vm.prank(user1);
        queue.requestWithdrawal(1 ether);

        vm.prank(attacker);
        queue.requestWithdrawal(0.5 ether);

        vm.prank(user2);
        queue.requestWithdrawal(1 ether);

        assertEq(queue.getQueueLength(), 3);

        queue.processNextWithdrawal();
        assertEq(queue.currentIndex(), 1);

        vm.prank(attacker);
        queue.resetUserStatus();

        vm.expectRevert("Withdrawal no longer requested");
        queue.processNextWithdrawal();

        assertEq(queue.currentIndex(), 1);
    }
}