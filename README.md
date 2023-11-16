# Coinbase Commerce Onchain Payment Protocol

The Coinbase Commerce Onchain Payment Protocol allows payers and merchants to transact using the blockchain as a settlement layer and source of truth.
It provides the following benefits over "traditional" cryptocurrency payments:

- Guaranteed settlement: merchants always receive exactly the amount that they request.
- Automatic conversion: payers can pay with any token that has liquidity on Uniswap, without exposing merchants to price volatility.
- Removal of payment errors: it is no longer possible to pay the wrong amount or to the wrong address.

### Contract Deployments

As of November 15, 2023, the Commerce Onchain Payment Protocol is deployed in the following locations:

| Chain    | Environment    | Address                                      |
|----------|----------------|----------------------------------------------|
| Ethereum | Mainnet        | `0x131642c019AF815Ae5F9926272A70C84AE5C37ab` |
| Ethereum | Goerli Testnet | `0x6F4bf00C7f081c5671A263bb65702c45B8dD9890` |
| Polygon  | Mainnet        | `0x48073112c8C48e2550Bd42E4CD0aA483a416c5af` |
| Polygon  | Mumbai Testnet | `0xeF0D482Daa16fa86776Bc582Aff3dFce8d9b8396` |
| Base     | Mainnet        | `0x30E95edE0b3C7Ef147EE97A5e88FdE06311EA11f` |
| Base     | Goerli Testnet | `0x71B3Ba7607Abd0cd35EB398c2a38313f10aa3FdB` |

### Browsing this Repo

The core source code can be found in [Transfers.sol](contracts/transfers/Transfers.sol).

Excluded from this repo is a copy of [Uniswap/permit2](https://github.com/Uniswap/permit2),
which would be copied to `contracts/permit2` in order to compile.