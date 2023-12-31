// SPDX-License-Identifier: MIT
import "./RolluxinoSlotGameLogic.sol";
import "./RolluxinoStringHelpers.sol";
import "./RolluxinoSlotPlayer.sol";
pragma solidity 0.8.18;
interface ISupraRouter {
    function generateRequest(
        string memory _functionSig,
        uint8 _rngCount,
        uint256 _numConfirmations,
        uint256 _clientSeed,
        address _clientWalletAddress
    ) external returns (uint256);
}
contract RolluxinoSlotGame {
    constructor(address supraRouterAddress) {
        require(supraRouterAddress != address(0));
        supraRouter = supraRouterAddress;
        owner = msg.sender;
        slotGameLogicContract = new RolluxinoSlotGameLogic();
        stringHelpersContract = new RolluxinoStringHelpers();
    }
    RolluxinoSlotGameLogic public immutable slotGameLogicContract;
    RolluxinoStringHelpers public immutable stringHelpersContract;
    bool private isWithdrawLocked;
    uint private maxBetSize = 5 ether;
    address internal immutable supraRouter;
    address public immutable owner;
    struct CallbackInfo {
        address payable originalSender;
        uint16 spinCount;
        uint256 betSize;
    }
    mapping(uint256 => CallbackInfo) public callbackInfo;
    mapping(address => address) public slotPlayers;
    mapping(address => bool) public slotPlayerContracts;
    event SpinCompleted(
        address indexed player,
        bytes8 indexed sessionId,
        bytes8 indexed spinId,
        uint256 bet,
        uint256 payout,
        string seed,
        bool bonus,
        uint8 bonusSpins
    );
    event Withdraw(address indexed to, uint256 amount);
    event GasleftDelegate(uint256 gasleft);
    event GasSeedParserDelegate(uint256 gasleft);
    event GasSupraBeforeDelegate(uint256 gasleft);
    event GasSupraAfterDelegate(uint256 gasleft);
    event Received(address indexed sender, uint256 amount);
    function spin(
        uint16 spinCount,
        uint256 betSize
    ) external payable noReentrancy onlySlotPlayerContract {
        require(spinCount > 0, "spin count < 0");
        require(spinCount < 6, "spin count > 5");
        require(betSize > 0, "betsize < 0");
        require(betSize <= maxBetSize, "exceeded betsize");
        require(
            msg.value == spinCount * betSize,
            "value != spincount * betsize"
        );
        uint8 vrfCount = uint8((spinCount + (6 * spinCount) + 2) / 3);
        uint256 nonce = ISupraRouter(supraRouter).generateRequest(
            "getSeedCallback(uint256,uint256[])",
            vrfCount,
            1,
            0,
            owner
        );
        require(nonce > 0, "Unexpected Supra nonce");
        callbackInfo[nonce] = CallbackInfo({
            originalSender: payable(msg.sender),
            spinCount: spinCount,
            betSize: betSize
        });
    }
    function getSeedCallback(
        uint256 nonce,
        uint256[] calldata rngList
    ) external {
        uint256 betSize = callbackInfo[nonce].betSize;
        address payable originalSender = callbackInfo[nonce].originalSender;
        uint16 spinCount = callbackInfo[nonce].spinCount;
        require(msg.sender == supraRouter, "router mismatch");
        require(originalSender != address(0), "nonce missing originalSender");
        require(spinCount > 0, "spinCount < 0");
        require(betSize > 0, "betsize < 0");
        require(
            rngList.length == ((spinCount + (6 * spinCount) + 2) / 3),
            "should match rngCount"
        );
        emit GasSupraBeforeDelegate(gasleft());
        string memory seed = stringHelpersContract.arrayToString(rngList);
        bytes8 sessionId = bytes8(
            keccak256(abi.encodePacked(block.timestamp, msg.sender))
        );
        emit GasSeedParserDelegate(gasleft());
        uint16 position;
        uint256 totalPayoutAggregation;
        for (uint16 i; i < spinCount; ) {
            uint8 prevBonusSpinsCount;
            uint256 totalPayout;
            (position, prevBonusSpinsCount, totalPayout) = spinSeed(
                sessionId,
                seed,
                position,
                prevBonusSpinsCount,
                betSize,
                originalSender
            );
            totalPayoutAggregation += totalPayout;
            if (prevBonusSpinsCount > 0) {
                do {
                    (position, prevBonusSpinsCount, totalPayout) = spinSeed(
                        sessionId,
                        seed,
                        position,
                        prevBonusSpinsCount,
                        betSize,
                        originalSender
                    );
                    totalPayoutAggregation += totalPayout;
                } while (prevBonusSpinsCount > 0);
            }
            emit GasleftDelegate(gasleft());
            unchecked {
                ++i;
            } 
        }
        RolluxinoSlotPlayer(originalSender).spinPayout{
            value: totalPayoutAggregation
        }(sessionId);
        delete callbackInfo[nonce];
        emit GasSupraAfterDelegate(gasleft());
    }
    function spinSeed(
        bytes8 sessionId,
        string memory seed,
        uint16 position,
        uint8 prevBonusSpinsCount,
        uint256 betSize,
        address initiator
    ) public returns (uint16, uint8, uint256) {
        (
            uint256 totalPayout,
            uint16 newSeedPosition,
            uint8 updatedBonusGamesCount
        ) = slotGameLogicContract.getSeedPayout(
                seed,
                position,
                prevBonusSpinsCount,
                betSize
            );
        string memory spinSeedTruncated = stringHelpersContract.truncateString(
            seed,
            position,
            newSeedPosition
        );
        bool isBonusGame = prevBonusSpinsCount > 0;
        bytes8 spinId = bytes8(
            keccak256(
                abi.encodePacked(block.timestamp, msg.sender, spinSeedTruncated)
            )
        );
        emit SpinCompleted(
            initiator,
            sessionId,
            spinId,
            betSize,
            totalPayout,
            spinSeedTruncated,
            isBonusGame,
            isBonusGame ? 0 : updatedBonusGamesCount
        );
        return (newSeedPosition, updatedBonusGamesCount, totalPayout);
    }
    function enrollSlotsPlayer() external returns (address) {
        require(slotPlayers[msg.sender] == address(0), "Already enrolled");
        RolluxinoSlotPlayer slotPlayer = new RolluxinoSlotPlayer(
            msg.sender,
            owner
        );
        slotPlayers[msg.sender] = address(slotPlayer);
        slotPlayerContracts[address(slotPlayer)] = true;
        return address(slotPlayer);
    }
    function setMaxBetSize(uint256 newMaxBetSize) external onlyOwner {
        require(newMaxBetSize > 0, "newMaxBetSize < 0");
        maxBetSize = newMaxBetSize;
    }
    function getMaxBetSize() public view returns (uint256) {
        return maxBetSize;
    }
    function getSlotsPlayer(
        address playerWallet
    ) external view returns (address) {
        return slotPlayers[playerWallet];
    }
    receive() external payable {
        require(msg.value > 0, "Amount < 0");
        emit Received(msg.sender, msg.value);
    }
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    function withdraw(uint256 amount) external onlyOwner noReentrancy {
        require(amount > 0, "Amount < 0");
        require(amount <= address(this).balance, "Insufficient balance");
        emit Withdraw(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
    modifier noReentrancy() {
        require(!isWithdrawLocked, "Reentrant call");
        isWithdrawLocked = true;
        _;
        isWithdrawLocked = false;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }
    modifier onlySlotPlayerContract() {
        require(slotPlayerContracts[msg.sender], "Only slot player can call");
        _;
    }
}
