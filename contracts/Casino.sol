// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract Casino is ReentrancyGuard, Ownable, VRFConsumerBaseV2 {
    enum GameType { CoinFlip, DiceNumber, DiceHighLow, DiceEvenOdd, SlotSpin }

    struct Game {
        GameType gameType;
        uint256 minBet;
        uint256 maxBet;
        bool isActive;
    }

    struct Choice {
        uint256 number;
        uint256[] numbers;
    }

    struct ActiveGame {
        GameType gameType;
        uint256 betAmount;
        Choice choice;
    }

    uint256 public HOUSE_EDGE = 5; 
    VRFCoordinatorV2Interface public immutable vrfCoordinator;
    uint64 private immutable subscriptionId;
    bytes32 private immutable keyHash;
    uint16 private immutable requestConfirmations;
    uint32 private immutable callbackGasLimit;
    uint32  private immutable numWords;

    mapping(uint256 => Game) public games;
    mapping(address => uint256) public balances;
    mapping(uint256 => address) public vrfRequests;
    mapping(address => ActiveGame) public activeGames;

    event BetPlaced(address player, GameType gameType, uint256 betAmount);
    event Payout(address winner, uint256 payoutAmount);
    event RandomNumberRequested(uint256 requestId);

    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint16 _requestConfirmations,
        uint32 _callbackGasLimit,
        uint32 _numWords
    ) VRFConsumerBaseV2(_vrfCoordinator)
      Ownable(msg.sender)
     {  // <- Добавьте вызов родительского конструктора
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        requestConfirmations = _requestConfirmations;
        callbackGasLimit = _callbackGasLimit;
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
        (bool success, ) = msg.sender.call{value: _calcHouseEdge(amount)}("");
        require(success, "Withdrawal failed");
    }


    function _validateBet(Game storage game, uint256 betAmount) private view {
        require(game.isActive, "Game is not active");
        require(betAmount >= game.minBet && betAmount <= game.maxBet, "Invalid bet amount");
        require(balances[msg.sender] >= betAmount, "Insufficient balance");
        require(activeGames[msg.sender].betAmount == 0, "Player already has an active game");
    }

    function _requestRandomness() private returns (uint256) {
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        emit RandomNumberRequested(requestId);
        return requestId;
    }

    function _calcHouseEdge(uint256 amount) private view returns (uint256) {
        return amount - (amount * HOUSE_EDGE) / 100;
    }

    function _getMultiplier(ActiveGame storage activeGame) private view returns (uint256) {
        if (activeGame.gameType == GameType.CoinFlip) return 2;
        if (activeGame.gameType == GameType.DiceNumber) return 6;
        if (activeGame.gameType == GameType.DiceHighLow) {
            uint256 totalOutcomes = 6;
            uint256 multiplier;
    
            if (activeGame.choice.numbers[0] == 1) {
                uint256 winningOutcomes = 6 - activeGame.choice.numbers[1];
                require(winningOutcomes > 0, "No winning outcomes for High bet");
                multiplier = totalOutcomes * 1e18 / winningOutcomes; // 6/3 = 2x
            } else {
                uint256 winningOutcomes = activeGame.choice.numbers[1];
                require(winningOutcomes > 0, "No winning outcomes for Low bet");
                multiplier = totalOutcomes * 1e18 / winningOutcomes; // 6/3 = 2x
            }
            return multiplier;
        }
        if (activeGame.gameType == GameType.DiceEvenOdd) return 2;
        if (activeGame.gameType == GameType.SlotSpin) return 34;
    }

    function playCoinFlip(uint256 betAmount, bool _guess) external nonReentrant{
        // guess = true for heads, false for tails
        Game storage game = games[1];
        _validateBet(game, betAmount);

        balances[msg.sender] -= betAmount;
        uint256 requestId = _requestRandomness();
        vrfRequests[requestId] = msg.sender;

        Choice memory choice = Choice({number: _guess ? 1 : 0, numbers: new uint256[](0)});

        activeGames[msg.sender] = ActiveGame(GameType.CoinFlip, betAmount, choice);

        emit BetPlaced(msg.sender, game.gameType, betAmount);
    }

    function playDiceNumber(uint256 betAmount, uint256 _choice) external nonReentrant {
        Game storage game = games[2];
        _validateBet(game, betAmount);

        require(_choice >= 1 && _choice <= 6, "Invalid choice");

        balances[msg.sender] -= betAmount;
        uint256 requestId = _requestRandomness();
        vrfRequests[requestId] = msg.sender;

        Choice memory choice = Choice({number: _choice, numbers: new uint256[](0)});

        activeGames[msg.sender] = ActiveGame(GameType.DiceNumber, betAmount, choice);

        emit BetPlaced(msg.sender, game.gameType, betAmount);
    }

    function playDiceHighLow(uint256 betAmount, bool _high, uint256 _target) external nonReentrant {
        Game storage game = games[3];
        _validateBet(game, betAmount);

        require(_target >= 2 && _target <= 5, "Invalid choice");

        balances[msg.sender] -= betAmount;
        uint256 requestId = _requestRandomness();
        vrfRequests[requestId] = msg.sender;

        uint256[] memory numbers = new uint256[](2);
        numbers[0] = _high ? 1 : 0;
        numbers[1] = _target;
        Choice memory choice = Choice({number: 0, numbers: numbers});

        activeGames[msg.sender] = ActiveGame(GameType.DiceHighLow, betAmount, choice);

        emit BetPlaced(msg.sender, game.gameType, betAmount);
    }

    function playDiceEvenOdd(uint256 betAmount, bool _guess) external nonReentrant {
        // guess = is even
        Game storage game = games[4];
        _validateBet(game, betAmount);
        balances[msg.sender] -= betAmount;
        uint256 requestId = _requestRandomness();
        vrfRequests[requestId] = msg.sender;

        Choice memory choice = Choice({number: _guess ? 1 : 0, numbers: new uint256[](0)});

        activeGames[msg.sender] = ActiveGame(GameType.DiceEvenOdd, betAmount, choice);

        emit BetPlaced(msg.sender, game.gameType, betAmount);
    }

    function playSlotSpin(uint256 betAmount) external nonReentrant {
        Game storage game = games[5];
        _validateBet(game, betAmount);
        balances[msg.sender] -= betAmount;
        uint256 requestId = _requestRandomness();
        vrfRequests[requestId] = msg.sender;

        Choice memory choice = Choice({number: 0, numbers: new uint256[](0)});

        activeGames[msg.sender] = ActiveGame(GameType.SlotSpin, betAmount, choice);

        emit BetPlaced(msg.sender, game.gameType, betAmount);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address playerAddress = vrfRequests[requestId];
        ActiveGame storage game = activeGames[playerAddress];
        
        uint256 randomness = randomWords[0];
        uint256 result;
        bool win;

        if (game.gameType == GameType.CoinFlip) {
            result = randomness % 2;
            win = (result == game.choice.number);
        } else if (game.gameType == GameType.DiceNumber) {
            result = randomness % 6 + 1;
            win = (result == game.choice.number);
        } else if (game.gameType == GameType.DiceHighLow) {
            result = randomness % 6 + 1;
            if (game.choice.numbers[0] == 1) {
                win = (result > game.choice.numbers[1]);
            } else {
                win = (result <= game.choice.numbers[1]);
            }
        } else if (game.gameType == GameType.DiceEvenOdd) {
            result = randomness % 2;
            win = (result == game.choice.number);
        } else if (game.gameType == GameType.SlotSpin) {
            uint256 num1 = uint256(keccak256(abi.encode(randomness, 1))) % 6;
            uint256 num2 = uint256(keccak256(abi.encode(randomness, 2))) % 6;
            uint256 num3 = uint256(keccak256(abi.encode(randomness, 3))) % 6;

            win = num1 == num2 && num2 == num3;
        }

        if (win) {
            balances[playerAddress] += game.betAmount * _getMultiplier(game);
        }
        
        delete activeGames[playerAddress];

        delete vrfRequests[requestId];
    }
}