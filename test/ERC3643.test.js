const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ERC-3643 / T-REX Core", function () {
  let registry, compliance, token;
  let owner, alice, bob, charlie;

  const US = 840;
  const GB = 826;
  const KP = 408; // restricted country for tests

  beforeEach(async function () {
    [owner, alice, bob, charlie] = await ethers.getSigners();

    const Registry = await ethers.getContractFactory("IdentityRegistry");
    registry = await Registry.deploy();

    const Compliance = await ethers.getContractFactory("BasicCompliance");
    compliance = await Compliance.deploy(registry.target);

    const Token = await ethers.getContractFactory("ERC3643Token");
    token = await Token.deploy("RWA Security Token", "RWA", registry.target, compliance.target);

    // Bind token in compliance
    await compliance.bindToken(token.target);

    // Register and accredit alice & bob
    await registry.registerIdentity(alice.address, US);
    await registry.setAccreditation(alice.address, true);

    await registry.registerIdentity(bob.address, GB);
    await registry.setAccreditation(bob.address, true);
  });

  // ──────────────────────────────────────────────
  //  Identity Registry
  // ──────────────────────────────────────────────

  describe("IdentityRegistry", function () {
    it("should register an identity", async function () {
      expect(await registry.hasIdentity(alice.address)).to.be.true;
      expect(await registry.investorCountry(alice.address)).to.equal(US);
    });

    it("should remove an identity", async function () {
      await registry.removeIdentity(alice.address);
      expect(await registry.hasIdentity(alice.address)).to.be.false;
    });

    it("should update country code", async function () {
      await registry.updateCountry(alice.address, GB);
      expect(await registry.investorCountry(alice.address)).to.equal(GB);
    });

    it("should track accreditation", async function () {
      expect(await registry.isAccredited(alice.address)).to.be.true;
      expect(await registry.isVerified(alice.address)).to.be.true;
    });

    it("should not verify without accreditation", async function () {
      await registry.registerIdentity(charlie.address, US);
      expect(await registry.hasIdentity(charlie.address)).to.be.true;
      expect(await registry.isAccredited(charlie.address)).to.be.false;
      expect(await registry.isVerified(charlie.address)).to.be.false;
    });

    it("should revert on duplicate registration", async function () {
      await expect(registry.registerIdentity(alice.address, US))
        .to.be.revertedWith("IdentityRegistry: already registered");
    });

    it("should revert on zero-address registration", async function () {
      await expect(registry.registerIdentity(ethers.ZeroAddress, US))
        .to.be.revertedWith("IdentityRegistry: zero address");
    });

    it("should revert when removing unregistered identity", async function () {
      await expect(registry.removeIdentity(charlie.address))
        .to.be.revertedWith("IdentityRegistry: not registered");
    });

    it("should revert when non-owner registers", async function () {
      await expect(registry.connect(alice).registerIdentity(charlie.address, US))
        .to.be.revertedWith("IdentityRegistry: caller is not owner");
    });
  });

  // ──────────────────────────────────────────────
  //  Compliance Module
  // ──────────────────────────────────────────────

  describe("BasicCompliance", function () {
    it("should manage country restrictions", async function () {
      await compliance.addCountryRestriction(KP);
      expect(await compliance.isCountryRestricted(KP)).to.be.true;

      await compliance.removeCountryRestriction(KP);
      expect(await compliance.isCountryRestricted(KP)).to.be.false;
    });

    it("should enforce max investor count", async function () {
      await compliance.setMaxInvestorCount(2);

      await token.mint(alice.address, ethers.parseEther("100"));
      await token.mint(bob.address, ethers.parseEther("100"));

      // Register and verify charlie
      await registry.registerIdentity(charlie.address, US);
      await registry.setAccreditation(charlie.address, true);

      // Should fail — already at max investors
      expect(await compliance.canTransfer(alice.address, charlie.address, ethers.parseEther("10")))
        .to.be.false;
    });

    it("should enforce max balance per investor", async function () {
      await compliance.setMaxBalancePerInvestor(ethers.parseEther("500"));

      await token.mint(alice.address, ethers.parseEther("100"));
      await token.mint(bob.address, ethers.parseEther("100"));

      // 450 would give bob 550 — should fail
      expect(await compliance.canTransfer(alice.address, bob.address, ethers.parseEther("450")))
        .to.be.false;

      // 50 would give bob 150 — should pass
      expect(await compliance.canTransfer(alice.address, bob.address, ethers.parseEther("50")))
        .to.be.true;
    });

    it("should track investor count", async function () {
      expect(await compliance.investorCount()).to.equal(0);

      await token.mint(alice.address, ethers.parseEther("100"));
      expect(await compliance.investorCount()).to.equal(1);

      await token.mint(bob.address, ethers.parseEther("100"));
      expect(await compliance.investorCount()).to.equal(2);

      // Transfer all from alice to bob — alice no longer a holder
      await token.connect(alice).transfer(bob.address, ethers.parseEther("100"));
      expect(await compliance.investorCount()).to.equal(1);
    });

    it("should revert when non-token calls hooks", async function () {
      await expect(compliance.connect(alice).transferred(alice.address, bob.address, 10))
        .to.be.revertedWith("BasicCompliance: caller is not the token");
    });
  });

  // ──────────────────────────────────────────────
  //  Token — Minting & Burning
  // ──────────────────────────────────────────────

  describe("ERC3643Token — Mint & Burn", function () {
    it("should mint tokens to verified investor", async function () {
      await token.mint(alice.address, ethers.parseEther("1000"));
      expect(await token.balanceOf(alice.address)).to.equal(ethers.parseEther("1000"));
      expect(await token.totalSupply()).to.equal(ethers.parseEther("1000"));
    });

    it("should burn tokens", async function () {
      await token.mint(alice.address, ethers.parseEther("1000"));
      await token.burn(alice.address, ethers.parseEther("400"));
      expect(await token.balanceOf(alice.address)).to.equal(ethers.parseEther("600"));
      expect(await token.totalSupply()).to.equal(ethers.parseEther("600"));
    });

    it("should revert minting to unverified address", async function () {
      await registry.registerIdentity(charlie.address, US);
      await expect(token.mint(charlie.address, ethers.parseEther("100")))
        .to.be.revertedWith("ERC3643Token: recipient not verified");
    });

    it("should revert minting by non-owner", async function () {
      await expect(token.connect(alice).mint(alice.address, ethers.parseEther("100")))
        .to.be.revertedWith("ERC3643Token: caller is not owner");
    });
  });

  // ──────────────────────────────────────────────
  //  Token — Transfers
  // ──────────────────────────────────────────────

  describe("ERC3643Token — Transfers", function () {
    beforeEach(async function () {
      await token.mint(alice.address, ethers.parseEther("1000"));
    });

    it("should transfer between verified investors", async function () {
      await token.connect(alice).transfer(bob.address, ethers.parseEther("300"));
      expect(await token.balanceOf(alice.address)).to.equal(ethers.parseEther("700"));
      expect(await token.balanceOf(bob.address)).to.equal(ethers.parseEther("300"));
    });

    it("should transferFrom with allowance", async function () {
      await token.connect(alice).approve(owner.address, ethers.parseEther("500"));
      await token.transferFrom(alice.address, bob.address, ethers.parseEther("200"));

      expect(await token.balanceOf(alice.address)).to.equal(ethers.parseEther("800"));
      expect(await token.balanceOf(bob.address)).to.equal(ethers.parseEther("200"));
      expect(await token.allowance(alice.address, owner.address)).to.equal(ethers.parseEther("300"));
    });

    it("should revert transfer to unverified address", async function () {
      await expect(token.connect(alice).transfer(charlie.address, ethers.parseEther("100")))
        .to.be.revertedWith("ERC3643Token: recipient not verified");
    });

    it("should revert transfer to country-restricted investor", async function () {
      await compliance.addCountryRestriction(GB);

      await expect(token.connect(alice).transfer(bob.address, ethers.parseEther("100")))
        .to.be.revertedWith("ERC3643Token: transfer not compliant");
    });
  });

  // ──────────────────────────────────────────────
  //  Token — Pause / Freeze / Recovery
  // ──────────────────────────────────────────────

  describe("ERC3643Token — Pause / Freeze / Recovery", function () {
    beforeEach(async function () {
      await token.mint(alice.address, ethers.parseEther("1000"));
    });

    it("should pause and unpause", async function () {
      await token.pause();
      expect(await token.paused()).to.be.true;

      await expect(token.connect(alice).transfer(bob.address, ethers.parseEther("100")))
        .to.be.revertedWith("ERC3643Token: token is paused");

      await token.unpause();
      expect(await token.paused()).to.be.false;

      await token.connect(alice).transfer(bob.address, ethers.parseEther("100"));
      expect(await token.balanceOf(bob.address)).to.equal(ethers.parseEther("100"));
    });

    it("should freeze an address", async function () {
      await token.setAddressFrozen(alice.address, true);
      expect(await token.isFrozen(alice.address)).to.be.true;

      await expect(token.connect(alice).transfer(bob.address, ethers.parseEther("100")))
        .to.be.revertedWith("ERC3643Token: sender is frozen");
    });

    it("should perform recovery transfer from frozen address", async function () {
      await token.setAddressFrozen(alice.address, true);
      await token.recoveryTransfer(alice.address, bob.address, ethers.parseEther("600"));

      expect(await token.balanceOf(alice.address)).to.equal(ethers.parseEther("400"));
      expect(await token.balanceOf(bob.address)).to.equal(ethers.parseEther("600"));
    });

    it("should revert recovery if source not frozen", async function () {
      await expect(token.recoveryTransfer(alice.address, bob.address, ethers.parseEther("100")))
        .to.be.revertedWith("ERC3643Token: source not frozen");
    });
  });

  // ──────────────────────────────────────────────
  //  Token — Registry / Compliance setters
  // ──────────────────────────────────────────────

  describe("ERC3643Token — Admin setters", function () {
    it("should update identity registry", async function () {
      const NewRegistry = await ethers.getContractFactory("IdentityRegistry");
      const newRegistry = await NewRegistry.deploy();

      await token.setIdentityRegistry(newRegistry.target);
      expect(await token.identityRegistry()).to.equal(newRegistry.target);
    });

    it("should update compliance module", async function () {
      const NewCompliance = await ethers.getContractFactory("BasicCompliance");
      const newCompliance = await NewCompliance.deploy(registry.target);

      await token.setCompliance(newCompliance.target);
      expect(await token.compliance()).to.equal(newCompliance.target);
    });

    it("should revert setting zero-address registry", async function () {
      await expect(token.setIdentityRegistry(ethers.ZeroAddress))
        .to.be.revertedWith("ERC3643Token: zero registry");
    });
  });

  // ──────────────────────────────────────────────
  //  ERC-20 basics
  // ──────────────────────────────────────────────

  describe("ERC3643Token — ERC-20 metadata", function () {
    it("should return correct metadata", async function () {
      expect(await token.name()).to.equal("RWA Security Token");
      expect(await token.symbol()).to.equal("RWA");
      expect(await token.decimals()).to.equal(18);
    });

    it("should approve spender", async function () {
      await token.connect(alice).approve(bob.address, ethers.parseEther("500"));
      expect(await token.allowance(alice.address, bob.address)).to.equal(ethers.parseEther("500"));
    });
  });
});
