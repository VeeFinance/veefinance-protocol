// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
contract VestingValve is Initializable{
    using SafeERC20 for IERC20;
    using Math for uint256;
    IERC20 public vestingToken;
    address itemMamager;
    bool internal _notEntered;
    address admin;

    struct VestingSchedule {
        uint totalAmount;
        uint amountWithdrawn;
        uint startTimestamp;
        uint endTimestamp;
        uint genesisCash;
        uint accelerateFactor;
    }

    mapping(address => uint) public lockingBalances;
    mapping(address => uint) public unlockedBalances;
    mapping(address => uint) public lastWithdrawTime;
    mapping(address => VestingSchedule[]) public vestingSchedules;
    mapping(address => uint) public delayConfig;

    event NewVestingSchedule(address account, uint8 slot, uint startTimestamp, uint endTimestamp, uint totalAmount, uint genesisCash, uint accelerateFactor);
    // event UpdateSchedule(address account, uint8 slot, uint startTimestamp, uint endTimestamp, uint totalAmount, uint genesisCash, uint accelerateFactor);
    // event RevokeSchedule(address account, uint8 slot, uint amountUnlocked, uint amountLocking);
    event Withdraw(address account, uint totalWithdrawAmount, uint legacyUnlockedAmount);
    event Unlock(address account, uint8 slot, uint amountUnlocked, uint amountLocking);
    event Deposit(address indexed account,address payer ,uint amount);

    modifier nonReentrant() {
        require(_notEntered, "nonReentrant: Warning re-entered!");
        _notEntered = false;
        _;
        _notEntered = true;
    }

    function initialize(address _token) public initializer {
        vestingToken = IERC20(_token);
        admin = msg.sender;
        _notEntered = true;
    }
   
    function addSchedule(address account, uint8 slot, VestingSchedule memory _schedule) nonReentrant external {
        require(msg.sender == admin, "only admin");

        vestingToken.safeTransferFrom(msg.sender, address(this), _schedule.totalAmount);
        emit Deposit(account,msg.sender, _schedule.totalAmount);
        if (vestingSchedules[account].length <= slot) {
            vestingSchedules[account].push();
        }
        require(vestingSchedules[account][slot].totalAmount == 0, "slot used");
        _schedule.amountWithdrawn = 0;
        _schedule.accelerateFactor = 1e18;
        vestingSchedules[account][slot] = _schedule;
        // VestingSchedule memory vestingSchedule = _addSchedule(msg.sender, slot, amount, block.timestamp, block.timestamp + 90 days, 1e18);
        emit NewVestingSchedule(msg.sender, slot, _schedule.startTimestamp, _schedule.endTimestamp, _schedule.totalAmount, _schedule.genesisCash, _schedule.accelerateFactor);
    }
    
    function withdrawVestedTokens() nonReentrant external {
        uint cooldownTime = 60 minutes;
        if (delayConfig[msg.sender] > 0) {
            cooldownTime = delayConfig[msg.sender];
        }
        require(block.timestamp > lastWithdrawTime[msg.sender] + cooldownTime, "withdraw too frequent");
        VestingSchedule[] storage schedules = vestingSchedules[msg.sender];
        uint totalUnlocked = unlockedBalances[msg.sender];
        for (uint i = 0; i < schedules.length; i++) {
            uint totalAmountVested = estimateVested(schedules[i]);
            uint amountUnlocked = totalAmountVested - schedules[i].amountWithdrawn;
            schedules[i].amountWithdrawn = totalAmountVested;

            if (amountUnlocked > 0) {
                totalUnlocked += amountUnlocked;
                emit Unlock(msg.sender, uint8(i), amountUnlocked, schedules[i].totalAmount - totalAmountVested);
            }
        }
        require( vestingToken.transfer(msg.sender, totalUnlocked) );
        emit Withdraw(msg.sender, totalUnlocked, unlockedBalances[msg.sender]);
        unlockedBalances[msg.sender] = 0;
        lastWithdrawTime[msg.sender] = block.timestamp;
    }

    function estimateVested(VestingSchedule memory vestingSchedule) internal view returns(uint) {
        if (block.timestamp < vestingSchedule.startTimestamp) {
            return 0;
        }
        if (block.timestamp >= vestingSchedule.endTimestamp || vestingSchedule.endTimestamp == 0) {
            return vestingSchedule.totalAmount;
        }
        uint totalVestingTime = vestingSchedule.endTimestamp - vestingSchedule.startTimestamp;
        uint durationSinceStart = block.timestamp - vestingSchedule.startTimestamp;
        uint vestedAmount = vestingSchedule.genesisCash + vestingSchedule.totalAmount.min((vestingSchedule.totalAmount - vestingSchedule.genesisCash) * durationSinceStart / totalVestingTime * vestingSchedule.accelerateFactor / 1e18);
 
        return vestedAmount;
    }

    function estimateWithdrawable(address account) external view returns(uint) {
        VestingSchedule[] storage schedules = vestingSchedules[account];
        uint withdrawable = unlockedBalances[account];
        for (uint i = 0; i < schedules.length; i++) {
            uint totalAmountVested = estimateVested(schedules[i]);
            uint amountUnlocked = totalAmountVested - schedules[i].amountWithdrawn;

            if (amountUnlocked > 0) {
                withdrawable += amountUnlocked;
            }
        }
        return withdrawable;
    }

    function getScheduleSize(address account) external view returns(uint) {
        return vestingSchedules[account].length;
    }

    function addDelayConfig(address account, uint delay) external {
        require(msg.sender == admin, "only admin");
        require(delayConfig[account] == 0, "already set");
        require(delay > 60 minutes, "must greater than 60 minutes");
        delayConfig[account] = delay;
    }

    function withdrawBehalf(address account) nonReentrant external {
        uint cooldownTime = 60 minutes;
        if (delayConfig[account] > 0) {
            cooldownTime = delayConfig[account];
        }
        require(block.timestamp > lastWithdrawTime[account] + cooldownTime, "withdraw too frequent");
        VestingSchedule[] storage schedules = vestingSchedules[account];
        uint totalUnlocked = unlockedBalances[account];
        for (uint i = 0; i < schedules.length; i++) {
            uint totalAmountVested = estimateVested(schedules[i]);
            uint amountUnlocked = totalAmountVested - schedules[i].amountWithdrawn;
            schedules[i].amountWithdrawn = totalAmountVested;

            if (amountUnlocked > 0) {
                totalUnlocked += amountUnlocked;
                emit Unlock(account, uint8(i), amountUnlocked, schedules[i].totalAmount - totalAmountVested);
            }
        }
        require( vestingToken.transfer(account, totalUnlocked) );
        emit Withdraw(account, totalUnlocked, unlockedBalances[account]);
        unlockedBalances[account] = 0;
        lastWithdrawTime[account] = block.timestamp;
    }
}