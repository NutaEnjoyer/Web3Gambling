// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract Casino {
    enum GameType { CoinFlip, DiceNumber, DiceHighLow, DiceEvenOdd, SlotSpin }

    struct Game {
        GameType gameType;
        uint256 minBet;
        uint256 maxBet;
        bool isActive;
    }

    struct ActiveGame {
        GameType gameType;
        uint256 betAmount;
        uint256 choice;
    }

    uint256 public HOUSE_EDGE = 5; 
    VRFCoordinatorV2Interface public immutable vrfCoordinator;
    uint64 private immutable subscriptionId;
    bytes32 private immutable keyHash;
    uint256 private immutable requestConfirmations;
    uint256 private immutable callbackGas;
    uint256 private immutable numWords;

    mapping(uint256 => Game) public games;
    mapping(address => uint256) public balances;
    mapping(uint256 => address) public vrfRequests;
    mapping(address => ActiveGame) public activeGames;

    event BetPlaced(address player, uint256 gameId, uint256 betAmount);
    event Payout(address winner, uint256 payoutAmount);
    event RandomNumberRequested(uint256 requestId);

    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint16 _requestConfirmations,
        uint32 _callbackGas,
        uint32 _numWords
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        requestConfirmations = _requestConfirmations;
        callbackGas = _callbackGas;
        numWords = _numWords;

        _initializeGames();
    }

    function _initializeGames() private {
        games[1] = Game(GameType.CoinFlip, 0.01 ether, 10 ether, true);
        games[2] = Game(GameType.DiceNumber, 0.1 ether, 10 ether, true);
        games[3] = Game(GameType.DiceHighLow, 0.1 ether, 10 ether, true);
        games[4] = Game(GameType.DiceEvenOdd, 0.1 ether, 10 ether, true);
        games[5] = Game(GameType.SlotSpin, 0.1 ether, 50 ether, true);
    }


    function deposit() external payable nonReentrant {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
    }


    function _validateBet(Game storage game, uint256 betAmount) private view {
        require(game.isActive, "Game is not active");
        require(betAmount >= game.minBet && betAmount <= game.maxBet, "Invalid bet amount");
        require(balances[msg.sender] >= betAmount, "Insufficient balance");
        require(!activeGames[msg.sender], "Player already has an active game");
    }

    function _requestRandomness() private returns (uint256) {
        requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        emit RandomNumberRequested(requestId);
        return requestId;
    }

    function _calcHouseEdge(uint256 amount) private pure returns (uint256) {
        return betAmount - (betAmount * HOUSE_EDGE) / 100;
    }

    function _getMultiplier(GameType gameType) private pure returns (uint256) {
        if (gameType == GameType.CoinFlip) return 2;
        if (gameType == GameType.DiceNumber) return 6;
        if (gameType == GameType.DiceHighLow) return 2;
        if (gameType == GameType.DiceEvenOdd) return 2;
        if (gameType == GameType.SlotSpin) return 10;
    }

    function playCoinFlip(uint256 betAmount, bool guess) external nonReentrant{
        // guess = true for heads, false for tails
        Game storage game = games[1];
        _validateBet(game, betAmount);

        balances[msg.sender] -= betAmount;
        uint256 requestId = _requestRandomness();
        vrfRequests[requestId] = msg.sender;

        activeGames[msg.sender] = ActiveGame(GameType.CoinFlip, betAmount, guess ? 1 : 0);

        emit BetPlaced(msg.sender, 1, betAmount);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address playerAddress = vrfRequests[requestId];
        GamePlay storage game = activeGames[playerAddress];
        
        uint256 randomness = randomWords[0];
        uint256 result;
        bool win;
        uint256 winAmount;

        if (game.gameType == GameType.CoinFlip) {
            result = randomness % 2;
            win = (result == game.userChoice);
        } else if (game.gameType == GameType.DiceNumber) {
            
        }

        if (win) {
            balances[playerAddress] += game.betAmount * _getMultiplier(game.gameType);
        }
        
        delete activeGames[playerAddress];

        // Здесь логика определения выигрыша
        // и выплаты на основе randomness

        delete vrfRequests[requestId];
    }
}