// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/erc1404/SimpleRestrictor.sol";

contract SimpleRestrictorTest is Test {
    SimpleRestrictor restrictor;

    address admin = address(this);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address stranger = address(0x5);

    // RestrictionCode enum values (mirror SimpleRestrictor.RestrictionCode).
    uint8 constant OK = 0;
    uint8 constant SENDER_NOT_WL = 1;
    uint8 constant RECEIVER_NOT_WL = 2;
    uint8 constant SENDER_FROZEN = 3;
    uint8 constant RECEIVER_FROZEN = 4;
    uint8 constant AMOUNT_EXCEEDS = 5;
    uint8 constant JURISDICTION_MISMATCH = 6;

    function setUp() public {
        restrictor = new SimpleRestrictor(admin);
    }

    function _whitelistBoth() internal {
        restrictor.setWhitelisted(alice, true);
        restrictor.setWhitelisted(bob, true);
    }

    // --- Defaults ---

    function test_globalMaxDefaultsToMax() public {
        assertEq(restrictor.globalMaxTransferAmount(), type(uint256).max);
    }

    function test_ownerIsAdmin() public {
        assertEq(restrictor.owner(), admin);
    }

    // --- Whitelist gating ---

    function test_senderNotWhitelistedBlocks() public {
        restrictor.setWhitelisted(bob, true);
        uint8 code = restrictor.detectTransferRestriction(alice, bob, 1);
        assertEq(code, SENDER_NOT_WL);
    }

    function test_receiverNotWhitelistedBlocks() public {
        restrictor.setWhitelisted(alice, true);
        uint8 code = restrictor.detectTransferRestriction(alice, bob, 1);
        assertEq(code, RECEIVER_NOT_WL);
    }

    function test_bothWhitelistedAllows() public {
        _whitelistBoth();
        uint8 code = restrictor.detectTransferRestriction(alice, bob, 1);
        assertEq(code, OK);
    }

    function test_mintFromZeroSkipsSenderWhitelist() public {
        // from == address(0) means a mint; sender whitelist check is skipped,
        // but the receiver must still be whitelisted.
        restrictor.setWhitelisted(bob, true);
        uint8 code = restrictor.detectTransferRestriction(address(0), bob, 1);
        assertEq(code, OK);
    }

    function test_burnToZeroSkipsReceiverWhitelist() public {
        // to == address(0) means a burn; receiver whitelist check is skipped,
        // but the sender must still be whitelisted.
        restrictor.setWhitelisted(alice, true);
        uint8 code = restrictor.detectTransferRestriction(alice, address(0), 1);
        assertEq(code, OK);
    }

    // --- Freeze gating ---

    function test_frozenSenderBlocks() public {
        _whitelistBoth();
        restrictor.setFrozen(alice, true);
        uint8 code = restrictor.detectTransferRestriction(alice, bob, 1);
        assertEq(code, SENDER_FROZEN);
    }

    function test_frozenReceiverBlocks() public {
        _whitelistBoth();
        restrictor.setFrozen(bob, true);
        uint8 code = restrictor.detectTransferRestriction(alice, bob, 1);
        assertEq(code, RECEIVER_FROZEN);
    }

    function test_unfreezeRestoresTransfer() public {
        _whitelistBoth();
        restrictor.setFrozen(alice, true);
        assertEq(restrictor.detectTransferRestriction(alice, bob, 1), SENDER_FROZEN);
        restrictor.setFrozen(alice, false);
        assertEq(restrictor.detectTransferRestriction(alice, bob, 1), OK);
    }

    // --- Amount limits ---

    function test_perAddressLimitEnforced() public {
        _whitelistBoth();
        restrictor.setMaxTransferAmount(alice, 100);
        assertEq(restrictor.detectTransferRestriction(alice, bob, 100), OK);
        assertEq(restrictor.detectTransferRestriction(alice, bob, 101), AMOUNT_EXCEEDS);
    }

    function test_globalLimitUsedWhenNoPerAddressLimit() public {
        _whitelistBoth();
        restrictor.setGlobalMaxTransferAmount(50);
        assertEq(restrictor.detectTransferRestriction(alice, bob, 50), OK);
        assertEq(restrictor.detectTransferRestriction(alice, bob, 51), AMOUNT_EXCEEDS);
    }

    function test_perAddressLimitOverridesGlobal() public {
        _whitelistBoth();
        restrictor.setGlobalMaxTransferAmount(10);
        restrictor.setMaxTransferAmount(alice, 1000);
        // alice's per-address limit (1000) is higher than the global (10).
        assertEq(restrictor.detectTransferRestriction(alice, bob, 500), OK);
        // bob has no per-address limit, so the global applies to him as sender.
        restrictor.setWhitelisted(stranger, true);
        assertEq(restrictor.detectTransferRestriction(bob, stranger, 11), AMOUNT_EXCEEDS);
    }

    function test_zeroAmountAlwaysWithinLimit() public {
        _whitelistBoth();
        restrictor.setGlobalMaxTransferAmount(0);
        // amount == 0 is never > maxAmt, so it passes the amount check.
        assertEq(restrictor.detectTransferRestriction(alice, bob, 0), OK);
    }

    // --- Precedence: whitelist > freeze > amount ---

    function test_whitelistCheckedBeforeFreeze() public {
        // alice frozen but also not whitelisted -> not-whitelisted wins.
        restrictor.setWhitelisted(bob, true);
        restrictor.setFrozen(alice, true);
        uint8 code = restrictor.detectTransferRestriction(alice, bob, 1);
        assertEq(code, SENDER_NOT_WL);
    }

    function test_freezeCheckedBeforeAmount() public {
        _whitelistBoth();
        restrictor.setFrozen(alice, true);
        restrictor.setMaxTransferAmount(alice, 1);
        // Over the limit AND frozen -> freeze takes precedence.
        uint8 code = restrictor.detectTransferRestriction(alice, bob, 1000);
        assertEq(code, SENDER_FROZEN);
    }

    // --- Access control ---

    function test_onlySetWhitelistByOwner() public {
        vm.prank(stranger);
        vm.expectRevert();
        restrictor.setWhitelisted(alice, true);
    }

    function test_onlySetFrozenByOwner() public {
        vm.prank(stranger);
        vm.expectRevert();
        restrictor.setFrozen(alice, true);
    }

    function test_onlySetMaxTransferByOwner() public {
        vm.prank(stranger);
        vm.expectRevert();
        restrictor.setMaxTransferAmount(alice, 1);
    }

    function test_onlySetGlobalMaxByOwner() public {
        vm.prank(stranger);
        vm.expectRevert();
        restrictor.setGlobalMaxTransferAmount(1);
    }

    // --- Messages ---

    function test_messagesForEachCode() public {
        assertEq(restrictor.messageForTransferRestriction(OK), "No restrictions");
        assertEq(restrictor.messageForTransferRestriction(SENDER_NOT_WL), "Sender not whitelisted");
        assertEq(restrictor.messageForTransferRestriction(RECEIVER_NOT_WL), "Receiver not whitelisted");
        assertEq(restrictor.messageForTransferRestriction(SENDER_FROZEN), "Sender frozen");
        assertEq(restrictor.messageForTransferRestriction(RECEIVER_FROZEN), "Receiver frozen");
        assertEq(restrictor.messageForTransferRestriction(AMOUNT_EXCEEDS), "Amount exceeds transfer limit");
        assertEq(restrictor.messageForTransferRestriction(JURISDICTION_MISMATCH), "Jurisdiction mismatch");
    }

    function test_messageForUnknownCode() public {
        assertEq(restrictor.messageForTransferRestriction(200), "Unknown restriction");
    }

    // --- Fuzz: any whitelisted+unfrozen pair under the limit is OK ---

    function testFuzz_withinLimitAlwaysOk(uint256 amount, uint256 limit) public {
        amount = bound(amount, 0, type(uint128).max);
        limit = bound(limit, amount, type(uint256).max);
        _whitelistBoth();
        restrictor.setMaxTransferAmount(alice, limit);
        assertEq(restrictor.detectTransferRestriction(alice, bob, amount), OK);
    }

    function testFuzz_overLimitAlwaysBlocked(uint256 limit, uint256 over) public {
        // A per-address max of 0 is treated as "unset" (falls back to the
        // global max), so the limit must be >= 1 for the over-limit invariant.
        limit = bound(limit, 1, type(uint128).max);
        over = bound(over, 1, type(uint128).max);
        _whitelistBoth();
        restrictor.setMaxTransferAmount(alice, limit);
        uint8 code = restrictor.detectTransferRestriction(alice, bob, limit + over);
        assertEq(code, AMOUNT_EXCEEDS);
    }

    function test_perAddressLimitOfZeroFallsBackToGlobal() public {
        // Setting a per-address max of 0 is indistinguishable from "no limit";
        // the contract falls back to the global max. This documents the quirk.
        _whitelistBoth();
        restrictor.setGlobalMaxTransferAmount(100);
        restrictor.setMaxTransferAmount(alice, 0);
        assertEq(restrictor.detectTransferRestriction(alice, bob, 100), OK);
        assertEq(restrictor.detectTransferRestriction(alice, bob, 101), AMOUNT_EXCEEDS);
    }
}
