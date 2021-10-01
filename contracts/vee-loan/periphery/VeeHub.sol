// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IVeeERC20.sol";
import "./interface/IPangolinRouter.sol";
import "./interface/IPangolinFactory.sol";
import "./interface/IVeeLPFarm.sol";
import "./interface/IVestingEscrow.sol";
import "./library/PangolinLibrary.sol";
import "./library/TransferHelper.sol";

contract VeeHub is Initializable, OwnableUpgradeable{
    using SafeERC20 for IERC20;

    address public vee;
    address public dexRouter;
    address public farmPool;
    address public vestingPool;
    mapping(address => uint) public veeBalances;
    mapping(address => mapping(address => uint)) public lpBalances;
    mapping(address => bool) public tokenWhitelist;
    uint public lockingRate;
    bool internal _notEntered;

    event Deposit(address indexed payer, address indexed user, uint amount);
    event DepositLPToken(address indexed payer, address indexed user, address indexed lpToken, uint amount);
    event SwapTokensForLP(address tokenA, address tokenB, uint amountA, uint amountB, address LPToken, uint liquidity);
    event SwapLPForTokens(address LPToken, uint liquidity, address tokenA, address tokenB, uint amountA, uint amountB);
    event TokenWhitelistChange(address token, bool isWhite, bool oldStatus);
    event EnterUnlocking(address account, uint amount, uint remainBalance);

    modifier nonReentrant() {
        require(_notEntered, "re-entered!");
        _notEntered = false;
        _;
        _notEntered = true;
    }
    function initialize(address _vee, address _dexRouter, address _farmPool, address _vestingPool, address[] memory _tokenWhitelist) public initializer{
        vee = _vee;
        dexRouter = _dexRouter;
        farmPool = _farmPool;
        vestingPool = _vestingPool;
        lockingRate = 0.9e18;
        for(uint8 i = 0; i < _tokenWhitelist.length; i++) {
            tokenWhitelist[_tokenWhitelist[i]] = true;
            emit TokenWhitelistChange(_tokenWhitelist[i], true, false);
        }
        __Ownable_init();
    }

    receive() external payable {}
    fallback() external payable {}

    function deposit(address account, uint amount) external {
        IERC20(vee).safeTransferFrom(msg.sender, address(this), amount);
        veeBalances[account] += amount;
        emit Deposit(msg.sender, account, amount);
    }

    function depositLPToken(address account, address lpToken, uint amount) external {
        require(lpToken != address(0), "invalid lpToken");
        IERC20(lpToken).safeTransferFrom(msg.sender, address(this), amount);
        lpBalances[account][lpToken] += amount;
        emit DepositLPToken(msg.sender, account, lpToken, amount);
    }

    function addLiquidity(address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin) external returns(uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB, liquidity) = _addLiquidity(tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
    }

    function _addLiquidity(address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin) internal returns(uint amountA, uint amountB, uint liquidity) {
        require(tokenWhitelist[tokenB], "tokenB not allowed");
        require(amountADesired <= veeBalances[msg.sender], "vee insufficient");
        TransferHelper.safeTransferFrom(tokenB, msg.sender, address(this), amountBDesired);
        TransferHelper.safeApprove(vee, dexRouter, amountADesired);
        TransferHelper.safeApprove(tokenB, dexRouter, amountBDesired);

        (amountA, amountB, liquidity) = IPangolinRouter(dexRouter).addLiquidity(vee, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, address(this), block.timestamp + 1000);

        address factory = IPangolinRouter(dexRouter).factory();
        address pairAddress = IPangolinFactory(factory).getPair(vee, tokenB);
        uint chargeB = amountBDesired - amountB;
        if (chargeB > 0) {
            TransferHelper.safeTransfer(tokenB, msg.sender, chargeB);
        }
        veeBalances[msg.sender] -= amountA;
        lpBalances[msg.sender][pairAddress] += liquidity;

        emit SwapTokensForLP(vee, tokenB, amountA, amountB, pairAddress, liquidity);
    }

    function addLiquidityAVAX(uint amountADesired, uint amountAMin, uint amountAVAXMin) external payable returns(uint amountA, uint amountAVAX, uint liquidity) {
        (amountA, amountAVAX, liquidity) = _addLiquidityAVAX(amountADesired, amountAMin, amountAVAXMin);
    }

    function _addLiquidityAVAX(uint amountADesired, uint amountAMin, uint amountAVAXMin) internal returns(uint amountA, uint amountAVAX, uint liquidity) {
        require(amountADesired <= veeBalances[msg.sender], "vee insufficient");
        TransferHelper.safeApprove(vee, dexRouter, amountADesired);

        (amountA, amountAVAX, liquidity) = IPangolinRouter(dexRouter).addLiquidityAVAX{value:msg.value}(vee, amountADesired, amountAMin, amountAVAXMin, address(this), block.timestamp + 1000);

        address factory = IPangolinRouter(dexRouter).factory();
        address WAVAX = IPangolinRouter(dexRouter).WAVAX();
        address pairAddress = IPangolinFactory(factory).getPair(vee, WAVAX);

        veeBalances[msg.sender] -= amountA;
        lpBalances[msg.sender][pairAddress] += liquidity;
        if (msg.value > amountAVAX) {
            TransferHelper.safeTransferAVAX(payable(msg.sender), msg.value - amountAVAX);
        }
        emit SwapTokensForLP(vee, WAVAX, amountA, amountAVAX, pairAddress, liquidity);
    }

    function removeLiquidity(address tokenB, uint liquidity, uint amountAMin, uint amountBMin) external returns(uint amountA, uint amountB) {
        address factory = IPangolinRouter(dexRouter).factory();
        address pairAddress = IPangolinFactory(factory).getPair(vee, tokenB);
        require(lpBalances[msg.sender][pairAddress] >= liquidity, "lpToken insufficient");
        lpBalances[msg.sender][pairAddress] -= liquidity;
        TransferHelper.safeApprove(pairAddress, dexRouter, liquidity);
        (amountA, amountB) = IPangolinRouter(dexRouter).removeLiquidity(vee, tokenB, liquidity, amountAMin, amountBMin, address(this), block.timestamp + 1000);
        veeBalances[msg.sender] += amountA;
        TransferHelper.safeTransfer(tokenB, msg.sender, amountB);

        emit SwapLPForTokens(pairAddress, liquidity, vee, tokenB, amountA, amountB);
    }

    function removeLiquidityAVAX(uint liquidity, uint amountAMin, uint amountAVAXMin) external returns(uint amountA, uint amountAVAX) {
        address WAVAX = IPangolinRouter(dexRouter).WAVAX();
        address factory = IPangolinRouter(dexRouter).factory();
        address pairAddress = IPangolinFactory(factory).getPair(vee, WAVAX);
        require(lpBalances[msg.sender][pairAddress] >= liquidity, "lpToken insufficient");
        lpBalances[msg.sender][pairAddress] -= liquidity;
        TransferHelper.safeApprove(pairAddress, dexRouter, liquidity);
        (amountA, amountAVAX) = IPangolinRouter(dexRouter).removeLiquidityAVAX(vee, liquidity, amountAMin, amountAVAXMin, address(this), block.timestamp + 1000);
        veeBalances[msg.sender] += amountA;
        TransferHelper.safeTransferAVAX(payable(msg.sender), amountAVAX);

        emit SwapLPForTokens(pairAddress, liquidity, vee, WAVAX, amountA, amountAVAX);
    }

    function enterFarm(uint pid, uint amount) external {
        _enterFarm(pid, amount);
    }

    function _enterFarm(uint pid, uint amount) internal {
        IVeeLPFarm pool = IVeeLPFarm(farmPool);
        (address lpToken,,,) = pool.poolInfo(pid);
        require(lpBalances[msg.sender][lpToken] >= amount, "lpToken insufficient");
        lpBalances[msg.sender][lpToken] -= amount;
        TransferHelper.safeApprove(lpToken, farmPool, amount);
        pool.depositBehalf(msg.sender, pid, amount);
    }

    function enterUnlocking(uint amount) external {
        require(veeBalances[msg.sender] >= amount, "vee insufficient");
        uint lockingAmount = amount * lockingRate / 1e18;
        uint withdrawAmount = amount - lockingAmount;
        veeBalances[msg.sender] -= amount;
        if (withdrawAmount > 0) {
            TransferHelper.safeTransfer(vee, msg.sender, withdrawAmount);
        }
        TransferHelper.safeApprove(vee, vestingPool, lockingAmount);
        IVestingEscrow(vestingPool).deposit(msg.sender, lockingAmount);
        emit EnterUnlocking(msg.sender, amount, veeBalances[msg.sender]);
    }

    function addLiquidityFarm(address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, uint pid) external {
        (, , uint liquidity) = _addLiquidity(tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        _enterFarm(pid, liquidity);
    }

    function addLiquidityAVAXFarm(uint amountADesired, uint amountAMin, uint amountAVAXMin, uint pid) external payable {
        (, , uint liquidity) = _addLiquidityAVAX(amountADesired, amountAMin, amountAVAXMin);
        _enterFarm(pid, liquidity);
    }
    
    function setTokenWhitelist(address token, bool isWhite) external onlyOwner {
        require(tokenWhitelist[token] != isWhite, "not change");

        bool oldStatus = tokenWhitelist[token];
        tokenWhitelist[token] = isWhite;
        emit TokenWhitelistChange(token, isWhite, oldStatus);
    }

}