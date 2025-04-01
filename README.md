# Coinbase Commerce Onchain Payment Protocol

The Coinbase Commerce Onchain Payment Protocol allows payers and merchants to transact using the blockchain as a settlement layer and source of truth.
It provides the following benefits over "traditional" cryptocurrency payments:

- Guaranteed settlement: merchants always receive exactly the amount that they request.
- Automatic conversion: payers can pay with any token that has liquidity on Uniswap, without exposing merchants to price volatility.
- Removal of payment errors: it is no longer possible to pay the wrong amount or to the wrong address.

### Contract Deployments

As of July 31, 2024, the Commerce Onchain Payment Protocol is deployed in the following locations:

| Chain    | Environment     | Address                                      |
| -------- | --------------- | -------------------------------------------- |
| Ethereum | Mainnet         | `0x1DAe28D7007703196d6f456e810F67C33b51b25C` |
| Ethereum | Sepolia Testnet | `0x96A08D8e8631b6dB52Ea0cbd7232d9A85d239147` |
| Polygon  | Mainnet         | `0xc2252Ce3348B8dAf90583E53e07Be53d3aE728FB` |
| Polygon  | Amoy Testnet    | `0x1A8f790a10D26bAd97dB8Da887D212eA49461cCC` |
| Base     | Mainnet         | `0xeADE6bE02d043b3550bE19E960504dbA14A14971` |
| Base     | Sepolia Testnet | `0x96A08D8e8631b6dB52Ea0cbd7232d9A85d239147` |

Since the contract is non-upgradeable, these addresses will change when new
versions are deployed.

### Browsing this Repo

The core source code can be found in [Transfers.sol](contracts/transfers/Transfers.sol).

Excluded from this repo is a copy of [Uniswap/permit2](https://github.com/Uniswap/permit2),
which would be copied to `contracts/permit2` in order to compile.

## Overview

### Operators

The Transfers contract facilitates payments from a payer to a merchant. Before
it may be used, an "operator" must register with the contract and specify
a destination for fees. This operator is responsible for setting merchants up
with the protocol and providing a UI for both merchants and payers to interact
with it. Registering as an operator is permissionless, and Coinbase maintains
control of an address used as the operator for Coinbase Commerce.

### Transfer Intents

Once an operator is registered, they may begin facilitating payments. Individual
payments use a primitive called a `TransferIntent`, represented by a Solidity
struct of the same name. This struct specifies the following:

- The merchant's address
- The currency the merchant wishes to receive
- The amount of that currency the merchant wishes to receive
- The deadline by which the payment must be made
- The payer's address
- The chain the payer will pay on
- The address any refund should be directed to
- The operator who is facilitating the payment
- The fee the operator should receive
- A unique identifier for identifying the payment
- A signature (and optional signature prefix) from the operator

Along with these attributes, a `TransferIntent` must be signed by the operator.
This allows an operator to be selective about what payments to allow based on
internal policies, legal requirements, or other reasons. It also ensures that
a `TransferIntent` cannot be forged or have its data modified in any way.

### Contract Guarantees

The contract ensures that, for a given valid `TransferIntent`:

- The merchant always receives the exact amount requested
- The merchant never receives payments past a stated deadline
- The merchant never receives more than one payment
- Payments may be made using the merchant's requested currency, or swapped from
  another token as part of the payment transaction
- Unsuccessful or partial payments will never reach the merchant, thus
  guaranteeing that payments are atomic. Either the merchant is correctly paid
  in full and the fee is correctly charged, or the transaction reverts and no
  state is changed onchain.

### Contract payment methods

Depending on the settlement token and the input token, along with the way
in which the payer allows movement of their input token, a frontend must select
the appropriate method by which to pay a `TransferIntent`. These methods are:

- `transferNative`: The merchant wants ETH and the payer wants to pay ETH
- `transferToken`: The merchant wants a token and the payer wants to pay with
  that token. Uses Permit2 for token movement.
- `transferTokenPreApproved`: Same as `transferToken`, except the Transfers
  contract is directly approved by the payer for the payment token
- `wrapAndTransfer`: The merchant wants WETH and the payer wants to pay ETH
- `unwrapAndTransfer`: The merchant wants ETH and the payer wants to pay WETH
- `unwrapAndTransferPreApproved`: Same as `unwrapAndTransfer`, except the
  Transfers contract is directly approved by the payer for WETH
- `swapAndTransferUniswapV3Native`: The merchant wants a token and the payer
  wants to pay ETH. The token must have sufficient liquidity with ETH on Uniswap
  V3.
- `swapAndTransferUniswapV3Token`: The merchant wants either ETH or a token and
  the payer wants to pay with a different token. The payment token must have
  sufficient liquidity with the settlement token on Uniswap V3.
- `swapAndTransferUniswapV3TokenPreApproved`: Same as
  `swapAndTransferUniswapV3Token`, except the Transfers contract is directly
  approved by the payer for the payment token

For any EVM-compatible network where ETH is not the native/gas currency, the
above descriptions should substitute that currency. For example, payments on
Polygon would use MATIC in the above descriptions.

### Payment Transaction Results

When the payment is successful, a `Transferred` event is emitted by the contract
with details about:

- The operator address
- The unique id of the `TransferIntent`
- The merchant (recipient) address
- The payer (sender) address
- The input token that was spent by the payer
- The amount of the input token spent by the payer

In the case of errors, a specific error type is returned with details about what
went wrong.

## Detailed Explanations and Examples for Each Function in `contracts/transfers/Transfers.sol`

### `transferNative`

The `transferNative` function handles native currency transfers. It ensures that the recipient receives the exact amount of native currency specified in the `TransferIntent`.

Example usage:
```solidity
TransferIntent memory intent = TransferIntent({
    recipientAmount: 1 ether,
    deadline: block.timestamp + 1 days,
    recipient: payable(0xRecipientAddress),
    recipientCurrency: address(0),
    refundDestination: address(0),
    feeAmount: 0.01 ether,
    id: bytes16(0),
    operator: 0xOperatorAddress,
    signature: bytes(""),
    prefix: bytes("")
});

transfersContract.transferNative{value: 1.01 ether}(intent);
```

### `transferToken`

The `transferToken` function handles ERC-20 token transfers. It ensures that the recipient receives the exact amount of tokens specified in the `TransferIntent`.

Example usage:
```solidity
TransferIntent memory intent = TransferIntent({
    recipientAmount: 1000 * 10**18,
    deadline: block.timestamp + 1 days,
    recipient: payable(0xRecipientAddress),
    recipientCurrency: 0xTokenAddress,
    refundDestination: address(0),
    feeAmount: 10 * 10**18,
    id: bytes16(0),
    operator: 0xOperatorAddress,
    signature: bytes(""),
    prefix: bytes("")
});

Permit2SignatureTransferData memory signatureTransferData = Permit2SignatureTransferData({
    permit: ISignatureTransfer.PermitTransferFrom({
        permitted: ISignatureTransfer.Permit({
            token: 0xTokenAddress,
            amount: 1010 * 10**18
        }),
        nonce: 0,
        deadline: block.timestamp + 1 days
    }),
    transferDetails: ISignatureTransfer.SignatureTransferDetails({
        to: address(transfersContract),
        requestedAmount: 1010 * 10**18
    }),
    signature: bytes("")
});

transfersContract.transferToken(intent, signatureTransferData);
```

### `unwrapAndTransfer`

The `unwrapAndTransfer` function handles wrapped native currency transfers. It ensures that the recipient receives the exact amount of native currency specified in the `TransferIntent`.

Example usage:
```solidity
TransferIntent memory intent = TransferIntent({
    recipientAmount: 1 ether,
    deadline: block.timestamp + 1 days,
    recipient: payable(0xRecipientAddress),
    recipientCurrency: address(0),
    refundDestination: address(0),
    feeAmount: 0.01 ether,
    id: bytes16(0),
    operator: 0xOperatorAddress,
    signature: bytes(""),
    prefix: bytes("")
});

Permit2SignatureTransferData memory signatureTransferData = Permit2SignatureTransferData({
    permit: ISignatureTransfer.PermitTransferFrom({
        permitted: ISignatureTransfer.Permit({
            token: 0xWrappedNativeCurrencyAddress,
            amount: 1.01 ether
        }),
        nonce: 0,
        deadline: block.timestamp + 1 days
    }),
    transferDetails: ISignatureTransfer.SignatureTransferDetails({
        to: address(transfersContract),
        requestedAmount: 1.01 ether
    }),
    signature: bytes("")
});

transfersContract.unwrapAndTransfer(intent, signatureTransferData);
```

### `swapAndTransferUniswapV3Native`

The `swapAndTransferUniswapV3Native` function handles swaps from native currency to another token. It ensures that the recipient receives the exact amount of tokens specified in the `TransferIntent`.

Example usage:
```solidity
TransferIntent memory intent = TransferIntent({
    recipientAmount: 1000 * 10**18,
    deadline: block.timestamp + 1 days,
    recipient: payable(0xRecipientAddress),
    recipientCurrency: 0xTokenAddress,
    refundDestination: address(0),
    feeAmount: 10 * 10**18,
    id: bytes16(0),
    operator: 0xOperatorAddress,
    signature: bytes(""),
    prefix: bytes("")
});

transfersContract.swapAndTransferUniswapV3Native{value: 1.01 ether}(intent, 3000);
```

### `swapAndTransferUniswapV3Token`

The `swapAndTransferUniswapV3Token` function handles swaps from one token to another. It ensures that the recipient receives the exact amount of tokens specified in the `TransferIntent`.

Example usage:
```solidity
TransferIntent memory intent = TransferIntent({
    recipientAmount: 1000 * 10**18,
    deadline: block.timestamp + 1 days,
    recipient: payable(0xRecipientAddress),
    recipientCurrency: 0xTokenAddress,
    refundDestination: address(0),
    feeAmount: 10 * 10**18,
    id: bytes16(0),
    operator: 0xOperatorAddress,
    signature: bytes(""),
    prefix: bytes("")
});

Permit2SignatureTransferData memory signatureTransferData = Permit2SignatureTransferData({
    permit: ISignatureTransfer.PermitTransferFrom({
        permitted: ISignatureTransfer.Permit({
            token: 0xTokenInAddress,
            amount: 1010 * 10**18
        }),
        nonce: 0,
        deadline: block.timestamp + 1 days
    }),
    transferDetails: ISignatureTransfer.SignatureTransferDetails({
        to: address(transfersContract),
        requestedAmount: 1010 * 10**18
    }),
    signature: bytes("")
});

transfersContract.swapAndTransferUniswapV3Token(intent, signatureTransferData, 3000);
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: Transfer fails with `InvalidSignature` error

**Solution:** Ensure that the `TransferIntent` is correctly signed by the operator. Verify that the signature and prefix (if any) are correct.

#### Issue: Transfer fails with `ExpiredIntent` error

**Solution:** Ensure that the `TransferIntent` has not passed its deadline. The `deadline` field should be a future timestamp.

#### Issue: Transfer fails with `NullRecipient` error

**Solution:** Ensure that the `recipient` field in the `TransferIntent` is not the zero address.

#### Issue: Transfer fails with `AlreadyProcessed` error

**Solution:** Ensure that the `TransferIntent` has not already been processed. Each `TransferIntent` should have a unique `id`.

#### Issue: Transfer fails with `IncorrectCurrency` error

**Solution:** Ensure that the `recipientCurrency` field in the `TransferIntent` matches the expected currency for the transfer function being used.

#### Issue: Transfer fails with `InsufficientBalance` error

**Solution:** Ensure that the payer has enough balance of the specified currency to cover the `recipientAmount` and `feeAmount`.

#### Issue: Transfer fails with `InsufficientAllowance` error

**Solution:** Ensure that the payer has approved the necessary allowance for the transfer function being used.

#### Issue: Transfer fails with `InexactTransfer` error

**Solution:** Ensure that the transfer amount matches the expected amount. This error can occur with fee-on-transfer tokens.

#### Issue: Swap fails with `SwapFailedString` or `SwapFailedBytes` error

**Solution:** Ensure that the swap parameters are correct and that there is sufficient liquidity on Uniswap V3 for the swap. Verify the error message for more details.
