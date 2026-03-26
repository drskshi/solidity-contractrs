const fs = require("fs");
const path = require("path");
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const RentalAgreement = await hre.ethers.getContractFactory("RentalAgreement");
  const rental = await RentalAgreement.deploy();
  await rental.waitForDeployment();

  const addr = await rental.getAddress();
  console.log("RentalAgreement deployed to:", addr);

  const out = path.join(__dirname, "..", "deployed-address.txt");
  fs.writeFileSync(
    out,
    [
      addr,
      "",
      "Paste ONLY the first line above into the DApp Contract address field.",
      "Do NOT paste the deployer line (0xf39F...) — that is a wallet, not the contract.",
      "MetaMask network: Localhost 8545, Chain ID 31337 (not Ethereum mainnet).",
    ].join("\n"),
    "utf8"
  );
  console.log("Saved for copy/paste:", out);

  return addr;
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
