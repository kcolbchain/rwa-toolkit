// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/JurisdictionCompliance.sol";

contract JurisdictionComplianceTest is Test {
    JurisdictionCompliance compliance;

    address owner = address(this);
    address investor1 = address(0x1);
    address investor2 = address(0x2);
    address investor3 = address(0x3);
    address investor4 = address(0x4);
    address unregistered = address(0x99);

    bytes32 US = keccak256("US");
    bytes32 EU = keccak256("EU");
    bytes32 UK = keccak256("UK");
    bytes32 SG = keccak256("SG");
    bytes32 JP = keccak256("JP");

    bytes32 ACCREDITED = "accredited";
    bytes32 RETAIL = "retail";
    bytes32 QUALIFIED = "qualified";

    // Local mirrors of the interface events for vm.expectEmit matching.
    event InvestorRegistered(address indexed investor, bytes32 jurisdiction, bytes32 category);
    event TransferAllowed(bytes32 indexed fromJurisdiction, bytes32 indexed toJurisdiction);
    event TransferBlocked(bytes32 indexed fromJurisdiction, bytes32 indexed toJurisdiction);

    function setUp() public {
        compliance = new JurisdictionCompliance(owner);

        // Register test investors
        compliance.registerInvestor(investor1, US, ACCREDITED);
        compliance.registerInvestor(investor2, EU, ACCREDITED);
        compliance.registerInvestor(investor3, JP, RETAIL);
        compliance.registerInvestor(investor4, US, RETAIL);
    }

    // --- Registration Tests ---

    function test_registerInvestor() public {
        (bytes32 jur, bytes32 cat, bool reg) = compliance.getInvestor(investor1);
        assertEq(jur, US);
        assertEq(cat, ACCREDITED);
        assertTrue(reg);
        assertEq(compliance.getInvestorCount(), 4);
    }

    function test_cannotRegisterZeroAddress() public {
        vm.expectRevert("Invalid address");
        compliance.registerInvestor(address(0), US, ACCREDITED);
    }

    function test_cannotRegisterWithEmptyJurisdiction() public {
        vm.expectRevert("Invalid jurisdiction");
        compliance.registerInvestor(address(0x10), bytes32(0), ACCREDITED);
    }

    function test_cannotRegisterTwice() public {
        vm.expectRevert("Already registered");
        compliance.registerInvestor(investor1, EU, RETAIL);
    }

    function test_updateInvestorJurisdiction() public {
        compliance.updateInvestor(investor1, UK, bytes32(0));
        (bytes32 jur,,) = compliance.getInvestor(investor1);
        assertEq(jur, UK);
    }

    function test_updateInvestorCategory() public {
        compliance.updateInvestor(investor1, bytes32(0), QUALIFIED);
        (, bytes32 cat,) = compliance.getInvestor(investor1);
        assertEq(cat, QUALIFIED);
    }

    function test_updateInvestorBoth() public {
        compliance.updateInvestor(investor1, EU, RETAIL);
        (bytes32 jur, bytes32 cat,) = compliance.getInvestor(investor1);
        assertEq(jur, EU);
        assertEq(cat, RETAIL);
    }

    function test_removeInvestor() public {
        compliance.removeInvestor(investor1);
        (, , bool reg) = compliance.getInvestor(investor1);
        assertFalse(reg);
        assertEq(compliance.getInvestorCount(), 3);
    }

    function test_cannotRemoveUnregistered() public {
        vm.expectRevert("Investor not registered");
        compliance.removeInvestor(unregistered);
    }

    // --- Same Jurisdiction Transfer Tests ---

    function test_sameJurisdictionAllowed() public {
        // Same jurisdiction (US) AND same category (accredited) must pass both
        // the jurisdiction and category checks. investor1 is US/accredited;
        // register a second US/accredited investor to transfer to.
        address usAccredited2 = address(0x8);
        compliance.registerInvestor(usAccredited2, US, ACCREDITED);
        bool ok = compliance.isTransferCompliant(investor1, usAccredited2);
        assertTrue(ok);
    }

    function test_sameJurisdictionBlockedWhenDefaultOff() public {
        compliance.setSameJurisdictionDefault(false);
        bool ok = compliance.isTransferCompliant(investor1, investor4);
        assertFalse(ok);
    }

    // --- Cross Jurisdiction Transfer Tests ---

    function test_usToEuAllowed() public {
        bool ok = compliance.isTransferCompliant(investor1, investor2);
        assertTrue(ok);
    }

    function test_euToUsAllowed() public {
        bool ok = compliance.isTransferCompliant(investor2, investor1);
        assertTrue(ok);
    }

    function test_usToUkAllowed() public {
        // Need to register a UK investor first
        address ukInvestor = address(0x5);
        compliance.registerInvestor(ukInvestor, UK, ACCREDITED);
        bool ok = compliance.isTransferCompliant(investor1, ukInvestor);
        assertTrue(ok);
    }

    function test_jpToUsBlocked() public {
        // JP is not in the default allowed list
        bool ok = compliance.isTransferCompliant(investor3, investor1);
        assertFalse(ok);
    }

    function test_jpToEuBlocked() public {
        bool ok = compliance.isTransferCompliant(investor3, investor2);
        assertFalse(ok);
    }

    function test_blockJurisdictionTransfer() public {
        // Block US->EU (previously allowed)
        compliance.setAllowedTransfer(US, EU, false);
        bool ok = compliance.isTransferCompliant(investor1, investor2);
        assertFalse(ok);
    }

    function test_allowNewJurisdictionTransfer() public {
        // JP->US is blocked by default. Register a JP/accredited investor so the
        // category check (accredited->accredited) passes and only the newly
        // allowed jurisdiction rule determines the outcome.
        address jpAccredited = address(0xA);
        compliance.registerInvestor(jpAccredited, JP, ACCREDITED);
        assertFalse(compliance.isTransferCompliant(jpAccredited, investor1));

        // Allow JP->US and confirm the transfer is now compliant.
        compliance.setAllowedTransfer(JP, US, true);
        bool ok = compliance.isTransferCompliant(jpAccredited, investor1);
        assertTrue(ok);
    }

    // --- Category Transfer Tests ---

    function test_accreditedToAccredited() public {
        bool ok = compliance.isTransferCompliant(investor1, investor2);
        assertTrue(ok); // Both accredited, US->EU allowed
    }

    function test_accreditedToRetailBlocked() public {
        // US accredited (inv1) -> US retail (inv4)
        // Same jurisdiction allowed, but category: accredited -> retail not in default mapping
        bool ok = compliance.isTransferCompliant(investor1, investor4);
        assertFalse(ok);
    }

    function test_sameCategoryAllowed() public {
        // Both retail in same jurisdiction
        address usRetail2 = address(0x6);
        compliance.registerInvestor(usRetail2, US, RETAIL);
        bool ok = compliance.isTransferCompliant(investor4, usRetail2);
        assertTrue(ok);
    }

    function test_allowCategoryTransfer() public {
        // Allow accredited -> retail
        compliance.setAllowedCategoryTransfer(ACCREDITED, RETAIL, true);
        bool ok = compliance.isTransferCompliant(investor1, investor4);
        assertTrue(ok);
    }

    function test_blockCategoryTransfer() public {
        // accredited -> qualified is allowed by default; register an EU/qualified
        // receiver so the jurisdiction check (US->EU) passes and only the
        // category rule is exercised.
        address euQualified = address(0x9);
        compliance.registerInvestor(euQualified, EU, QUALIFIED);
        assertTrue(compliance.isTransferCompliant(investor1, euQualified));

        // Block accredited -> qualified and confirm the transfer is now denied.
        compliance.setAllowedCategoryTransfer(ACCREDITED, QUALIFIED, false);
        bool ok = compliance.isTransferCompliant(investor1, euQualified);
        assertFalse(ok);
    }

    function test_sameCategoryAlwaysAllowedRegardlessOfMapping() public {
        // Same-category transfers are hard-coded as allowed; toggling the
        // cross-category mapping for an identical pair has no effect.
        compliance.setAllowedCategoryTransfer(ACCREDITED, ACCREDITED, false);
        // US->EU jurisdiction is allowed and both are accredited.
        bool ok = compliance.isTransferCompliant(investor1, investor2);
        assertTrue(ok);
        assertTrue(compliance.isCategoryTransferAllowed(ACCREDITED, ACCREDITED));
    }

    // --- Unregistered Investor Tests ---

    function test_unregisteredSenderBlocked() public {
        vm.expectRevert("Sender not registered");
        compliance.isTransferCompliant(unregistered, investor1);
    }

    function test_unregisteredReceiverBlocked() public {
        vm.expectRevert("Receiver not registered");
        compliance.isTransferCompliant(investor1, unregistered);
    }

    function test_transferFromCompliant() public {
        assertTrue(compliance.isTransferFromCompliant(investor1));
        assertFalse(compliance.isTransferFromCompliant(unregistered));
    }

    function test_transferToCompliant() public {
        assertTrue(compliance.isTransferToCompliant(investor2));
        assertFalse(compliance.isTransferToCompliant(unregistered));
    }

    // --- Jurisdiction View Tests ---

    function test_isJurisdictionTransferAllowed() public {
        assertTrue(compliance.isJurisdictionTransferAllowed(US, EU));
        assertFalse(compliance.isJurisdictionTransferAllowed(JP, US));
    }

    function test_isCategoryTransferAllowed() public {
        assertTrue(compliance.isCategoryTransferAllowed(ACCREDITED, ACCREDITED));
        assertFalse(compliance.isCategoryTransferAllowed(RETAIL, ACCREDITED));
    }

    // --- Access Control Tests ---

    function test_onlyOwnerCanRegister() public {
        vm.prank(investor1);
        vm.expectRevert();
        compliance.registerInvestor(address(0x10), US, ACCREDITED);
    }

    function test_onlyOwnerCanSetTransfer() public {
        vm.prank(investor1);
        vm.expectRevert();
        compliance.setAllowedTransfer(US, JP, true);
    }

    function test_onlyOwnerCanSetCategory() public {
        vm.prank(investor1);
        vm.expectRevert();
        compliance.setAllowedCategoryTransfer(RETAIL, ACCREDITED, true);
    }

    // --- Complex Scenario Tests ---

    function test_multiHopNotRequired_singleCheckSufficient() public {
        // US->SG allowed, SG->JP not allowed
        // Direct US->JP should be blocked (no need for multi-hop)
        address sgInvestor = address(0x7);
        compliance.registerInvestor(sgInvestor, SG, ACCREDITED);

        // US->SG should work
        assertTrue(compliance.isTransferCompliant(investor1, sgInvestor));

        // SG->JP should be blocked
        assertFalse(compliance.isTransferCompliant(sgInvestor, investor3));
    }

    function test_fullLifecycle() public {
        // Register -> update -> check compliance -> remove
        address newInv = address(0x20);
        compliance.registerInvestor(newInv, EU, QUALIFIED);

        assertTrue(compliance.isTransferCompliant(investor2, newInv)); // EU->EU, accredited->qualified

        compliance.updateInvestor(newInv, US, RETAIL);
        assertFalse(compliance.isTransferCompliant(investor2, newInv)); // EU->US, accredited->retail (no category mapping)

        compliance.removeInvestor(newInv);
        vm.expectRevert("Receiver not registered");
        compliance.isTransferCompliant(investor1, newInv);
    }

    // --- Additional geo-gating edge cases ---

    // Jurisdiction rules are directional: allowing A->B does not allow B->A.
    function test_asymmetricJurisdictionRule() public {
        address auInvestor = address(0x30); // AU, accredited
        compliance.registerInvestor(auInvestor, keccak256("AU"), ACCREDITED);

        // Allow US->AU only.
        compliance.setAllowedTransfer(US, keccak256("AU"), true);
        assertTrue(compliance.isTransferCompliant(investor1, auInvestor)); // US->AU
        // Reverse direction (AU->US) was never allowed.
        assertFalse(compliance.isTransferCompliant(auInvestor, investor1));
    }

    function test_revokingJurisdictionReblocks() public {
        // US->EU is allowed by default.
        assertTrue(compliance.isTransferCompliant(investor1, investor2));
        compliance.setAllowedTransfer(US, EU, false);
        assertFalse(compliance.isTransferCompliant(investor1, investor2));
        compliance.setAllowedTransfer(US, EU, true);
        assertTrue(compliance.isTransferCompliant(investor1, investor2));
    }

    function test_updateInvestorChangesGeoGating() public {
        // investor3 is JP/retail; JP->US is blocked. Move investor3 to US.
        address usRetailDest = address(0x31);
        compliance.registerInvestor(usRetailDest, US, RETAIL);
        assertFalse(compliance.isTransferCompliant(investor3, usRetailDest)); // JP->US blocked

        compliance.updateInvestor(investor3, US, bytes32(0)); // now US/retail
        // US->US (default allowed) and retail->retail (allowed) => compliant.
        assertTrue(compliance.isTransferCompliant(investor3, usRetailDest));
    }

    function test_registerEmitsEvent() public {
        address newInv = address(0x32);
        vm.expectEmit(true, false, false, true);
        emit InvestorRegistered(newInv, SG, QUALIFIED);
        compliance.registerInvestor(newInv, SG, QUALIFIED);
    }

    function test_setAllowedTransferEmitsAllowAndBlock() public {
        vm.expectEmit(true, true, false, false);
        emit TransferAllowed(JP, US);
        compliance.setAllowedTransfer(JP, US, true);

        vm.expectEmit(true, true, false, false);
        emit TransferBlocked(JP, US);
        compliance.setAllowedTransfer(JP, US, false);
    }

    function test_removeInvestorBlocksAsSenderAndReceiver() public {
        compliance.removeInvestor(investor1);
        vm.expectRevert("Sender not registered");
        compliance.isTransferCompliant(investor1, investor2);

        vm.expectRevert("Receiver not registered");
        compliance.isTransferCompliant(investor2, investor1);
    }

    function test_investorEnumeration() public {
        // setUp registered 4 investors; the public array getter exposes them.
        assertEq(compliance.getInvestorCount(), 4);
        assertEq(compliance.investors(0), investor1);
        assertEq(compliance.investors(3), investor4);
    }

    function test_cannotRegisterEmptyCategory() public {
        vm.expectRevert("Invalid category");
        compliance.registerInvestor(address(0x33), US, bytes32(0));
    }

    // Same jurisdiction + cross-category that is NOT in the default mapping
    // must be blocked (retail cannot receive from accredited by default).
    function test_sameJurisdictionCrossCategoryBlocked() public {
        // investor1 US/accredited -> investor4 US/retail.
        assertFalse(compliance.isTransferCompliant(investor1, investor4));
    }
}
