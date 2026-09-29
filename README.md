# Ammalgam Deployments

Latest `core-v1` and `peripheral` contract deployed addresses, ABIs and interfaces.

> **Chain IDs**
> - Sepolia (testnet) — chain ID `11155111`
> - Ethereum mainnet — chain ID `1`
>
> Every address below is on the chain named in its section heading. Verify the
> chain ID in your wallet before signing anything against these addresses.

## Sepolia

### v0.11.0

| Name                   | Address                                                                                                                                        | Interface                                                                              | ABI                                                            |
|------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------|----------------------------------------------------------------|
| Ammalgam Factory       | [`0x5a6A9C26587F80eF235903e6de814cB35CF26307`](https://sepolia.etherscan.io/address/0x5a6A9C26587F80eF235903e6de814cB35CF26307)                  | [IAmmalgamFactory](./interfaces/factories/IAmmalgamFactory.sol)                          | [AmmalgamFactory.json](./abis/AmmalgamFactory.json)            |
| Ammalgam Peripheral    | [`0xAfFC6c525660480dA9656165490aA9c27E5ea9B3`](https://sepolia.etherscan.io/address/0xAfFC6c525660480dA9656165490aA9c27E5ea9B3)                  | [IPeripheral](./interfaces/IPeripheral.sol)                                              | [AmmalgamPeripheral.json](./abis/AmmalgamPeripheral.json)      |
| Ammalgam Pair Creator  | [`0x4194bF08fb7Ff37e96715492a5a713A44Ada272E`](https://sepolia.etherscan.io/address/0x4194bF08fb7Ff37e96715492a5a713A44Ada272E)                  | [IPairCreator](./interfaces/IPairCreator.sol)                                            | [AmmalgamPairCreator.json](./abis/AmmalgamPairCreator.json)    |
| Ammalgam Swap Helper   | [`0xd84A2e3D5f68e299823b44557102bF2BfdC16185`](https://sepolia.etherscan.io/address/0xd84A2e3D5f68e299823b44557102bF2BfdC16185)                  | [IPeripheralSwapHelper](./interfaces/IPeripheralSwapHelper.sol)                          | [AmmalgamSwapHelper.json](./abis/AmmalgamSwapHelper.json)      |
| Ammalgam TWAP State    | [`0xf0E5Ec52B0F03A9ef5B1F12F1789Df3A1818C5B7`](https://sepolia.etherscan.io/address/0xf0E5Ec52B0F03A9ef5B1F12F1789Df3A1818C5B7)                  | _not published in this repository_                                                       | _not published in this repository_                             |

The TWAP State contract is deployed but neither its interface nor its ABI has
been published here yet. Treat the address above as unverified against any
artifact in this repository and do not build against it from here.

> **Known divergence — read before indexing.**
> The `subgraph` repository's `config.yaml` indexes a *different* Sepolia
> factory, `0xbf3367206d684fbf4b27b56624a64d4933ee111d` (chain ID `11155111`,
> start block `11185304`). The factory address published above
> (`0x5a6A9C26587F80eF235903e6de814cB35CF26307`) is **not** the one the indexer
> reads. Both cannot be current. Until the team reconciles them, confirm on the
> Sepolia explorer which factory corresponds to the `core-v1` version you intend
> to integrate, and record the deployment block alongside the address.

## What this repository contains

`interfaces/` holds the `core-v1` and `peripheral` interfaces; `abis/` holds the
compiled ABIs. The ABIs are the authoritative artifact for calldata encoding and
log decoding. The `.sol` files are a convenience for `import` in your own
project and are kept in sync with the ABIs, but a mismatch is possible — when in
doubt, encode against the ABI.

To compile the interfaces, copy `remappings.txt` into your project root (or pass
its contents to your build tool). The interfaces import OpenZeppelin from
`node_modules`, so `@openzeppelin/contracts` must be a dependency.

### Verifying the interfaces against the ABIs

`verify_abi_consistency.cjs` compiles the `.sol` files with `solc` and diffs the
result against the published JSON ABIs. It exists because a struct that is
missing or reordered in a `.sol` file still compiles cleanly but produces
calldata that decodes to different values than the caller intended — the defect
is invisible to the compiler and to review, and only a structural diff of the two
artifacts catches it.

```sh
# requires a solc >= 0.8.28 binary on PATH, or set SOLC_PATH
SOLC_PATH=/path/to/solc npm run verify:abi
```

Only *types* are compared. Parameter and component names are cosmetic: they do
not enter the function selector and do not change the calldata layout, so a
naming difference is reported but is not a failure.

### Core contracts

The main two contracts are the [IAmmalgamFactory](./interfaces/factories/IAmmalgamFactory.sol)
and the [IAmmalgamPair](./interfaces/IAmmalgamPair.sol). The pair follows the
general shape of the Uniswap V2 factory/pair design, but it is **not** ABI
compatible with Uniswap V2: `getReserves()` returns
`(uint112, uint112, uint256)`, and the pair adds `borrow`, `borrowLiquidity`,
`repay`, `repayLiquidity`, `getTickRange` and `updateExternalLiquidity`, none of
which have a V2 analogue. Do not assume a V2 integration will drop in.

`IAmmalgamPair` inherits [ITokenController](./interfaces/tokens/ITokenController.sol),
which exposes the per-token accounting the pair maintains.

### Lending tokens

The pair mints 6 token types, one per possible position: `DEPOSIT_L`,
`DEPOSIT_X`, `DEPOSIT_Y`, `BORROW_L`, `BORROW_X`, `BORROW_Y`. Their interfaces
are in the [tokens folder](./interfaces/tokens) and their ABIs are
[IAmmalgamERC20.json](./abis/IAmmalgamERC20.json) (L/X/Y share tokens),
[IAmmalgamERC20Debt.json](./abis/IAmmalgamERC20Debt.json) and
[IAmmalgamERC4626.json](./abis/IAmmalgamERC4626.json).

### Callbacks

[IAmmalgamCallee](./interfaces/callbacks/IAmmalgamCallee.sol) lets a callee run
operations in the middle of `swap`, `borrow` and `borrowLiquidity`.

## Licensing

The `.sol` files carry SPDX `GPL-3.0-only` headers, except
[interfaces/tokens/IPluginRegistry.sol](./interfaces/tokens/IPluginRegistry.sol)
which carries `MIT`. **This repository has no top-level `LICENSE` file, and the
two SPDX identifiers are not reconciled.** GPL-3.0 is copyleft: importing these
interfaces into your own contract can place obligations on the combined work.

If you intend to integrate, obtain a written clarification of the license from
the Ammalgam team before relying on these files commercially. Nothing in this
repository should be read as legal advice.

## Questions

If you have additional questions please reach out on Discord, and we will attempt
to help.
