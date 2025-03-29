//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SafeContract is Ownable {
    constructor() Ownable(msg.sender) {}
    struct WithdrawalRequest {
        address payable recipient;
        uint256 amount;
    }
    mapping(address => uint256) public balances;
    WithdrawalRequest[] public withdrawals;
    uint256 public minWithdraw = 0.001 ether;

    function requestWithdrawal(uint256 _amount) external {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        require(_amount >= minWithdraw, "Amount below minimum value");
        WithdrawalRequest memory request = WithdrawalRequest(payable(msg.sender), _amount);
        withdrawals.push(request);
    }

    function processWithdrawals(uint256 _count) external onlyOwner {
        require(_count <= withdrawals.length);
        require(_count > 0);
        for (uint256 i = 0; i < _count; i++) {
            WithdrawalRequest memory request = withdrawals[i];
            request.recipient.transfer(request.amount); 
        }
        for (uint256 i = 0; i < withdrawals.length - _count; i++) {
            withdrawals[i] = withdrawals[i + _count];
        }
        for (uint256 i = 0; i < _count; i++) {withdrawals.pop;} 
    }
}

contract safeContractTest is Test {
    SafeContract public safeContract;
    address payable attacker = payable(address(1337));
    address payable user = payable(address(42));

    function setUp() public {
        safeContract = new SafeContract();
        vm.deal(address(safeContract), 10 ether);
    }

    function testDenialOfServiceViaZeroValueTransactions() public {
        vm.startPrank(attacker);
        for (uint256 i = 0; i < 25; i++) { 
            safeContract.requestWithdrawal(0);
        }
        vm.stopPrank();

        vm.startPrank(user);
        safeContract.requestWithdrawal(1 ether);
        vm.stopPrank();

        uint256 beforeGas = gasleft();
        safeContract.processWithdrawals(26); 
        uint256 afterGas = gasleft();
        uint256 gasUsed = beforeGas - afterGas;
        assertTrue(gasUsed > 5000);
    }
}