pragma solidity >= 0.8.0;

interface IVeeLPFarm {
    event ClaimVee( address indexed user,uint256 indexed pid,uint256 veeReward ) ;
    event Deposit( address indexed payer,address indexed user,uint256 indexed pid,uint256 amount ) ;
    event EmergencyWithdraw( address indexed user,uint256 indexed pid,uint256 amount,uint256 unlockedAmount,uint256 lockingAmount ) ;
    event NewRewardsPerBlock( uint256 newRewardsPerBlock,uint256 oldRewardsPerBlock ) ;
    event NewVeeHub( address newVeeHub,address oldVeeHub ) ;
    event OwnershipTransferred( address indexed previousOwner,address indexed newOwner ) ;
    event Withdraw( address indexed user,uint256 indexed pid,uint256 amount ) ;
    function BONUS_MULTIPLIER(  ) external view returns (uint256 ) ;
    function add( uint256 _allocPoint,address _lpToken,bool _withUpdate ) external   ;
    function claimVee( address _account ) external   ;
    function deposit( uint256 _pid,uint256 _amount ) external   ;
    function depositBehalf( address _account,uint256 _pid,uint256 _amount ) external   ;
    function emergencyWithdraw( uint256 _pid ) external   ;
    function endBlock(  ) external view returns (uint256 ) ;
    function getPoolSize(  ) external view returns (uint256 ) ;
    function initialize( address _vee,uint256 _rewardsPerBlock,uint256 _startBlock,uint256 _endBlock ) external   ;
    function lpTokenTotal( address  ) external view returns (uint256 ) ;
    function owner(  ) external view returns (address ) ;
    function pendingRewards( uint256 _pid,address _user ) external view returns (uint256 ) ;
    function poolInfo( uint256  ) external view returns (address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accRewardsPerShare) ;
    function renounceOwnership(  ) external   ;
    function rewardsPerBlock(  ) external view returns (uint256 ) ;
    function set( uint256 _pid,uint256 _allocPoint,bool _withUpdate ) external   ;
    function setRewardsPerBlock( uint256 _rewardsPerBlock ) external   ;
    function setVeeHub( address _veeHub ) external   ;
    function startBlock(  ) external view returns (uint256 ) ;
    function totalAllocPoint(  ) external view returns (uint256 ) ;
    function transferOwnership( address newOwner ) external   ;
    function updateAllPools(  ) external   ;
    function updateMultiplier( uint256 multiplierNumber ) external   ;
    function userInfo( uint256 ,address  ) external view returns (uint256 amount, uint256 lockingAmount, uint256 unlockedAmount, uint256 rewardDebt, bool inBlackList) ;
    function vee(  ) external view returns (address ) ;
    function veeHub(  ) external view returns (address ) ;
    function withdraw( uint256 _pid,uint256 _amount ) external   ;
}