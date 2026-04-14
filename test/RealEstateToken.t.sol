// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/examples/RealEstateToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Mock payment token (USDC/DAI)
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1_000_000e6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RealEstateTokenTest is Test {
    RealEstateToken public token;
    MockUSDC public usdc;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    uint256 constant TOTAL_UNITS = 1000000e18; // 1M fractional tokens
    uint256 constant MAX_OWNERSHIP_BPS = 2000; // 20% max per wallet

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        usdc = new MockUSDC();

        RealEstateToken.PropertyMetadata memory metadata = RealEstateToken.PropertyMetadata({
            streetAddress: "123 Main St, New York, NY 10001",
            legalDescription: "Lot 42, Block 7, Manhattan",
            appraisalValue: 5_000_000e6,
            appraisalDate: block.timestamp,
            totalUnits: TOTAL_UNITS,
            documentURI: "ipfs://QmExampleHash"
        });

        token = new RealEstateToken(
            "Main Street Building",
            "MSB",
            TOTAL_UNITS,
            address(usdc),
            MAX_OWNERSHIP_BPS,
            metadata
        );
    }

    // -------------------------------------------------------------------------
    // Deployment tests
    // -------------------------------------------------------------------------
    function test_deployment() public {
        assertEq(token.name(), "Main Street Building");
        assertEq(token.symbol(), "MSB");
        assertEq(token.totalSupply(), TOTAL_UNITS);
        assertEq(token.balanceOf(owner), TOTAL_UNITS);
        assertEq(token.maxOwnershipBps(), MAX_OWNERSHIP_BPS);
    }

    function test_property_metadata() public {
        (
            string memory street,
            uint256 appraisal,
            uint256 appraisalDate,
            uint256 totalUnits,
            string memory docURI,
            address paymentTokenAddr,
            uint256 distCount
        ) = token.getPropertyInfo();

        assertEq(street, "123 Main St, New York, NY 10001");
        assertEq(appraisal, 5_000_000e6);
        assertEq(totalUnits, TOTAL_UNITS);
        assertEq(docURI, "ipfs://QmExampleHash");
        assertEq(paymentTokenAddr, address(usdc));
        assertEq(distCount, 0);
    }

    // -------------------------------------------------------------------------
    // Fractional ownership tests
    // -------------------------------------------------------------------------
    function test_fractional_transfer() public {
        uint256 amount = 100000e18; // 10% of property
        token.transfer(alice, amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.getOwnershipPercentage(alice), 1000); // 10% in bps
    }

    function test_max_ownership_cap_enforced() public {
        // Owner has 100% = 10000 bps, max is 2000 bps
        // Transfer 21% to alice should fail
        uint256 tooMuch = (TOTAL_UNITS * 2100) / 10000;

        // First transfer 10% (should succeed)
        token.transfer(alice, (TOTAL_UNITS * 1000) / 10000);
        assertEq(token.balanceOf(alice), (TOTAL_UNITS * 1000) / 10000);

        // Now alice has 10%. Transfer another 11% from owner to alice should fail
        vm.expectRevert();
        token.transfer(alice, (TOTAL_UNITS * 1100) / 10000);
    }

    function test_multiple_fractional_holders() public {
        uint256 tenPct = TOTAL_UNITS / 10;

        token.transfer(alice, tenPct);   // 10%
        token.transfer(bob, tenPct);      // 10%
        token.transfer(charlie, tenPct);  // 10%

        assertEq(token.getOwnershipPercentage(alice), 1000);
        assertEq(token.getOwnershipPercentage(bob), 1000);
        assertEq(token.getOwnershipPercentage(charlie), 1000);
        // Owner has 70%
        assertEq(token.getOwnershipPercentage(owner), 7000);
    }

    // -------------------------------------------------------------------------
    // Rental income distribution tests
    // -------------------------------------------------------------------------
    function test_deposit_rental_income() public {
        uint256 rentAmount = 10000e6; // $10,000

        // Distribute ownership
        token.transfer(alice, TOTAL_UNITS / 4); // 25%
        token.transfer(bob, TOTAL_UNITS / 4);   // 25%

        // Owner deposits rental income
        usdc.approve(address(token), rentAmount);
        token.depositRentalIncome(rentAmount);

        assertEq(token.claimableEarnings(alice), 2500e6); // 25% of $10k
        assertEq(token.claimableEarnings(bob), 2500e6);   // 25% of $10k
    }

    function test_claim_rental_income() public {
        uint256 rentAmount = 10000e6;

        token.transfer(alice, TOTAL_UNITS / 4);

        usdc.approve(address(token), rentAmount);
        token.depositRentalIncome(rentAmount);

        uint256 aliceBalBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        token.claimRentalIncome();
        uint256 aliceBalAfter = usdc.balanceOf(alice);

        assertEq(aliceBalAfter - aliceBalBefore, 2500e6);
    }

    function test_multiple_distributions() public {
        token.transfer(alice, TOTAL_UNITS / 2); // 50%

        // First distribution
        usdc.approve(address(token), 6000e6);
        token.depositRentalIncome(6000e6);

        // Second distribution
        token.depositRentalIncome(4000e6);

        // Alice should be able to claim both: 50% of 6000 + 50% of 4000 = 5000
        assertEq(token.claimableEarnings(alice), 5000e6);

        vm.prank(alice);
        token.claimRentalIncome();

        assertEq(usdc.balanceOf(alice), 5000e6);
    }

    function test_cannot_claim_twice() public {
        token.transfer(alice, TOTAL_UNITS / 2);

        usdc.approve(address(token), 10000e6);
        token.depositRentalIncome(10000e6);

        vm.prank(alice);
        token.claimRentalIncome();

        // Second claim should revert
        vm.prank(alice);
        vm.expectRevert();
        token.claimRentalIncome();
    }

    function test_zero_claim_reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        token.claimRentalIncome();
    }

    // -------------------------------------------------------------------------
    // Admin function tests
    // -------------------------------------------------------------------------
    function test_update_property_metadata() public {
        token.updatePropertyMetadata(
            "456 Oak Ave, Los Angeles, CA 90001",
            6_000_000e6,
            block.timestamp,
            "ipfs://QmNewHash"
        );

        (string memory street, uint256 appraisal,,,,,) = token.getPropertyInfo();
        assertEq(street, "456 Oak Ave, Los Angeles, CA 90001");
        assertEq(appraisal, 6_000_000e6);
    }

    function test_set_max_ownership() public {
        token.setMaxOwnershipBps(5000);
        assertEq(token.maxOwnershipBps(), 5000);
    }

    function test_non_owner_cannot_set_max() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setMaxOwnershipBps(9000);
    }

    // -------------------------------------------------------------------------
    // Pause tests
    // -------------------------------------------------------------------------
    function test_pause_blocks_transfers() public {
        token.pause();

        vm.expectRevert();
        token.transfer(alice, 100);
    }

    function test_unpause_restores_transfers() public {
        token.pause();
        token.unpause();
        token.transfer(alice, 1000);
        assertEq(token.balanceOf(alice), 1000);
    }

    // -------------------------------------------------------------------------
    // Edge cases
    // -------------------------------------------------------------------------
    function test_ownership_percentage_zero() public {
        assertEq(token.getOwnershipPercentage(alice), 0);
    }

    function test_deployment_rejects_zero_units() public {
        RealEstateToken.PropertyMetadata memory meta = RealEstateToken.PropertyMetadata({
            streetAddress: "",
            legalDescription: "",
            appraisalValue: 0,
            appraisalDate: 0,
            totalUnits: 0,
            documentURI: ""
        });

        vm.expectRevert();
        new RealEstateToken("X", "X", 0, address(usdc), 1000, meta);
    }

    function test_deployment_rejects_invalid_payment_token() public {
        RealEstateToken.PropertyMetadata memory meta = RealEstateToken.PropertyMetadata({
            streetAddress: "",
            legalDescription: "",
            appraisalValue: 0,
            appraisalDate: 0,
            totalUnits: 1000,
            documentURI: ""
        });

        vm.expectRevert();
        new RealEstateToken("X", "X", 1000, address(0), 1000, meta);
    }
}
