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
        // Both US accredited
        bool ok = compliance.isTransferCompliant(investor1, investor4);
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
        // Allow JP->US
        compliance.setAllowedTransfer(JP, US, true);
        bool ok = compliance.isTransferCompliant(investor3, investor1);
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
        // Block accredited -> accredited (previously allowed)
        compliance.setAllowedCategoryTransfer(ACCREDITED, ACCREDITED, false);
        bool ok = compliance.isTransferCompliant(investor1, investor2);
        assertFalse(ok);
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
}
