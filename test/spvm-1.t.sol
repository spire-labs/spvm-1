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

    function testGetBalance() view external {
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
        bytes memory txParam = abi.encode(MintTransactionParams("TST", address(this), 100));
        bytes memory rawTx = abi.encode(TransactionContent(address(this), 0, txParam));
        executeRawTransaction(rawTx);
        assertEq(getBalance("TST", address(this)), 100);
        assertEq(getBalance("TST", address(1)), 0);

        bytes memory txParam2 = abi.encode(MintTransactionParams("TST2", address(1), 200));
        bytes memory rawTx2 = abi.encode(TransactionContent(address(1), 0, txParam2));
        executeRawTransaction(rawTx2);
        assertEq(getBalance("TST2", address(1)), 200);
        assertEq(getBalance("TST2", address(this)), 0);
        assertEq(getBalance("TST", address(this)), 100);
    }

    function testExecuteRawTransferTransaction() external {
        bytes memory txParam = abi.encode(MintTransactionParams("TST", address(this), 100));
        bytes memory rawTx = abi.encode(TransactionContent(address(this), 0, txParam));
        executeRawTransaction(rawTx);
        assertEq(getBalance("TST", address(this)), 100);
        assertEq(getBalance("TST", address(1)), 0);

        bytes memory txParam2 = abi.encode(MintTransactionParams("TST2", address(1), 200));
        bytes memory rawTx2 = abi.encode(TransactionContent(address(1), 0, txParam2));
        executeRawTransaction(rawTx2);
        assertEq(getBalance("TST2", address(1)), 200);
        assertEq(getBalance("TST2", address(this)), 0);
        assertEq(getBalance("TST", address(this)), 100);

        bytes memory txParam3 = abi.encode(TransferTransactionParams("TST", address(1), 50));
        bytes memory rawTx3 = abi.encode(TransactionContent(address(this), 1, txParam3));
        executeRawTransaction(rawTx3);
        assertEq(getBalance("TST", address(this)), 50);
        assertEq(getBalance("TST", address(1)), 50);

        // self transfer
        bytes memory txParam4 = abi.encode(TransferTransactionParams("TST", address(this), 25));
        bytes memory rawTx4 = abi.encode(TransactionContent(address(this), 1, txParam4));
        executeRawTransaction(rawTx4);
        assertEq(getBalance("TST", address(this)), 50);
    }

    // check that function reverts when it should
    function testValidityChecking() external {
        // token already initialized
        bytes memory txParam = abi.encode(MintTransactionParams("TST", address(this), 100));
        bytes memory rawTx = abi.encode(TransactionContent(address(this), 0, txParam));
        executeRawTransaction(rawTx);
        bytes memory rawTx2 = abi.encode(TransactionContent(address(this), 0, txParam));
        vm.expectRevert("Token already initialized");
        executeRawTransaction(rawTx2);

        // token not initialized
        bytes memory txParam3 = abi.encode(TransferTransactionParams("TST2", address(1), 50));
        bytes memory rawTx3 = abi.encode(TransactionContent(address(this), 1, txParam3));
        vm.expectRevert("Token not initialized");
        executeRawTransaction(rawTx3);

        // Insufficient balance
        bytes memory txParam4 = abi.encode(TransferTransactionParams("TST", address(1), 50));
        bytes memory rawTx4 = abi.encode(TransactionContent(address(this), 1, txParam4));
        vm.expectRevert("Insufficient balance");
        executeRawTransaction(rawTx4);

        bytes memory txParam5 = abi.encode(MintTransactionParams("TST2", address(this), 999));
        bytes memory rawTx5 = abi.encode(TransactionContent(address(this), 0, txParam5));
        vm.expectRevert("Insufficient balance");
        executeRawTransaction(rawTx5);

        // Invalid transaction
        bytes memory txParam6 = abi.encode(MintTransactionParams("TST", address(this), 100));
        bytes memory rawTx6 = abi.encode(TransactionContent(address(this), 2, txParam6));
        vm.expectRevert("Invalid transaction type");
        executeRawTransaction(rawTx6);
    }

    function testValidateSignature() view external {
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
        bytes memory txParam = abi.encode(MintTransactionParams("TST", signer, 100));
        bytes memory rawTx = abi.encode(TransactionContent(signer, 0, txParam));
        bytes32 txHash = keccak256(rawTx);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, txHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        Transaction memory Tx = Transaction(TransactionContent(signer, 0, txParam), txHash, signature);
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
}
