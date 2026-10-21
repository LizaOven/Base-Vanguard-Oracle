// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

contract VanguardOracleVault {
    struct PriceFeed {
        uint256 price;
        uint256 lastUpdated;
        uint256 confidenceLevel; // 1-100%
        bool isActive;
    }

    struct UserDeposit {
        uint256 amount;
        uint256 depositedAt;
        bytes32 collateralAsset;
    }

    address payable public immutable masterOracle;
    string public networkTag;
    uint256 public managementFeeRate; // В базисных пунктах (например, 50 = 0.5%)
    uint256 public totalVaultCollateral;
    bool public isOracleCircuitBreakerActive;

    mapping(bytes32 => PriceFeed) public priceFeeds;
    mapping(address => UserDeposit) public userDeposits;

    event FeedSubmitted(bytes32 indexed symbolKey, uint256 price, uint256 confidence);
    event FeedStatusToggled(bytes32 indexed symbolKey, bool isActive);
    event CollateralDeposited(address indexed user, bytes32 indexed asset, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount, uint256 feePaid);
    event ManagementFeeUpdated(uint256 newRate);
    event CircuitBreakerToggled(bool state);
    event NetworkTagModified(string newTag);
    event EmergencyFundsHarvested(address indexed receiver, uint256 amount);

    modifier onlyMaster() {
        require(msg.sender == masterOracle, "VanguardVault: Unauthorized access");
        _;
    }

    modifier whenOperational() {
        require(!isOracleCircuitBreakerActive, "VanguardVault: Circuit breaker triggered");
        _;
    }

    constructor() {
        masterOracle = payable(msg.sender);
        networkTag = "Vanguard Base L2 Mainnet Core";
        managementFeeRate = 50; // 0.5%
        isOracleCircuitBreakerActive = false;
    }

    // 1. Публикация / обновление котировки оракула
    function updatePriceFeed(bytes32 symbolKey, uint256 newPrice, uint256 confidence) external onlyMaster {
        require(newPrice > 0, "VanguardVault: Invalid price");
        require(confidence <= 100, "VanguardVault: Confidence ceiling is 100");

        priceFeeds[symbolKey] = PriceFeed({
            price: newPrice,
            lastUpdated: block.timestamp,
            confidenceLevel: confidence,
            isActive: true
        });

        emit FeedSubmitted(symbolKey, newPrice, confidence);
    }

    // 2. Включение / отключение конкретного ценового потока
    function toggleFeedStatus(bytes32 symbolKey) external onlyMaster {
        require(priceFeeds[symbolKey].price > 0, "VanguardVault: Feed does not exist");
        priceFeeds[symbolKey].isActive = !priceFeeds[symbolKey].isActive;
        emit FeedStatusToggled(symbolKey, priceFeeds[symbolKey].isActive);
    }

    // 3. Депозит залогового обеспечения в хранилище
    function depositCollateral(bytes32 assetKey) external payable whenOperational {
        require(msg.value > 0, "VanguardVault: Zero collateral rejected");
        require(priceFeeds[assetKey].isActive, "VanguardVault: Feed not active for asset");

        UserDeposit storage dep = userDeposits[msg.sender];
        dep.amount += msg.value;
        dep.depositedAt = block.timestamp;
        dep.collateralAsset = assetKey;

        totalVaultCollateral += msg.value;
        emit CollateralDeposited(msg.sender, assetKey, msg.value);
    }

    // 4. Частичный или полный вывод залога с удержанием протокольной комиссии
    function withdrawCollateral(uint256 amount) external {
        UserDeposit storage dep = userDeposits[msg.sender];
        require(dep.amount >= amount, "VanguardVault: Exceeds deposit");

        uint256 fee = (amount * managementFeeRate) / 10000;
        uint256 payout = amount - fee;

        dep.amount -= amount;
        totalVaultCollateral -= amount;

        (bool sent, ) = payable(msg.sender).call{value: payout}("");
        require(sent, "VanguardVault: Collateral return failed");

        emit CollateralWithdrawn(msg.sender, payout, fee);
    }

    // 5. Изменение ставки комиссии
    function setManagementFee(uint256 newFeeRate) external onlyMaster {
        require(newFeeRate <= 500, "VanguardVault: Fee capped at 5%");
        managementFeeRate = newFeeRate;
        emit ManagementFeeUpdated(newFeeRate);
    }

    // 6. Включение / выключение аварийного стоп-крана
    function setCircuitBreaker(bool state) external onlyMaster {
        isOracleCircuitBreakerActive = state;
        emit CircuitBreakerToggled(state);
    }

    // 7. Обновление метаданных сети
    function setNetworkTag(string calldata newTag) external onlyMaster {
        networkTag = newTag;
        emit NetworkTagModified(newTag);
    }

    // 8. Вывод накопленных протокольных комиссий
    function harvestCollectedFees() external onlyMaster {
        uint256 feesBalance = address(this).balance - totalVaultCollateral;
        require(feesBalance > 0, "VanguardVault: No fee revenue available");

        (bool sent, ) = masterOracle.call{value: feesBalance}("");
        require(sent, "VanguardVault: Fee transfer failed");

        emit EmergencyFundsHarvested(masterOracle, feesBalance);
    }

    // Чтение статуса котировки
    function getFeed(bytes32 symbolKey) external view returns (uint256 price, uint256 lastUpdated, uint256 confidence, bool active) {
        PriceFeed memory f = priceFeeds[symbolKey];
        return (f.price, f.lastUpdated, f.confidenceLevel, f.isActive);
    }
}