// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IVault {
    function token() external returns (address);

    function stayking() external returns (address);

    function interestModel() external returns (address);

    function totalAmount() external view returns (uint256);

    function debtAmountOf(address user) external view returns (uint256);

    function debtAmountInBase(address user) external view returns (uint256);

    function totalStakedDebtAmount() external view returns (uint256);

    function totalDebtAmount() external view returns (uint256);

    function totalPendingDebtAmount() external view returns (uint256);

    function totalPendingDebtShare() external view returns (uint256);

    function accInterest() external view returns (uint256);

    function minReservedBps() external view returns (uint256);

    function lastAccruedAt() external view returns (uint256);

    function utilizationRateBps() external view returns (uint256);

    /// @dev denominator = 1E18
    function getInterestRate() external view returns (uint256);

    function deposit(uint256 amount) external returns (uint256 share);

    function withdraw(uint256 share) external returns (uint256 amount);

    function getPendingDebt(address user) external view returns (uint256 debt);

    function getPendingDebtInBase(address user)
        external
        view
        returns (uint256 debtInBase);

    function getBaseIn(uint256 tokenOut) external view returns (uint256 baseIn);

    function getBaseOut(uint256 tokenIn)
        external
        view
        returns (uint256 baseOut);

    function getTokenIn(uint256 baseOut)
        external
        view
        returns (uint256 tokenIn);

    function getTokenOut(uint256 baseIn)
        external
        view
        returns (uint256 tokenOut);

    function pendingDebtAmountToShare(uint256 amount)
        external
        view
        returns (uint256);

    function pendingDebtShareToAmount(uint256 share)
        external
        view
        returns (uint256);

    /******************************
     * Only for Stayking Contract *
     ******************************/
    function loan(address user, uint256 debtInBase)
        external
        returns (uint256 debt);

    function repayInToken(address user, uint256 debt) external;

    function repayInBase(address user, uint256 minRepaid)
        external
        payable
        returns (uint256 repaid);

    function takeDebtOwnership(address from, uint256 amount) external;

    function getInterestInBase() external view returns (uint256);

    function payInterest(uint256 minPaidInterest) external payable;

    function pendRepay(address user, uint256 amount)
        external
        returns (uint256 pendingDebtShare);

    function repayPendingDebt(address user) external payable returns (uint256);

    function updateInterestModel(address newInterestModel) external;

    function updateSwapHelper(address newSwapHelper) external;

    function updateMinReservedBps(uint256 newMinReservedBps) external;
}