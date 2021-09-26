pragma solidity >= 0.8.0;

interface IVeeHub {
    event Deposit( address indexed payer,address indexed user,uint256 amount ) ;
    event DepositLPToken( address indexed payer,address indexed user,address indexed lpToken,uint256 amount ) ;
    event EnterUnlocking( address account,uint256 amount,uint256 remainBalance ) ;
    event OwnershipTransferred( address indexed previousOwner,address indexed newOwner ) ;
    event SwapLPForTokens( address LPToken,uint256 liquidity,address tokenA,address tokenB,uint256 amountA,uint256 amountB ) ;
    event SwapTokensForLP( address tokenA,address tokenB,uint256 amountA,uint256 amountB,address LPToken,uint256 liquidity ) ;
    event TokenWhitelistChange( address token,bool isWhite,bool oldStatus ) ;
    function addLiquidity( address tokenB,uint256 amountADesired,uint256 amountBDesired,uint256 amountAMin,uint256 amountBMin ) external  returns (uint256 amountA, uint256 amountB, uint256 liquidity) ;
    function addLiquidityAVAX( uint256 amountADesired,uint256 amountAMin,uint256 amountAVAXMin ) external payable returns (uint256 amountA, uint256 amountAVAX, uint256 liquidity) ;
    function addLiquidityAVAXFarm( uint256 amountADesired,uint256 amountAMin,uint256 amountAVAXMin,uint256 pid ) external payable  ;
    function addLiquidityFarm( address tokenB,uint256 amountADesired,uint256 amountBDesired,uint256 amountAMin,uint256 amountBMin,uint256 pid ) external   ;
    function deposit( address account,uint256 amount ) external   ;
    function depositLPToken( address account,address lpToken,uint256 amount ) external   ;
    function dexRouter(  ) external view returns (address ) ;
    function enterFarm( uint256 pid,uint256 amount ) external   ;
    function enterUnlocking( uint256 amount ) external   ;
    function farmPool(  ) external view returns (address ) ;
    function initialize( address _vee,address _dexRouter,address _farmPool,address _vestingPool,address[] memory _tokenWhitelist ) external   ;
    function lockingRate(  ) external view returns (uint256 ) ;
    function lpBalances( address ,address  ) external view returns (uint256 ) ;
    function owner(  ) external view returns (address ) ;
    function removeLiquidity( address tokenB,uint256 liquidity,uint256 amountAMin,uint256 amountBMin ) external  returns (uint256 amountA, uint256 amountB) ;
    function removeLiquidityAVAX( uint256 liquidity,uint256 amountAMin,uint256 amountAVAXMin ) external  returns (uint256 amountA, uint256 amountAVAX) ;
    function renounceOwnership(  ) external   ;
    function setTokenWhitelist( address token,bool isWhite ) external   ;
    function tokenWhitelist( address  ) external view returns (bool ) ;
    function transferOwnership( address newOwner ) external   ;
    function vee(  ) external view returns (address ) ;
    function veeBalances( address  ) external view returns (uint256 ) ;
    function vestingPool(  ) external view returns (address ) ;
}