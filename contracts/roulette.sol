pragma solidity ^0.4.19;

contract owned {
    function owned() public { bankAddress = msg.sender; }
    address bankAddress;

    modifier onlyOwner {
        require(msg.sender == bankAddress);
        _;
    }
}

contract roulette is owned {

    struct GameRound {
        // bank
        bytes32 storedBankHash;
        uint8 storedBankValue;

        // user
        bytes32 storedUserHash;
        uint8 storedUserValue;

        // game
        bool storedUserBet;
        uint256 blockWhenValueSubmitted;
        uint256 lockedFunds;
    }

    mapping (address => GameRound) public gameRounds;
    mapping (address => uint8) public lastRouletteNumbers;
    mapping (address => uint256) public registeredFunds;

    bool[37] numberIsRed = [false, true, false, true, false, true, false, true, false, true, false, false, true, false, true, false, true, false, true, true, false, true, false, true, false, true, false, true, false, false, true, false, true, false, true, false, true];

    function resetContractFor(address _address) private {
        gameRounds[_address] = GameRound(0x0, 0, 0x0, 0, false, 0, 0);
    }

    function increaseBankFunds() external payable onlyOwner {
        require(msg.value > 0);
        registeredFunds[bankAddress] += msg.value;
    }

    function retrieveMoney() external {
        require (registeredFunds[msg.sender] > 0);

        registeredFunds[msg.sender] = 0;
        msg.sender.transfer(registeredFunds[msg.sender]);
    }

    function getUserAndBankBalance() external view returns (uint256, uint256) {
        return (registeredFunds[msg.sender], registeredFunds[bankAddress]);
    }

    function showBankAddress() external view returns (address) {
        return bankAddress;
    }

    function placeBet(bool _bet, bytes32 _hash) external payable {
        require(gameRounds[msg.sender].storedUserHash == 0);
        require(_hash != 0);
        require(registeredFunds[bankAddress] >= msg.value);

        gameRounds[msg.sender].storedUserHash = _hash;
        gameRounds[msg.sender].storedUserBet = _bet;
        gameRounds[msg.sender].lockedFunds = msg.value * 2;
        registeredFunds[bankAddress] -= msg.value;
    }

    function setBankHash(bytes32 _hash, address _address) external onlyOwner {
        require(gameRounds[_address].storedUserHash != 0);
        require(gameRounds[_address].storedBankHash != 0);

        gameRounds[_address].storedBankHash = _hash;
    }

    function sendBankValue(uint8 _value, address _address) external onlyOwner {
        require(keccak256(_value) == gameRounds[_address].storedBankHash);
        require(gameRounds[_address].storedUserValue != 0);

        gameRounds[_address].storedBankValue = _value;
        gameRounds[_address].blockWhenValueSubmitted = block.number;
    }

    function sendUserValue(uint8 _value) external {
        require(keccak256(_value) == gameRounds[msg.sender].storedUserHash);

        gameRounds[msg.sender].storedUserValue = _value;
    }

    function checkUserValueTimeout(address _address) external onlyOwner {
        require(block.number > (gameRounds[_address].blockWhenValueSubmitted + 1000));
        require(gameRounds[_address].storedUserValue != 0);

        registeredFunds[bankAddress] += gameRounds[_address].lockedFunds;
        resetContractFor(_address);
    }

    function evaluateBet() external {
        GameRound memory round = gameRounds[msg.sender];

        require(round.storedUserValue != 0);
        require(round.storedBankValue != 0);

        uint8 random = round.storedBankValue ^ round.storedUserValue;
        uint8 number = getRouletteNumber(random);
        uint256 winningAmount = round.lockedFunds;
        address winner;

        bool isRed = numberIsRed[number];
        bool userBet = round.storedUserBet;

        if ((isRed && userBet) || (!isRed && !userBet && number != 0)) {
            winner = msg.sender;
        } else {
            winner = bankAddress;
        }

        registeredFunds[winner] += winningAmount;
        lastRouletteNumbers[msg.sender] = number;
        resetContractFor(msg.sender);
    }

    function debugShowHashForValue(uint8 _value) external pure returns (bytes32) {
        return keccak256(_value);
    }

    function getRouletteNumber(uint8 _random) public pure returns (uint8) {
        // TODO public -> private
        // uint256 max = 2**256 - 1;
        uint8 numberDistance = 7; // uint256: max / 37;
        return _random / numberDistance;
    }
}
