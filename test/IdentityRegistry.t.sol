// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/IdentityRegistry.sol";
import "../contracts/interfaces/IIdentityRegistry.sol";

contract IdentityRegistryTest is Test {
    IdentityRegistry registry;

    address owner = address(this);
    address issuer = address(0xBEEF);
    address stranger = address(0xCAFE);

    address walletA = address(0xA1);
    address walletB = address(0xA2);
    address walletC = address(0xA3);

    address idA = address(0x1D1);
    address idB = address(0x1D2);
    address idC = address(0x1D3);

    // Mirror the interface events so we can expectEmit against them.
    event IdentityRegistered(address indexed wallet, address indexed identity);
    event IdentityRemoved(address indexed wallet, address indexed identity);
    event IdentityUpdated(address indexed wallet, address indexed identity);
    event TrustedIssuerAdded(address indexed issuer);
    event TrustedIssuerRemoved(address indexed issuer);

    function setUp() public {
        registry = new IdentityRegistry(owner);
    }

    // --- Construction / ownership ---

    function test_ownerIsInitialOwner() public {
        assertEq(registry.owner(), owner);
    }

    // --- Trusted issuer management ---

    function test_ownerCanAddTrustedIssuer() public {
        vm.expectEmit(true, false, false, false);
        emit TrustedIssuerAdded(issuer);
        registry.addTrustedIssuer(issuer);
        assertTrue(registry.trustedIssuers(issuer));
    }

    function test_ownerCanRemoveTrustedIssuer() public {
        registry.addTrustedIssuer(issuer);
        vm.expectEmit(true, false, false, false);
        emit TrustedIssuerRemoved(issuer);
        registry.removeTrustedIssuer(issuer);
        assertFalse(registry.trustedIssuers(issuer));
    }

    function test_cannotAddZeroAddressIssuer() public {
        vm.expectRevert("Invalid issuer address");
        registry.addTrustedIssuer(address(0));
    }

    function test_onlyOwnerCanAddIssuer() public {
        vm.prank(stranger);
        vm.expectRevert();
        registry.addTrustedIssuer(issuer);
    }

    function test_onlyOwnerCanRemoveIssuer() public {
        registry.addTrustedIssuer(issuer);
        vm.prank(stranger);
        vm.expectRevert();
        registry.removeTrustedIssuer(issuer);
    }

    // --- Registration (verified addresses) ---

    function test_ownerCanRegisterAsImplicitIssuer() public {
        // owner() passes the onlyTrustedIssuer modifier even without being added.
        vm.expectEmit(true, true, false, false);
        emit IdentityRegistered(walletA, idA);
        registry.registerIdentity(walletA, idA);

        assertEq(registry.getIdentity(walletA), idA);
        assertTrue(registry.isVerified(walletA));
        assertTrue(registry.isRegistered(idA));
        assertEq(registry.getIdentityCount(), 1);
    }

    function test_trustedIssuerCanRegister() public {
        registry.addTrustedIssuer(issuer);
        vm.prank(issuer);
        registry.registerIdentity(walletA, idA);
        assertTrue(registry.isVerified(walletA));
    }

    function test_nonIssuerCannotRegister() public {
        vm.prank(stranger);
        vm.expectRevert("Not trusted issuer");
        registry.registerIdentity(walletA, idA);
    }

    function test_cannotRegisterZeroWallet() public {
        vm.expectRevert("Invalid wallet");
        registry.registerIdentity(address(0), idA);
    }

    function test_cannotRegisterZeroIdentity() public {
        vm.expectRevert("Invalid identity");
        registry.registerIdentity(walletA, address(0));
    }

    function test_cannotRegisterSameWalletTwice() public {
        registry.registerIdentity(walletA, idA);
        vm.expectRevert("Identity already exists");
        registry.registerIdentity(walletA, idB);
    }

    // --- isVerified semantics (verified vs blocked/unknown) ---

    function test_unregisteredWalletIsNotVerified() public {
        assertFalse(registry.isVerified(walletA));
        assertEq(registry.getIdentity(walletA), address(0));
    }

    function test_revokeBlocksVerification() public {
        registry.registerIdentity(walletA, idA);
        assertTrue(registry.isVerified(walletA));

        // Revoking the identity should block the wallet (verified -> false)
        // while leaving the wallet->identity link intact.
        registry.revokeIdentity(idA);
        assertFalse(registry.isVerified(walletA));
        assertFalse(registry.isRegistered(idA));
        assertEq(registry.getIdentity(walletA), idA);
    }

    function test_verifyReinstatesAfterRevoke() public {
        registry.registerIdentity(walletA, idA);
        registry.revokeIdentity(idA);
        assertFalse(registry.isVerified(walletA));

        registry.verifyIdentity(idA);
        assertTrue(registry.isVerified(walletA));
        assertTrue(registry.isRegistered(idA));
    }

    function test_cannotVerifyZeroIdentity() public {
        vm.expectRevert("Invalid identity");
        registry.verifyIdentity(address(0));
    }

    function test_onlyIssuerCanRevoke() public {
        registry.registerIdentity(walletA, idA);
        vm.prank(stranger);
        vm.expectRevert("Not trusted issuer");
        registry.revokeIdentity(idA);
    }

    function test_onlyIssuerCanVerify() public {
        vm.prank(stranger);
        vm.expectRevert("Not trusted issuer");
        registry.verifyIdentity(idA);
    }

    // --- Removal ---

    function test_removeIdentityClearsLinkAndVerification() public {
        registry.registerIdentity(walletA, idA);
        vm.expectEmit(true, true, false, false);
        emit IdentityRemoved(walletA, idA);
        registry.removeIdentity(walletA);

        assertFalse(registry.isVerified(walletA));
        assertEq(registry.getIdentity(walletA), address(0));
        assertFalse(registry.isRegistered(idA));
        assertEq(registry.getIdentityCount(), 0);
    }

    function test_cannotRemoveUnregisteredWallet() public {
        vm.expectRevert("Identity not found");
        registry.removeIdentity(walletA);
    }

    function test_onlyIssuerCanRemove() public {
        registry.registerIdentity(walletA, idA);
        vm.prank(stranger);
        vm.expectRevert("Not trusted issuer");
        registry.removeIdentity(walletA);
    }

    function test_removeMiddleWalletKeepsOthers() public {
        registry.registerIdentity(walletA, idA);
        registry.registerIdentity(walletB, idB);
        registry.registerIdentity(walletC, idC);
        assertEq(registry.getIdentityCount(), 3);

        // Remove the middle wallet; swap-and-pop must preserve the other two.
        registry.removeIdentity(walletB);
        assertEq(registry.getIdentityCount(), 2);
        assertFalse(registry.isVerified(walletB));
        assertTrue(registry.isVerified(walletA));
        assertTrue(registry.isVerified(walletC));

        address[] memory wallets = registry.getRegisteredWallets();
        assertEq(wallets.length, 2);
    }

    // --- Update ---

    function test_updateIdentitySwapsVerification() public {
        registry.registerIdentity(walletA, idA);
        vm.expectEmit(true, true, false, false);
        emit IdentityUpdated(walletA, idB);
        registry.updateIdentity(walletA, idB);

        assertEq(registry.getIdentity(walletA), idB);
        assertTrue(registry.isVerified(walletA));
        assertTrue(registry.isRegistered(idB));
        // The old identity is no longer verified.
        assertFalse(registry.isRegistered(idA));
    }

    function test_cannotUpdateUnregisteredWallet() public {
        vm.expectRevert("Identity not found");
        registry.updateIdentity(walletA, idB);
    }

    function test_cannotUpdateToZeroIdentity() public {
        registry.registerIdentity(walletA, idA);
        vm.expectRevert("Invalid identity");
        registry.updateIdentity(walletA, address(0));
    }

    function test_onlyIssuerCanUpdate() public {
        registry.registerIdentity(walletA, idA);
        vm.prank(stranger);
        vm.expectRevert("Not trusted issuer");
        registry.updateIdentity(walletA, idB);
    }

    // --- Batch registration (regression: parameter previously shadowed the
    //     storage mapping and did not compile / would not persist) ---

    function test_batchRegisterPersistsAllIdentities() public {
        address[] memory wallets = new address[](3);
        wallets[0] = walletA;
        wallets[1] = walletB;
        wallets[2] = walletC;

        address[] memory ids = new address[](3);
        ids[0] = idA;
        ids[1] = idB;
        ids[2] = idC;

        registry.batchRegisterIdentities(wallets, ids);

        assertEq(registry.getIdentityCount(), 3);
        assertEq(registry.getIdentity(walletA), idA);
        assertEq(registry.getIdentity(walletB), idB);
        assertEq(registry.getIdentity(walletC), idC);
        assertTrue(registry.isVerified(walletA));
        assertTrue(registry.isVerified(walletB));
        assertTrue(registry.isVerified(walletC));
        assertTrue(registry.isRegistered(idA));
        assertTrue(registry.isRegistered(idB));
        assertTrue(registry.isRegistered(idC));
    }

    function test_batchRegisterEmitsPerWallet() public {
        address[] memory wallets = new address[](2);
        wallets[0] = walletA;
        wallets[1] = walletB;
        address[] memory ids = new address[](2);
        ids[0] = idA;
        ids[1] = idB;

        vm.expectEmit(true, true, false, false);
        emit IdentityRegistered(walletA, idA);
        vm.expectEmit(true, true, false, false);
        emit IdentityRegistered(walletB, idB);
        registry.batchRegisterIdentities(wallets, ids);
    }

    function test_batchRegisterRevertsOnLengthMismatch() public {
        address[] memory wallets = new address[](2);
        wallets[0] = walletA;
        wallets[1] = walletB;
        address[] memory ids = new address[](1);
        ids[0] = idA;

        vm.expectRevert("Arrays length mismatch");
        registry.batchRegisterIdentities(wallets, ids);
    }

    function test_batchRegisterRevertsOnZeroWallet() public {
        address[] memory wallets = new address[](1);
        wallets[0] = address(0);
        address[] memory ids = new address[](1);
        ids[0] = idA;

        vm.expectRevert("Invalid wallet");
        registry.batchRegisterIdentities(wallets, ids);
    }

    function test_batchRegisterRevertsOnZeroIdentity() public {
        address[] memory wallets = new address[](1);
        wallets[0] = walletA;
        address[] memory ids = new address[](1);
        ids[0] = address(0);

        vm.expectRevert("Invalid identity");
        registry.batchRegisterIdentities(wallets, ids);
    }

    function test_batchRegisterRevertsOnDuplicateExisting() public {
        registry.registerIdentity(walletA, idA);

        address[] memory wallets = new address[](1);
        wallets[0] = walletA;
        address[] memory ids = new address[](1);
        ids[0] = idB;

        vm.expectRevert("Identity already exists");
        registry.batchRegisterIdentities(wallets, ids);
    }

    function test_batchRegisterOnlyIssuer() public {
        address[] memory wallets = new address[](1);
        wallets[0] = walletA;
        address[] memory ids = new address[](1);
        ids[0] = idA;

        vm.prank(stranger);
        vm.expectRevert("Not trusted issuer");
        registry.batchRegisterIdentities(wallets, ids);
    }

    function test_batchRegisterEmptyArraysIsNoop() public {
        address[] memory wallets = new address[](0);
        address[] memory ids = new address[](0);
        registry.batchRegisterIdentities(wallets, ids);
        assertEq(registry.getIdentityCount(), 0);
    }

    // --- Shared-identity edge case ---
    // Two wallets registered with the same identity address. Removing one
    // unverifies that identity, which (by design) also unverifies the other
    // wallet that shares it. This documents the contract's current behavior.
    function test_sharedIdentityRemovalAffectsBoth() public {
        registry.registerIdentity(walletA, idA);
        registry.registerIdentity(walletB, idA);
        assertTrue(registry.isVerified(walletA));
        assertTrue(registry.isVerified(walletB));

        registry.removeIdentity(walletA);
        // Identity idA is now unverified, so walletB (still linked to idA) is
        // no longer verified either.
        assertFalse(registry.isVerified(walletA));
        assertFalse(registry.isVerified(walletB));
        assertEq(registry.getIdentity(walletB), idA);
    }
}
