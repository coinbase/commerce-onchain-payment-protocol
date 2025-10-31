require("dotenv").config();
const hre = require("hardhat");

async function main() {
  const {
    UNISWAP_UNIVERSAL_ROUTER,
    PERMIT2_ADDRESS,
    WRAPPED_NATIVE_ADDRESS,
    INITIAL_OPERATOR,
    INITIAL_FEE_DESTINATION,
  } = process.env;

  if (
    !UNISWAP_UNIVERSAL_ROUTER ||
    !PERMIT2_ADDRESS ||
    !WRAPPED_NATIVE_ADDRESS ||
    !INITIAL_OPERATOR ||
    !INITIAL_FEE_DESTINATION
  ) {
    throw new Error("Missing one or more environment variables");
  }

  const Transfers = await hre.ethers.getContractFactory("Transfers");
  const transfers = await Transfers.deploy(
    UNISWAP_UNIVERSAL_ROUTER,
    PERMIT2_ADDRESS,
    INITIAL_OPERATOR,
    INITIAL_FEE_DESTINATION,
    WRAPPED_NATIVE_ADDRESS
  );
  await transfers.waitForDeployment();

  const address = await transfers.getAddress();
  const tx = transfers.deploymentTransaction();
  if (tx) await tx.wait(5);

  console.log("Transfers deployed to:", address);

  try {
    await hre.run("verify:verify", {
      address,
      constructorArguments: [
        UNISWAP_UNIVERSAL_ROUTER,
        PERMIT2_ADDRESS,
        INITIAL_OPERATOR,
        INITIAL_FEE_DESTINATION,
        WRAPPED_NATIVE_ADDRESS,
      ],
    });
    console.log("Contract verified successfully");
  } catch (e) {
    console.error("Verification failed:", e.message);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
