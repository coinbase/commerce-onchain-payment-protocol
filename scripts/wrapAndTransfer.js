require("dotenv").config();
const { ethers } = require("ethers");

(async () => {
  const RPC_URL = process.env.RPC_URL || process.env.SEPOLIA_RPC_URL;
  const {
    CONTRACT_ADDRESS,
    OPERATOR_PRIVATE_KEY,
    PAYER_PRIVATE_KEY,
    RECIPIENT,
    REFUND_DESTINATION,
    WRAPPED_NATIVE_ADDRESS,
    RECIPIENT_AMOUNT_WEI,
    FEE_AMOUNT_WEI,
  } = process.env;

  if (!RPC_URL) throw new Error("RPC_URL/SEPOLIA_RPC_URL not set");
  if (!CONTRACT_ADDRESS) throw new Error("CONTRACT_ADDRESS not set");
  if (!WRAPPED_NATIVE_ADDRESS) throw new Error("WRAPPED_NATIVE_ADDRESS not set");
  if (!OPERATOR_PRIVATE_KEY || !PAYER_PRIVATE_KEY) throw new Error("Missing private keys");
  if (!RECIPIENT || !REFUND_DESTINATION) throw new Error("Missing recipient/refund");

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const operator = new ethers.Wallet(OPERATOR_PRIVATE_KEY, provider);
  const payer = new ethers.Wallet(PAYER_PRIVATE_KEY, provider);

  const abi = [
    "function wrapAndTransfer((uint256,uint256,address,address,address,uint256,bytes16,address,bytes,bytes)) external payable",
  ];
  const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, payer);

  const recipientAmount = BigInt(RECIPIENT_AMOUNT_WEI || ethers.parseEther("0.001"));
  const feeAmount = BigInt(FEE_AMOUNT_WEI || ethers.parseEther("0.0001"));
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
  const nativeCurrency = "0x0000000000000000000000000000000000000000";
  const idBytes16 = ethers.hexlify(ethers.randomBytes(16));

  const operatorAddr = await operator.getAddress();
  const senderAddr = await payer.getAddress();
  const chainId = BigInt((await provider.getNetwork()).chainId);

  const hash = ethers.solidityPackedKeccak256(
    [
      "uint256","uint256","address","address","address","uint256",
      "bytes16","address","uint256","address","address",
    ],
    [
      recipientAmount,deadline,RECIPIENT,WRAPPED_NATIVE_ADDRESS,REFUND_DESTINATION,
      feeAmount,idBytes16,operatorAddr,chainId,senderAddr,CONTRACT_ADDRESS,
    ]
  );

  const signature = await operator.signMessage(ethers.getBytes(hash));

  const intent = [
    recipientAmount,
    deadline,
    RECIPIENT,
    WRAPPED_NATIVE_ADDRESS,
    REFUND_DESTINATION,
    feeAmount,
    idBytes16,
    operatorAddr,
    signature,
    "0x",
  ];

  const value = recipientAmount + feeAmount;
  const tx = await contract.wrapAndTransfer(intent, { value });
  const receipt = await tx.wait();
  console.log(JSON.stringify({ txHash: receipt.hash, value: value.toString() }));
})();
