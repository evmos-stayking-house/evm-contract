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

    function killFactorBps() external view returns(uint256);

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

    /// @dev Borrow more debt (increase debt ratio)
    /// @param debtToken    debtToken Address (not vault address)
    /// @param extraDebtInBase  amount of additional debt in EVMOS
    function addDebt(
        address debtToken,
        uint256 extraDebtInBase
    ) external;

    /// @dev Repay debt (decrease debt ratio)
    /// @notice user should repay debt using debtToken
    /// @notice user approve should be preceded
    /// @param debtToken    debtToken Address (not vault address)
    /// @param repaidDebt  amount of repaid debt in debtToken
    function repayDebt(
        address debtToken,
        uint256 repaidDebt
    ) external;

    function repayDebtInBase(
        address debtToken,
        uint256 minRepaid
    ) payable external;

    /// @dev add additional equity (decrease debt ratio)
    /// @param debtToken    debtToken Address (not vault address)
    /// @param extraEquity  amount of additional equity
    function addEquity(
        address debtToken,
        uint256 extraEquity
    ) payable external;

    function positionInfo(
        address user,
        address vault
    ) external view returns (uint256 equityInBase, uint256 debtInBase);

    function isKillable(address debtToken, uint256 positionId) external view returns(bool);
    
    function kill(address debtToken, uint256 positionId) external;

    /***********************
     * Only for Delegator *
     ***********************/
    function accrue(uint256 currentTotalStaked) payable external;

}