// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./interface/ComptrollerInterfaceLite.sol";
import "./CTokenInterfaces.sol";
import "./ExponentialNoError.sol";
contract VeeHelper is ExponentialNoError {
    address public comptroller;
    struct VeeMarketState {
        uint224 index;
        uint32 block;
    }
    constructor(address _comptroller) {
        comptroller = _comptroller;
    }

    function updateVeeSupplyIndex(address cToken) internal view returns(VeeMarketState memory){
        ComptrollerInterfaceLite comptrollerI = ComptrollerInterfaceLite(comptroller);
        // VeeMarketState storage supplyState = veeSupplyState[cToken];
        (uint224 indexSS, uint32 blockSS) = comptrollerI.veeSupplyState(cToken);
        VeeMarketState memory supplyState = VeeMarketState({
            index: indexSS,
            block: blockSS
        });
        uint supplySpeed = comptrollerI.veeSpeeds(cToken);
        uint blockNumber = block.number;
        
        if (blockNumber > supplyState.block && supplySpeed > 0) {
            uint deltaBlocks = sub_(blockNumber, uint(supplyState.block));
            uint supplyTokens = CTokenInterface(cToken).totalSupply();
            uint veeAccrued = mul_(deltaBlocks, supplySpeed);
            Double memory ratio = supplyTokens > 0 ? fraction(veeAccrued, supplyTokens) : Double({mantissa: 0});
            Double memory index = add_(Double({mantissa: supplyState.index}), ratio);
            // veeSupplyState[cToken] = VeeMarketState({
            //     index: safe224(index.mantissa, "new index exceeds 224 bits"),
            //     block: safe32(blockNumber, "block number exceeds 32 bits")
            // });
            return VeeMarketState({
                index: safe224(index.mantissa, "new index exceeds 224 bits"),
                block: safe32(blockNumber, "block number exceeds 32 bits")
            });
        } 

        return VeeMarketState({
            index: safe224(indexSS, "new index exceeds 224 bits"),
            block: safe32(blockNumber, "block number exceeds 32 bits")
        });
    }

    function distributeSupplierVee(VeeMarketState memory supplyState, address cToken, address supplier) internal view returns(uint) {
        ComptrollerInterfaceLite comptrollerI = ComptrollerInterfaceLite(comptroller);
        // VeeMarketState storage supplyState = veeSupplyState[cToken];
        Double memory supplyIndex = Double({mantissa: supplyState.index});
        Double memory supplierIndex = Double({mantissa: comptrollerI.veeSupplierIndex(cToken, supplier)});
        // veeSupplierIndex[cToken][supplier] = supplyIndex.mantissa;

        if (supplierIndex.mantissa == 0 && supplyIndex.mantissa > 0) {
            supplierIndex.mantissa = comptrollerI.veeInitialIndex();
        }
        if (supplyIndex.mantissa < supplierIndex.mantissa) {
            supplierIndex.mantissa = supplyIndex.mantissa;
        }
        Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
        uint supplierTokens = CTokenInterface(cToken).balanceOf(supplier);
        uint supplierDelta = mul_(supplierTokens, deltaIndex);
        uint supplierAccrued = add_(comptrollerI.veeAccrued(supplier), supplierDelta);
        return supplierAccrued;
        // veeAccrued[supplier] = supplierAccrued;
        // emit DistributedSupplierVee(CToken(cToken), supplier, supplierDelta, supplyIndex.mantissa);
    }

    function updateVeeBorrowIndex(address cToken, Exp memory marketBorrowIndex) internal view returns(VeeMarketState memory) {
        ComptrollerInterfaceLite comptrollerI = ComptrollerInterfaceLite(comptroller);
        (uint224 indexBS, uint32 blockBS) = comptrollerI.veeBorrowState(cToken);
        VeeMarketState memory borrowState = VeeMarketState({
            index: indexBS,
            block: blockBS
        });
        uint borrowSpeed = comptrollerI.veeSpeeds(cToken);
        uint blockNumber = block.number;
        if (blockNumber > borrowState.block && borrowSpeed > 0) {
            uint deltaBlocks = sub_(blockNumber, uint(borrowState.block));
            uint borrowAmount = div_(CTokenInterface(cToken).totalBorrows(), marketBorrowIndex);
            uint veeAccrued = mul_(deltaBlocks, borrowSpeed);
            Double memory ratio = borrowAmount > 0 ? fraction(veeAccrued, borrowAmount) : Double({mantissa: 0});
            Double memory index = add_(Double({mantissa: borrowState.index}), ratio);
            // veeBorrowState[cToken] = VeeMarketState({
            //     index: safe224(index.mantissa, "new index exceeds 224 bits"),
            //     block: safe32(blockNumber, "block number exceeds 32 bits")
            // });
            return VeeMarketState({
                index: safe224(index.mantissa, "new index exceeds 224 bits"),
                block: safe32(blockNumber, "block number exceeds 32 bits")
            });
        } 

	return VeeMarketState({
	    index: safe224(indexBS, "new index exceeds 224 bits"),
	    block: safe32(blockNumber, "block number exceeds 32 bits")
	});
    }

    function distributeBorrowerVee(VeeMarketState memory borrowState, address cToken, address borrower, Exp memory marketBorrowIndex) internal view returns(uint) {
        ComptrollerInterfaceLite comptrollerI = ComptrollerInterfaceLite(comptroller);
        // VeeMarketState storage borrowState = veeBorrowState[cToken];
        Double memory borrowIndex = Double({mantissa: borrowState.index});
        Double memory borrowerIndex = Double({mantissa: comptrollerI.veeBorrowerIndex(cToken, borrower)});
        // veeBorrowerIndex[cToken][borrower] = borrowIndex.mantissa;

        if (borrowerIndex.mantissa > 0) {
             if (borrowIndex.mantissa < borrowerIndex.mantissa) {
                borrowerIndex.mantissa = borrowIndex.mantissa;
            }
            Double memory deltaIndex = sub_(borrowIndex, borrowerIndex);
            uint borrowerAmount = div_(CTokenInterface(cToken).borrowBalanceStored(borrower), marketBorrowIndex);
            uint borrowerDelta = mul_(borrowerAmount, deltaIndex);
            uint borrowerAccrued = add_(comptrollerI.veeAccrued(borrower), borrowerDelta);
            return borrowerAccrued;
            // veeAccrued[borrower] = borrowerAccrued;
            // emit DistributedBorrowerVee(CToken(cToken), borrower, borrowerDelta, borrowIndex.mantissa);
        }
        return 0;
    }

    function miningBalance(address holder, bool borrowers, bool suppliers) public view returns(uint, uint){
        ComptrollerInterfaceLite comptrollerI = ComptrollerInterfaceLite(comptroller);
        address[] memory cTokens = comptrollerI.getAssetsIn(holder);
        uint veeAccrued;
        for (uint i = 0; i < cTokens.length; i++) {
            // address cToken = cTokens[i];
            (bool isListed,,) = comptrollerI.markets(cTokens[i]);
            // require(isListed, "market must be listed");
            if (!isListed) {
                continue;
            }
            if (borrowers) {
                Exp memory borrowIndex = Exp({mantissa: CTokenInterface(cTokens[i]).borrowIndex()});
                VeeMarketState memory borrowState = updateVeeBorrowIndex(cTokens[i], borrowIndex);
                uint rewards = distributeBorrowerVee(borrowState, cTokens[i], holder, borrowIndex);
                veeAccrued = add_(veeAccrued, rewards);
                // veeAccrued[holder] = grantVeeInternal(holder, veeAccrued[holder]);
            }
            if (suppliers) {
                VeeMarketState memory sypplyState = updateVeeSupplyIndex(cTokens[i]);
                uint rewards = distributeSupplierVee(sypplyState, cTokens[i], holder);
                veeAccrued = add_(veeAccrued, rewards);
                // veeAccrued[holder] = grantVeeInternal(holder, veeAccrued[holder]);
            }
        }
        return (veeAccrued, block.number);
    }
}

