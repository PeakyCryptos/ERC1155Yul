# Intro

Fully compliant custom ERC1155 implementation in 100% yul, based on Openzeppelin's standard.

# Tests

`npx hardhat test`

```
like an ERC1155 (mint parameters modified)
    balanceOf
      ✔ reverts when queried about the zero address
      when accounts don't own tokens
        ✔ returns zero for given addresses
      when accounts own some tokens
        ✔ returns the amount of tokens owned by the given addresses
    balanceOfBatch
      ✔ reverts when input arrays don't match up
      ✔ reverts when one of the addresses is the zero address
      when accounts don't own tokens
        ✔ returns zeros for each accounts
      when accounts own some tokens
        ✔ returns amounts owned by each accounts in order passed
        ✔ returns multiple times the balance of the same address when asked
    setApprovalForAll
      ✔ sets approval status which can be queried via isApprovedForAll
      ✔ emits an ApprovalForAll log
      ✔ can unset approval for an operator
      ✔ reverts if attempting to approve self as an operator
    safeTransferFrom
      ✔ reverts when transferring more than balance
      ✔ reverts when transferring to zero address
      when called by the firstTokenHolder
        ✔ preserves existing balances which are not transferred by firstTokenHolder
      when called by an operator on behalf of the firstTokenHolder
        when operator is not approved by firstTokenHolder
          ✔ reverts
        when operator is approved by firstTokenHolder
          ✔ preserves operator's balances not involved in the transfer
      when sending to a valid receiver
        without data
          ✔ calls onERC1155Received
        with data
          ✔ calls onERC1155Received
      to a receiver contract returning unexpected value
        ✔ reverts
      to a receiver contract that reverts
        ✔ reverts
      to a contract that does not implement the required function
        ✔ reverts
    safeBatchTransferFrom
      ✔ reverts when transferring amount more than any of balances
      ✔ reverts when ids array length doesn't match amounts array length
      ✔ reverts when transferring to zero address
      when called by an operator on behalf of the firstTokenHolder
        when operator is not approved by firstTokenHolder
          ✔ reverts
        when operator is approved by firstTokenHolder
          ✔ preserves operator's balances not involved in the transfer
      when sending to a valid receiver
        without data
          ✔ calls onERC1155BatchReceived
        with data
          ✔ calls onERC1155Received
      to a receiver contract returning unexpected value
        ✔ reverts
      to a receiver contract that reverts
        ✔ reverts
      to a receiver contract that reverts only on single transfers
        ✔ calls onERC1155BatchReceived
      to a contract that does not implement the required function
        ✔ reverts

  internal functions
    _mint
      ✔ reverts with a zero destination address
      with minted tokens
        ✔ emits a TransferSingle event
        ✔ credits the minted amount of tokens
    _mintBatch
      ✔ reverts with a zero destination address
      ✔ reverts if length of inputs do not match
      with minted batch of tokens
        ✔ emits a TransferBatch event
        ✔ credits the minted batch of tokens
    _burn
      ✔ reverts when burning the zero account's tokens
      ✔ reverts when burning a non-existent token id
      ✔ reverts when burning more than available tokens
      with minted-then-burnt tokens
        ✔ emits a TransferSingle event
        ✔ accounts for both minting and burning
```

# To do

- Add revert reason strings for more definite revert testing
- Add a setURI function for dynamic changing of URI
