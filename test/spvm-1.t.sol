// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/spvm-1.sol";

contract SPVMTest is Test, SPVM {
    uint256 internal pk;
    address internal signer;

    function setUp() public {
        pk = 0x1234567890abcdef;
        signer = vm.addr(pk);
    }

    function createTransaction(
        address _signer,
        uint8 _type,
        bytes memory _params
    ) internal returns (Transaction memory) {
        bytes memory rawTx = abi.encode(TransactionContent(_signer, _type, _params));
        bytes32 txHash = keccak256(rawTx);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, txHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        return Transaction(TransactionContent(_signer, _type, _params), txHash, signature);
    }

    function encodeRawTransaction(Transaction memory _tx) internal returns (bytes memory) {
        return abi.encode(_tx.txContent, _tx.transactionHash, _tx.signature);
    }

    function createMintTransaction(
        string memory _tokenTicker,
        address _owner,
        uint16 _supply
    ) internal returns (Transaction memory) {
        bytes memory txParam = abi.encode(MintTransactionParams(_tokenTicker, _owner, _supply));
        return createTransaction(_owner, 0, txParam);
    }

    function createTransferTransaction(
        string memory _tokenTicker,
        address _from,
        address _to,
        uint16 _amount
    ) internal returns (Transaction memory) {
        bytes memory txParam = abi.encode(TransferTransactionParams(_tokenTicker, _to, _amount));
        return createTransaction(_from, 1, txParam);
    }

    function testGetBalance() external view {
        assertEq(getBalance("TST", address(this)), 0);
    }

    function testSetBalance() external {
        setBalance("TST", address(this), 100);
        assertEq(getBalance("TST", address(this)), 100);

        setBalance("TST", address(1), 200);
        assertEq(getBalance("TST", address(1)), 200);

        setBalance("TST", address(this), 0);
        assertEq(getBalance("TST", address(this)), 0);
    }

    function testExecuteRawMintTransaction() external {
        Transaction memory tx1 = createMintTransaction("TST", address(this), 100);

        // Execute the transaction
        executeRawTransaction(encodeRawTransaction(tx1));
        assertEq(getBalance("TST", address(this)), 100);
        assertEq(getBalance("TST", address(1)), 0);

        Transaction memory tx2 = createMintTransaction("TST2", address(1), 200);

        // Execute the second transaction
        executeRawTransaction(encodeRawTransaction(tx2));
        assertEq(getBalance("TST2", address(1)), 200);
        assertEq(getBalance("TST2", address(this)), 0);
        assertEq(getBalance("TST", address(this)), 100);
    }

    function testExecuteRawTransferTransaction() external {
        Transaction memory tx1 = createMintTransaction("TST", address(this), 100);
        executeRawTransaction(encodeRawTransaction(tx1));
        assertEq(getBalance("TST", address(this)), 100);
        assertEq(getBalance("TST", address(1)), 0);

        Transaction memory tx2 = createMintTransaction("TST2", address(1), 200);
        executeRawTransaction(encodeRawTransaction(tx2));
        assertEq(getBalance("TST2", address(1)), 200);
        assertEq(getBalance("TST2", address(this)), 0);
        assertEq(getBalance("TST", address(this)), 100);

        Transaction memory tx3 = createTransferTransaction("TST", address(this), address(1), 50);
        executeRawTransaction(encodeRawTransaction(tx3));
        assertEq(getBalance("TST", address(this)), 50);
        assertEq(getBalance("TST", address(1)), 50);

        // self transfer
        Transaction memory tx4 = createTransferTransaction("TST", address(this), address(this), 50);
        executeRawTransaction(encodeRawTransaction(tx4));
        assertEq(getBalance("TST", address(this)), 50);
    }

    // check that function reverts when it should
    function testValidityChecking() external {
        // token already initialized
        Transaction memory tx1 = createMintTransaction("TST", address(this), 100);
        executeRawTransaction(encodeRawTransaction(tx1));
        Transaction memory tx2 = createMintTransaction("TST", address(this), 100);
        vm.expectRevert("Token already initialized");
        executeRawTransaction(encodeRawTransaction(tx2));

        // token not initialized
        Transaction memory tx3 = createTransferTransaction("TST", address(this), address(1), 50);
        vm.expectRevert("Token not initialized");
        executeRawTransaction(encodeRawTransaction(tx3));

        // Insufficient balance
        Transaction memory tx4 = createTransferTransaction("TST", address(this), address(1), 100);
        vm.expectRevert("Insufficient balance");
        executeRawTransaction(encodeRawTransaction(tx4));

        Transaction memory tx5 = createTransferTransaction("TST", address(1), address(this), 100);
        vm.expectRevert("Insufficient balance");
        executeRawTransaction(encodeRawTransaction(tx5));

        // Invalid transaction
        bytes memory txParam6 = abi.encode(
            MintTransactionParams("TST", address(this), 100)
        );
        bytes memory rawTx6 = abi.encode(
            TransactionContent(address(this), 2, txParam6)
        );
        vm.expectRevert("Invalid transaction type");
        executeRawTransaction(rawTx6);
    }

    function testValidateSignature() external view {
        bytes32 tx_hash = keccak256(abi.encodePacked("test"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, tx_hash);
        bytes memory signature = abi.encodePacked(r, s, v); // note the order here is different from line above.

        assert(validateSignature(tx_hash, signature, signer));
    }

    function testInvalidSignature() external {
        bytes32 tx_hash = keccak256(abi.encodePacked("test"));

        bytes memory signature = bytes("test");
        vm.expectRevert("Invalid signature");
        validateSignature(tx_hash, signature, signer);
    }

    // test executeTx
    function testExecuteTx() external {
        bytes memory txParam = abi.encode(
            MintTransactionParams("TST", signer, 100)
        );
        bytes memory rawTx = abi.encode(TransactionContent(signer, 0, txParam));
        bytes32 txHash = keccak256(rawTx);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, txHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        Transaction memory Tx = Transaction(
            TransactionContent(signer, 0, txParam),
            txHash,
            signature
        );
        executeTx(Tx);
        assertEq(getBalance("TST", signer), 100);
    }

    ////// BLOCK ///////
    function testInitialBlockState() external view {
        assert(blocks[0].blockNumber == 0);
        assert(blocks[0].parentHash == bytes32(0));
        assert(blocks[0].blockHash == bytes32(0));
        assert(blocks[0].transactions.length == 0);
    }

    function testExecuteBlockTransactions() external {
        bytes memory txParam = abi.encode(
            MintTransactionParams("TST", signer, 100)
        );
        bytes memory rawTx = abi.encode(TransactionContent(signer, 0, txParam));
        bytes32 txHash = keccak256(rawTx);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, txHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        Transaction memory Tx = Transaction(
            TransactionContent(signer, 0, txParam),
            txHash,
            signature
        );

        bytes memory txParam2 = abi.encode(
            MintTransactionParams("TST2", signer, 200)
        );
        bytes memory rawTx2 = abi.encode(
            TransactionContent(signer, 0, txParam2)
        );
        bytes32 txHash2 = keccak256(rawTx2);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pk, txHash2);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);
        Transaction memory Tx2 = Transaction(
            TransactionContent(signer, 0, txParam2),
            txHash2,
            signature2
        );

        // transfer
        bytes memory txParam3 = abi.encode(
            TransferTransactionParams("TST2", address(1), 50)
        );
        bytes memory rawTx3 = abi.encode(
            TransactionContent(signer, 1, txParam3)
        );
        bytes32 txHash3 = keccak256(rawTx3);
        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(pk, txHash3);
        bytes memory signature3 = abi.encodePacked(r3, s3, v3);
        Transaction memory Tx3 = Transaction(
            TransactionContent(signer, 1, txParam3),
            txHash3,
            signature3
        );

        Transaction[] memory txs = new Transaction[](3);
        txs[0] = Tx;
        txs[1] = Tx2;
        txs[2] = Tx3;

        executeBlockTransactions(txs);
        assertEq(getBalance("TST", signer), 100);
        assertEq(getBalance("TST2", signer), 150);
        assertEq(getBalance("TST2", address(1)), 50);
    }

    function testProposeEmptyBlock() external {
        bytes memory txs_raw = abi.encode(new Transaction[](0));

        bytes32 blockHash = keccak256(
            abi.encodePacked(blocks[0].blockHash, txs_raw)
        );

        Block memory b = Block({
            blockNumber: 1,
            parentHash: blocks[0].blockHash,
            blockHash: blockHash,
            transactions: new Transaction[](0)
        });

        this.proposeBlock(b);

        assertEq(blocks[1].blockNumber, 1);
        assertEq(blocks[1].parentHash, blocks[0].blockHash);
        assertEq(blocks[1].blockHash, blockHash);
        assertEq(blocks[1].transactions.length, 0);
    }

    function testProposeBlock() external {
        // propose a block with one transaction
        bytes memory txParam = abi.encode(
            MintTransactionParams("TST", signer, 100)
        );
        bytes memory rawTx = abi.encode(TransactionContent(signer, 0, txParam));
        bytes32 txHash = keccak256(rawTx);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, txHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        Transaction memory Tx = Transaction(
            TransactionContent(signer, 0, txParam),
            txHash,
            signature
        );

        Transaction[] memory txs = new Transaction[](1);
        txs[0] = Tx;

        bytes memory txs_raw = abi.encode(txs);

        bytes32 blockHash = keccak256(
            abi.encodePacked(blocks[0].blockHash, txs_raw)
        );

        Block memory b = Block({
            blockNumber: 1,
            parentHash: blocks[0].blockHash,
            blockHash: blockHash,
            transactions: txs
        });

        this.proposeBlock(b);

        assertEq(blocks[1].blockNumber, 1);
        assertEq(blocks[1].parentHash, blocks[0].blockHash);
        assertEq(blocks[1].blockHash, blockHash);
        assertEq(blocks[1].transactions.length, 1);
        assertEq(getBalance("TST", signer), 100);

        // second block
        bytes memory txParam2 = abi.encode(
            TransferTransactionParams("TST", address(1), 50)
        );
        bytes memory rawTx2 = abi.encode(
            TransactionContent(signer, 1, txParam2)
        );
        bytes32 txHash2 = keccak256(rawTx2);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pk, txHash2);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);
        Transaction memory Tx2 = Transaction(
            TransactionContent(signer, 1, txParam2),
            txHash2,
            signature2
        );

        Transaction[] memory txs2 = new Transaction[](1);
        txs2[0] = Tx2;

        bytes memory txs_raw2 = abi.encode(txs2);

        bytes32 blockHash2 = keccak256(
            abi.encodePacked(blocks[1].blockHash, txs_raw2)
        );

        Block memory b2 = Block({
            blockNumber: 2,
            parentHash: blocks[1].blockHash,
            blockHash: blockHash2,
            transactions: txs2
        });

        this.proposeBlock(b2);

        assertEq(blocks[2].blockNumber, 2);
        assertEq(blocks[2].parentHash, blocks[1].blockHash);
        assertEq(blocks[2].blockHash, blockHash2);
        assertEq(blocks[2].transactions.length, 1);
        assertEq(getBalance("TST", signer), 50);
        assertEq(getBalance("TST", address(1)), 50);
    }

    function testProposeBlockWithMultipleTxs() external {
        // mint
        bytes memory txParam = abi.encode(
            MintTransactionParams("TST", signer, 100)
        );
        bytes memory rawTx = abi.encode(TransactionContent(signer, 0, txParam));
        bytes32 txHash = keccak256(rawTx);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, txHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        Transaction memory Tx = Transaction(
            TransactionContent(signer, 0, txParam),
            txHash,
            signature
        );

        // transfer
        bytes memory txParam2 = abi.encode(
            TransferTransactionParams("TST", address(1), 50)
        );
        bytes memory rawTx2 = abi.encode(
            TransactionContent(signer, 1, txParam2)
        );
        bytes32 txHash2 = keccak256(rawTx2);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pk, txHash2);
        bytes memory signature2 = abi.encodePacked(r2, s2, v2);
        Transaction memory Tx2 = Transaction(
            TransactionContent(signer, 1, txParam2),
            txHash2,
            signature2
        );

        Transaction[] memory txs = new Transaction[](2);
        txs[0] = Tx;
        txs[1] = Tx2;

        bytes memory txs_raw = abi.encode(txs);

        bytes32 blockHash = keccak256(
            abi.encodePacked(blocks[0].blockHash, txs_raw)
        );

        Block memory b = Block({
            blockNumber: 1,
            parentHash: blocks[0].blockHash,
            blockHash: blockHash,
            transactions: txs
        });

        this.proposeBlock(b);

        assertEq(blocks[1].blockNumber, 1);
        assertEq(blocks[1].parentHash, blocks[0].blockHash);
        assertEq(blocks[1].blockHash, blockHash);
        assertEq(blocks[1].transactions.length, 2);
        assertEq(getBalance("TST", signer), 50);
        assertEq(getBalance("TST", address(1)), 50);
    }
}
