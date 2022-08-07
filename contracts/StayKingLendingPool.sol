// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


/*
    @dev 1) deposit : 렌딩 풀에 돈을 맡긴 사용자에게 돈을 맡기면 ibToken 을 1:1 로 지갑으로 전송함
            (ibToken 은 Daily 로 이자를 계산하여 유저 지갑에 지속적으로 이자를 지급하기 위한 매개체)
         2) withdraw : 유저 출금 시 ibToken 을 전송한 만큼 1:1 비율로 Evmos Coin 을 바로 지급함
            (Unbonding 기간 없이... Pool 에서 바로 지급)
         3) loan : Leveraged Staking 시 해당 Pool 에서 자금을 Leveraged Staking 을 실행한 유저에게
            Atom 코인 시세에 맞춰 Evmos 로 Borrow 함
            (이 때 유저 지갑에 전송하는 개념이 아닌 StakingLeveragedPool 에는 유저의 Supply 자금과 x2, x3 레버리지하여
             빌린 금액만큼의 Evmos 를 토대로 Auto Compounding 하면 됨
*/
contract StayKingLendingPool is Ownable, Pausable {
    using SafeMath for uint256;

    uint256 public constant MAX_INTEREST_RATIO = 3000; // 30% APY 이자 MAX 값

    uint256 public interestRatio = 1000; // 10% // 10% APY 이자 초기 값

    IERC20 public ibToken; // ibToken
    uint256 public totalShares; // 총 지분
    address payable vault; // Vault 주소

    struct UserInfo {
        uint256 shares; // number of shares for a user
        uint256 lastDepositedTime; // keeps track of deposited time for potential penalty
        uint256 evmosAtLastUserAction; // keeps track of evmos deposited at the last user action
        uint256 lastUserActionTime; // keeps track of the last user action time
    }

    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed sender, uint256 amount, uint256 shares, uint256 lastDepositedTime);
    event Withdraw(address indexed sender, uint256 amount, uint256 shares);

    /**
     * @notice Checks if the msg.sender is a contract or a proxy
     */
    modifier notContract() {
        require(!_isContract(msg.sender), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    constructor(
        IERC20 _ibToken,
        address _vault
    ) public {
        ibToken = _ibToken;
        vault = payable(_vault);
    }

    /*
        @dev 유저 입금 시 지분 계산 후 UserInfo state 에 기록
    */
    function deposit() external payable whenNotPaused notContract {
        require(msg.value > 0, "Nothing to deposit");

        uint256 depositedAmount = msg.value;
        uint256 pool = balanceOf();
        uint256 currentShares = 0;

        if (totalShares != 0) {
            currentShares = (depositedAmount.mul(totalShares)).div(pool);
        } else {
            currentShares = depositedAmount;
        }
        UserInfo storage user = userInfo[msg.sender];

        user.shares = user.shares.add(currentShares);
        user.lastDepositedTime = block.timestamp;

        totalShares = totalShares.add(currentShares);

        user.evmosAtLastUserAction = user.shares.mul(pool).div(totalShares);
        user.lastUserActionTime = block.timestamp;

        ibToken.transfer(msg.sender, depositedAmount);

        emit Deposit(msg.sender, depositedAmount, currentShares, block.timestamp);
    }

    // evmos balance Of this contract
    function balanceOf() public view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() external whenNotPaused notContract {

    }

    function loan() external whenNotPaused notContract {

    }

    //
    function _calculateDepositWithInterestBeforeWithdraw() internal {}


    /**
     * @notice Checks if address is a contract
     * @dev It prevents contract from being targeted
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
