// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;

import "./interfaces/IStayKingLendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StayKingLendingPool is IStayKingLendingPool {

    IERC20 public ibToken; // ibToken
    uint256 public totalShares;
    address payable vault;

    struct UserInfo {
        uint256 shares; // number of shares for a user
        uint256 lastDepositedTime; // keeps track of deposited time for potential penalty
        uint256 evmosAtLastUserAction; // keeps track of evmos deposited at the last user action
        uint256 lastUserActionTime; // keeps track of the last user action time
    }

    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed sender, uint256 amount, uint256 shares, uint256 lastDepositedTime);
    event Withdraw(address indexed sender, uint256 amount, uint256 shares);


    constructor(
        IERC20 _ibToken,
        address _vault
    ) {
        ibToken = _ibToken;
        vault = _vault;
    }

    function deposit() external payable whenNotPaused notContract {
        require(msg.value > 0, "Nothing to deposit");

        uint256 depositedToken = msg.value;
        uint256 pool = balanceOf();
        uint256 currentShares = 0;

        if (totalShares != 0) {
            currentShares = (depositedToken.mul(totalShares)).div(pool);
        } else {
            currentShares = amount;
        }
        UserInfo storage user = userInfo[msg.sender];

        user.shares = user.shares.add(currentShares);
        user.lastDepositedTime = block.timestamp;

        totalShares = totalShares.add(currentShares);

        user.evmosAtLastUserAction = user.shares.mul(pool).div(totalShares);
        user.lastUserActionTime = block.timestamp;

        emit Deposit(msg.sender, amount, currentShares, block.timestamp);
    }

    // evmos balance Of this contract
    function balanceOf() public view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() external whenNotPaused notContract {

    }

    function loan() external whenNotPaused notContract {

    }

    function _calculateInterest() internal {

    }
}
