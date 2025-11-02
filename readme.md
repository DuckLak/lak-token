# 🪙 Lak Token - PoW Mining on EVM

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Solidity](https://img.shields.io/badge/solidity-0.8.20-brightgreen.svg)
![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.0-purple.svg)

**Lak Token** is an ERC20 token with Proof-of-Work (PoW) mining mechanism on EVM-compatible chains, inspired by Solana's ORE project.

## 🌟 ScreenShot

<img width="280" height="771" alt="image" src="https://github.com/user-attachments/assets/c3493770-16eb-4ff1-bcc2-afc75e9d74a7" />
<img width="280" height="687" alt="image" src="https://github.com/user-attachments/assets/8712ba12-a406-43f0-8090-4147572c693d" />
<img width="280" height="670" alt="image" src="https://github.com/user-attachments/assets/6110e17b-ad97-45c4-8791-6e7804cb989e" />


- Success Mine: [Transaction](https://testnet.monadexplorer.com/tx/0xf49155476758c267b78a92f78227f97bfab9b5f1eeb1da27c4ec38ceaee6adf6)

- Fail Mine: [Transaction](https://testnet.monadexplorer.com/tx/0x0a39fd461d6862de2e98e14247be53ca155d59e907d0d22070cf4840ebe736b8)


## 🌟 Features

- ⛏️ **On-chain PoW Mining**: Mine tokens directly on the blockchain by finding valid nonces.
- 🎯 **Dual Difficulty Adjustment**:
    - **Interval-based**: Difficulty adjusts based on the network's overall mining rate.
    - **Time-based**: A "Time Bonus" makes it easier to mine the longer it has been since the last successful mine.
- 🔒 **Fixed Supply**: A hard cap of 10,000,000 LAK tokens can ever be created.
- 💎 **Fair Distribution**: A constant reward of 1 LAK per successful mine.
- 🛡️ **Secure Foundation**: Built using battle-tested OpenZeppelin contracts.
- 📊 **Transparent Stats**: All mining statistics are available on-chain for anyone to view.

## 📋 Contract Details

| Parameter | Value |
|-----------|-------|
| Token Name | Lak Token |
| Symbol | LAK |
| Decimals | 18 |
| Max Supply | 10,000,000 LAK |
| Reward per Mine | 1 LAK |
| Interval Difficulty Adjustment | Every 100 blocks |
| Target Mines per Interval | 50 |
| Time Bonus | 10% easier every 30 seconds (up to 100%) |

## 🚀 Quick Start

### Prerequisites

- [Node.js](https://nodejs.org/) v16+
- [MetaMask](https://metamask.io/) or [Phantom](https://phantom.com/) wallet
- Test network tokens (e.g., Monad Testnet MON)

### Deployment

1. Clone the repository:
```bash
git clone https://github.com/DuckLak/lak-token.git
cd lak-token
```

2. Install dependencies:
```bash
npm install
```

3. Deploy using Remix IDE:
   - Open [Remix IDE](https://remix.ethereum.org/)
   - Create new file `LakToken.sol`
   - Paste the contract code
   - Compile with Solidity 0.8.20+
   - Deploy to your desired network

### Mining

#### Using the Web Interface

1. Open the mining web app
2. Connect your wallet (MetaMask,Phantom)
3. Click "Start Mining (100x)"
4. Wait for the bot to find valid nonces and submit transactions

#### Manual Mining (Advanced)

```javascript
// This example demonstrates the core logic.
// A timestamp is now required to prevent race conditions.

const lastHash = await contract.lastHash();
// Get the current timestamp which will be used as a fixed reference
const timestamp = (await provider.getBlock('latest')).timestamp; 
// Get the difficulty calculated for this specific timestamp
const difficulty = await contract.getEffectiveDifficulty(timestamp);

for(let nonce = 0; nonce < 1000000; nonce++) {
  // Use abi.encodePacked equivalent in ethers.js
  const hash = ethers.keccak256(
    ethers.solidityPacked(
      ['bytes32', 'address', 'uint256', 'uint256'],
      [lastHash, myAddress, nonce, timestamp]
    )
  );
  
  if(BigInt(hash) < BigInt(difficulty)) {
    // Submit the nonce along with the timestamp used to find it
    await contract.mine(nonce, timestamp);
    break;
  }
}
```

## 🏗️ Architecture

### Core Functions

#### `mine(uint256 nonce, uint256 timestamp)`
The primary function for miners. A `nonce` is submitted along with the `timestamp` that was used as the basis for the PoW calculation. This design prevents race conditions where the difficulty changes mid-search.

#### `adjustDifficulty()`
This internal function is automatically called every 100 blocks. It recalibrates the `baseDifficulty` to ensure the network maintains the target mining rate.

#### `getEffectiveDifficulty(uint256 _timestamp)`
A view function that calculates the difficulty for any given timestamp. It incorporates both the `baseDifficulty` and the time-based bonus.

### Security Features

- ✅ **Overflow Protection**: Solidity 0.8.x automatic checks
- ✅ **Supply Cap**: Hard-coded maximum supply enforcement
- ✅ **Bounded Difficulty**: Min/max difficulty limits (0.01% - 10%)
- ✅ **Smooth Adjustments**: Maximum ±20% difficulty change per interval
- ✅ **Hash Collision Resistance**: Using `abi.encode` instead of `abi.encodePacked`

## 📊 Statistics Functions

```solidity
totalMines()              // Total successful mines
minerStats(address)       // Mines by specific address
balanceOf(address)        // LAK token balance
remainingSupply()         // Tokens left to mine
getDifficultyPercent()    // Current difficulty as percentage
```

## ⚙️ Owner Functions

### `setDifficulty(uint256 newDifficulty)`
Manually adjust difficulty (emergency use only).

### `setTargetMines(uint256 newTarget)`
Adjust target mines per adjustment interval.

> ⚠️ **Note**: Owner functions are provided for emergency adjustments. For production use, consider implementing a timelock or DAO governance.

## 🧪 Testing Networks

Successfully tested on:
- ✅ Monad Testnet (Chain ID: 10143)

## 📈 Difficulty Algorithms

The contract uses a dual-algorithm system for difficulty:

1.  **Time Bonus (Short-Term Incentive)**: Encourages consistent mining.
    - For every 30 seconds (`TIME_THRESHOLD`) that pass since the last successful mine, the difficulty becomes 10% easier.
    - This bonus is capped at 100% (after 300 seconds) to prevent the difficulty from dropping too low.

2.  **Interval Adjustment (Long-Term Health)**: Maintains network stability.
    - Every 100 blocks (`ADJUSTMENT_INTERVAL`), the contract compares the actual number of mines to the `targetMinesPerInterval` (50).
    - If `actual mines > target` → `baseDifficulty` increases (mining becomes harder).
    - If `actual mines < target` → `baseDifficulty` decreases (mining becomes easier).

## 🔐 Security Considerations

### Audited Security Features
- No reentrancy vulnerabilities
- No integer overflow/underflow risks
- No arbitrary external calls
- Protected against front-running attacks

### Known Limitations
- **Timestamp Dependence**: Uses `block.timestamp` (±15 sec miner influence)
- **Owner Privileges**: Owner can adjust parameters
- **Gas Costs**: Mining transactions require gas fees

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [ORE](https://ore.supply/) on Solana
- Built with [OpenZeppelin Contracts](https://openzeppelin.com/contracts/)
- Thanks to the Monad and EVM community

- Twitter: [@DuckLak](https://twitter.com/DuckLak)

## ⚠️ Disclaimer

This is experimental software. Use at your own risk. This contract has not been formally audited for production use. Always test thoroughly on testnets before deploying to mainnet.

---

**Built with ❤️ Duck for the decentralized future**
