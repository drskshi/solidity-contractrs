================================================================================
  RENTAL AGREEMENT DAPP — STUDENT PROJECT README
  RentalAgreement.sol + Hardhat (compile, deploy, automated demo)
================================================================================

  **Start from zero:** open START-HERE.txt in this folder (full steps + MetaMask).

================================================================================

TESTING ONLY — NO REAL MONEY
-----------------------------
For class and demos, use **Hardhat localhost** or **Remix VM** only. All ETH
there is fake “test ether.” Never deploy this school project to Ethereum
mainnet or send real cryptocurrency.

STUDENTS — MetaMask “fee” / Review alert on localhost
 MetaMask sometimes shows a dollar amount or “Review alert” for transactions
 from http://localhost. On Hardhat (chain 31337) you still only spend **fake
 ETH**; the USD number is misleading. Open Review → Confirm. If your Hardhat
 account has no ETH, import a key from the `npx hardhat node` terminal output
 (those accounts start with ~10,000 fake ETH each).

WHAT THIS PROJECT IS
--------------------
A decentralized rental agreement on Ethereum (Solidity). It lets a landlord
and tenant register roles, create an agreement on-chain, sign it, pay a
security deposit (held in the contract), pay rent (sent directly to the
landlord), and withdraw the deposit after the lease ends (or refund rules if
the landlord ends the lease early).


WHAT YOU CAN SHOW YOUR TEACHER
------------------------------
1) SOURCE CODE: contracts/RentalAgreement.sol — smart contract with roles,
   agreements, events, require() checks, reentrancy protection, and NatSpec.

2) COMPILE + RUN: Open a terminal in this folder and run the commands below.
   You will see printed proof that:
   • The contract compiles.
   • Deploy succeeds.
   • The tenant deposits a tiny test amount (default demo: 0.002 ETH fake).
   • The tenant pays a tiny test rent (default demo: 0.001 ETH fake).
   • Time advances past the lease end date (demo only — Hardhat network).
   • The landlord withdraws the deposit — contract balance goes to 0 ETH and
     depositReleased becomes true on-chain.

3) WEB UI (recommended for demos): ui/index.html — full DApp in the browser.
   • Customize rent (ETH), deposit (ETH), lease duration (seconds / minutes / hours / days).
   • Connect MetaMask; paste deployed contract address; use the Activity log (no console).
   • Start the server: npm run ui  →  open the URL shown (e.g. http://localhost:5500)


FOLDER STRUCTURE
----------------
  deployed-address.txt            Auto-written by deploy to localhost (copy line 1 into UI)
  contracts/RentalAgreement.sol   Main Solidity contract
  scripts/deploy.js               Deploy contract only (also saves deployed-address.txt)
  scripts/rental-demo.js          Full scripted demo (deposit + withdraw)
  hardhat.config.js               Solidity version 0.8.20
  package.json                    npm scripts (compile, deploy, demo, all, ui)
  RUNNING.txt                     Step-by-step + sample terminal output (running format)
  readme.txt                      This file
  ui/index.html                   Browser UI (wallet + custom amounts + activity log)


PREREQUISITES
-------------
• Node.js (LTS recommended): https://nodejs.org/
• This folder: the project root (where package.json is)


FIRST-TIME SETUP (ONCE)
-----------------------
Open PowerShell or Command Prompt, go to the project folder, then:

  cd path\to\aab
  npm install

(This downloads Hardhat and testing tools. Internet required.)


COMMANDS TO RUN FOR A DEMO
--------------------------

  ONE COMMAND (compile + deploy + demo):

     npm run all

  OR run separately:

1) Compile the smart contract:

     npm run compile

   Expected: "Compiled ... successfully" (or "Nothing to compile" if unchanged).

2) Deploy only (optional — prints contract address):

     npm run deploy

3) Full automated demo (RECOMMENDED FOR PRESENTATION):

     npm run demo

   Expected end line: "DONE — no errors"

   This script deploys fresh, runs register → create → sign → payDeposit →
   payRent → advances blockchain time → withdrawDeposit, and prints balances.

  For a printable transcript of commands and expected output, open RUNNING.txt


WEB UI DEMO (browser, customizable numbers)
-------------------------------------------
  Terminal 1 — local chain (MetaMask can use this network):

     npx hardhat node

  Terminal 2 — deploy to localhost (copy the printed contract address):

     npx hardhat run scripts/deploy.js --network localhost

  Terminal 3 — start the UI server:

     npm run ui

  Browser:
  • Open http://localhost:5500/index.html
  • Add Hardhat network in MetaMask: RPC http://127.0.0.1:8545, chainId 31337,
    import a test key from the hardhat node console output if needed.
  • Paste contract address; Connect wallet; fill rent / deposit / duration; tenant address.
  • Easy UI (section 3): only two main buttons. Order matters:
      1) Tenant wallet → Tenant button (registers tenant).
      2) Landlord wallet → Landlord button (registers landlord + creates agreement).
      3) Tenant wallet → Tenant button again (signs + pays deposit automatically).
  • Optional: Pay rent · Skip time (Hardhat) · Withdraw deposit.
  • Recommended test values: rent 0.001 ETH, deposit 0.002 ETH, duration 120 seconds;
    skip time ≥ lease length before landlord withdraw.

EXAMPLE OUTPUT (WHAT "npm run demo" SHOULD LOOK LIKE)
-----------------------------------------------------
Below is real output shape from a successful run. Addresses may differ slightly
on your machine; the important part is small test deposit held (e.g. 0.002 ETH
fake), then 0 ETH in contract after withdraw, and depositReleased: true.

  ========== COMPILE & DEPLOY ==========
  Contract deployed at: 0x5FbDB2315678afecb367f032d93F642f64180aa3

  ========== REGISTER ROLES ==========
  Landlord registered: 0xf39F...
  Tenant registered:   0x7099...

  ========== CREATE & SIGN AGREEMENT ==========
  Agreement ID: 0 (first agreement)
  Tenant signed agreement.

  ========== DEPOSIT (tenant -> contract) ==========
  Contract ETH before deposit: 0.0
  Contract ETH after deposit:  0.002
  getHeldDeposit(agreementId):  0.002
  depositPaid (on-chain):       true

  ========== PAY RENT (tenant -> landlord) ==========
  Landlord balance increased by rent ... OK
  (approx rent) 0.001

  ========== ADVANCE TIME PAST endDate ==========
  Time moved past endDate so landlord can withdraw deposit.

  ========== WITHDRAW DEPOSIT (landlord <- contract) ==========
  Contract ETH before withdraw: 0.002
  Contract ETH after withdraw:  0.0 (deposit sent out)
  depositReleased (on-chain):    true

  ========== DONE — no errors ==========


KEY POINTS TO EXPLAIN (SECURITY & LOGIC)
----------------------------------------
• require() validates roles, amounts, signatures, and agreement state.
• ReentrancyGuard pattern protects payDeposit, payRent, withdrawDeposit.
• Deposit must equal msg.value exactly (no accidental under/overpayment).
• Rent is forwarded to the landlord with a low-level call; success is checked.
• Landlord withdraws deposit only after endDate unless early termination
  rules apply (tenant may claim deposit if landlord ended lease early).


REMIX IDE (ALTERNATIVE DEMO)
----------------------------
1. Open https://remix.ethereum.org
2. Create RentalAgreement.sol and copy the full contract source.
3. Compile with compiler 0.8.20+.
4. Deploy "RentalAgreement" on Remix VM.
5. Use two accounts: landlord does registerLandlord and createAgreement;
   tenant does registerTenant, signAgreement, payDeposit (set VALUE to exact
   deposit in wei), payRent (exact rent in wei).
6. To withdraw deposit as landlord after lease end: increase block time in the
   Remix VM past endDate, then call withdrawDeposit(0).
   If you skip increasing time, the contract correctly reverts — that is
   expected behavior, not a bug.


TROUBLESHOOTING
---------------
• "npm is not recognized" — Install Node.js and restart the terminal.
• Remix withdraw reverts with "term not ended" — Increase simulated time past
  endDate before withdrawDeposit (landlord path).
• payDeposit reverts with "wrong deposit amount" — Value sent must equal the
  depositAmount in the agreement exactly (in wei).

UI / MetaMask (common student mistakes)
• "could not decode result data" — You pasted a WALLET address as the contract.
  0xf39F…92266 is Hardhat ACCOUNT #0, not RentalAgreement. Paste the address
  printed after: npx hardhat run scripts/deploy.js --network localhost
• chainId 1 + "insufficient funds" — You are on Ethereum MAINNET. Add Hardhat
  network in MetaMask: RPC http://127.0.0.1:8545, chain ID 31337; run npx hardhat node.
• "Rental: agreement does not exist" — No lease created at that ID yet. Order:
  Tenant button → Landlord button → Tenant button. Or click Read nextAgreementId();
  if 0, create agreement first.


CONTACT / ACADEMIC USE
----------------------
This readme documents a student Rental Agreement DApp for demonstration and
grading. All commands were verified to run with: npm install, npm run compile,
npm run demo (exit code 0, no errors).


================================================================================
  End of readme.txt
================================================================================
