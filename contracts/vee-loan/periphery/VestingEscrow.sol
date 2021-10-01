// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
contract VestingEscrow is Initializable, OwnableUpgradeable{
    using SafeERC20 for IERC20;
    using Math for uint256;
    IERC20 public vestingToken;
    address itemMamager;
    bool internal _notEntered;

    struct VestingSchedule {
        uint totalAmount;               // Total amount of tokens to be vested.
        uint amountWithdrawn;           // The amount that has been withdrawn.
        uint startTimestamp;            // Timestamp of when vesting begins.
        uint endTimestamp;              // Timestamp of when vesting ends and tokens are completely available.
        address depositor;              // Address of the depositor of the tokens to be vested. (Crowdsale contract)
        uint accelerateFactor;          // accelerate factor 
    }

    mapping(address => uint) public lockingBalances;
    mapping(address => uint) public unlockedBalances;
    mapping(address => uint) public lastWithdrawTime;
    mapping(address => VestingSchedule[]) public vestingSchedules;

    event NewVestingSchedule(address account, uint8 slot, uint startTimestamp, uint endTimestamp, uint totalAmount, address depositor, uint accelerateFactor);
    event UpdateSchedule(address account, uint8 slot, uint startTimestamp, uint endTimestamp, uint totalAmount, address depositor, uint accelerateFactor);
    event CompleteSchedule(address account, uint8 slot, uint startTimestamp, uint endTimestamp, uint totalAmount);
    event RevokeSchedule(address account, uint8 slot, uint amountUnlocked, uint amountLocking);
    event Withdraw(address account, uint totalWithdrawAmount, uint legacyUnlockedAmount);
    event Unlock(address account, uint8 slot, uint amountUnlocked, uint amountLocking);
    event Deposit(address indexed account,address payer ,uint amount,uint total);

    modifier nonReentrant() {
        require(_notEntered, "re-entered!");
        _notEntered = false;
        _;
        _notEntered = true;
    }

    function initialize(address _token) public initializer {
        vestingToken = IERC20(_token);
        _notEntered = true;
        __Ownable_init();
    }
   
    function deposit(address account, uint amount) nonReentrant external {
        vestingToken.safeTransferFrom(msg.sender, address(this), amount);
        lockingBalances[account] += amount;
        emit Deposit(account,msg.sender, amount, lockingBalances[account]);
    }

    function addSchedule(uint8 slot, uint amount) nonReentrant external {
        require(lockingBalances[msg.sender] >= amount, "insufficient amount");
        VestingSchedule memory vestingSchedule = _addSchedule(msg.sender, slot, amount, block.timestamp, block.timestamp + 90 days, 1e18);
        emit NewVestingSchedule(msg.sender, slot, vestingSchedule.startTimestamp, vestingSchedule.endTimestamp, vestingSchedule.totalAmount, msg.sender, vestingSchedule.accelerateFactor);
    }

    function _addSchedule(address account, uint8 slot, uint amount, uint startTimestamp, uint endTimestamp, uint accelerateFactor) internal returns(VestingSchedule memory) {
        if (vestingSchedules[account].length < 1) { //create 1 slots for users
            vestingSchedules[account].push();
        }
        require(vestingSchedules[account][slot].totalAmount == 0, "slot used");
        vestingSchedules[account][slot] = VestingSchedule(amount, 0, startTimestamp, endTimestamp, account, accelerateFactor);
        lockingBalances[account] -= amount;
        return vestingSchedules[account][slot];
    }

    function getScheduleSize(address account) external view returns(uint8) {
        return uint8(vestingSchedules[account].length);
    }

    function revokeSchedule(uint8 slot) nonReentrant external {
        require(vestingSchedules[msg.sender][slot].totalAmount > 0,"slot empty");
        (uint amountUnlocked, uint amountLocking) = _revokeSchedule(msg.sender, slot);
        emit RevokeSchedule(msg.sender, slot, amountUnlocked, amountLocking);
    }

    function _revokeSchedule(address account, uint8 slot) internal returns(uint, uint) {
        VestingSchedule storage vestingSchedule = vestingSchedules[account][slot];
        uint amountUnlocked;
        uint amountLocking;

        uint totalAmountVested = estimateVested(vestingSchedule);
        amountUnlocked = totalAmountVested - vestingSchedule.amountWithdrawn;
        amountLocking = vestingSchedule.totalAmount - totalAmountVested;
        delete vestingSchedules[account][slot];
        unlockedBalances[account] += amountUnlocked;
        lockingBalances[account] += amountLocking;
        emit Unlock(account, slot, amountUnlocked, amountLocking);
        return (amountUnlocked, amountLocking);
    }
    
    function withdrawVestedTokens() nonReentrant external {
        require(block.timestamp > lastWithdrawTime[msg.sender] + 3600, "withdraw too frequent");
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
            if (totalAmountVested == schedules[i].totalAmount) {
                emit CompleteSchedule(msg.sender, uint8(i), schedules[i].startTimestamp, schedules[i].endTimestamp, schedules[i].totalAmount);
                delete vestingSchedules[msg.sender][uint8(i)];
            }
        }
        vestingToken.safeTransfer(msg.sender, totalUnlocked);
        emit Withdraw(msg.sender, totalUnlocked, unlockedBalances[msg.sender]);
        unlockedBalances[msg.sender] = 0;
        lastWithdrawTime[msg.sender] = block.timestamp;
    }

    function estimateVested(VestingSchedule memory vestingSchedule) internal view returns(uint) {
        if (block.timestamp >= vestingSchedule.endTimestamp || vestingSchedule.endTimestamp == 0) {
            return vestingSchedule.totalAmount;
        }
        uint totalVestingTime = vestingSchedule.endTimestamp - vestingSchedule.startTimestamp;
        uint durationSinceStart = block.timestamp - vestingSchedule.startTimestamp;
        uint vestedAmount = vestingSchedule.totalAmount.min(vestingSchedule.totalAmount * durationSinceStart / totalVestingTime * vestingSchedule.accelerateFactor / 1e18);
 
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


    function useItem(address account, uint8 slot, uint itemId) external {
        /*
        require(ItemManager(itemMamager).itemExists(account, itemId), "item not exist");
        consumption = ItemManager(itemMamager).useItem()

        */
        uint accelerateFactor = 2e18;

        VestingSchedule storage vestingSchedule = vestingSchedules[account][slot];
        require(vestingSchedule.totalAmount > 0, "schedule empty");
        require(vestingSchedule.accelerateFactor < accelerateFactor, "accelerateFactor invalid");
        uint endTimestamp = vestingSchedule.endTimestamp;
        (, uint amountLocking) = _revokeSchedule(account, slot);
        VestingSchedule memory vestingScheduleNew = _addSchedule(account, slot, amountLocking, block.timestamp, endTimestamp, accelerateFactor);
        emit UpdateSchedule(account, slot, vestingScheduleNew.startTimestamp, vestingScheduleNew.endTimestamp, vestingScheduleNew.totalAmount, msg.sender, vestingScheduleNew.accelerateFactor);
    }
}