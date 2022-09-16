// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;


/************************************************************
 * @dev
 * Glossary
 * debt : debtAmount in borrowing token (e.g. OSMO, ATOM)
 * debtInBase: debtAmount in EVMOS(Base Token)
 *************************************************************/
interface IStayking { 

    function updateVault(address token, address vault) external;
    
    function tokenToVault(address token) external view returns(address vault);

    function changeDelegator(address delegator) external;
    // function setWhitelistDelegatorStatus(address delegator, bool status) external;

    /// @dev min debtAmount in EVMOS (base token)
    function minDebtInBase() external view returns (uint256);

    function reservedBps() external view returns(uint256);

    function vaultRewardBps() external view returns(uint256);

    function totalAmount() external view returns(uint256);

    function totalShare() external view returns(uint256);

    function killFactorBps() external view returns(uint256);

    function liquidateDebtFactorBps() external view returns(uint256);

    function liquidationFeeBps() external view returns(uint256);

    function debtAmountOf (
        address user,
        address vault
    ) external view returns(uint256 debt);

    /// @param debtToken    debtToken Address (not vault address)
    /// @param equity       equityAmount in EVMOS
    /// @param debtInBase   debtAmount in EVMOS
    function addPosition(
        address debtToken,
        uint256 equity,
        uint256 debtInBase
    ) payable external;

    /// @param debtToken    debtToken Address (not vault address)
    function removePosition(address debtToken) external;

    function positionInfo(
        address user,
        address vault
    ) external view returns (uint256 equityInBase, uint256 debtInBase, uint256 debt, uint256 positionId);

    function isKillable(address debtToken, uint256 positionId) external view returns(bool);
    
    function kill(address debtToken, uint256 positionId) external;

    /***********************
     * Only for Delegator *
     ***********************/
    function getAccruedValue(uint256 reward) external view returns(uint256);
    function accrue(uint256 totalStaked) payable external;

}