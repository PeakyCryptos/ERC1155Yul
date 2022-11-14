object "Token"
{
  code
  {
    // Store the deployer in slot zero
    sstore(0, caller())

    // Store the minMint value in slot one
    sstore(1, 1) // 1 wei per tokenID

    // Store minMint amount in slot two
    // 10 max mints of an id at once
    sstore(2, 10)

    // store the uri string
    // these are stored last to allow for strings of variable length (no storage collision)
    // Used as the URI for all token types by relying on ID substitution, 
    // e.g. https://token-cdn-domain/{id}.json
    sstore(5, 0x22) // size 34 bytes (0x22)
    sstore(6, 0x68747470733a2f2f746f6b656e2d63646e2d646f6d61696e2f7b69647d2e6a73) // 'https://token-cdn-domain/{id}.js'
    sstore(7, 0x6f63) // 'on'

    // Deploy the contract
    datacopy(0, dataoffset("runtime"), datasize("runtime"))
    return (0, datasize("runtime"))
  }
  object "runtime"
  {
    code
    {
      // initalize memory pointer 0x80 at 0x40
      mstore(0x40, 0x80)

      // Dispatcher
      // All high-level functions
      // enforcing non payable as certain functions require ether
      switch selector()
      case 0x0e89341c /* "uri(uint256)" */
      {
        enforceNonPayable()

        // tokenID
        uri(decodeAsUint(0))
      }
      case 0x00fdd58e /* "balanceOf(address,uint256)" */
      {
        enforceNonPayable()

        // account, id
        returnSingleSlotData(balanceOf(decodeAsAddress(0), decodeAsUint(1)))
      }
      case 0x4e1273f4 /* "balanceOfBatch(address[],uint256[])" */
      {
        enforceNonPayable()

        // accounts[], ids[]
        balanceOfBatch(decodeAsArray(0), decodeAsArray(1))
      }
      case 0xa22cb465 /* "setApprovalForAll(address, bool)" */
      {
        enforceNonPayable()

        // msg.sender, operator, approved
        _setApprovalForAll(caller(), decodeAsAddress(0), decodeAsBool(1))
      }
      case 0xe985e9c5 /* "isApprovedForAll(address,address)" */
      {
        enforceNonPayable()

        // account, operator
        returnSingleSlotData(_operatorApprovalsAccess(decodeAsAddress(0), decodeAsAddress(1)))
      }
      case 0xf242432a /* "safeTransferFrom(address,address,uint256,uint256,bytes)" */
      {
        enforceNonPayable()

        // from, to, id, amount
        _safeTransferFrom(decodeAsAddress(0), decodeAsAddress(1), decodeAsUint(2), decodeAsUint(3), decodeAsBytes(4))
      }
      case 0x2eb2c2d6 /* "safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)" */
      {
        enforceNonPayable()

        // from, to, ids[], amounts[], data 
        _safeBatchTransferFrom(decodeAsAddress(0), decodeAsAddress(1), decodeAsArray(2), decodeAsArray(3), decodeAsBytes(4))
      }
      case 0x731133e9 /* "mint(address,uint256,uint256,bytes)" */
      {
        // to, id, amount, data              
        _mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2), decodeAsBytes(3))
      }
      case 0x1f7fdffa /* "mintBatch(address,uint256[],uint256[],bytes)" */
      {
        // to, ids[], amounts[], data
        _mintBatch(decodeAsAddress(0), decodeAsArray(1), decodeAsArray(2), decodeAsBytes(3))
      }
      case 0x80a5a371 /* "burn(uint256,uint256,bytes)" */
      {
        enforceNonPayable()

        // from(msg.sender), id, amount)
        _burn(caller(), decodeAsAddress(0), decodeAsUint(1))
      }
      case 0xe090fa3c /* "burnBatch(uint256[],uint256[],bytes)" */
      {
        enforceNonPayable()

        // from(msg.sender), ids[], amounts[])
        _burnBatch(caller(), decodeAsArray(0), decodeAsArray(1))
      }
      default
      {
        revert(0, 0)
      }

      /* -------- storage layout ---------- */
      function ownerPos() - > p { p: = 0 }

      function minMintValPos() - > p { p: = 1 }

      function minMintAmtPos() - > p { p: = 2 }

      // balances[tokenID][account]
      function acctBalancesMappingPos() - > p { p: = 3 }

      // operatorApprovals[account][operator] 
      function operatorApprovalsMappingPos() - > p { p: = 4 }

      // hardcoded uri data position
      function uriPos() - > sizePos
      {
        // no need to return the data slot locations
        // as the position is sequential (length + 1) etc
        sizePos: = 5
      }

      // Mapping from token ID to account balances
      // mapping(uint256 => mapping(address => uint256)) private _balances;
      // keccak256(abi.encode(address, keccak256(abi.encode(ID_uint, uint256(IDslotHash)))));
      function balancesStorageOffset(account, id) - > offset
      {
        // no need to keep track of FMP as we only use scratch space

        // nested mapping
        mstore(0x00, id) // 0x00 -> 0x20
        mstore(0x20, acctBalancesMappingPos()) // 0x20 -> 0x40  
        let nestedMappingHash: = keccak256(0x00, 0x40)

        // outter mapping
        mstore(0x00, account) // overwrite 0x00 -> 0x20
        mstore(0x20, nestedMappingHash) // overwrite 0x20 ->0x40

        // location balances[tokenID][account] 
        offset: = keccak256(0x00, 0x40)
      }

      function operatorApprovalsStorageOffset(account, operator) - > offset
      {
        // no need to keep track of FMP as we only use scratch space

        // nested mapping
        mstore(0x00, account) // 0x00 -> 0x20
        mstore(0x20, operatorApprovalsMappingPos()) // 0x20 -> 0x40  
        let nestedMappingHash: = keccak256(0x00, 0x40)

        // outter mapping
        mstore(0x00, operator) // overwrite 0x00 -> 0x20
        mstore(0x20, nestedMappingHash) // overwrite 0x20 -> 0x40

        // location operatorApprovals[account][operator]  
        offset: = keccak256(0x00, 0x40)
      }

      /* -------- main ERC1155 functions ---------- */
      function _mint(to, id, amount, dataSizeMemPos)
      {
        // check if callvalue = storage slot 1 data * amount
        // also ensure no token a higher number than what is in storage slot 2 is minted
        checkCallValue(amount)
        checkMaxMint(amount)

        // _balances[id][to] += amount;
        addToBalance(to, id, amount)

        // emit event
        TransferSingle(caller(), zeroAddress(), to, id, amount)

        // ensure if sending to contract it accepts this standard
        _doSafeTransferAcceptanceCheck(caller(), zeroAddress(), to, id, amount, dataSizeMemPos)
      }

      function _mintBatch(to, idsLengthMemPos, amountsLengthMemPos, bytesSizeMemPos)
      {
        // make sure receiver is not zero address
        revertIfZeroAddress(to)

        // make sure arrays are the same length
        let commonArrLength: = compareArrayLengths(idsLengthMemPos, amountsLengthMemPos)

        // total tokens being attempted to mint in this function
        let totalAmount: = 0

        // loop as many times as the common array length
        for { let i: = 0 } lt(i, commonArrLength) { i: = add(i, 1) }
        {
          // corresponding element of array for each iteration of this loop
          let id, amount: = getEqualArrElement(i, idsLengthMemPos, amountsLengthMemPos)

          // check for this token if you are minting over allowed limit
          checkMaxMint(amount)

          // _balances[id][to] += amount;
          addToBalance(to, id, amount)

          // increment record keeper
          totalAmount: = add(totalAmount, amount)
        }

        // check if callvalue is sufficient for total tokens minted
        checkCallValue(totalAmount)

        // emit event
        TransferBatch(caller(), zeroAddress(), to, idsLengthMemPos, amountsLengthMemPos, commonArrLength)

        // revert if not implementing receiving interface
        if isContract(to)
        {
          _doSafeBatchTransferAcceptanceCheck(caller(), zeroAddress(), to, idsLengthMemPos, amountsLengthMemPos, bytesSizeMemPos)
        }
      }

      function _burn(from, id, amount)
      {
        // _balances[id][from] = fromBalance - amount;
        deductFromBalance(from, id, amount)

        // emit event
        TransferSingle(caller(), from, zeroAddress(), id, amount)
      }

      function _burnBatch(from, idsLengthMemPos, amountsLengthMemPos)
      {
        // compare array lengths
        // reverts if not equal sized elements
        let commonArrLength: = compareArrayLengths(idsLengthMemPos, amountsLengthMemPos)

        // loop as many times as the common array length
        for { let i: = 0 } lt(i, commonArrLength) { i: = add(i, 1) }
        {
          // corresponding element of array for each iteration of this loop
          let id, amount: = getEqualArrElement(i, idsLengthMemPos, amountsLengthMemPos)

          // _balances[id][from] = fromBalance - amount;
          deductFromBalance(from, id, amount)
        }
      }

      // hardcode to default uri
      // same uri for all id's relies on {id} substitution
      function uri(id)
      {
        // load size position
        let sizePos: = uriPos()

        // load data from storage positions
        let size: = sload(sizePos)

        // return the string in proper format for return
        // sizePtr -> size -> data laid out end-to-end
        let startPos: = getFMP()
        mstore(startPos, 0x20)
        incrementFMP(0x20)

        // size is next 32 bytes
        mstore(getFMP(), size)
        incrementFMP(0x20)

        // store the 2 hardcoded data slots
        // done for extendability purposes incase hardcoded URI string
        // ...could be more than 2 storage slots in future
        for { let i: = 1 } lte(i, 2) { i: = add(i, 1) }
        {
          // i.e first loop  i = 1
          // we will load length pos + 1 and so on
          let data: = sload(add(sizePos, i))

          // store the data end-to-end
          mstore(getFMP(), data)
          incrementFMP(0x20)
        }

        return (startPos, getFMP())
      }

      function balanceOf(account, id) - > bal
      {
        //make sure not 0 address
        revertIfZeroAddress(account)

        // return balance[id][account]               
        bal: = sload(balancesStorageOffset(account, id))
      }

      function balanceOfBatch(accountsLengthMemPos, idsLengthMemPos)
      {
        /* parameters passed in are the pos
        ...of the arrays as memory is laid out end to end
        to read each individual element you move the lengthmemoryPtr + 32 -> by 32 bytes
        as many times as there are elements in the array 

        first 32 bytes from memPointers have the length of the array (hence the + 32)
        */

        // check if arrays are same length, else revert
        // if same length store as the new balance array length
        let balancesLength: = compareArrayLengths(accountsLengthMemPos, idsLengthMemPos)

        // initalize the balances array in memory at the free memory pointer
        // when returning an array we pass a ptr location to be read from 
        // which points to where the length position is stored in (in return data)
        // we do this so we can return end-to-end: PtrReturnArrLength->arrLength->Data packed next to each other
        let returnLengthPtrPos: = getFMP()
        mstore(returnLengthPtrPos, 0x20) // length of arr is pos 0x20 in return data for this func
        incrementFMP(0x20)

        // next in the following 32 bytes store the length 
        mstore(getFMP(), balancesLength)
        incrementFMP(0x20)

        // loop as many times as the balanceLength array should be
        // balances[index] = balanceOf[address][id]
        for { let i: = 0 } lt(i, balancesLength) { i: = add(i, 1) }
        {
          // where to write the current index of balances
          let toWritePos: = getFMP()

          // get array data for corresponding loop/index
          let account, id: = getEqualArrElement(i, accountsLengthMemPos, idsLengthMemPos)

          // retrieve the balance
          let bal: = balanceOf(account, id)

          // store balance for this index in specified position
          mstore(toWritePos, bal)

          // increment FMP by 32 bytes
          incrementFMP(0x20)
        }

        // returns the array location (returnLengthPtr -> end of data) in memory
        return (returnLengthPtrPos, getFMP())
      }

      // returns a bool, operatorApprovals[account][operator]
      function _operatorApprovalsAccess(account, operator) - > approvalBool
      {
        approvalBool: = sload(operatorApprovalsStorageOffset(account, operator))
      }

      // sets _operatorApprovals[account][operator] to a bool
      function _setApprovalForAll(owner, operator, approved)
      {
        // require(owner != operator, "ERC1155: setting approval status for self");
        if eq(owner, operator) { revert(0, 0) }

        // set approval bool in mapping offset
        sstore(operatorApprovalsStorageOffset(owner, operator), approved)

        // emit event
        ApprovalForAll(owner, operator, approved)
      }

      // _safeTransferFrom(from, to, id, amount, data);
      function _safeTransferFrom(from, to, id, amount, bytesDataSizeMemPos)
      {
        // require from is msg.sender or isApprovedForAll(from, msg.sender)
        // continue with execution if no revert occurs
        validInitiator(from)

        // require to is not the zero-address
        revertIfZeroAddress(to)

        // _balances[id][from] = fromBalance - amount;
        deductFromBalance(from, id, amount)

        // _balances[id][to] += amount;
        addToBalance(to, id, amount)

        // emit event
        TransferSingle(caller(), from, to, id, amount)

        // check if reciever is a contract
        // revert if not implementing receiving interface
        if isContract(to)
        {
          _doSafeTransferAcceptanceCheck(caller(), from, to, id, amount, bytesDataSizeMemPos)
        }
      }

      function _safeBatchTransferFrom(from, to, idsLengthMemPos, amountsLengthMemPos, bytesDataSizeMemPos)
      {
        // require from is msg.sender or isApprovedForAll(from, msg.sender)
        // continue with execution if no revert occurs
        validInitiator(from)

        // require to is not the zero-address
        revertIfZeroAddress(to)

        // stores length of both arrays if they are equal sized
        // revert is arrays not the same length
        let commonArrLength: = compareArrayLengths(idsLengthMemPos, amountsLengthMemPos)

        // loop as many times as the commonArrLength array should be
        for { let i: = 0 } lt(i, commonArrLength) { i: = add(i, 1) }
        {
          // where to write the current index of balances
          let toWritePos: = getFMP()

          // get array data for corresponding loop/index
          let id, amount: = getEqualArrElement(i, idsLengthMemPos, amountsLengthMemPos)

          // _balances[id][to] += amount;
          addToBalance(to, id, amount)

          // _balances[id][from] = fromBalance - amount;
          // checks for withdrawing over possible balance
          deductFromBalance(from, id, amount)
        }

        // emit event
        TransferBatch(caller(), from, to, idsLengthMemPos, amountsLengthMemPos, commonArrLength)

        // revert if not implementing receiving interface
        if isContract(to)
        {
          _doSafeBatchTransferAcceptanceCheck(caller(), from, to, idsLengthMemPos, amountsLengthMemPos, bytesDataSizeMemPos)
        }
      }

      function _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, bytesDataSizeMemPos)
      {
        // should return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
        // 0xf23a6e61 when calling onERC1155Received (it's own function selector)
        // EVM will interpret this with leading 0's so we must shift for selector notation
        let onERC1155ReceivedSelector: = shl(0xE0, 0xf23a6e61) // 224 bits shift left

        // do a call onto the account and compare returned data
        /*  gas: amount of gas to send to the sub context to execute. 
            The gas that is not used by the sub context is returned to this one.
            address: the account which context to execute.
            value: value in wei to send to the account.
            argsOffset: byte offset in the memory in bytes, the calldata of the sub context.
            argsSize: byte size to copy (size of the calldata).
            retOffset: byte offset in the memory in bytes, where to store the return data of the sub context.
            retSize: byte size to copy (size of the return data).
        */

        /********* construct calldata arguments *********/
        //construct calldata in memory end-to-end as calling functions calldata
        let cdStart: = getFMP()

        // function selector 
        mstore(cdStart, onERC1155ReceivedSelector)
        incrementFMP(0x04) // -> 4 bytes (calldata size)

        // operator
        mstore(getFMP(), caller()) // overwrites the last 28 bytes of prev
        incrementFMP(0x20) // -> 36 bytes (calldata size) 

        // from
        mstore(getFMP(), from)
        incrementFMP(0x20) // -> 68 bytes (calldata size) 

        // id
        mstore(getFMP(), id)
        incrementFMP(0x20) // -> 100 bytes (calldata size) 

        // amount
        mstore(getFMP(), amount)
        incrementFMP(0x20) // -> 132 bytes (calldata size)

        // total amount of bytes to write
        let bytesSize: = mload(bytesDataSizeMemPos)

        // bytes size ptr (ptr pos to byte size in calldata) 
        // (disregarding the initial 4 bytes of function selector)
        mstore(getFMP(), 0xa0) // points to immediately proceeding mem slot
        incrementFMP(0x20) // -> 164 bytes (calldata size)

        // bytes size data
        mstore(getFMP(), bytesSize)
        incrementFMP(0x20) // -> 196 bytes (calldata size)  

        // pack bytes data end-to-end 
        // (will be variable memory slots taken depending on the bytes size)
        packBytesMem(bytesDataSizeMemPos, bytesSize)

        // 196 bytes + size of byte data 
        let cdSize: = add(0xc4, bytesSize)
        /********* construct calldata arguments *********/

        //safeContractCall(cdStart, cdSize)
        // execute call and require successful return from exeuction context
        let success: = call(gas(), to, 0, cdStart, cdSize, 0x00, 0x20)
        require(success)

        // ensure valid selector is returned
        require(eq(mload(0x00), onERC1155ReceivedSelector))
      }

      function _doSafeBatchTransferAcceptanceCheck(operator, from, to, idsLengthMemPos, amountsLengthMemPos, bytesDataSizeMemPos)
      {
        // should return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
        // 0xbc197c81 when calling onERC1155Received (it's own function selector)
        // EVM will interpret this with leading 0's so we must shift for selector notation
        let onERC1155BatchReceivedSelector: = shl(0xE0, 0xbc197c81) // 224 bits shift left

        // do a call onto the account and compare returned data
        /* gas: amount of gas to send to the sub context to execute. 
            The gas that is not used by the sub context is returned to this one.
            address: the account which context to execute.
            value: value in wei to send to the account.
            argsOffset: byte offset in the memory in bytes, the calldata of the sub context.
            argsSize: byte size to copy (size of the calldata).
            retOffset: byte offset in the memory in bytes, where to store the return data of the sub context.
            retSize: byte size to copy (size of the return data).
        */

        /********* construct calldata arguments *********/
        /* since we return multiple dynamic size elements
            the memory layout will look like so: 
            operator, from, to, ids length ptr, amounts length ptr, bytes length ptr,
            amounts length, amounts data, ids length, ids data, bytes size, bytes data                        
        */
        let cdStart: = getFMP()

        // function selector 
        mstore(cdStart, onERC1155BatchReceivedSelector)
        incrementFMP(0x04) // -> 4 bytes (calldata size)

        // operator
        mstore(getFMP(), caller()) // overwrites the last 28 bytes of prev
        incrementFMP(0x20) // -> 36 bytes (calldata size) 

        // from
        mstore(getFMP(), from)
        incrementFMP(0x20) // -> 68 bytes (calldata size) 

        /* dynamic elements pointers */
        // load array length
        let arrayLen: = mload(idsLengthMemPos)
        let arrFullSize: = add(mul(arrayLen, 0x20), 0x20) // data size including length

        // ids array length ptr (ptr pos to length in calldata) 
        // (disregarding the initial 4 bytes of function selector)
        mstore(getFMP(), 0xa0)
        incrementFMP(0x20) // -> 164 bytes (calldata size)

        // amounts array length ptr = 0xa0 + full length of array (including length)
        let amountsPtr: = add(0xa0, arrFullSize)
        mstore(getFMP(), amountsPtr)
        incrementFMP(0x20) // -> 196 bytes (calldata size)

        // bytes size ptr = amountsPtr + full length of array (including length)
        let bytesPtr: = add(amountsPtr, arrFullSize)
        mstore(getFMP(), bytesPtr)
        incrementFMP(0x20)
        /* dynamic elements pointers */

        /* dynamic elements size/length */

        /* ID */
        // store ids length at ptr pos (disregarding length slot)
        mstore(getFMP(), arrayLen)
        incrementFMP(0x20)

        // id data
        // copys back array data from memory end-to-end
        packArrayMem(arrayLen, idsLengthMemPos)
        /* ID */

        /* AMOUNT */
        // store amount length at ptr pos (disregarding length slot)
        mstore(getFMP(), arrayLen)
        incrementFMP(0x20)

        // amount data
        packArrayMem(arrayLen, amountsLengthMemPos)
        /* AMOUNT */

        /* BYTES */
        let bytesSize: = mload(bytesDataSizeMemPos)
        mstore(getFMP(), bytesSize)
        incrementFMP(0x20)

        // pack bytes data end-to-end
        packBytesMem(bytesDataSizeMemPos, bytesSize)
        /* BYTES */
        /* dynamic elements size/length */
        /********* construct calldata arguments *********/

        // all memory operations incremented the FMP accordingly
        // we can use the current FMP position to calculate CD size
        let cdSize: = sub(getFMP(), cdStart)

        // execute call and require successful return from exeuction context
        // stores return data in scratch space
        let success: = call(gas(), to, 0, cdStart, cdSize, 0x00, 0x20)
        require(success)

        // ensure valid selector is returned
        // checks scratch space
        require(eq(mload(0x00), onERC1155BatchReceivedSelector))
      }

      /* ---------- calldata decoding functions ----------- */
      function selector() - > s
      {
        s: = div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      // Checks if valid address passed in
      function decodeAsAddress(offset) - > v
      {
        v: = decodeAsUint(offset)
        if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff))))
        {
          revert(0, 0)
        }
      }

      // Checks if valid uint passed in
      function decodeAsUint(offset) - > v
      {
        let pos: = add(4, mul(offset, 0x20))
        if lt(calldatasize(), add(pos, 0x20))
        {
          revert(0, 0)
        }

        v: = calldataload(pos)
      }

      // Checks if valid bool passed in
      function decodeAsBool(offset) - > data
      {
        let pos: = add(4, mul(offset, 0x20))
        if lt(calldatasize(), add(pos, 0x20))
        {
          revert(0, 0)
        }

        // load bool value (full 32 bytes)
        // also returned if function executes successfully
        data: = calldataload(pos)

        // check if bool (0 or 1)
        // if not reverts
        isBool(data)
      }

      // Checks if valid array passed in, and prepares data format for function
      function decodeAsArray(offset) - > arrLengthMemPos
      {
        /* offset passed in is the location to start reading the following 32 bytes
           that holds the length of the array (how many increments of 0x20 to read from)

           because there are multiple arrays loaded in certain ERC1155 functions
           we must ensure there is no memory being overwritten
           meaning we have to keep track of the memory pointer of where to start
           reading the data into the memory from the calldata

           As we will put into memory the full array data including length as first 32 bytes
           the function will recieve the pointer to memory where the length porition starts
        */

        // calldata offset position
        let arrOffsetPos: = add(4, mul(offset, 0x20))

        // read calldata to get where the arr length portion starts
        // add 4 as we must account for the function selector
        let arrLengthPos: = add(calldataload(arrOffsetPos), 4)

        // full array length data (including the length value as the first item)
        let arrLengthData: = add(calldataload(arrLengthPos), 1)

        // if array length is 0 revert
        if eq(arrLengthData, 1)
        {
          revert(0, 0)
        }

        // full byte size of array including length portion
        let fullArrDataSize: = mul(arrLengthData, 0x20)

        // ensure this is a valid array (length portion matches the remaining data portion)
        // the length * 0x20  (how many 32 bytes lengths it takes up)   
        // calldatasize = arrLengthPos + fullArrDataSize        
        if lt(calldatasize(), add(arrLengthPos, fullArrDataSize))
        {
          revert(0, 0)
        }

        // This is returned to the calling function at the end of function execution
        // holds in memory where to start copying the full array
        // first 32 bytes will hold the length porition of the array
        arrLengthMemPos: = getFMP()

        // copy to memory (starting at where the free memory pointer is)
        // copies the full array including the length)
        calldatacopy(arrLengthMemPos, arrLengthPos, fullArrDataSize)

        // increment the FMP by the full arr size
        incrementFMP(fullArrDataSize)
      }

      // Checks if valid bytes data passed in, and prepares data format for function
      function decodeAsBytes(offset) - > bytesSizeMemPos
      {
        /* similar to how an array is decoded however the ptr points to calldata offeset
           where the size of the bytes data is stored. Unlike an array using the
           length (amount of elements in the array)
        */

        // calldata offset position
        let cdSizeOffsetPos: = add(4, mul(offset, 0x20))

        // read calldata to get where the bytes size portion starts
        // add 4 as we must account for the function selector
        let cdSizePos: = add(calldataload(cdSizeOffsetPos), 4)

        // full byte size, including size data (preceding 32 bytes)  
        let bytesSizeData: = add(calldataload(cdSizePos), 0x20)

        // if there is no bytes size data then revert
        require(bytesSizeData)

        // ensure this is a valid bytes data (size matches the bytes passed in)
        // calldatasize == cdSizePos + bytesSizeData  
        if lt(calldatasize(), add(cdSizePos, bytesSizeData))
        {
          revert(0, 0)
        }

        // This is returned to the calling function at the end of function execution
        // holds in memory where to start copying the bytes data
        // first 32 bytes will hold the length porition of the data
        bytesSizeMemPos: = getFMP()

        // copy to memory (starting at where the free memory pointer is)
        // copies the full byte size(including the length)
        calldatacopy(bytesSizeMemPos, cdSizePos, bytesSizeData)

        // increment the FMP by the full bytes size
        incrementFMP(bytesSizeData)
      }

      /* ---------- calldata encoding functions ---------- */
      // handles all return data that only takes up 32 bytes
      // i.e uints,bools etc 
      function returnSingleSlotData(v)
      {
        mstore(0x00, v)
        return (0x00, 0x20)
      }

      /* -------- events ---------- */
      function TransferSingle(operator, from, to, id, amount)
      {
        /* event TransferSingle(address indexed _operator, address indexed _from, 
           address indexed _to, uint256 _id, uint256 _value) */
        // No need for FMP as we make use of scratch space

        // keccak256("TransferSingle(address,address,address,uint256,uint256)")
        let signatureHash: = 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62

        // non-indexed arguments must be stored in memory
        mstore(0x00, id)
        mstore(0x20, amount)

        // emit log
        log4(0x00, 0x40, signatureHash, operator, from, to)
      }

      function TransferBatch(operator, from, to, idsLengthMemPos, amountsLengthMemPos, commonArrLength)
      {
        /* event TransferBatch(address indexed _operator, address indexed _from, 
           ...address indexed _to, uint256[] _ids, uint256[] _values) */

        // keccak256("TransferBatch(address,address,address,uint256[],uint256[])")
        let signatureHash: = 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb

        // non-indexed arguments must be stored in memory
        // dynamic arrays are stored with a pointer to the length within the log data
        // similar to calldata/return
        // to avoid overwriting memory construct the data starting from the free memory pointer
        // Layout: idLengthPtr, amountLengthPtr, idLength, idData, amountLength, amountData

        // fullArrSize = idsLength * 0x20 + 0x20(including length slot)
        let fullArrSize: = add(mul(commonArrLength, 0x20), 0x20)

        // at FMP store idsLengthPtr -> FMP + 0x40
        // start of where the new arrays end-to-end format will be copied to
        let idsLengthPtrPos: = getFMP()
        // at FMP + 0x20 store AmountsLengthPtr -> idsLengthPtr + fullArrSize
        let amountsLengthPtrPos: = add(idsLengthPtrPos, 0x20)

        // store their relative locations in the log data
        mstore(idsLengthPtrPos, 0x40) // FMP + 0x40
        mstore(amountsLengthPtrPos, add(0x40, fullArrSize)) // idsLengthPtr + fullArrSize

        // load the relative pos of log data in relation to memory
        let idsLengthPos: = add(getFMP(), mload(idsLengthPtrPos))
        let amountLengthPos: = add(getFMP(), mload(amountsLengthPtrPos))

        // store the length in corresponding mem pos
        mstore(idsLengthPos, commonArrLength)
        mstore(amountLengthPos, commonArrLength)

        // for loop as many elements in common array and append to appropriate memory positions
        for { let i: = 0 } lt(i, commonArrLength) { i: = add(i, 1) }
        {
          // for each arr what pos to read the current index at
          // add 0x20 to account for the length slot
          let shiftPos: = add(mul(i, 0x20), 0x20)

          // get the account and id data values (from calldata decoded location in mem)
          let id: = mload(add(idsLengthMemPos, shiftPos))
          let amount: = mload(add(amountsLengthMemPos, shiftPos))

          // append to new mem position
          mstore(add(idsLengthPos, shiftPos), id)
          mstore(add(amountLengthPos, shiftPos), amount)
        }

        // Update the FMP
        let endMemPos: = add(mul(fullArrSize, 2), 0x40)
        // (2 full arrays(including length + the length ptr pos)
        incrementFMP(endMemPos)

        // emit log 
        log4(idsLengthPtrPos, endMemPos, signatureHash, operator, from, to)
      }

      function ApprovalForAll(owner, operator, approved)
      {
        /* event ApprovalForAll(address indexed _owner, address indexed _operator, 
           bool _approved) */

        // keccak256("ApprovalForAll(address,address,bool)")                
        let signatureHash: = 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31

        // bool is non-indexed argument, stored in memory
        mstore(0x00, approved) // 0x00 -> 0x20

        log3(0x00, 0x20, signatureHash, owner, operator)
      }

      /* -------- storage access helpers ---------- */
      function ownerAddress() - > o
      {
        o: = sload(ownerPos())
      }

      // function to return minMint value
      function minMintVal() - > v
      {
        v: = sload(minMintValPos())
      }

      // function to return minMint amount (total tokens per transaction)
      function minMintAmt() - > v
      {
        v: = sload(minMintAmtPos())
      }

      // Add to tokenID balance per address
      function addToBalance(account, id, amount)
      {
        // location of balance[tokenID][account]  
        let offset: = balancesStorageOffset(account, id)

        // update balance at storage location
        sstore(offset, safeAdd(sload(offset), amount))
      }

      // Deduct from tokenID balance per address
      function deductFromBalance(account, id, amount)
      {
        // location of balance[tokenID][account]
        let offset: = balancesStorageOffset(account, id)

        // check if amount to deduct isn't more than balance
        let bal: = sload(offset)
        require(lte(amount, bal))

        // update balance at storage location
        sstore(offset, sub(bal, amount))
      }

      // for 2 arrays of equal size return same element 
      // i = element of array we want to access (arr[i])
      function getEqualArrElement(i, firstArrMemPos, secondArrMemPos) - > firstData, secondData
      {
        // for each arr what pos to read the current index at
        // add 0x20 to account for the length slot
        let shiftPos: = add(mul(i, 0x20), 0x20)

        // get the account and id data values
        firstData: = mload(add(firstArrMemPos, shiftPos))
        secondData: = mload(add(secondArrMemPos, shiftPos))
      }

      /* ---------- memory functions ---------- */
      // get current free memory pointer location
      function getFMP() - > fmp
      {
        fmp: = mload(0x40)
      }

      // increment free memory pointer by specified amount
      function incrementFMP(amount)
      {
        mstore(0x40, add(getFMP(), amount))
      }

      // copy bytes data from memory back into memory end-to-end (starting at FMP)
      function packBytesMem(bytesDataSizeMemPos, bytesSize)
      {
        // data preceding stores in memory each 32 bytes of data
        // i.e if 64 bytes of data (0x40) then 0x40 / 0x20 = 2 loops/data
        // add 1 as i.e 0x02 / 0x20 = 0.0625
        // we still have a slot to copy here as default behavior drops after decimal point
        let numLoops: = add(1, div(bytesSize, 0x20))
        for { let i: = 1 } lte(i, numLoops) { i: = add(i, 1) }
        {
          let shiftPos: = mul(i, 0x20)
          let data: = mload(add(bytesDataSizeMemPos, shiftPos))
          mstore(getFMP(), data)
          incrementFMP(0x20)
        }
      }

      // copy array data from memory back into memory end-to-end (starting at FMP)
      function packArrayMem(length, lengthMemPos)
      {
        for { let i: = 1 } lte(i, length) { i: = add(i, 1) }
        {
          // for each arr what pos to read the current index at
          // add 0x20 to account for the length slot
          let shiftPos: = mul(i, 0x20)

          // get the account and id data values
          let data: = mload(add(lengthMemPos, shiftPos))
          mstore(getFMP(), data)

          incrementFMP(0x20)
        }
      }

      /* ---------- utility functions ---------- */
      // a <= b
      function lte(a, b) - > r
      {
        r: = iszero(gt(a, b))
      }

      // a >= b
      function gte(a, b) - > r
      {
        r: = iszero(lt(a, b))
      }

      // conduct addition without overflow possibility
      function safeAdd(a, b) - > r
      {
        r: = add(a, b)
        if or(lt(r, a), lt(r, b)) { revert(0, 0) }
      }

      // if condition == 0, then revert
      function require(condition)
      {
        if iszero(condition) { revert(0, 0) }
      }

      // revert if adddress is 0 address
      function revertIfZeroAddress(addr)
      {
        require(addr)
      }

      // return 0 address
      function zeroAddress() - > addr
      {
        addr: = 0x0000000000000000000000000000000000000000000000000000000000000000
      }

      // check if ether was sent
      function enforceNonPayable()
      {
        require(iszero(callvalue()))
      }

      // amount = total tokens minting
      // check if callvalue is sufficient for the amount being minted
      function checkCallValue(amount)
      {
        // must equal constructor specified max mint value * amount minting
        require(eq(mul(minMintVal(), amount), callvalue()))

      }

      function checkMaxMint(amount)
      {
        // must be less than or equal to contructor specified max mint amount
        // (maximum tokens you can mint in one transaction) 
        require(lte(amount, minMintAmt()))
      }

      // check if valid bool
      function isBool(data)
      {
        // if data < 2 this is a bool val (0,1)
        require(lt(data, 2))
      }

      function validInitiator(from)
      {
        // from == _msgSender() || isApprovedForAll(from, _msgSender())
        // if acc from is not the msg.sender and the msg.sender is not
        // ...approved for the account token is coming out of then revert
        if eq(caller(), from)
        {
          leave
        }

        // else if
        // operatorApprovals[account][operator]
        if _operatorApprovalsAccess(from, caller())
        {
          leave
        }

        revert(0, 0)
      }

      // check if 2 arrays are of the same length
      function compareArrayLengths(arr1, arr2) - > data1
      {
        //require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch
        data1: = mload(arr1)
        let data2: = mload(arr2)

        require(eq(data1, data2))

        // end of execution returns data1
        // which is the common length of both the arrays
      }

      // check if address passed in is a contract
      function isContract(receiver) - > codeSize
      {
        // returns byte size of the contract code
        // if not a valid contract this will return 0
        // ...unless called via a contracts constructor
        codeSize: = extcodesize(receiver)
      }
    }
  }
}