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

contract safeETHWithdrawal is Ownable {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public withdrawableBalances;
    constructor() Ownable(msg.sender) {}

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function getUsers() private returns (address[] memory) { }

    function startBatchWithdrawal() public {
        address[] memory users = getUsers();
        for (uint i = 0; i<users.length; i++) {
            uint amount = balances[users[i]];
            if (amount > 0) {
                balances[users[i]] = 0;
                withdrawableBalances[users[i]] += amount;
            }
        }
    }

    function withdraw() public {
        uint amount = withdrawableBalances[msg.sender];
        require(amount > 0, "Insufficient balance");
        withdrawableBalances[msg.sender] = 0;

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

contract safeETHWithdrawalTest is Test {
    safeETHWithdrawal public safeContract;
    RevertingReceiver public revertingContract;
    address public user = address(1);

    function setUp() public {
        safeContract = new safeETHWithdrawal();
        revertingContract = new RevertingReceiver();
        vm.deal(user, 10 ether);

        vm.startPrank(user);
        safeContract.deposit{value: 10 ether}();
        vm.stopPrank();

        safeContract.transferOwnership(address(revertingContract));
    }

    function testWithdrawalFailsDueToRevertingOwner() public {
        vm.startPrank(user);
        assertEq(safeContract.balances(user), 10 ether);

        vm.expectRevert("Fee transfer failed");
        safeContract.startBatchWithdrawal();
        safeContract.withdraw();

        assertEq(safeContract.balances(user), 10 ether);
        vm.stopPrank();
    }

    receive() external payable {}
}
