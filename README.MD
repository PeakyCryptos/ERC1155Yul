# ERC1155Yul

An educational implementation of core ERC-1155 behavior written directly in
Yul. The token runtime handles selector dispatch, ABI decoding, storage,
events, balance accounting, approvals, transfers, receiver callbacks, minting,
and burning without a Solidity token implementation.

Solidity is used only for the receiver mock and surrounding Hardhat test
harness. This project is intended to demonstrate EVM-level implementation
details; it is not audited or intended for production use.

## Why Yul

ERC-1155 is a useful surface for exploring more than arithmetic opcodes. A
correct implementation needs to handle dynamic arrays and bytes, nested
mappings, event encoding, contract detection, external callback return values,
and authorization across both single and batch operations.

The project makes those mechanisms explicit instead of relying on Solidity's
generated dispatcher and ABI encoder.

## Implemented behavior

- `uri`
- `balanceOf` and `balanceOfBatch`
- `setApprovalForAll` and `isApprovedForAll`
- `safeTransferFrom` and `safeBatchTransferFrom`
- single and batch minting
- single and batch burning
- `TransferSingle`, `TransferBatch`, and `ApprovalForAll` events
- `onERC1155Received` and `onERC1155BatchReceived` acceptance checks
- nested balance and operator-approval mappings
- dynamic-array and byte-string calldata decoding
- checked balance arithmetic

Minting also has two deliberate non-standard constraints: a price per token and
a maximum quantity per token ID in one mint operation.

## Runtime structure

The Yul runtime uses a selector switch followed by internal functions for ABI
decoding, storage access, events, and receiver callbacks.

```text
calldata
   |
   v
selector dispatcher
   |
   +-- static/dynamic ABI decoding
   +-- authorization and input checks
   +-- nested mapping reads/writes
   +-- event encoding
   +-- ERC-1155 receiver callback validation
```

### Storage layout

| Slot | Purpose |
|---:|---|
| `0` | Deployer/owner value |
| `1` | Mint price per token |
| `2` | Maximum amount per token ID in one mint |
| `3` | Root slot for `balances[tokenId][account]` |
| `4` | Root slot for `operatorApprovals[account][operator]` |
| `5+` | Length and data words for the shared metadata URI |

## Tests

The suite adapts OpenZeppelin-style ERC-1155 behavior tests and adds coverage
for the custom mint and burn paths.

```bash
# Hardhat 2.12 supports Node.js 18.
npm ci
npm test
```

Current result:

```text
51 passing
```

Coverage includes:

- zero-address and array-length validation;
- single and batch balance accounting;
- operator authorization;
- transfer and batch-transfer behavior;
- receiver success, wrong-selector, revert, and missing-interface cases;
- single and batch minting and burning;
- emitted events; and
- shared metadata URI behavior.

## Repository map

```text
contracts/ERC1155/ERC1155.yul          Yul creation and runtime code
contracts/ERC1155/ERC1155ByteCode.json deployable bytecode used by tests
contracts/ERC1155/ERC1155ReceiverMock.sol
abis/ERC1155/ERC1155ABI.json
test/ERC1155.behavior.js                compatibility behavior suite
test/ERC1155.test.js                    mint, burn, and metadata tests
```

## Deliberate limitations

- The runtime does not expose ERC-165 `supportsInterface`, so this repository
  should not be described as a fully compliant drop-in ERC-1155 implementation.
- Mint price and per-ID mint limits are application-specific extensions.
- The URI is fixed in the current bytecode.
- Reverts generally do not include human-readable reason strings.
- The committed bytecode and test harness target the historical toolchain in
  `package-lock.json`.
- The code has not received an external security audit.

For production contracts, use a maintained and audited implementation such as
OpenZeppelin Contracts.
