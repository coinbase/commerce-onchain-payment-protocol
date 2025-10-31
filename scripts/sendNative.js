require("dotenv").config();
const { ethers } = require("ethers");

(async () => {
  const {
    RPC_URL,
    CONTRACT_ADDRESS,
    OPERATOR_PRIVATE_KEY,
    PAYER_PRIVATE_KEY,
    RECIPIENT,
    REFUND_DESTINATION,
    RECIPIENT_AMOUNT_WEI,
    FEE_AMOUNT_WEI,
  } = process.env;

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const operator = new ethers.Wallet(OPERATOR_PRIVATE_KEY, provider);
  const payer = new ethers.Wallet(PAYER_PRIVATE_KEY, provider);

  const abi = [
    "function transferNative((uint256,uint256,address,address,address,uint256,bytes16,address,bytes,bytes)) external payable",
  ];
  const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, payer);

  const recipientAmount = BigInt(RECIPIENT_AMOUNT_WEI || ethers.parseEther("0.001"));
  const feeAmount = BigInt(FEE_AMOUNT_WEI || ethers.parseEther("0.0001"));
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
  const recipient = RECIPIENT;
  const refundDestination = REFUND_DESTINATION;
  const operatorAddr = await operator.getAddress();
  const senderAddr = await payer.getAddress();
  const chainId = BigInt((await provider.getNetwork()).chainId);
  const nativeCurrency = "0x0000000000000000000000000000000000000000";
  const idBytes16 = ethers.hexlify(ethers.randomBytes(16));

  const hash = ethers.solidityPackedKeccak256(
    [
      "uint256",
      "uint256",
      "address",
      "address",
      "address",
      "uint256",
      "bytes16",
      "address",
      "uint256",
      "address",
      "address",
    ],
    [
      recipientAmount,
      deadline,
      recipient,
      nativeCurrency,
      refundDestination,
      feeAmount,
      idBytes16,
      operatorAddr,
      chainId,
      senderAddr,
      CONTRACT_ADDRESS,
    ]
  );

  const signature = await operator.signMessage(ethers.getBytes(hash));

  const intentTuple = [
    recipientAmount,
    deadline,
    recipient,
    nativeCurrency,
    refundDestination,
    feeAmount,
    idBytes16,
    operatorAddr,
    signature,
    "0x",
  ];

  const value = recipientAmount + feeAmount;
  const tx = await contract.transferNative(intentTuple, { value });
  const receipt = await tx.wait();
  console.log(JSON.stringify({ txHash: receipt.hash, contract: CONTRACT_ADDRESS, value: value.toString() }));
})();
