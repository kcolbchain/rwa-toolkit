// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/examples/RealEstateToken.sol";

/// @title DeployRealEstateToken
/// @notice Deployment script for RealEstateToken with property metadata
/// @dev Run with: forge script script/DeployRealEstateToken.s.sol --rpc-url $RPC_URL --broadcast
contract DeployRealEstateToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address paymentToken = vm.envAddress("PAYMENT_TOKEN"); // USDC or DAI address

        vm.startBroadcast(deployerPrivateKey);

        RealEstateToken.PropertyMetadata memory metadata = RealEstateToken.PropertyMetadata({
            streetAddress: "123 Main St, New York, NY 10001",
            legalDescription: "Lot 42, Block 7, Manhattan",
            appraisalValue: 5_000_000e6,
            appraisalDate: block.timestamp,
            totalUnits: 1_000_000e18,
            documentURI: "ipfs://QmReplaceWithActualCID"
        });

        RealEstateToken token = new RealEstateToken(
            "Main Street Building",     // name
            "MSB",                       // symbol
            1_000_000e18,                // total fractional units
            paymentToken,                // USDC/DAI for rental payments
            2000,                        // 20% max ownership per wallet
            metadata
        );

        console.log("RealEstateToken deployed at:", address(token));

        vm.stopBroadcast();
    }
}
