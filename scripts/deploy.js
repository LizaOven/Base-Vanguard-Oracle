const hre = require("hardhat");
async function main() {
  const VaultData = await hre.ethers.getContractFactory("VanguardOracleVault");
  const vault = await VaultData.deploy();
  await vault.deployed();
  console.log("Vanguard Oracle Vault deployed securely to:", vault.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
