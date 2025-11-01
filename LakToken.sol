// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LakToken is ERC20, Ownable {
    // 채굴 관련 변수
    uint256 public difficulty;
    bytes32 public lastHash;
    uint256 public constant REWARD_AMOUNT = 1 * 10**18; // 1 LAK
    uint256 public constant MAX_SUPPLY = 10_000_000 * 10**18; // 10,000,000 LAK
    
    // 난이도 조정 관련
    uint256 public lastAdjustmentBlock;
    uint256 public constant ADJUSTMENT_INTERVAL = 100; // 100블록마다 난이도 조정
    uint256 public minesInCurrentInterval;
    uint256 public targetMinesPerInterval = 50; // 목표: 100블록당 50회 채굴
    uint256 public constant MAX_DIFFICULTY_CHANGE = 20; // 난이도 최대 변화율 20%
    
    // 통계
    uint256 public totalMines;
    mapping(address => uint256) public minerStats;
    
    // 이벤트
    event Mined(address indexed miner, uint256 reward, bytes32 hash, uint256 difficulty);
    event DifficultyAdjusted(uint256 oldDifficulty, uint256 newDifficulty);
    
    constructor() ERC20("Lak Token", "LAK") Ownable(msg.sender) {
        // 초기 난이도 설정 (낮은 난이도로 시작)
        difficulty = type(uint256).max / 1000; // 0.1% 확률
        lastHash = keccak256(abi.encodePacked(block.timestamp, block.prevrandao));
        lastAdjustmentBlock = block.number;
    }
    
    /**
     * @dev 채굴 함수 - 사용자가 nonce를 찾아서 제출
     * @param nonce 찾은 nonce 값
     */
    function mine(uint256 nonce) external {
        require(totalSupply() + REWARD_AMOUNT <= MAX_SUPPLY, "Max supply reached");
        
        // 해시 계산
        bytes32 hash = keccak256(abi.encodePacked(
            lastHash,
            msg.sender,
            nonce,
            block.timestamp
        ));
        
        // 난이도 체크
        require(uint256(hash) < difficulty, "Hash does not meet difficulty requirement");
        
        // 상태 업데이트
        lastHash = hash;
        totalMines++;
        minerStats[msg.sender]++;
        minesInCurrentInterval++;
        
        // 보상 지급
        _mint(msg.sender, REWARD_AMOUNT);
        
        emit Mined(msg.sender, REWARD_AMOUNT, hash, difficulty);
        
        // 난이도 조정 체크
        if (block.number >= lastAdjustmentBlock + ADJUSTMENT_INTERVAL) {
            adjustDifficulty();
        }
    }
    
    /**
     * @dev 난이도 자동 조정
     */
    function adjustDifficulty() internal {
        uint256 oldDifficulty = difficulty;
        
        // Division by zero 방지 및 overflow 방지
        if (minesInCurrentInterval > 0 && minesInCurrentInterval != targetMinesPerInterval) {
            if (minesInCurrentInterval > targetMinesPerInterval) {
                // 채굴이 너무 많음 -> 난이도 증가 (difficulty 감소)
                // Overflow 방지: difficulty가 너무 작아지지 않도록
                uint256 newDifficulty = (difficulty / minesInCurrentInterval) * targetMinesPerInterval;
                if (newDifficulty > 0) {
                    difficulty = newDifficulty;
                }
            } else {
                // 채굴이 너무 적음 -> 난이도 감소 (difficulty 증가)
                // Overflow 방지: difficulty가 type(uint256).max를 넘지 않도록
                uint256 ratio = targetMinesPerInterval / minesInCurrentInterval;
                if (ratio > 0 && difficulty <= type(uint256).max / ratio) {
                    difficulty = difficulty * ratio;
                }
            }
        }
        
        // 극단적인 난이도 방지
        uint256 minDifficulty = type(uint256).max / 10000; // 최소 0.01%
        uint256 maxDifficulty = type(uint256).max / 10; // 최대 10%
        
        if (difficulty < minDifficulty) difficulty = minDifficulty;
        if (difficulty > maxDifficulty) difficulty = maxDifficulty;
        
        emit DifficultyAdjusted(oldDifficulty, difficulty);
        
        // 리셋
        lastAdjustmentBlock = block.number;
        minesInCurrentInterval = 0;
    }
    
    /**
     * @dev 현재 난이도를 퍼센트로 반환 (편의 함수)
     */
    function getDifficultyPercent() external view returns (uint256) {
        return (difficulty * 100) / type(uint256).max;
    }
    
    /**
     * @dev 특정 nonce로 채굴 성공 가능한지 미리 체크 (오프체인 계산용)
     */
    function checkHash(uint256 nonce) external view returns (bytes32 hash, bool valid) {
        hash = keccak256(abi.encodePacked(
            lastHash,
            msg.sender,
            nonce,
            block.timestamp
        ));
        valid = uint256(hash) < difficulty;
    }
    
    /**
     * @dev 남은 채굴 가능 토큰 수
     */
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
    
    /**
     * @dev 긴급 상황용: 난이도 수동 조정 (Owner only)
     */
    function setDifficulty(uint256 newDifficulty) external onlyOwner {
        uint256 oldDifficulty = difficulty;
        difficulty = newDifficulty;
        emit DifficultyAdjusted(oldDifficulty, newDifficulty);
    }
    
    /**
     * @dev 목표 채굴 횟수 조정 (Owner only)
     */
    function setTargetMines(uint256 newTarget) external onlyOwner {
        targetMinesPerInterval = newTarget;
    }
}