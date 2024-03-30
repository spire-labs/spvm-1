// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/spvm-1.sol";

contract SPVMTest is Test {
    SPVM spvm;

    function setUp() public {
        spvm = new SPVM();
    }

    function test_setBalance() public {
        spvm.setBalance(1, address(this), 100);
        assertEq(spvm.getBalance(1, address(this)), 100);
    }

    function test_getBalance() public {
        spvm.setBalance(1, address(this), 100);
        assertEq(spvm.getBalance(1, address(this)), 100);
    }

    function test_initialized_tickers() public {
        spvm.setBalance(1, address(this), 100);
        assertEq(spvm.initialized_tickers(1), true);
    }

    function test_executeRawTransaction() public {
        bytes memory rawTx = abi.encode(
            SPVM.TransactionContent({
                from: address(this),
                txType: 0,
                txParam: abi.encode(
                    SPVM.MintTransactionParams({
                        tokenTicker: 1,
                        owner: address(this),
                        supply: 100
                    })
                )
            })
        );
        spvm.executeRawTransaction(rawTx);
        assertEq(spvm.getBalance(1, address(this)), 100);

        rawTx = abi.encode(
            SPVM.TransactionContent({
                from: address(this),
                txType: 1,
                txParam: abi.encode(
                    SPVM.TransferTransactionParams({
                        tokenTicker: 1,
                        to: address(0),
                        amount: 50
                    })
                )
            })
        );
        spvm.executeRawTransaction(rawTx);
        assertEq(spvm.getBalance(1, address(this)), 50);
        assertEq(spvm.getBalance(1, address(0)), 50);
    }

    // test that the checkValidity function reverts when the transaction is invalid
    function test_checkValidity_revert() public {
        bytes memory rawTx = abi.encode(
            SPVM.TransactionContent({
                from: address(this),
                txType: 0,
                txParam: abi.encode(
                    SPVM.MintTransactionParams({
                        tokenTicker: 1,
                        owner: address(this),
                        supply: 100
                    })
                )
            })
        );
        spvm.executeRawTransaction(rawTx);

        rawTx = abi.encode(
            SPVM.TransactionContent({
                from: address(this),
                txType: 0,
                txParam: abi.encode(
                    SPVM.MintTransactionParams({
                        tokenTicker: 1,
                        owner: address(this),
                        supply: 100
                    })
                )
            })
        );
        vm.expectRevert(bytes("Token already initialized"));
        spvm.executeRawTransaction(rawTx);

        rawTx = abi.encode(
            SPVM.TransactionContent({
                from: address(this),
                txType: 1,
                txParam: abi.encode(
                    SPVM.TransferTransactionParams({
                        tokenTicker: 2,
                        to: address(0),
                        amount: 50
                    })
                )
            })
        );

        vm.expectRevert(bytes("Token not initialized"));
        spvm.executeRawTransaction(rawTx);

        rawTx = abi.encode(
            SPVM.TransactionContent({
                from: address(this),
                txType: 1,
                txParam: abi.encode(
                    SPVM.TransferTransactionParams({
                        tokenTicker: 1,
                        to: address(0),
                        amount: 150
                    })
                )
            })
        );

        vm.expectRevert(bytes("Insufficient balance"));
        spvm.executeRawTransaction(rawTx);

        rawTx = abi.encode(
            SPVM.TransactionContent({
                from: address(this),
                txType: 1,
                txParam: abi.encode(
                    SPVM.TransferTransactionParams({
                        tokenTicker: 1,
                        to: address(0),
                        amount: 50
                    })
                )
            })
        );

        spvm.executeRawTransaction(rawTx);
    }
}
