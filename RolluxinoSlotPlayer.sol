// SPDX-License-Identifier: MIT
import "./RolluxinoSlotGame.sol";
pragma solidity 0.8.18;
contract RolluxinoSlotPlayer {
    constructor(address playerWalletAddress, address owner) {
        require(msg.sender != address(0));
        require(owner != address(0));
        require(playerWalletAddress != address(0));
        playerAddress = playerWalletAddress;
        slotGame = payable(msg.sender); 
        slotGameOwner = owner;
    }
    address payable public slotGame;
    address public immutable slotGameOwner;
    address public immutable playerAddress;
    bool private isWithdrawLocked;
    event UpgradeSlotContract(
        address indexed oldAddress,
        address indexed newAddress
    );
    event PayoutReceived(bytes8 indexed sessionId, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    event Received(address indexed sender, uint256 amount);
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    function withdraw(uint256 amount) external onlyPlayer noReentrancy {
        require(amount > 0, "Amount < 0");
        require(amount <= address(this).balance, "Insufficient balance");
        emit Withdraw(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
    function spin(
        uint8 spinCount,
        uint256 betSize
    ) external payable onlyPlayer {
        uint256 totalBetAmount = spinCount * betSize;
        require(totalBetAmount <= 50 ether, "Max bet");
        require(
            (msg.value + address(this).balance) >= totalBetAmount,
            "Value != spin cost"
        );
        RolluxinoSlotGame(slotGame).spin{value: totalBetAmount}(
            spinCount,
            betSize
        );
    }
    function upgradeSlotContract(
        address newContract
    ) external onlySlotGameOwner {
        require(newContract != address(0));
        emit UpgradeSlotContract(slotGame, newContract);
        slotGame = payable(newContract);
    }
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    function spinPayout(bytes8 spinSessionId) external payable onlySlotGame {
        require(spinSessionId != bytes8(0), "spinSessionId needs value");
        emit PayoutReceived(spinSessionId, msg.value);
    }
    modifier noReentrancy() {
        require(!isWithdrawLocked, "Reentrant call");
        isWithdrawLocked = true;
        _;
        isWithdrawLocked = false;
    }
    modifier onlySlotGame() {
        require(msg.sender == slotGame, "Only slot game can call");
        _;
    }
    modifier onlyPlayer() {
        require(msg.sender == playerAddress, "Only player can call");
        _;
    }
    modifier onlySlotGameOwner() {
        require(msg.sender == slotGameOwner, "Only owner can call");
        _;
    }
}
