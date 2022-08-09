// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;


/************************************************************
 * @dev
 * Glossary
 * debt : debtAmount in borrowing token (e.g. OSMO, ATOM)
 * debtInBase: debtAmount in EVMOS(Base Token)
 *************************************************************/
interface IStayking { 

    // struct Position {
    //     address user;
    //     address vault;
    //     uint256 equity;
    //     uint256 debt;
    // }

    function addVault(address token, address vault) external;
    
    function tokenToVault(address token) external view returns(address vault);

    function addWhitelistDelegator(address delegator) external;

    /// @dev min debtAmount in EVMOS (base token)
    function minDebtInBase() external view returns (uint256);

    function killFactorBps() external view returns(uint256);

    /// @param debtToken    debtToken Address (not vault address)
    /// @param equity       equityAmount in EVMOS
    /// @param debtInBase   debtAmount in EVMOS
    function addPosition(
        address debtToken,
        uint256 equity,
        uint256 debtInBase
    ) payable external;


    /// @param debtToken    debtToken Address (not vault address)
    function removePosition(uint256 debtToken) external;

    /// @dev Put more equity or increase debt.
    /// @param debtToken    debtToken Address (not vault address)
    /// @param extraEquity  amount of additional equity
    /// @param extraDebtInBase  amount of additional debt in EVMOS
    function editPosition(
        address debtToken,
        uint256 extraEquity,
        uint256 extraDebtInBase
    ) payable external;


    function isKillable(uint256 positionId) external view returns(bool);
    
    function kill(uint256 positionId) external;

    function delegate (uint256 amount) external;

}