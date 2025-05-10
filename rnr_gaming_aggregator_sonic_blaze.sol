// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "./RandomNumberRetailerInterface.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";


interface RNRBaccaratInterface {
        struct Proof {
            uint256[2] pk;
            uint256[2] gamma;
            uint256 c;
            uint256 s;
            uint256 seed;
            address uWitness;
            uint256[2] cGammaWitness;
            uint256[2] sHashWitness;
            uint256 zInv;
        }

        struct RequestCommitment {
            uint64 blockNum;
            uint256 subId;
            uint32 callbackGasLimit;
            uint32 numWords;
            address sender;
            bytes extraArgs;
        }

        function largestBetAllowedInWei() external view returns (uint256 largestBetAllowedInWei);

        enum Suit{ HEART, SPADE, CLUB, DIAMOND }

        struct Card{
            string cardValue;
            Suit suit;
        }

        enum HandResult{ PLAYER_WIN, BANKER_WIN, DRAW }

        function playAsAggregator(
            bool userIsPlayer, 
            Proof memory proof, 
            RequestCommitment memory rc, 
            address userAddress
        ) external payable returns (Card[] memory playerCards, Card[] memory bankerCards, HandResult result);
}


struct BaccaratInput{
    address user;
    bool userIsPlayer;
    uint256 totalAmountPlayerSentInWei;
}

contract RNRGamingAggregator is ReentrancyGuard
{
    address public ownerAddress = 0x5F13FF49EF06a108c66D45C2b1F1211dBdE154CD;
    address private constant serverAddress = 0xD16512fdBb90096B1f1888Cae6152177065FdA62;
    IERC20 randoToken = IERC20(0x8BDe81Dd5e30b058b71362b50faD06e3fdACE640);
    RandomNumberRetailerInterface public constant RANDOM_NUMBER_RETAILER = RandomNumberRetailerInterface(0x91B80393Fd73775f48553e4F54C23EdB114463a0);
    RNRBaccaratInterface public constant RNR_BACCARAT = RNRBaccaratInterface(0xf47165AC10dDB50bd7DFa9e3AF4C442a00762C98);

    uint8 public minimumQueueLengthToExecuteTransactions = 1;
    uint8 public maximumLengthOfQueue = 20;

    modifier onlyOwner() {
        require(
            msg.sender == ownerAddress, 
            "FAILURE: Only the owner can call this method."
        );

        _;
    }

    modifier onlyServer() {
        require(
            msg.sender == serverAddress, 
            "FAILURE: Only the server can call this method."
        );

        _;
    }

    function setMinimumQueueLengthToExecuteTransactions (uint8 newMinimumQueueLengthToExecuteTransactions) external onlyOwner{
        minimumQueueLengthToExecuteTransactions = newMinimumQueueLengthToExecuteTransactions;
    }

    function setMaximumLengthOfQueue (uint8 newSetMaximumLengthOfQueue) external onlyOwner{
        maximumLengthOfQueue = newSetMaximumLengthOfQueue;
    }
    
    mapping(bool => BaccaratInput[]) public baccaratHandQueue;

    function playBaccarat(
        bool userIsPlayer
    ) external payable {

        uint256 priceOfARandomNumberInWei = RANDOM_NUMBER_RETAILER.priceOfARandomNumberInWei();
        uint256 amountToBetWithInWei = msg.value - priceOfARandomNumberInWei;

        require(
            amountToBetWithInWei > 0,
            "ERROR: You did not send enough ETH to pay for the RNR random number. Please send more ETH next time."
        );

        require(
            amountToBetWithInWei <= RNR_BACCARAT.largestBetAllowedInWei(),
            "ERROR: Your bet is too large. Please bet less ETH."
        );

        require(
            baccaratHandQueue[true].length < maximumLengthOfQueue,
            "Error: The play queue is already full. Please wait a minute and try again."
        );

        BaccaratInput memory input =  BaccaratInput(msg.sender, userIsPlayer, msg.value);
        baccaratHandQueue[true].push(input);
    }

    // add handPlayedOnBehalfOf to baccarat contract so that the player can get the correct information from the baccarat contract event emission

    function executeOneBatchOfTransactions(RNRBaccaratInterface.Proof[] memory proofs, RNRBaccaratInterface.RequestCommitment[] memory rcs) external onlyServer nonReentrant {
        BaccaratInput[] memory transactionsToExecute = baccaratHandQueue[true];

        require(
            transactionsToExecute.length >= minimumQueueLengthToExecuteTransactions,
            "Error: queue is too small to execute. Please wait until it is large enough."
        );

        require(
            proofs.length == transactionsToExecute.length, 
            "Error: Number of proofs does not match number of transactions to execute."
        );

        require(
            rcs.length == transactionsToExecute.length, 
            "Error: Number of request commitments does not match number of transactions to execute."
        );

        for (uint8 i = 0; i < transactionsToExecute.length; i++){
            BaccaratInput memory input = transactionsToExecute[i];
            RNR_BACCARAT.playAsAggregator{value: input.totalAmountPlayerSentInWei}(input.userIsPlayer, proofs[i], rcs[i], input.user);
        }

        delete baccaratHandQueue[true];
    }


    function deposit() public payable {
        // This function can receive the native token
    }
}

contract Deployer {
   event ContractDeployed(address deployedContractAddress);

   constructor() {
      emit ContractDeployed(
        Create2.deploy(
            0, 
            "RNR Gaming Aggregator v6", // SPDX-License-Identifier: MIT
            type(RNRGamingAggregator).creationCode
        )
      );
   }
}