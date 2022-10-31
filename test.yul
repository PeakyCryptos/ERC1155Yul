object "Token" {
    code {
        // Store the creator in slot zero.
        sstore(0, caller())

        // Store the minMint value in slot one
        // 1000000000000000 = 0.001 eth
        sstore(1, 1000000000000000)

        // Store minMint amount in slot two
        // 10 mints of an id at once
        sstore(2, 10)

        // store the uri string

        // Deploy the contract
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        return(0, datasize("runtime"))
    }
    object "runtime" {
        code {
            // initalize memory pointer 0x80 at 0x40
            mstore(0x40, 0x80)

            // Dispatcher
            // All high-level functions
            switch selector()
            case 0x00fdd58e /* "balanceOf(address,uint256)" */ {
                enforceNonPayable()
                returnSingleSlotData(balanceOf(decodeAsAddress(0), decodeAsUint(1)))
            } 
            case 0x4e1273f4 /* "balanceOfBatch(address[],uint256[])" */ {
                enforceNonPayable()
                balanceOfBatch(decodeAsArray(0), decodeAsArray(1))
            }
            case 0xe985e9c5 /* "isApprovedForAll(address,address)" */ {
                enforceNonPayable()
                returnSingleSlotData(_operatorApprovalsAccess(decodeAsAddress(0), decodeAsAddress(1)))
            }
            case 0xa22cb465 /* "setApprovalForAll(address, bool)" */ {
                enforceNonPayable()
                // _setApprovalForAll(_msgSender(), operator, approved)
                _setApprovalForAll(caller(), decodeAsAddress(0), decodeAsBool(1))
            }
            case 0x0febdd49 /* "safeTransferFrom(address,address,uint256,uint256)" ignoring bytes for now*/ {                
                enforceNonPayable()
                _safeTransferFrom(decodeAsAddress(0), decodeAsAddress(1), decodeAsUint(2), decodeAsUint(3)/*, decodeAsBytes(3)*/)
            }
            case 0xe950b7f4 /* "safeBatchTransferFrom(from, to, ids, amounts)" ignoring bytes for now*/ {
                enforceNonPayable()
                _safeBatchTransferFrom(decodeAsAddress(0), decodeAsAddress(1), decodeAsArray(2), decodeAsArray(3)/*, decodeAsBytes(3)*/)
            }
            case 0x156e29f6 /* "mint(address,uint256,uint256)" */ {                
                _mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2)/*, decodeAsBytes(3)*/)
            }            
            // mintBatch, burn, burnBatch

            // add case for return uri(tokenID)

            default {
                revert(0, 0)
            }

            /* -------- storage layout ---------- */
            function ownerPos() -> p { p := 0 }
            function minMintValPos() -> p { p := 1}
            function minMintAmtPos() -> p { p := 2}
            function uriPos() -> p { p := 3 }	
            // balances[tokenID][account]
			function acctBalancesMappingPos() -> p { p := 4 }
            // operatorApprovals[account][operator] 
			function operatorApprovalsMappingPos() -> p { p := 5 } 
	
            // Mapping from token ID to account balances
            // mapping(uint256 => mapping(address => uint256)) private _balances;
			// keccak256(abi.encode(address, keccak256(abi.encode(ID_uint, uint256(IDslotHash)))));
            function balancesStorageOffset(account, id) -> offset {	
                // no need to keep track of FMP as we only use scratch space

				// nested mapping
                mstore(0x00, id) // 0x00 -> 0x20
				mstore(0x20, acctBalancesMappingPos()) // 0x20 -> 0x40  
				let nestedMappingHash := keccak256(0x00, 0x40) 

                // outter mapping
                mstore(0x00, account) // overwrite 0x00 -> 0x20
                mstore(0x20, nestedMappingHash) // overwrite 0x20 ->0x40

                // location balances[tokenID][account] 
                offset := keccak256(0x00, 0x40)
			}

			function operatorApprovalsStorageOffset(account, operator) -> offset {
                // no need to keep track of FMP as we only use scratch space

				// nested mapping
                mstore(0x00, account) // 0x00 -> 0x20
				mstore(0x20, operatorApprovalsMappingPos()) // 0x20 -> 0x40  
				let nestedMappingHash := keccak256(0x00, 0x40) 

                // outter mapping
                mstore(0x00, operator) // overwrite 0x00 -> 0x20
                mstore(0x20, nestedMappingHash) // overwrite 0x20 -> 0x40

                // location operatorApprovals[account][operator]  
                offset := keccak256(0x00, 0x40)
			}

            /* -------- storage access functions ---------- */
            function _mint(to, id, amount /*, data*/) {
                // check if they passed in 0.001 ether
                // and max 10 mints of a token at a time
                equalsMinMint(amount)

                // _balances[id][to] += amount;
                addToBalance(to, id, amount)

                // emit TransferSingle(operator, address(0), to, id, amount);

                // _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);

            }

            function _mintBatch() {
                //
            }

            function burn() {

            }

            function burnBatch() {
                //
            }

            function uri(id) {
                //
            }

            function balanceOf(account, id) -> bal {
                //make sure not 0 address
                revertIfZeroAddress(account)

                // return balance[id][account]               
                bal := sload(balancesStorageOffset(account, id))
            }

            function balanceOfBatch(accountsLengthMemPos, idsLengthMemPos) {
                /* parameters passed in are the pos
                ...of the arrays as memory is laid out end to end
                to read each individual element you move the lengthmemoryPtr + 32 -> by 32 bytes
                as many times as there are elements in the array 

                first 32 bytes from memPointers have the length of the array (hence the + 32)
                */

                // check if arrays are same length
                compareArrayLengths(accountsLengthMemPos, idsLengthMemPos)

                // balances array length
                let balancesLength := mload(accountsLengthMemPos)

                // initalize the balances array in memory at the free memory pointer
                // when returning an array we pass a ptr location to be read from 
                // which points to where the length position is stored in (in return data)
                // we do this so we can return end-to-end: PtrReturnArrLength->arrLength->Data packed next to each other
                let returnLengthPtrPos := getFMP()
                mstore(returnLengthPtrPos, 0x20) // length of arr is pos 0x20 in return data for this func
                incrementFMP(0x20)
                // next in the following 32 bytes store the length 
                mstore(getFMP(), balancesLength)
                incrementFMP(0x20)

                // loop as many times as the balanceLength array should be
                // balances[index] = balanceOf[address][id]
                for { let i := 0 } lt(i, balancesLength) { i := add(i, 1) } {
                    // where to write the current index of balances
                    let toWritePos := getFMP()

                    // for each arr what pos to read the current index at
                    // add 0x20 to account for the length slot
                    let shiftPos := add(mul(i, 0x20), 0x20)

                    // get the account and id data values
                    let account := mload(add(accountsLengthMemPos, shiftPos)) 
                    let id := mload(add(idsLengthMemPos, shiftPos))

                    // retrieve the balance
                    let bal := balanceOf(account, id)

                    // store balance for this index in specified position
                    mstore(toWritePos, bal)

                    // increment FMP by 32 bytes
                    incrementFMP(0x20)
                }

                // returns the array location (returnLengthPtr -> end of data) in memory
                return(returnLengthPtrPos,getFMP())
            }

            function _operatorApprovalsAccess(account, operator) -> approvalBool {
                approvalBool := sload(operatorApprovalsStorageOffset(account, operator))
            }

            function _setApprovalForAll(owner, operator, approved) {
                // require(owner != operator, "ERC1155: setting approval status for self");
                if eq(owner, operator) { revert(0, 0) }

                // set approval bool in mapping offset
                sstore(operatorApprovalsStorageOffset(owner, operator), approved)

                // emit ApprovalForAll(owner, operator, approved);
            }

            // _safeTransferFrom(from, to, id, amount, data);
            function _safeTransferFrom(from, to, id, amount /*, data*/) {
                // require from is msg.sender or isApprovedForAll(from, msg.sender)
                // continue with execution if no revert occurs
                validInitiator(from)

                // require to is not the zero-address
                revertIfZeroAddress(to)

                // uint256 fromBalance = _balances[id][from];
                let fromBalance := balanceOf(from, id)
                
                // require(fromBalance >= amount)
                require(gte(fromBalance, amount))

                // _balances[id][from] = fromBalance - amount;
                deductFromBalance(from, id, amount)
                
                // _balances[id][to] += amount;
                addToBalance(to, id, amount)

                // emit TransferSingle(operator, from, to, id, amount);

                // _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
            }

            function _safeBatchTransferFrom(from, to, idsLengthMemPos, amountsLengthMemPos /*, data*/) {
                // require from is msg.sender or isApprovedForAll(from, msg.sender)
                // continue with execution if no revert occurs
                validInitiator(from)

                // require to is not the zero-address
                revertIfZeroAddress(to)  

                // check if arrays are same length
                compareArrayLengths(idsLengthMemPos, amountsLengthMemPos)

                // length of both arrays, as we know they are equal sized
                let commonArrLength := mload(idsLengthMemPos)

                // loop as many times as the commonArrLength array should be
                for { let i := 0 } lt(i, commonArrLength) { i := add(i, 1) } {
                    // where to write the current index of balances
                    let toWritePos := getFMP()

                    // for each arr what pos to read the current index at
                    // add 0x20 to account for the length slot
                    let shiftPos := add(mul(i, 0x20), 0x20)

                    // get the account and id data values
                    let id := mload(add(idsLengthMemPos, shiftPos)) 
                    let amount := mload(add(amountsLengthMemPos, shiftPos))

                    // fromBalance = _balances[id][from];
                    let fromBalance := balanceOf(from, id)

                    // require(fromBalance >= amount
                    require(gte(fromBalance, amount))

                    // _balances[id][from] = fromBalance - amount;
                    deductFromBalance(from, id, amount)
                
                    // _balances[id][to] += amount;
                    addToBalance(to, id, amount)
                }                 

                // emit TransferBatch(operator, from, to, ids, amounts);

                // _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
            }

            function _doSafeTransferAcceptanceCheck(operator, from, to, id, amount /*, data*/) {
                if isContract(to) {

                }
            }

            function _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts /*, data*/) {
                // first check extcodesize to see if contract
            }

            /* ---------- calldata decoding functions ----------- */
            function selector() -> s {
                s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
            }

            function decodeAsAddress(offset) -> v {
                v := decodeAsUint(offset)
                if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
                    revert(0, 0)
                } 
            }

            function decodeAsUint(offset) -> v {
                let pos := add(4, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }
                
                v := calldataload(pos)
            }

            function decodeAsBool(offset) -> data {
               let pos := add(4, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }

                // load bool value (full 32 bytes)
                // also returned if function executes successfully
                data := calldataload(pos)  
                
                // check if bool (0 or 1)
                // if not reverts
                isBool(data) 
            }

            function decodeAsArray(offset) -> arrLengthMemPos {
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
                let arrOffsetPos := add(4, mul(offset, 0x20))

                // read calldata to get where the arr length portion starts
                // add 4 as we must account for the function selector
                let arrLengthPos := add(calldataload(arrOffsetPos), 4)

                // full array length data (including the length as the first element)
                let arrLengthData := add(calldataload(arrLengthPos), 1)

                // if array length is 0 revert
                if eq(arrLengthData, 1) {
                    revert(0,0)
                }

                // full byte size of array including length portion
                let fullArrDataSize := mul(arrLengthData, 0x20)

                // ensure this is a valid array (length portion matches the remaining data portion)
                // the length * 0x20  (how many 32 bytes lengths it takes up)   
                // calldatasize = arrLengthPos + fullArrDataSize        
                if lt(calldatasize(), add(arrLengthPos, fullArrDataSize)) {
                    revert(0, 0)
                }

                // This is returned to the calling function at the end of function execution
                // holds in memory where to start copying the full array
                // first 32 bytes will hold the length porition of the array
                arrLengthMemPos := getFMP()
                
                // copy to memory (starting at where the free memory pointer is)
                // copies the full array including the length)
                calldatacopy(arrLengthMemPos, arrLengthPos, fullArrDataSize)

                // increment the FMP by the full arr size
                incrementFMP(fullArrDataSize)
            }

            function decodeAsBytes(offset) -> bytesLengthMemPos {
                /* similar to how an array is decoded however the ptr points to calldata offeset
                   where the size of the bytes data is stored. Unlike an array using the
                   length (amount of elements in the array)
                */

                // calldata offset position
                let cdSizeOffsetPos := add(4, mul(offset, 0x20))

                // read calldata to get where the arr length portion starts
                // add 4 as we must account for the function selector
                let cdSizePos := add(calldataload(cdSizeOffsetPos), 4)

                // full byte size, including size data (preceding 32 bytes)  
                let bytesSizeData := add(calldataload(cdSizePos), 0x20)

                // if bytes size is 0 revert
                require(bytesSizeData)

                // full byte size of array including length portion
                let fullArrDataSize := mul(arrLengthData, 0x20)

                // ensure this is a valid bytes data (size matches the bytes passed in)
                // the length * 0x20  (how many 32 bytes lengths it takes up)   
                // calldatasize = arrLengthPos + fullArrDataSize        
                if lt(calldatasize(), add(arrLengthPos, fullArrDataSize)) {
                    revert(0, 0)
                }

                // This is returned to the calling function at the end of function execution
                // holds in memory where to start copying the full array
                // first 32 bytes will hold the length porition of the array
                arrLengthMemPos := getFMP()
                
                // copy to memory (starting at where the free memory pointer is)
                // copies the full array including the length)
                calldatacopy(arrLengthMemPos, arrLengthPos, fullArrDataSize)

                // increment the FMP by the full arr size
                incrementFMP(fullArrDataSize)
            }

            function decodeAsSingletonArray(offset) -> arrLengthMemPos {
                // convert single item to an array for safeTransfer

            }
            /* ---------- calldata encoding functions ---------- */
            // handles all return data that only takes up 32 bytes
            // i.e uints,bools etc 
            function returnSingleSlotData(v) {
                mstore(0x00, v)
                return(0x00, 0x20)
            }

            /* -------- events ---------- */
            /*
            function emitTransfer(from, to, amount) {
                let signatureHash := 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
                emitEvent(signatureHash, from, to, amount)
            }
            function emitApproval(from, spender, amount) {
                let signatureHash := 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925
                emitEvent(signatureHash, from, spender, amount)
            }
            function emitEvent(signatureHash, indexed1, indexed2, nonIndexed) {
                mstore(0, nonIndexed)
                log3(0, 0x20, signatureHash, indexed1, indexed2)
            }
            */

            /* -------- storage access helpers ---------- */
            function ownerAddress() -> o {
                o := sload(ownerPos())
            }

            // function to return minMint value
            function minMintVal() -> v {
                v := sload(minMintValPos())
            }
            
            // function to return minMint amount (total tokens per transaction)
            function minMintAmt() -> v {
                v := sload(minMintAmtPos())
            }

            // Add to tokenID balance per address
            function addToBalance(account, id, amount) {
                // location of balance[tokenID][account]  
                let offset := balancesStorageOffset(account, id)

                // update balance at storage location
                sstore(offset, safeAdd(sload(offset), amount))
            }

            // Deduct from tokenID balance per address
            function deductFromBalance(account, id, amount) {
                // location of balance[tokenID][account]
                let offset := balancesStorageOffset(account, id)
                
                // check if amount to deduct isn't more than balance
                let bal := sload(offset)
                require(lte(amount, bal))

                // update balance at storage location
                sstore(offset, sub(bal, amount))
            }

            /* ---------- memory functions ---------- */
            // get current free memory pointer location
            function getFMP() -> fmp {
                fmp := mload(0x40)
            }

            // increment free memory pointer by specified amount
            function incrementFMP(amount) {
                mstore(0x40, add(getFMP(), amount))
            }

            /* ---------- utility functions ---------- */
            function lte(a, b) -> r {
                r := iszero(gt(a, b))
            }

            function gte(a, b) -> r {
                r := iszero(lt(a, b))
            }

            function safeAdd(a, b) -> r {
                r := add(a, b)
                if or(lt(r, a), lt(r, b)) { revert(0, 0) }
            }

            function calledByOwner() -> cbo {
                cbo := eq(ownerAddress(), caller())
            }

            function require(condition) {
                if iszero(condition) { revert(0, 0) }
            }

            function revertIfZeroAddress(addr) {
                require(addr)
            }

            // check if ether was sent
            function enforceNonPayable() {
                require(iszero(callvalue()))
            }

            // checks minMint values and amount per transaction
            function equalsMinMint(amount) {
                // must be less than or equal to contructor specified max mint amount
                // (maximum tokens you can mint in one transaction) 
                require(lte(amount, minMintAmt()))

                // must equal constructor specified max mint value * amount minting
                // (value passed in must be correct for the amount you are minting)
                require(eq(mul(minMintVal(), amount), callvalue()))
            }

            // check if valid bool
            function isBool(data) {
                // if data < 2 this is a bool val (0,1)
                require(lt(data, 2))
            }

            function validInitiator(from) {
                // from == _msgSender() || isApprovedForAll(from, _msgSender())
                // if acc from is not the msg.sender and the msg.sender is not
                // ...approved for the account token is coming out of then revert
                if not(eq(caller(), from)) {
                    if not(_operatorApprovalsAccess(from, caller())) {
                        revert(0,0)
                    } 
                }
            }

            function compareArrayLengths(arr1, arr2) {
                //require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch
                let data1 := mload(arr1)
                let data2 := mload(arr2)

                require(eq(data1, data2))
            }

            function isContract(receiver) -> codeSize {
                // returns byte size of the contract code
                // if not a valid contract this will return 0
                // ...unless called via a contracts constructor
                codeSize := extcodesize(receiver)
            }
        }
    }
}