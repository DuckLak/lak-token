const { ethers } = require('ethers');
const os = require('os');

// ========================================
// Configuration
// ========================================
const CONFIG = {
    PRIVATE_KEY: 'YOUR_PRIVATE_KEY_HERE',
    RPC_URL: 'wss://monad-testnet.drpc.org',
    CONTRACT_ADDRESS: '0x569d430a45F5F71F9f04A882c45eA71274BBa24c',
    
    // Gas Settings
    GAS_LIMIT: 150000,
    MAX_PRIORITY_FEE: ethers.parseUnits('0.01', 'gwei'),
    MAX_FEE: ethers.parseUnits('103', 'gwei'),
    
    // Mining Settings
    NUM_WORKERS: Math.max(2, os.cpus().length),
    MAX_MINING_TIME: 5, // In seconds
    BATCH_SIZE: 100000,
};

// ========================================
// Contract ABI
// ========================================
const CONTRACT_ABI = [
    'function mine(uint256 nonce, uint256 timestamp) external',
    'function checkHash(uint256 nonce, uint256 timestamp) external view returns (bytes32 hash, bool valid)',
    'function getEffectiveDifficulty(uint256 _timestamp) public view returns (uint256)',
    'function lastHash() external view returns (bytes32)',
    'function getDifficultyPercent() external view returns (uint256)',
    'function getBaseDifficultyPercent() external view returns (uint256)',
    'function getTimeSinceLastMine() external view returns (uint256)',
    'function remainingSupply() external view returns (uint256)',
    'function totalMines() external view returns (uint256)',
    'function minerStats(address) external view returns (uint256)',
    'function balanceOf(address) external view returns (uint256)',
    'event Mined(address indexed miner, uint256 reward, bytes32 hash, uint256 effectiveDifficulty, uint256 timeSinceLastMine)'
];

// --- Utilities & UI ---
const colors = {
    reset: '\x1b[0m', bright: '\x1b[1m', dim: '\x1b[2m', red: '\x1b[31m',
    green: '\x1b[32m', yellow: '\x1b[33m', blue: '\x1b[34m', magenta: '\x1b[35m', cyan: '\x1b[36m',
};
function colorize(text, color) { return `${colors[color]}${text}${colors.reset}`; }

// --- Local Hash Verification ---
function checkHashLocal(lastHash, miner, nonce, timestamp, difficulty) {
    const hash = ethers.keccak256(ethers.solidityPacked(['bytes32', 'address', 'uint256', 'uint256'], [lastHash, miner, nonce, timestamp]));
    return { hash, valid: BigInt(hash) < BigInt(difficulty) };
}

// ========================================
// >> Main Bot Class <<
// ========================================
class LakMiningBot {
    constructor(config) {
        this.config = config;
        this.provider = null;
        this.wallet = null;
        this.contract = null;
        this.isMining = false;
        
        // UI state management object
        this.uiState = {
            status: 'Initializing...',
            successfulMines: 0,
            failedMines: 0,
            totalRewards: 0,
            avgHashrate: '0 H/s',
            lastHash: 'N/A',
            timeBonus: '0%',
            nonce: null,
            txHash: null,
        };
        this.startTime = Date.now();
        this.totalAttempts = 0;
    }

    // --- UI Rendering ---
    renderDashboard() {
        // Move cursor up and clear the screen to redraw the dashboard
        process.stdout.write('\x1B[8A'); // Move up 8 lines
        process.stdout.write('\x1B[J');  // Clear from cursor to end of screen

        const border = colorize('━'.repeat(60), 'dim');
        console.log(border);
        console.log(`  [STATUS] ${colorize(this.uiState.status.padEnd(45), 'yellow')}`);
        console.log(`  [STATS]  ${colorize('Success', 'green')}: ${this.uiState.successfulMines} | ${colorize('Fails', 'red')}: ${this.uiState.failedMines} | ${colorize('Total Rewards', 'cyan')}: ${this.uiState.totalRewards} LAK`);
        console.log(`  [PERF]   ${colorize('Avg. Hashrate', 'magenta')}: ${this.uiState.avgHashrate}`);
        console.log(border);
        console.log(`  [TARGET] LastHash: ${colorize(this.uiState.lastHash.slice(0, 12) + '...', 'dim')} | ${colorize('Time Bonus', 'green')}: +${this.uiState.timeBonus}`);
        console.log(`  [RESULT] Nonce: ${this.uiState.nonce ? colorize(this.uiState.nonce, 'yellow') : '...'} | TX Hash: ${this.uiState.txHash ? colorize(this.uiState.txHash.slice(0,12) + '...', 'blue') : '...'}`);
        console.log(border);
    }
    
    logEvent(message) {
        const timestamp = new Date().toLocaleTimeString();
        console.log(`[${timestamp}] ${message}`);
    }

    // --- Core Bot Logic ---
    async initialize() {
        console.clear();
        console.log(colorize('🚀 LAK Token Mining Bot (v1.7.1 - English UI)', 'cyan'));
        console.log(colorize('━'.repeat(60), 'dim'));

        this.provider = new ethers.WebSocketProvider(this.config.RPC_URL);
        this.wallet = new ethers.Wallet(this.config.PRIVATE_KEY, this.provider);
        this.contract = new ethers.Contract(this.config.CONTRACT_ADDRESS, CONTRACT_ABI, this.wallet);
        
        const network = await this.provider.getNetwork();
        const balance = await this.provider.getBalance(this.wallet.address);

        console.log(`  [NETWORK]  Chain ID: ${colorize(network.chainId, 'green')}`);
        console.log(`  [WALLET]   ${colorize(this.wallet.address, 'yellow')} | Balance: ${colorize(ethers.formatEther(balance).slice(0,6) + ' MON', 'green')}`);
        console.log(`  [CONTRACT] ${colorize(this.config.CONTRACT_ADDRESS, 'cyan')}`);
        console.log(colorize('━'.repeat(60), 'dim'));
        
        // Create empty space for the dashboard to be rendered into
        console.log('\n\n\n\n\n\n\n\n'); 
    }

    async getCurrentTimestamp() {
        try {
            const block = await this.provider.getBlock('latest');
            return block.timestamp;
        } catch (error) {
            return Math.floor(Date.now() / 1000);
        }
    }
    
    async findValidNonceParallel() {
        this.uiState.status = 'Starting search ⛏️';
        this.uiState.nonce = null;
        this.uiState.txHash = null;

        try {
            const currentTimestamp = await this.getCurrentTimestamp();
            const [lastHashValue, effectiveDifficultyValue, timeSinceLastMine] = await Promise.all([
                this.contract.lastHash(), this.contract.getEffectiveDifficulty(currentTimestamp), this.contract.getTimeSinceLastMine()
            ]);
            
            this.uiState.lastHash = lastHashValue;
            const periods = Math.min(10, Math.floor(Number(timeSinceLastMine) / 30));
            this.uiState.timeBonus = `${periods * 10}%`;

            let found = false, foundNonce = null, totalAttemptsInRound = 0;
            let startNonce = BigInt(Math.floor(Math.random() * 1e9));
            const batchSizeBigInt = BigInt(this.config.BATCH_SIZE);
            const numWorkersBigInt = BigInt(this.config.NUM_WORKERS);
            const maxEndTime = Date.now() + (this.config.MAX_MINING_TIME * 1000);

            while (!found && Date.now() < maxEndTime) {
                const workers = Array.from({ length: this.config.NUM_WORKERS }, (_, i) => {
                    const searchStart = startNonce + (BigInt(i) * batchSizeBigInt);
                    return this.searchRange(lastHashValue, effectiveDifficultyValue, currentTimestamp, searchStart, searchStart + batchSizeBigInt);
                });
                const results = await Promise.all(workers);
                for (const result of results) {
                    totalAttemptsInRound += result.attempts;
                    if (result.found) { found = true; foundNonce = result.nonce; break; }
                }
                if (found) break;
                startNonce += batchSizeBigInt * numWorkersBigInt;
                this.uiState.status = `Mining ⛏️... (Attempts: ${(totalAttemptsInRound / 1000).toFixed(1)}k)`;
                this.renderDashboard();
                await this.sleep(100);
            }

            if (found) {
                this.uiState.status = `Nonce found ✨`;
                this.uiState.nonce = foundNonce.toString();
                this.renderDashboard();
                this.totalAttempts += totalAttemptsInRound;
                return { nonce: foundNonce, timestamp: currentTimestamp };
            }
            this.totalAttempts += totalAttemptsInRound;
            return null; // Timed out
        } catch (error) {
            this.uiState.status = `Error: ${error.message}`;
            this.renderDashboard();
            return null;
        }
    }
    
    async searchRange(lastHash, difficulty, timestamp, start, end) {
        let attempts = 0;
        for (let nonce = start; nonce < end; nonce = nonce + 1n) {
            attempts++;
            if (checkHashLocal(lastHash, this.wallet.address, nonce, timestamp, difficulty.toString()).valid) {
                return { found: true, nonce, attempts };
            }
        }
        return { found: false, nonce: null, attempts };
    }

    async submitMine(nonce, timestamp) {
        this.uiState.status = 'Submitting transaction 📤...';
        this.renderDashboard();
        const maxRetries = 3;
        let attempt = 0;
        while (attempt < maxRetries) {
            attempt++;
            try {
                const tx = await this.contract.mine(nonce, timestamp, { gasLimit: this.config.GAS_LIMIT, maxPriorityFeePerGas: this.config.MAX_PRIORITY_FEE, maxFeePerGas: this.config.MAX_FEE });
                this.uiState.txHash = tx.hash;
                this.uiState.status = 'Waiting for confirmation 🕒...';
                this.renderDashboard();
                const receipt = await tx.wait();
                if (receipt.status === 1) {
                    this.uiState.successfulMines++; this.uiState.totalRewards++;
                    this.logEvent(`${colorize('✅ Mine successful!', 'green')} | Reward: 1 LAK | Nonce: ${nonce.toString()}`);
                    return true;
                } else {
                    this.uiState.failedMines++;
                    this.logEvent(`${colorize('❌ Mine failed', 'red')} (Status 0) | Nonce: ${nonce.toString()}`);
                    return false;
                }
            } catch (error) {
                const reason = error.reason || error.message;
                if (reason.includes('could not coalesce') && attempt < maxRetries) {
                    this.uiState.status = `RPC Error, retrying (${attempt}/${maxRetries}) ⚠️...`;
                    this.renderDashboard();
                    await this.sleep(500);
                    continue;
                }
                this.uiState.failedMines++;
                this.logEvent(`${colorize('❌ Mine failed', 'red')} | Reason: ${reason.slice(0, 40)}... | Nonce: ${nonce.toString()}`);
                return false;
            }
        }
        return false;
    }
    
    async startMining() {
        this.isMining = true;
        while (this.isMining) {
            const elapsedSeconds = (Date.now() - this.startTime) / 1000;
            this.uiState.avgHashrate = elapsedSeconds > 0 ? `${(this.totalAttempts / elapsedSeconds / 1000).toFixed(1)} kH/s` : '0 H/s';
            const result = await this.findValidNonceParallel();
            if (result) {
                await this.submitMine(result.nonce, result.timestamp);
            }
            await this.sleep(1000); // 1-second delay before next attempt
        }
    }

    sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

    async cleanup() {
        if (this.provider) {
            await this.provider.destroy();
            console.log(colorize('Connection closed.', 'dim'));
        }
    }
}

// ========================================
// >> Main Execution <<
// ========================================
async function main() {
    if (CONFIG.PRIVATE_KEY.startsWith('YOUR_') || CONFIG.CONTRACT_ADDRESS.startsWith('YOUR_')) {
        console.error(colorize('❌ Please set your PRIVATE_KEY and CONTRACT_ADDRESS in the CONFIG section!', 'red'));
        process.exit(1);
    }
    const bot = new LakMiningBot(CONFIG);
    process.on('SIGINT', async () => {
        bot.isMining = false;
        await bot.sleep(200);
        console.log('\n\n' + colorize('⏹️  Mining stopped. Final stats:', 'yellow'));
        console.log(`  - Success: ${bot.uiState.successfulMines}, Fails: ${bot.uiState.failedMines}`);
        console.log(`  - Total Rewards: ${bot.uiState.totalRewards} LAK`);
        console.log(`  - Avg. Hashrate: ${bot.uiState.avgHashrate}`);
        await bot.cleanup();
        process.exit(0);
    });
    try {
        await bot.initialize();
        await bot.startMining();
    } catch (error) {
        console.error(colorize('❌ Fatal error:', 'red'), error);
        await bot.cleanup(); process.exit(1);
    }
}

main();
