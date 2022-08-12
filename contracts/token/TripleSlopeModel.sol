// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../interface/IInterestModel.sol";

contract TripleSlopeModel is IInterestModel {
    /****************************
     * POLICY CONSTANT SECTIONS *
     ****************************/

    uint256 public constant DENOM = 1e18;

    uint256 public constant CEIL_SLOPE_1 = 60 * DENOM;
    uint256 public constant CEIL_SLOPE_2 = 90 * DENOM;
    uint256 public constant CEIL_SLOPE_3 = 100 * DENOM;

    uint256 public constant MAX_INTEREST_SLOPE_1 = (20 * DENOM) / 100;
    uint256 public constant MAX_INTEREST_SLOPE_2 = (20 * DENOM) / 100;
    uint256 public constant MAX_INTEREST_SLOPE_3 = (150 * DENOM) / 100;

    /// @dev Intrest Rate per Second 계산하여 반환
    /// @dev 가동률 = debt / (debt + floating)
    /// @param debt 대출되어 나간돈
    /// @param floating 대기자금
    /// @return IR per 365days, denominator = 1e18
    function calcInterestRate(uint256 debt, uint256 floating)
        external
        pure
        override
        returns (uint256)
    {
        if (debt == 0 && floating == 0) return 0;

        uint256 total = debt + floating;
        uint256 utilization = (debt * (100 * DENOM)) / (total);

        // 구간별 이자율
        if (utilization < CEIL_SLOPE_1) {
            // utilization(0~60%) - 0%~20% APY
            return
                (utilization * MAX_INTEREST_SLOPE_1) / CEIL_SLOPE_1 / 365 days;
        } else if (utilization < CEIL_SLOPE_2) {
            // utilization(60%~90%) - 20% APY
            return uint256(MAX_INTEREST_SLOPE_2) / 365 days;
        } else if (utilization < CEIL_SLOPE_3) {
            // utilization(90%~100%) - 20%~150% APY
            return
                (MAX_INTEREST_SLOPE_2 +
                    ((utilization - CEIL_SLOPE_2) *
                        (MAX_INTEREST_SLOPE_3 - MAX_INTEREST_SLOPE_2)) /
                    (CEIL_SLOPE_3 - CEIL_SLOPE_2)) / 365 days;
        } else {
            // 그 외 모든 상황 - 150% APY
            // 사실상 이 조건으로 들어올 수 없음
            return MAX_INTEREST_SLOPE_3 / 365 days;
        }
    }
}
