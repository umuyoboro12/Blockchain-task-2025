// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoan {
    function executeFlashLoan(address _token, uint256 _amount, bytes calldata _data) external;
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FlashLoanBorrower {
    function executeOperation(address _token, uint256 _amount, uint256 _fee) external {
        // Do something with the loan (in a real scenario)
        
        // Repay the loan + fee
        require(IERC20(_token).transfer(msg.sender, _amount + _fee), "Repayment failed");
    }
    
    function requestFlashLoan(address _flashLoan, address _token, uint256 _amount) external {
        // Encode the callback function
        bytes memory data = abi.encodeWithSignature(
            "executeOperation(address,uint256,uint256)",
            _token,
            _amount,
            (_amount * 5) / 10000 // 0.05% fee
        );
        
        IFlashLoan(_flashLoan).executeFlashLoan(_token, _amount, data);
    }
}