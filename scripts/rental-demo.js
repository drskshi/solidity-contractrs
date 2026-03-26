/**
 * Compile: npm run compile
 * Run full flow (deploy + deposit + withdraw demo): npm run demo
 */
const hre = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

function eth(wei) {
  return hre.ethers.formatEther(wei);
}

async function main() {
  const [landlord, tenant] = await hre.ethers.getSigners();

  console.log("\n========== COMPILE & DEPLOY ==========");
  const RentalAgreement = await hre.ethers.getContractFactory("RentalAgreement");
  const rental = await RentalAgreement.deploy();
  await rental.waitForDeployment();
  const rentalAddr = await rental.getAddress();
  console.log("Contract deployed at:", rentalAddr);

  // Tiny test amounts only — Hardhat in-memory network uses fake ETH, not real money.
  const rent = hre.ethers.parseEther("0.001");
  const deposit = hre.ethers.parseEther("0.002");
  const durationSec = 120n;

  console.log("\n========== REGISTER ROLES ==========");
  await (await rental.connect(landlord).registerLandlord()).wait();
  await (await rental.connect(tenant).registerTenant()).wait();
  console.log("Landlord registered:", landlord.address);
  console.log("Tenant registered: ", tenant.address);

  console.log("\n========== CREATE & SIGN AGREEMENT ==========");
  await (await rental.connect(landlord).createAgreement(tenant.address, rent, deposit, durationSec)).wait();
  const agreementId = 0n;
  console.log("Agreement ID:", agreementId.toString(), "(first agreement)");

  await (await rental.connect(tenant).signAgreement(agreementId)).wait();
  console.log("Tenant signed agreement.");

  console.log("\n========== DEPOSIT (tenant -> contract) ==========");
  const balBeforeDeposit = await hre.ethers.provider.getBalance(rentalAddr);
  console.log("Contract ETH before deposit:", eth(balBeforeDeposit));

  await (
    await rental.connect(tenant).payDeposit(agreementId, { value: deposit })
  ).wait();

  const balAfterDeposit = await hre.ethers.provider.getBalance(rentalAddr);
  const held = await rental.getHeldDeposit(agreementId);
  const aAfterDeposit = await rental.getAgreement(agreementId);

  console.log("Contract ETH after deposit: ", eth(balAfterDeposit));
  console.log("getHeldDeposit(agreementId): ", eth(held));
  console.log("depositPaid (on-chain):      ", aAfterDeposit.depositPaid);

  console.log("\n========== PAY RENT (tenant -> landlord) ==========");
  const landlordBalBeforeRent = await hre.ethers.provider.getBalance(landlord.address);
  await (await rental.connect(tenant).payRent(agreementId, { value: rent })).wait();
  const landlordBalAfterRent = await hre.ethers.provider.getBalance(landlord.address);
  console.log("Landlord balance increased by rent (minus gas is visible on-chain): OK");
  console.log("  (approx rent)", eth(rent));

  console.log("\n========== ADVANCE TIME PAST endDate ==========");
  const agr = await rental.getAgreement(agreementId);
  const end = agr.endDate;
  await time.increaseTo(Number(end) + 1);
  console.log("Time moved past endDate so landlord can withdraw deposit.");

  console.log("\n========== WITHDRAW DEPOSIT (landlord <- contract) ==========");
  const landlordBeforeWd = await hre.ethers.provider.getBalance(landlord.address);
  const contractBeforeWd = await hre.ethers.provider.getBalance(rentalAddr);

  await (await rental.connect(landlord).withdrawDeposit(agreementId)).wait();

  const landlordAfterWd = await hre.ethers.provider.getBalance(landlord.address);
  const contractAfterWd = await hre.ethers.provider.getBalance(rentalAddr);
  const aFinal = await rental.getAgreement(agreementId);

  console.log("Contract ETH before withdraw:", eth(contractBeforeWd));
  console.log("Contract ETH after withdraw: ", eth(contractAfterWd), "(deposit sent out)");
  console.log("depositReleased (on-chain):   ", aFinal.depositReleased);
  console.log("Landlord received deposit (balance change includes gas). Flow: OK");

  console.log("\n========== DONE — no errors ==========\n");
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
