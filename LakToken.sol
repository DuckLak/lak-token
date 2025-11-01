// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LakToken
 * @dev Final debugging version with specific error messages to identify the exact point of failure.
 * Version: 1.6.0 (Debug)
 */
contract LakToken is ERC20, Ownable, ReentrancyGuard {
    // --- State Variables ---

    // Mining Core
    uint256 public baseDifficulty;
    bytes32 public lastHash;
    uint256 public lastMineTimestamp;

    // Constants
    uint256 public constant REWARD_AMOUNT = 1 * 10**18;
    uint256 public constant MAX_SUPPLY = 10_000_000 * 10**18;

    // Time-based Difficulty Adjustment (Bonus for waiting)
    uint256 public constant TIME_THRESHOLD = 30;
    uint256 public constant DIFFICULTY_DECREASE_RATE = 10;
    uint256 public constant MAX_TIME_BONUS_PERIODS = 10;

    // Interval-based Difficulty Adjustment (Network health)
    uint256 public lastAdjustmentBlock;
    uint256 public constant ADJUSTMENT_INTERVAL = 100;
    uint256 public minesInCurrentInterval;
    uint256 public targetMinesPerInterval = 50;
    uint256 public constant MAX_DIFFICULTY_RATIO = 3;

    // Statistics
    uint256 public totalMines;
    mapping(address => uint256) public minerStats;

    // --- Events ---

    event Mined(address indexed miner, uint256 reward, bytes32 hash, uint256 effectiveDifficulty, uint256 timeSinceLastMine);
    event DifficultyAdjusted(uint256 oldDifficulty, uint256 newDifficulty);
    event OwnerActionExecuted(string action, uint256 value);

    // --- Functions ---

    constructor() ERC20("Lak Token", "LAK") Ownable(msg.sender) {
        baseDifficulty = type(uint256).max / 1000; // ~0.1% success chance
        lastHash = keccak256(abi.encode(block.timestamp, block.prevrandao, address(this)));
        lastMineTimestamp = block.timestamp;
        lastAdjustmentBlock = block.number;
    }

    /**
     * @notice Calculates the effective mining difficulty for a specific timestamp.
     * @param _timestamp The timestamp to calculate the difficulty for. This makes the calculation deterministic.
     * @return effectiveDifficulty The calculated difficulty target.
     */
    function getEffectiveDifficulty(uint256 _timestamp) public view returns (uint256 effectiveDifficulty) {
        if (_timestamp < lastMineTimestamp) { // Use < instead of <= to handle edge case of same timestamp
            return baseDifficulty;
        }
        
        uint256 timeSinceLastMine = _timestamp - lastMineTimestamp;
        if (timeSinceLastMine < TIME_THRESHOLD) {
            return baseDifficulty;
        }
        
        uint256 periods = timeSinceLastMine / TIME_THRESHOLD;
        if (periods > MAX_TIME_BONUS_PERIODS) {
            periods = MAX_TIME_BONUS_PERIODS;
        }
        
        uint256 multiplier = 100 + (DIFFICULTY_DECREASE_RATE * periods);
        
        if (baseDifficulty > type(uint256).max / multiplier) {
            return type(uint256).max / 10; // Cap at 10%
        }
        
        effectiveDifficulty = (baseDifficulty * multiplier) / 100;
        
        uint256 maxDifficultyTarget = type(uint256).max / 10;
        if (effectiveDifficulty > maxDifficultyTarget) {
            effectiveDifficulty = maxDifficultyTarget;
        }
        
        return effectiveDifficulty;
    }

    /**
     * @notice The main mining function with detailed revert reasons for debugging.
     */
    function mine(uint256 nonce, uint256 timestamp) external nonReentrant {
        // --- Debugging require statements with unique error codes ---
        require(totalSupply() + REWARD_AMOUNT <= MAX_SUPPLY, "E1: Max supply reached");
        require(timestamp <= block.timestamp, "E2: Future timestamp submitted");
        require(block.timestamp - timestamp < 120, "E3: Timestamp is too old");

        uint256 effectiveDifficulty = getEffectiveDifficulty(timestamp);
        bytes32 hash = keccak256(abi.encodePacked(lastHash, msg.sender, nonce, timestamp));
        
        require(uint256(hash) < effectiveDifficulty, "E4: Hash does not meet difficulty requirement");
        
        // --- State updates (only if all checks pass) ---
        uint256 timeSinceLastMine = block.timestamp - lastMineTimestamp;
        lastHash = hash;
        lastMineTimestamp = block.timestamp;
        totalMines++;
        minerStats[msg.sender]++;
        minesInCurrentInterval++;
        
        _mint(msg.sender, REWARD_AMOUNT);
        
        emit Mined(msg.sender, REWARD_AMOUNT, hash, effectiveDifficulty, timeSinceLastMine);
        
        if (block.number >= lastAdjustmentBlock + ADJUSTMENT_INTERVAL) {
            adjustDifficulty();
        }
    }

    /**
     * @dev Adjusts the base difficulty every ADJUSTMENT_INTERVAL blocks to maintain a target mining rate.
     */
    function adjustDifficulty() internal {
        uint256 oldDifficulty = baseDifficulty;
        if (minesInCurrentInterval > 0 && minesInCurrentInterval != targetMinesPerInterval) {
            uint256 ratio;
            if (minesInCurrentInterval > targetMinesPerInterval) {
                ratio = minesInCurrentInterval / targetMinesPerInterval;
                if (ratio > MAX_DIFFICULTY_RATIO) ratio = MAX_DIFFICULTY_RATIO;
                baseDifficulty = baseDifficulty / ratio;
            } else {
                ratio = targetMinesPerInterval / minesInCurrentInterval;
                if (ratio > MAX_DIFFICULTY_RATIO) ratio = MAX_DIFFICULTY_RATIO;
                require(baseDifficulty <= type(uint256).max / ratio, "Overflow risk");
                baseDifficulty = baseDifficulty * ratio;
            }
        }
        uint256 minDifficulty = type(uint256).max / 10000;
        uint256 maxDifficulty = type(uint256).max / 100;
        if (baseDifficulty < minDifficulty) baseDifficulty = minDifficulty;
        if (baseDifficulty > maxDifficulty) baseDifficulty = maxDifficulty;
        emit DifficultyAdjusted(oldDifficulty, baseDifficulty);
        lastAdjustmentBlock = block.number;
        minesInCurrentInterval = 0;
    }

    /**
     * @notice A view function to check if a nonce would be valid for a given timestamp.
     */
    function checkHash(uint256 nonce, uint256 timestamp) external view returns (bytes32 hash, bool valid) {
        uint256 effectiveDifficulty = getEffectiveDifficulty(timestamp);
        hash = keccak256(abi.encodePacked(lastHash, msg.sender, nonce, timestamp));
        valid = uint256(hash) < effectiveDifficulty;
    }

    // --- View Functions for UI ---

    function getDifficultyPercent() external view returns (uint256) {
        uint256 currentDifficulty = getEffectiveDifficulty(block.timestamp);
        return currentDifficulty / (type(uint256).max / 10000);
    }
    
    function getBaseDifficultyPercent() external view returns (uint256) {
        return baseDifficulty / (type(uint256).max / 10000);
    }

    function getTimeSinceLastMine() external view returns (uint256) {
        return block.timestamp - lastMineTimestamp;
    }
    
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
    
    // --- Owner Functions ---

    function setBaseDifficulty(uint256 newDifficulty) external onlyOwner {
        require(newDifficulty >= type(uint256).max / 10000, "Difficulty too low");
        require(newDifficulty <= type(uint256).max / 100, "Difficulty too high");
        emit OwnerActionExecuted("setBaseDifficulty", newDifficulty);
    }
    
    function setTargetMines(uint256 newTarget) external onlyOwner {
        require(newTarget > 0 && newTarget <= 200, "Invalid target");
        targetMinesPerInterval = newTarget;
        emit OwnerActionExecuted("setTargetMines", newTarget);
    }
    
    function resetLastMineTimestamp() external onlyOwner {
        lastMineTimestamp = block.timestamp;
        emit OwnerActionExecuted("resetLastMineTimestamp", block.timestamp);
    }

    function version() external pure returns (string memory) {
        return "1.6.0-Debug";
    }
}
