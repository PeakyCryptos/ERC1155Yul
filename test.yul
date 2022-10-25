object "Token" {
    code {
        // Store the creator in slot zero.
        sstore(0, caller())

        // Store the minMint value in slot one
        // 1000000000000000 = 0.001 eth
        sstore(1, 1000000000000000)

        // Store minMint amount in slot two
        // 10 mints of an id at once
        sstore(1, 10)

        // store the uri string
object "Token" {
    code {
        // Store the creator in slot zero.
        sstore(0, caller())

        // Store the minMint value in slot one
        // 1000000000000000 = 0.001 eth
        sstore(1, 1000000000000000)

        // Store minMint amount in slot two
        // 10 mints of an id at once
        sstore(1, 10)

        // store the uri string

        // Deploy the contract
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        return(0, datasize("runtime"))
    }
    object "runtime" {
        code {   
            // Dispatcher
            // All high-level functions
            switch selector()
            case 0xd330b578 /* "balanceOf(address, uint256)" */ {
                enforceNonPayable()
                returnUint(balanceOf(decodeAsAddress(0), decodeAsUint(1)))
            }
            case 0xe985e9c5 /* "isApprovedForAll(address,address)" */ {
                enforceNonPayable()
                returnBool(_operatorApprovalsAccess(decodeAsAddress(0), decodeAsAddress(1)))
            }
            case 0x989579aa /* "setApprovalForAll(address, bool)" */ {
                enforceNonPayable()
                // _setApprovalForAll(_msgSender(), operator, approved)
                _setApprovalForAll(caller(), decodeAsAddress(0), decodeAsBool(1))
            }
            case 0x156e29f6 /* "mint(address,uint256,uint256)" */ {                
                // call low-level mint
                _mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2)/*, decodeAsBytes(3)*/)
                
                // on success
                returnTrue()
            }
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
            // operatorApprovals[account][spender] 
			function operatorApprovalsMappingPos() -> p { p := 5 } 
	
            // Mapping from token ID to account balances
            // mapping(uint256 => mapping(address => uint256)) private _balances;
			// keccak256(abi.encode(address, keccak256(abi.encode(ID_uint, uint256(IDslotHash)))));
            function balancesStorageOffset(account, id) -> offset {	
				// nested mapping
                mstore(0x00, account)
				mstore(0x20, acctBalancesMappingPos())  
				let nestedMappingHash := keccak256(0, 0x40)

                // outter mapping
                mstore(0x60, id)
                mstore(0x80, nestedMappingHash)

                // location balances[tokenID][account] 
                offset := keccak256(0x60, 0x80)
			}

			function operatorApprovalsStorageOffset(account, operator) -> offset {
				// nested mapping
                mstore(0x00, account)
				mstore(0x20, operatorApprovalsMappingPos())  
				let nestedMappingHash := keccak256(0, 0x40)

                // outter mapping
                mstore(0x60, operator)
                mstore(0x80, nestedMappingHash)

                // location operatorApprovals[account][operator] 
                offset := keccak256(0x60, 0x80)
			}

            /* ---------- high-level functions ----------- */
            /* should be blended into the case (those are the high-level functions)
            // comment these out **************
            function transfer(to, amount) {
                executeTransfer(caller(), to, amount)
            }

            function approve(spender, amount) {
                revertIfZeroAddress(spender)
                setAllowance(caller(), spender, amount)
                emitApproval(caller(), spender, amount)
            }

            function transferFrom(from, to, amount) {
                decreaseAllowanceBy(from, caller(), amount)
                executeTransfer(from, to, amount)
            }

            function executeTransfer(from, to, amount) {
                revertIfZeroAddress(to)
                deductFromBalance(from, amount)
                addToBalance(to, amount)
                emitTransfer(from, to, amount)
            }
            */
            // comment these out **************

            /* -------- storage access low-level functions ---------- */
            // works successfully
            //calls into low-level mint
            function _mint(to, id, amount /*, data*/) {
                // check if they passed in 0.001 ether
                // and max 1 mint at a time
                equalsMinMint(amount)

                // check if deployer of contract(owner) is calling
                require(calledByOwner())

                // _balances[id][to] += amount;
                addToBalance(to, id, amount)

                // emit TransferSingle(operator, address(0), to, id, amount);

                // _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
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
                data := calldataload(pos)  
                
                // check if bool (0 or 1)
                // if not reverts
                isBool(data) 

                // return
                //b := data
            }

            /*
            function decodeAsBytes(offset) -> v {
                // Work in progress
                let pos := add(4, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }
                v := calldataload(pos)
            }
            */

            /* ---------- calldata encoding functions ---------- */
            function returnUint(v) {
                mstore(0, v)
                return(0, 0x20)
            }

            function returnBool(b) {
                mstore(0, b)
                return(0, 0x20)
            }

            function returnTrue() {
                returnUint(1)
            }

            /* -------- events ---------- */
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

            function balanceOf(account, id) -> bal {
                //make sure not 0 address
                revertIfZeroAddress(account)

                // return balance[id][account]               
                bal := sload(balancesStorageOffset(account, id))
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
                // must equal contructor specified max mint amount 
                require(eq(minMintAmt(), amount))
                // must equal constructor specified max mint value
                require(eq(minMintVal(), callvalue()))
            }

            // check if valid bool
            function isBool(data) {
                // if data < 2 this is a bool val (0,1)
                require(lt(data, 2))
            }
        }
    }
}
        // Deploy the contract
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        return(0, datasize("runtime"))
    }
    object "runtime" {
        code {   
            // Dispatcher
            // All high-level functions
            switch selector()
            case 0xd330b578 /* "balanceOf(address, uint256)" */ {
                enforceNonPayable()
                returnUint(balanceOf(decodeAsAddress(0), decodeAsUint(1)))
            }
            case 0xe985e9c5 /* "isApprovedForAll(address,address)" */ {
                enforceNonPayable()
                returnBool(_operatorApprovalsAccess(decodeAsAddress(0), decodeAsAddress(1)))
            }
            case 0x989579aa /* "setApprovalForAll(address, bool)" */ {
                enforceNonPayable()
                // _setApprovalForAll(_msgSender(), operator, approved)
                _setApprovalForAll(caller(), decodeAsAddress(0), decodeAsBool(1))
            }
            case 0x156e29f6 /* "mint(address,uint256,uint256)" */ {                
                // call low-level mint
                _mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2)/*, decodeAsBytes(3)*/)
                
                // on success
                returnTrue()
            }
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
            // operatorApprovals[account][spender] 
			function operatorApprovalsMappingPos() -> p { p := 5 } 
	
            // Mapping from token ID to account balances
            // mapping(uint256 => mapping(address => uint256)) private _balances;
			// keccak256(abi.encode(address, keccak256(abi.encode(ID_uint, uint256(IDslotHash)))));
            function balancesStorageOffset(account, id) -> offset {	
				// nested mapping
                mstore(0x00, account)
				mstore(0x20, acctBalancesMappingPos())  
				let nestedMappingHash := keccak256(0, 0x40)

                // outter mapping
                mstore(0x60, id)
                mstore(0x80, nestedMappingHash)

                // location balances[tokenID][account] 
                offset := keccak256(0x60, 0x80)
			}

			function operatorApprovalsStorageOffset(account, operator) -> offset {
				// nested mapping
                mstore(0x00, account)
				mstore(0x20, operatorApprovalsMappingPos())  
				let nestedMappingHash := keccak256(0, 0x40)

                // outter mapping
                mstore(0x60, operator)
                mstore(0x80, nestedMappingHash)

                // location operatorApprovals[account][operator] 
                offset := keccak256(0x60, 0x80)
			}

            /* ---------- high-level functions ----------- */
            /* should be blended into the case (those are the high-level functions)
            // comment these out **************
            function transfer(to, amount) {
                executeTransfer(caller(), to, amount)
            }

            function approve(spender, amount) {
                revertIfZeroAddress(spender)
                setAllowance(caller(), spender, amount)
                emitApproval(caller(), spender, amount)
            }

            function transferFrom(from, to, amount) {
                decreaseAllowanceBy(from, caller(), amount)
                executeTransfer(from, to, amount)
            }

            function executeTransfer(from, to, amount) {
                revertIfZeroAddress(to)
                deductFromBalance(from, amount)
                addToBalance(to, amount)
                emitTransfer(from, to, amount)
            }
            */
            // comment these out **************

            /* -------- storage access low-level functions ---------- */
            // works successfully
            //calls into low-level mint
            function _mint(to, id, amount /*, data*/) {
                // check if they passed in 0.001 ether
                // and max 1 mint at a time
                equalsMinMint(amount)

                // check if deployer of contract(owner) is calling
                require(calledByOwner())

                // _balances[id][to] += amount;
                addToBalance(to, id, amount)

                // emit TransferSingle(operator, address(0), to, id, amount);

                // _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
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

            function decodeAsBool(offset) -> b {
               let pos := add(4, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }

                // load bool value (full 32 bytes)
                let data := calldataload(pos)  
                
                // check if bool (0 or 1)
                // if not reverts
                isBool(data) 

                // return
                //b := data
            }

            /*
            function decodeAsBytes(offset) -> v {
                // Work in progress
                let pos := add(4, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }
                v := calldataload(pos)
            }
            */

            /* ---------- calldata encoding functions ---------- */
            function returnUint(v) {
                mstore(0, v)
                return(0, 0x20)
            }

            function returnBool(b) {
                mstore(0, b)
                return(0, 0x20)
            }

            function returnTrue() {
                returnUint(1)
            }

            /* -------- events ---------- */
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

            function balanceOf(account, id) -> bal {
                //make sure not 0 address
                revertIfZeroAddress(account)

                // return balance[id][account]               
                bal := sload(balancesStorageOffset(account, id))
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
                // must equal contructor specified max mint amount 
                require(eq(minMintAmt(), amount))
                // must equal constructor specified max mint value
                require(eq(minMintVal(), callvalue()))
            }

            // check if valid bool
            function isBool(data) {
                // if data < 2 this is a bool val (0,1)
                require(lt(data, 2))
            }
        }
    }
}