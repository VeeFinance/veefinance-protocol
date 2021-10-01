pragma solidity >=0.8.0;

interface IVestingEscrow {
    event Deposit( address indexed account,address payer,uint256 amount,uint256 total ) ;
    event NewVestingSchedule( address account,uint8 slot,uint256 startTimestamp,uint256 endTimestamp,uint256 totalAmount,address depositor,uint256 accelerateFactor ) ;
    event OwnershipTransferred( address indexed previousOwner,address indexed newOwner ) ;
    event RevokeSchedule( address account,uint8 slot,uint256 amountUnlocked,uint256 amountLocking ) ;
    event Unlock( address account,uint8 slot,uint256 amountUnlocked,uint256 amountLocking ) ;
    event UpdateSchedule( address account,uint8 slot,uint256 startTimestamp,uint256 endTimestamp,uint256 totalAmount,address depositor,uint256 accelerateFactor ) ;
    event Withdraw( address account,uint256 totalWithdrawAmount,uint256 legacyUnlockedAmount ) ;
    function addSchedule( uint8 slot,uint256 amount ) external   ;
    function deposit( address account,uint256 amount ) external   ;
    function estimateWithdrawable( address account ) external view returns (uint256 ) ;
    function initialize( address _token ) external   ;
    function lastWithdrawTime( address  ) external view returns (uint256 ) ;
    function lockingBalances( address  ) external view returns (uint256 ) ;
    function owner(  ) external view returns (address ) ;
    function renounceOwnership(  ) external   ;
    function revokeSchedule( uint8 slot ) external   ;
    function transferOwnership( address newOwner ) external   ;
    function unlockedBalances( address  ) external view returns (uint256 ) ;
    function useItem( address account,uint8 slot,uint256 itemId ) external   ;
    function vestingSchedules( address ,uint256  ) external view returns (uint256 totalAmount, uint256 amountWithdrawn, uint256 startTimestamp, uint256 endTimestamp, address depositor, uint256 accelerateFactor) ;
    function vestingToken(  ) external view returns (address ) ;
    function withdrawVestedTokens(  ) external   ;
}
