pragma solidity >=0.8.0;

import "./BaseJumpRateModelV2.sol";
import "./InterestRateModel.sol";


/**
  * @title Compound's JumpRateModel Contract V2 for V2 cTokens
  * @author Arr00
  * @notice Supports only for V2 cTokens
  */
contract JumpRateModelV2 is InterestRateModel, BaseJumpRateModelV2  {

	/**
     * @notice Calculates the current borrow rate per block
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @return The borrow rate percentage per block as a mantissa (scaled by 1e18)
     */
    function getBorrowRate(uint cash, uint borrows, uint reserves) external override view returns (uint) {
        return getBorrowRateInternal(cash, borrows, reserves);
    }

    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external override(InterestRateModel, BaseJumpRateModelV2) virtual view returns (uint) {
        uint oneMinusReserveFactor = uint(1e18) - reserveFactorMantissa;
        uint borrowRate = getBorrowRateInternal(cash, borrows, reserves);
        uint rateToPool = borrowRate * oneMinusReserveFactor / 1e18;
        return utilizationRate(cash, borrows, reserves) * rateToPool / 1e18;
    }

    constructor(uint baseRatePerYear, uint multiplierPerYear, uint jumpMultiplierPerYear, uint kink_, address owner_) 
    	BaseJumpRateModelV2(baseRatePerYear,multiplierPerYear,jumpMultiplierPerYear,kink_,owner_) public {}
}
