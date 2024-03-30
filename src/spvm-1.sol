// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

/// @title Spire PoC Virtual Machine - version 1 - interpreter
/// @author mteam
contract SPVM {
    mapping(string => bool) public initialized_tickers;
    mapping(string => mapping(address => uint16)) public state;
    // all historical blocks
    Block[] public blocks; 

    struct TransactionContent {
        address from;
        uint8 txType; // only first 2 bits used
        bytes txParam; // abi encoded parameters
    }

    struct MintTransactionParams {
        string tokenTicker;
        address owner;
        uint16 supply;
    }

    struct TransferTransactionParams {
        string tokenTicker;
        address to;
        uint16 amount;
    }

    struct Block {
        Transaction[] transactions;
        bytes32 blockHash;
        bytes32 parentHash;
        string blockNumber;
    }

    struct Transaction {
        TransactionContent txContent;
        bytes32 transactionHash;
        bytes signature;
    }

    // Function to set a balance in the nested map
    function setBalance(
        string tokenTicker,
        address holder_address,
        uint16 balance
    ) internal {
        initialized_tickers[tokenTicker] = true;
        state[tokenTicker][holder_address] = balance;
    }

    // Function to get a balance from the nested map
    function getBalance(
        string tokenTicker,
        address holder_address
    ) external view returns (uint16) {
        return state[tokenTicker][holder_address];
    }

    function executeRawTransaction(bytes memory rawTx) internal {
        TransactionContent memory txContent = abi.decode(
            rawTx,
            (TransactionContent)
        );

        require(checkValidity(txContent), "Invalid transaction");

        if (txContent.txType == 0) {
            MintTransactionParams memory mintParams = abi.decode(
                txContent.txParam,
                (MintTransactionParams)
            );
            this.setBalance(
                mintParams.tokenTicker,
                mintParams.owner,
                mintParams.supply
            );
        } else if (txContent.txType == 1) {
            TransferTransactionParams memory transferParams = abi.decode(
                txContent.txParam,
                (TransferTransactionParams)
            );
            uint16 fromBalance = this.getBalance(
                transferParams.tokenTicker,
                txContent.from
            );
            uint16 toBalance = this.getBalance(
                transferParams.tokenTicker,
                transferParams.to
            );
            state[transferParams.tokenTicker][txContent.from] =
                fromBalance -
                transferParams.amount;
            state[transferParams.tokenTicker][transferParams.to] =
                toBalance +
                transferParams.amount;
        }
    }

    function checkValidity(
        TransactionContent memory txContent
    ) internal view returns (bool) {
        if (txContent.txType == 0) {
            MintTransactionParams memory mintParams = abi.decode(
                txContent.txParam,
                (MintTransactionParams)
            );
            require(
                !initialized_tickers[mintParams.tokenTicker],
                "Token already initialized"
            );
        } else if (txContent.txType == 1) {
            TransferTransactionParams memory transferParams = abi.decode(
                txContent.txParam,
                (TransferTransactionParams)
            );
            require(
                initialized_tickers[transferParams.tokenTicker],
                "Token not initialized"
            );
            require(
                state[transferParams.tokenTicker][txContent.from] >=
                    transferParams.amount,
                "Insufficient balance"
            );
        } else {
            revert("Invalid transaction type");
        }
        return true;
    }

    // recover signer of transaction from signature
    function validateSignature(
        bytes32 transaction_hash,
        bytes memory signature,
        address expected_signer
    ) internal pure returns (bool) {
        return SignatureChecker.isValidSignatureNow(
            expected_signer,
            transaction_hash,
            signature
        );
    }

    function executeTx(
        Transaction tx
    ) internal {
        bytes32 txHash = keccak256(abi.encode(tx.txContent));
        require(
            txHash == tx.transactionHash,
            "Invalid transaction hash"
        );
        require(
            validateSignature(tx.transactionHash, tx.signature, txContent.from),
            "Invalid signature"
        );
        executeRawTransaction(abi.encode(txContent));
    }

    function executeBlockTransactions(
        Transaction[] memory txs
    ) internal {
        for (uint i = 0; i < txs.length; i++) {
            executeTx(txs[i]);
        }
    }

    // TODO: add permissions
    function proposeBlock (
        Block memory block
    ) external {
        // get most recent block
        Block memory lastBlock = blocks[blocks.length - 1];

        require(
            block.blockHash == keccak256(block.parentHash + abi.encode(block.transactions)),
            "Invalid block hash"
        );
        require(
            block.blockNumber == lastBlock.blockNumber + 1,
            "Invalid block number"
        );
        require(
            block.parentHash == lastBlock.blockHash,
            "Invalid parent hash"
        );

        blocks.push(block);

        executeBlockTransactions(block.transactions);
    }
}
