pragma solidity >=0.8.0;
import "./Comptroller.sol";
import './CToken.sol';
contract EmergencyStop {
	event NewGuardian(address owner,address oldGuardian,address newGuardian);
	address public owner;
	address public guardian;
	constructor(address _owner,address _guardian){
		owner = _owner;
		guardian = _guardian;
	}

	function setGuardian(address newGuardian) external{
		require(msg.sender == owner,"only owner can call this function");
		address oldGuardian = guardian;
		guardian = newGuardian;
		emit NewGuardian(owner, oldGuardian, newGuardian);
	}
	function systemStop(address _unitroller,address _stableunitroller) external {
		require(msg.sender == guardian,"permission deny");
		Comptroller unitroller = Comptroller(_unitroller);
		Comptroller stableUintroller = Comptroller(_stableunitroller);
		
		CToken[] memory ctokens1 = unitroller.getAllMarkets();
		for(uint i = 0; i < ctokens1.length; i++){
			unitroller._setMintPaused(ctokens1[i],true);
			unitroller._setBorrowPaused(ctokens1[i],true);
		}
		CToken[] memory ctokens2 = stableUintroller.getAllMarkets();
		for(uint i = 0; i < ctokens2.length; i++){
			stableUintroller._setMintPaused(ctokens2[i],true);
			stableUintroller._setBorrowPaused(ctokens2[i],true);
		}
		unitroller._setTransferPaused(true);
		unitroller._setSeizePaused(true);
		stableUintroller._setTransferPaused(true);
		stableUintroller._setSeizePaused(true);
	}

}