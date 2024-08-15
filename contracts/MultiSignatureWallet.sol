// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

///This is a simple multi-signature wallet implementation for transferring ether.
///This contract outlines all the basic functionality of a multi-sig wallet.
contract MultiSignatureWallet {
    struct Transaction {
        address receiver;
        uint256 amount;
        //uint256 confirmedCount;
        bool isExecuted;
    }

    uint256 private numOfConfirmations; //confirmations required to execute a transaction.
    Transaction[] public transactions;
    address[] private owners; //Signers of the transaction
    mapping(uint256 => mapping(address => bool)) isTransactionSigned;
    mapping(address => bool) private isOwner;

    event TransactionSubmitted(
        uint256 indexed transactionId,
        address indexed sender,
        address indexed receiver,
        uint256 amount
    );

    error MultiSig_InvalidTxId();
    error MultiSig_TxAlreadyExecuted();

    constructor(uint256 _numOfConfirmations, address[] memory _owners) {
        require(
            _numOfConfirmations > 1 && _numOfConfirmations < _owners.length,
            "MultiSig: Invalid confirmations"
        );
        uint256 ownersLength = _owners.length;
        address owner;
        for (uint256 i = 0; i < ownersLength; ++i) {
            owner = _owners[i];
            require(owner != address(0), "MultiSig: Invalid owner address");
            require(!isOwner[owner], "MultiSig: Already a owner");
            isOwner[owner] = true;
            owners.push(owner);
        }
        numOfConfirmations = _numOfConfirmations;
    }

    function submitTransaction(address _receiver) public payable {
        require(_receiver != address(0), "MultiSig: Invalid receiver address");
        require(msg.value > 0, "MultiSig: Invalid ether value");
        uint256 transactionId = transactions.length;
        transactions.push(
            Transaction({
                receiver: _receiver,
                amount: msg.value,
                //confirmedCount: 0,
                isExecuted: false
            })
        );
        emit TransactionSubmitted(
            transactionId,
            msg.sender,
            _receiver,
            msg.value
        );
    }

    function signTheTransaction(uint256 _transactionId) public {
        if (_transactionId >= transactions.length)
            revert MultiSig_InvalidTxId();
        require(
            isOwner[msg.sender],
            "MultiSig: Only owner is allowed to sign the transaction"
        );
        require(
            !isTransactionSigned[_transactionId][msg.sender],
            "MultiSig: transaction already signed"
        );
        // require(
        //     !transactions[_transactionId].isExecuted,
        //     "MultiSig: can't sign! Transaction already executed"
        // );
        Transaction storage transaction = transactions[_transactionId];
        if (transaction.isExecuted) revert MultiSig_TxAlreadyExecuted();
        isTransactionSigned[_transactionId][msg.sender] = true;

        if (canExecuteTransaction(_transactionId)) {
            executeTransaction(_transactionId);
        }
    }

    function executeTransaction(uint256 _transactionId) public payable {
        if (_transactionId >= transactions.length)
            revert MultiSig_InvalidTxId();
        Transaction storage transaction = transactions[_transactionId];
        if (transaction.isExecuted) revert MultiSig_TxAlreadyExecuted();
        (bool success, ) = transaction.receiver.call{value: transaction.amount}(
            ""
        );
        require(success, "MultiSig: execute transaction failed");
        transaction.isExecuted = true;
    }

    function canExecuteTransaction(
        uint256 _transactionId
    ) internal view returns (bool) {
        uint256 arrayLength = owners.length;
        uint256 confirmations = 0;
        for (uint256 i = 0; i < arrayLength; ++i) {
            unchecked {
                if (isTransactionSigned[_transactionId][owners[i]])
                    ++confirmations;
            }
        }
        return confirmations >= numOfConfirmations;
    }
}
