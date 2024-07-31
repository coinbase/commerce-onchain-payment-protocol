// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../permit2/src/interfaces/ISignatureTransfer.sol";

// @notice Description of the transfer
// @member recipientAmount Amount of currency to transfer
// @member deadline The timestamp by when the transfer must be in a block.
// @member chainId The chain which the transfer must occur on.
// @member recipient The address which will receive the funds.
// @member recipientCurrency The currency address that amount is priced in.
// @member refundDestination The address which will receive any refunds. If blank, this will be msg.sender.
// @member feeAmount The fee value (in currency) to send to the operator.
// @member id An ID which can be used to track payments.
// @member operator The address of the operator (who created and signed the intent).
// @member signature A hash of all the other struct properties signed by the operator.
// @member prefix An alternate signature prefix to use instead of the standard EIP-191 "\x19Ethereum Signed Message:\n"
// @dev signature=keccak256(encodePacked(...allPropsInOrderExceptSignatureAndPrefix, chainId, _msgSender(), address(transfersContract))
struct TransferIntent {
    uint256 recipientAmount;
    uint256 deadline;
    address payable recipient;
    address recipientCurrency;
    address refundDestination;
    uint256 feeAmount;
    bytes16 id;
    address operator;
    bytes signature;
    bytes prefix;
}

struct Permit2SignatureTransferData {
    ISignatureTransfer.PermitTransferFrom permit;
    ISignatureTransfer.SignatureTransferDetails transferDetails;
    bytes signature;
}

struct EIP2612SignatureTransferData {
    address owner; // The owner of the funds
    bytes signature; // The signature for the permit
}

// @title Transfers Contract
// @notice Functions for making checked transfers between accounts
interface ITransfers {
    // @notice Emitted when a transfer is completed
    // @param operator The operator for the transfer intent
    // @param id The ID of the transfer intent
    // @param recipient Who recieved the funds.
    // @param sender Who sent the funds.
    // @param spentAmount How much the payer sent
    // @param spentCurrency What currency the payer sent
    event Transferred(
        address indexed operator,
        bytes16 id,
        address recipient,
        address sender,
        uint256 spentAmount,
        address spentCurrency
    );

    // @notice Raised when a native currency transfer fails
    // @param recipient Who the transfer was intended for
    // @param amount The amount of the transfer
    // @param isRefund Whether the transfer was part of a refund
    // @param data The data returned from the failed call
    error NativeTransferFailed(address recipient, uint256 amount, bool isRefund, bytes data);

    // @notice Emitted when an operator is registered
    // @param operator The operator that was registered
    // @param feeDestination The new fee destination for the operator
    event OperatorRegistered(address operator, address feeDestination);

    // @notice Emitted when an operator is unregistered
    // @param operator The operator that was registered
    event OperatorUnregistered(address operator);

    // @notice Raised when the operator in the intent is not registered
    error OperatorNotRegistered();

    // @notice Raised when the intent signature is invalid
    error InvalidSignature();

    // @notice Raised when the invalid amount of native currency is provided
    // @param difference The surplus (or deficit) amount sent
    error InvalidNativeAmount(int256 difference);

    // @notice Raised when the payer does not have enough of the payment token
    // @param difference The balance deficit
    error InsufficientBalance(uint256 difference);

    // @notice Raised when the payer has not approved enough of the payment token
    // @param difference The allowance deficit
    error InsufficientAllowance(uint256 difference);

    // @notice Raised when providing an intent with the incorrect currency. e.g. a USDC intent to `wrapAndTransfer`
    // @param attemptedCurrency The currency the payer attempted to pay with
    error IncorrectCurrency(address attemptedCurrency);

    // @notice Raised when the permit2 transfer details are incorrect
    error InvalidTransferDetails();

    // @notice Raised when an intent is paid past its deadline
    error ExpiredIntent();

    // @notice Raised when an intent's recipient is the null address
    error NullRecipient();

    // @notice Raised when an intent has already been processed
    error AlreadyProcessed();

    // @notice Raised when a transfer does not result in the correct balance increase,
    // such as with fee-on-transfer tokens
    error InexactTransfer();

    // @notice Raised when a swap fails and returns a reason string
    // @param reason The error reason returned from the swap
    error SwapFailedString(string reason);

    // @notice Raised when a swap fails and returns another error
    // @param reason The error reason returned from the swap
    error SwapFailedBytes(bytes reason);

    // @notice Send the exact amount of the native currency from the sender to the recipient.
    // @dev The intent's recipient currency must be the native currency.
    // @param _intent The intent which describes the transfer
    function transferNative(TransferIntent calldata _intent) external payable;

    // @notice Transfer the exact amount of any ERC-20 token from the sender to the recipient.
    // @dev The intent's recipient currency must be an ERC-20 token matching the one in `_signatureTransferData`.
    // @dev The user must have approved the Permit2 contract for at least `_intent.recipientAmount + _intent.feeAmount`
    //      with the `_intent.recipientCurrency` ERC-20 contract prior to invoking.
    // @param _intent The intent which describes the transfer
    function transferToken(
        TransferIntent calldata _intent,
        Permit2SignatureTransferData calldata _signatureTransferData
    ) external;

    // @notice Transfer the exact amount of any ERC-20 token from the sender to the recipient.
    // @dev The intent's recipient currency must be an ERC-20 token.
    // @dev The user must have approved this contract for at least `_intent.recipientAmount + _intent.feeAmount`
    //      with the `_intent.recipientCurrency` ERC-20 contract prior to invoking.
    // @param _intent The intent which describes the transfer
    function transferTokenPreApproved(TransferIntent calldata _intent) external;

    // @notice Takes native currency (e.g. ETH) from the sender and sends wrapped currency (e.g. wETH) to the recipient.
    // @dev The intent's recipient currency must be the wrapped native currency.
    // @param _intent The intent which describes the transfer
    function wrapAndTransfer(TransferIntent calldata _intent) external payable;

    // @notice Takes wrapped currency (e.g. wETH) from the sender and sends native currency (e.g. ETH) to the recipient.
    // @dev The intent's recipient currency must be the native currency.
    // @dev The user must have approved the Permit2 contract for at least `_intent.recipientAmount + _intent.feeAmount`
    //      with the wETH contract prior to invoking.
    // @param _intent The intent which describes the transfer
    // @param _signatureTransferData The signed Permit2 transfer data for the payment
    function unwrapAndTransfer(
        TransferIntent calldata _intent,
        Permit2SignatureTransferData calldata _signatureTransferData
    ) external;

    // @notice Takes wrapped currency (e.g. wETH) from the sender and sends native currency (e.g. ETH) to the recipient.
    // @dev The intent's recipient currency must be the native currency.
    // @dev The user must have approved this contract for at least `_intent.recipientAmount + _intent.feeAmount` with the wETH contract prior to invoking.
    // @param _intent The intent which describes the transfer
    function unwrapAndTransferPreApproved(TransferIntent calldata _intent) external;

    // @notice Allows the sender to pay for an intent with a swap from the native currency using Uniswap.
    // @param _intent The intent which describes the transfer
    // @param poolFeesTier The Uniswap pool fee the user wishes to pay. See: https://docs.uniswap.org/protocol/concepts/V3-overview/fees#pool-fees-tiers
    function swapAndTransferUniswapV3Native(TransferIntent calldata _intent, uint24 poolFeesTier) external payable;

    // @notice Allows the sender to pay for an intent with a swap from any ERC-20 token using Uniswap.
    // @dev The user must have approved the Permit2 contract for at least `_signatureTransferData.transferDetails.requestedAmount`
    //      with the `_signatureTransferData.permit.permitted.token` ERC-20 contract prior to invoking.
    // @param _intent The intent which describes the transfer
    // @param _signatureTransferData The signed Permit2 transfer data for the payment
    // @param poolFeesTier The Uniswap pool fee the user wishes to pay. See: https://docs.uniswap.org/protocol/concepts/V3-overview/fees#pool-fees-tiers
    function swapAndTransferUniswapV3Token(
        TransferIntent calldata _intent,
        Permit2SignatureTransferData calldata _signatureTransferData,
        uint24 poolFeesTier
    ) external;

    // @notice Allows the sender to pay for an intent with a swap from any ERC-20 token using Uniswap.
    // @dev The user must have approved this contract for at least `maxWillingToPay` with the `_tokenIn` ERC-20 contract prior to invoking.
    // @param _intent The intent which describes the transfer
    // @param _tokenIn The currency address which the sender wishes to pay for the intent.
    // @param maxWillingToPay The maximum amount of _tokenIn the sender is willing to pay.
    // @param poolFeesTier The Uniswap pool fee the user wishes to pay. See: https://docs.uniswap.org/protocol/concepts/V3-overview/fees#pool-fees-tiers
    function swapAndTransferUniswapV3TokenPreApproved(
        TransferIntent calldata _intent,
        address _tokenIn,
        uint256 maxWillingToPay,
        uint24 poolFeesTier
    ) external;

    // @notice Allows the sender to pay for an intent with gasless transaction
    // @param _intent The intent which describes the transfer
    // @param _signatureTransferData The signed EIP-2612 permit data for the payment
    function subsidizedTransferToken(
        TransferIntent calldata _intent,
        EIP2612SignatureTransferData calldata _signatureTransferData
    ) external;
}
