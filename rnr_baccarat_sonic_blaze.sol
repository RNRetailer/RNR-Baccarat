pragma solidity ^0.8.7;

import "./RandomNumberRetailerInterface.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT

enum Suit{ HEART, SPADE, CLUB, DIAMOND }

enum HandResult{ PLAYER_WIN, BANKER_WIN, DRAW }

//event HandPlayed(address indexed player, bool userIsPlayer, HandResult result, uint256 sizeOfBetInWei, Card[] playerCards, Card[] bankerCards, uint8 playerHandScore, uint8 bankerHandScore);

event HandLog(string handLog);

struct Card{
    string cardValue;
    Suit suit;
}

contract RNRBaccaratSonic is ReentrancyGuard
{

   mapping(string => uint8) public cardValueMapping;

   Card[]  private deck;
   uint256 public largestBetAllowedInWei;
   uint64 private banPlayerIfTheyAreProfitableAfterThisManyHandsOrMore = 100;
   uint64 private banPlayerIfTheyAreRNGLuckyAfterThisManyHandsOrMore = 50;
   uint8 private percentWinsConsideredRNGLucky = 57;

   address public ownerAddress = 0x5F13FF49EF06a108c66D45C2b1F1211dBdE154CD;

   mapping(address => uint64) public handsPlayedMap;
   mapping(address => uint64) public handsWonMap;
   mapping(address => int256) public playerPNLMap;
   mapping(address => bool) public playerIsAllowedToPlayMap;

   constructor() {
        cardValueMapping["2"] = 2;
        cardValueMapping["3"] = 3;
        cardValueMapping["4"] = 4;
        cardValueMapping["5"] = 5;
        cardValueMapping["6"] = 6;
        cardValueMapping["7"] = 7;
        cardValueMapping["8"] = 8;
        cardValueMapping["9"] = 9;
        cardValueMapping["10"] = 10;
        cardValueMapping["J"] = 0;
        cardValueMapping["Q"] = 0;
        cardValueMapping["K"] = 0;
        cardValueMapping["A"] = 1;

        deck.push(Card("2", Suit.HEART));
        deck.push(Card("3", Suit.HEART));
        deck.push(Card("4", Suit.HEART));
        deck.push(Card("5", Suit.HEART));
        deck.push(Card("6", Suit.HEART));
        deck.push(Card("7", Suit.HEART));
        deck.push(Card("8", Suit.HEART));
        deck.push(Card("9", Suit.HEART));
        deck.push(Card("10", Suit.HEART));
        deck.push(Card("J", Suit.HEART));
        deck.push(Card("K", Suit.HEART));
        deck.push(Card("Q", Suit.HEART));
        deck.push(Card("A", Suit.HEART));

        deck.push(Card("2", Suit.SPADE));
        deck.push(Card("3", Suit.SPADE));
        deck.push(Card("4", Suit.SPADE));
        deck.push(Card("5", Suit.SPADE));
        deck.push(Card("6", Suit.SPADE));
        deck.push(Card("7", Suit.SPADE));
        deck.push(Card("8", Suit.SPADE));
        deck.push(Card("9", Suit.SPADE));
        deck.push(Card("10", Suit.SPADE));
        deck.push(Card("J", Suit.SPADE));
        deck.push(Card("K", Suit.SPADE));
        deck.push(Card("Q", Suit.SPADE));
        deck.push(Card("A", Suit.SPADE));

        deck.push(Card("2", Suit.CLUB));
        deck.push(Card("3", Suit.CLUB));
        deck.push(Card("4", Suit.CLUB));
        deck.push(Card("5", Suit.CLUB));
        deck.push(Card("6", Suit.CLUB));
        deck.push(Card("7", Suit.CLUB));
        deck.push(Card("8", Suit.CLUB));
        deck.push(Card("9", Suit.CLUB));
        deck.push(Card("10", Suit.CLUB));
        deck.push(Card("J", Suit.CLUB));
        deck.push(Card("K", Suit.CLUB));
        deck.push(Card("Q", Suit.CLUB));
        deck.push(Card("A", Suit.CLUB));

        deck.push(Card("2", Suit.DIAMOND));
        deck.push(Card("3", Suit.DIAMOND));
        deck.push(Card("4", Suit.DIAMOND));
        deck.push(Card("5", Suit.DIAMOND));
        deck.push(Card("6", Suit.DIAMOND));
        deck.push(Card("7", Suit.DIAMOND));
        deck.push(Card("8", Suit.DIAMOND));
        deck.push(Card("9", Suit.DIAMOND));
        deck.push(Card("10", Suit.DIAMOND));
        deck.push(Card("J", Suit.DIAMOND));
        deck.push(Card("K", Suit.DIAMOND));
        deck.push(Card("Q", Suit.DIAMOND));
        deck.push(Card("A", Suit.DIAMOND));
   }

    modifier onlyOwner() {
        require(
            msg.sender == ownerAddress, 
            "FAILURE: Only the owner can call this method."
        );

        _;
    }

    function whitelistPlayer(address playerToWhitelist) external onlyOwner{
        playerIsAllowedToPlayMap[playerToWhitelist] = true;
    }

    function setlargestBetAllowedInWei(uint256 newLargestBetAllowedInWei) external onlyOwner{
        largestBetAllowedInWei = newLargestBetAllowedInWei;
    }

    function setBanPlayerIfTheyAreProfitableAfterThisManyHandsOrMore(uint64 newBanPlayerIfTheyAreProfitableAfterThisManyHandsOrMore) external onlyOwner{
        banPlayerIfTheyAreProfitableAfterThisManyHandsOrMore = newBanPlayerIfTheyAreProfitableAfterThisManyHandsOrMore;
    }

    function setPercentWinsConsideredRNGLucky(uint8 newPercentWinsConsideredRNGLucky) external onlyOwner{
        percentWinsConsideredRNGLucky = newPercentWinsConsideredRNGLucky;
    }

    function setBanPlayerIfTheyAreRNGLuckyAfterThisManyHandsOrMore(uint64 newBanPlayerIfTheyAreRNGLuckyAfterThisManyHandsOrMore) external onlyOwner{
        banPlayerIfTheyAreRNGLuckyAfterThisManyHandsOrMore = newBanPlayerIfTheyAreRNGLuckyAfterThisManyHandsOrMore;
    }

    // Points to the official RandomNumberRetailer contract.
    RandomNumberRetailerInterface public constant RANDOM_NUMBER_RETAILER = RandomNumberRetailerInterface(0x91B80393Fd73775f48553e4F54C23EdB114463a0);
    
    // Points to RANDO token
    IERC20 randoToken = IERC20(0x8BDe81Dd5e30b058b71362b50faD06e3fdACE640);

    function sendPlayerSomeRandoTokens() private {
    	 uint256 tokensToSend = (10 ** 18) / 10;
         randoToken.transfer(msg.sender, tokensToSend);
    }

    function play(
        bool userIsPlayer, 
        RandomNumberRetailerInterface.Proof memory proof, 
        RandomNumberRetailerInterface.RequestCommitment memory rc
    ) external payable nonReentrant returns (Card[] memory playerCards, Card[] memory bankerCards, HandResult result){

        require(
            playerIsAllowedToPlayMap[msg.sender],
            "ERROR: Player is not whitelisted. Player cannot use this smart contract."
        );

        uint256 randomNumbersAvailable = RANDOM_NUMBER_RETAILER.randomNumbersAvailable();
        uint256 priceOfARandomNumberInWei = RANDOM_NUMBER_RETAILER.priceOfARandomNumberInWei();

        require(
            randomNumbersAvailable > 0, 
            "ERROR: RNR is out of random numbers. Please try again later."
        );

        uint256 amountToBetWithInWei = msg.value - priceOfARandomNumberInWei;

        require(
            amountToBetWithInWei > 0,
            "ERROR: You did not send enough ETH to pay for the RNR random number. Please send more ETH next time."
        );

        require(
            amountToBetWithInWei <= largestBetAllowedInWei,
            "ERROR: Your bet is too large. Please bet less ETH."
        );

        uint256[] memory randomNumbersReturned = RANDOM_NUMBER_RETAILER.requestRandomNumbersSynchronousUsingVRFv2Seed{value: priceOfARandomNumberInWei}(1, proof, rc, false);

        uint256 randomNumberToUse = randomNumbersReturned[0];

        return playImpl(amountToBetWithInWei, userIsPlayer, randomNumberToUse);
    }
    
    function shuffleDeck(uint256 randomNumber) private {
      uint8 deckSize = 52;

      for (uint8 i = 0; i < deckSize; i++) {
        uint8 n = i + uint8(randomNumber % (deckSize - i));
        
        if(i != n) {
	      Card memory temp = deck[n];
	      deck[n] = deck[i];
	      deck[i] = temp;
        }
      }
    }
    
    function getLastDigitOfUInt(uint8 input) private pure returns (uint8 lastDigit){
        lastDigit = input % 10;
    }
    
    function calculateHandScore(Card[] memory hand) private view returns (uint8 currentHandScore){
        currentHandScore = 0;
    
    	for (uint8 i = 0; i < hand.length; i++){
    	    Card memory currentCard = hand[i];
    	    uint8 cardValue = cardValueMapping[currentCard.cardValue];
    	    currentHandScore += cardValue;
    	}
    	
    	if (currentHandScore > 9){
    	    currentHandScore = getLastDigitOfUInt(currentHandScore);
    	}
    }

    function playImpl(
        uint256 sizeOfBetInWei,
        bool userIsPlayer,
        uint256 randomNumberToUse
    ) private returns (Card[] memory playerCards, Card[] memory bankerCards, HandResult result){
        
        playerCards = new Card[](3);
        bankerCards = new Card[](3);

        shuffleDeck(randomNumberToUse);
        
        bool playerDrewThirdCard = false;
        
        // deal 1 to player, 1 to banker, 1 to player, 1 to banker
        
        playerCards[0] = deck[0];
        bankerCards[0] = deck[1];
        
        playerCards[1] = deck[2];
        bankerCards[1] = deck[3];

        uint8 numberOfPlayerCardsDelt = 2;
        uint8 numberOfBankerCardsDelt = 2;
        
        uint8 lastDrawnIndex = 3;
        
        uint8 playerHandScore = calculateHandScore(playerCards);
        uint8 bankerHandScore = calculateHandScore(bankerCards);
        
        // if anybody gets a natural stand, no further cards are drawn
        if (playerHandScore == 8 || playerHandScore == 9 || bankerHandScore == 8 || bankerHandScore == 9){
            return finishGame(playerCards, bankerCards, userIsPlayer, sizeOfBetInWei, numberOfPlayerCardsDelt, numberOfBankerCardsDelt);
        }
        
        // player draws a third card with a total less than 6, stands on 6-7, natural stands on 8-9
        if (playerHandScore < 6){
            playerCards[2] = deck[++lastDrawnIndex];
            playerDrewThirdCard = true;
            numberOfPlayerCardsDelt++;
        }
        else if (playerHandScore == 8 || playerHandScore == 9){
            return finishGame(playerCards, bankerCards, userIsPlayer, sizeOfBetInWei, numberOfPlayerCardsDelt, numberOfBankerCardsDelt);
        }
 
        // banker draws a third card with a total less than 3, stands on 7, natural stands on 8-9
        
        if (bankerHandScore < 3){
            bankerCards[2] = deck[++lastDrawnIndex];
            numberOfBankerCardsDelt++;
        }
        else{
            // otherwise, the banker uses this logic:
            
            if (!playerDrewThirdCard){
                return finishGame(playerCards, bankerCards, userIsPlayer, sizeOfBetInWei, numberOfPlayerCardsDelt, numberOfBankerCardsDelt);
            }
            
            uint8 playerThirdCardValue = cardValueMapping[playerCards[2].cardValue];
            
            //if banker has 3, he draws if player's third card is in 1-2-3-4-5-6-7-9-0
            
            if (bankerHandScore == 3){
                if (playerThirdCardValue == 1 || playerThirdCardValue == 2 || playerThirdCardValue == 3 || playerThirdCardValue == 4 || playerThirdCardValue == 5 || playerThirdCardValue == 6 || playerThirdCardValue == 7 || playerThirdCardValue == 9 || playerThirdCardValue == 0){
                    bankerCards[2] = deck[++lastDrawnIndex];
                    numberOfBankerCardsDelt++;
                }
            }
            
            //if banker has 4, he draws if player's third card is in 2-3-4-5-6-7
            
            else if (bankerHandScore == 4){
                if (playerThirdCardValue == 2 || playerThirdCardValue == 3 || playerThirdCardValue == 4 || playerThirdCardValue == 5 || playerThirdCardValue == 6 || playerThirdCardValue == 7){
                    bankerCards[2] = deck[++lastDrawnIndex];
                    numberOfBankerCardsDelt++;
                }
            }
            
            //if banker has 5, he draws if player's third card is in 4-5-6-7
            
            else if (bankerHandScore == 5){
                if (playerThirdCardValue == 4 || playerThirdCardValue == 5 || playerThirdCardValue == 6 || playerThirdCardValue == 7){
                    bankerCards[2] = deck[++lastDrawnIndex];
                    numberOfBankerCardsDelt++;
                }
            }
            
            //if banker has 6, he draws if player's third card is in 6-7
            
            else if (bankerHandScore == 6){
                if (playerThirdCardValue == 6 || playerThirdCardValue == 7){
                    bankerCards[2] = deck[++lastDrawnIndex];
                    numberOfBankerCardsDelt++;
                }
            }
        }
        
        return finishGame(playerCards, bankerCards, userIsPlayer, sizeOfBetInWei, numberOfPlayerCardsDelt, numberOfBankerCardsDelt);
    }

    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;

        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }
    
   function toString(uint256 value) private pure returns (string memory) {
        unchecked {
            uint256 length = log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            assembly ("memory-safe") {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                assembly ("memory-safe") {
                    mstore8(ptr, byte(mod(value, 10), "0123456789abcdef"))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    function getStringForCard(Card memory card) private pure returns (string memory cardString){
        string memory suitString;

        if (card.suit == Suit.HEART){
            suitString = "Hearts";
        }
        else if (card.suit == Suit.SPADE){
            suitString = "Spades";
        }
        else if (card.suit == Suit.CLUB){
            suitString = "Clubs";
        }
        else{
            suitString = "Diamonds";
        }
        
        cardString = string.concat(
            card.cardValue,
            " of ",
            suitString
        );
    }

    function outputResultEvent(Card[] memory playerCards, Card[] memory bankerCards, HandResult result, uint8 playerHandScore, uint8 bankerHandScore, bool userIsPlayer, uint256 sizeOfBetInWei, uint8 numberOfPlayerCardsDelt, uint8 numberOfBankerCardsDelt) private{
        string memory handResultString;

        // is user player or banker

        if (userIsPlayer){
            handResultString = "User is Player.\r\n";
        }
        else{
            handResultString = "User is Banker.\r\n";
        }

        // bet size

        handResultString = string.concat(
            handResultString,
            " Bet size is ",
            toString(sizeOfBetInWei),
            ".\r\n"
        );

        // who won the hand

        if (result == HandResult.PLAYER_WIN){
            handResultString = string.concat(
                handResultString,
                " Player wins the hand.\r\n"
            );
        }
        else if (result == HandResult.BANKER_WIN){
            handResultString = string.concat(
                handResultString,
                " Banker wins the hand.\r\n"
            );
        }
        else{
            handResultString = string.concat(
                handResultString,
                " Hand is a draw.\r\n"
            );
        }

        // show the hand scores

        handResultString = string.concat(
            handResultString,
            " Player's hand value is ",
            toString(playerHandScore),
            ".\r\n"
        );

        handResultString = string.concat(
            handResultString,
            " Banker's hand value is ",
            toString(bankerHandScore),
            ".\r\n"
        );

        // show the hands

        handResultString = string.concat(
            handResultString,
            " Player's hand:"
        );

        for (uint8 i = 0; i < numberOfPlayerCardsDelt; i++){
            Card memory currentCard = playerCards[i];

            string memory punctuation;

            if (i == numberOfPlayerCardsDelt - 1){
                punctuation = ".\r\n";
            }
            else{
                punctuation = ",";
            }

            handResultString = string.concat(
                handResultString,
                " ",
                getStringForCard(currentCard),
                punctuation
            );
        }

        handResultString = string.concat(
            handResultString,
            " Banker's hand:"
        );
    
        for (uint8 i = 0; i < numberOfBankerCardsDelt; i++){
            Card memory currentCard = bankerCards[i];

            string memory punctuation;

            if (i == numberOfBankerCardsDelt - 1){
                punctuation = ".";
            }
            else{
                punctuation = ",";
            }

            handResultString = string.concat(
                handResultString,
                " ",
                getStringForCard(currentCard),
                punctuation
            );
        }

        emit HandLog(handResultString);

    }
    
    function finishGame(
        Card[] memory playerCards, 
        Card[] memory bankerCards, 
        bool userIsPlayer,
        uint256 sizeOfBetInWei, 
        uint8 numberOfPlayerCardsDelt, 
        uint8 numberOfBankerCardsDelt
    )   private returns (Card[] memory, Card[] memory, HandResult result){
     
        uint8 playerHandScore = calculateHandScore(playerCards);
        uint8 bankerHandScore = calculateHandScore(bankerCards);
        
        uint256 payOutToMessageSenderInWei = 0;
        
        if (playerHandScore > bankerHandScore){
            result = HandResult.PLAYER_WIN;
            
            if (userIsPlayer){
                payOutToMessageSenderInWei = sizeOfBetInWei * 2;

                handsWonMap[msg.sender] = handsWonMap[msg.sender] + 1;
            }
        }
        else if (bankerHandScore > playerHandScore){
            result = HandResult.BANKER_WIN;
            
            if (!userIsPlayer){
                // 5% tax on wins as banker
                payOutToMessageSenderInWei = ((sizeOfBetInWei * 95) / 100) + sizeOfBetInWei;

                handsWonMap[msg.sender] = handsWonMap[msg.sender] + 1;
            }
        }
        else {
            result = HandResult.DRAW;
            payOutToMessageSenderInWei = sizeOfBetInWei;
        }
        
        if(payOutToMessageSenderInWei != 0){
            require(
                payable(msg.sender).send(payOutToMessageSenderInWei),
                "Error: Failed to withdraw ETH to the message sender."
            );
        }

        playerPNLMap[msg.sender] = playerPNLMap[msg.sender] + int256(payOutToMessageSenderInWei) - int256(msg.value) + int256(RANDOM_NUMBER_RETAILER.priceOfARandomNumberInWei());
        
        outputResultEvent(playerCards, bankerCards, result, playerHandScore, bankerHandScore, userIsPlayer, sizeOfBetInWei, numberOfPlayerCardsDelt, numberOfBankerCardsDelt);
        
        sendPlayerSomeRandoTokens();

        handsPlayedMap[msg.sender] = handsPlayedMap[msg.sender] + 1;

        if ((handsPlayedMap[msg.sender] >= banPlayerIfTheyAreProfitableAfterThisManyHandsOrMore) && (playerPNLMap[msg.sender] > 0)){
            playerIsAllowedToPlayMap[msg.sender] = false;
        }
        else if ((handsPlayedMap[msg.sender] >= banPlayerIfTheyAreRNGLuckyAfterThisManyHandsOrMore) && ((((100 * handsWonMap[msg.sender]) / handsPlayedMap[msg.sender])) >= percentWinsConsideredRNGLucky)){
            playerIsAllowedToPlayMap[msg.sender] = false;
        }

        return (playerCards, bankerCards, result);
    }

    function deposit() public payable {
        // This function can receive the native token
    }

    function withdrawETHToOwner(
        uint256 weiToWithdraw
    ) external onlyOwner {

        require(
            address(this).balance > weiToWithdraw,
            "FAILURE: There is not enough ETH in this contract to complete the withdrawal."
        );

        require(
            payable(ownerAddress).send(weiToWithdraw),
            "FAILURE: Failed to withdraw ETH to the owner."
        );
    }
}

contract Deployer {
   event ContractDeployed(address deployedContractAddress);

   constructor() {
      emit ContractDeployed(
        Create2.deploy(
            0, 
            "RNR Baccarat v0.94 Alpha", 
            type(RNRBaccaratSonic).creationCode
        )
      );
   }
}