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

- ⛏️ **On-chain PoW Mining**: Mine tokens by finding valid nonces
- 🎯 **Auto-adjusting Difficulty**: Dynamic difficulty based on mining activity
- 🔒 **Fixed Supply**: Maximum 10,000,000 LAK tokens
- 💎 **Fair Distribution**: 1 LAK reward per successful mine
- 🛡️ **Security Audited**: Built with OpenZeppelin contracts
- 📊 **Transparent Stats**: On-chain mining statistics

## 📋 Contract Details

| Parameter | Value |
|-----------|-------|
| Token Name | Lak Token |
| Symbol | LAK |
| Decimals | 18 |
| Max Supply | 10,000,000 LAK |
| Reward per Mine | 1 LAK |
| Difficulty Adjustment | Every 100 blocks |
| Max Difficulty Change | ±20% per adjustment |

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
// Find a valid nonce off-chain
const lastHash = await contract.lastHash();
const difficulty = await contract.difficulty();

for(let nonce = 0; nonce < 1000000; nonce++) {
  const hash = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ['bytes32', 'address', 'uint256', 'uint256'],
      [lastHash, myAddress, nonce, Math.floor(Date.now()/1000)]
    )
  );
  
  if(BigInt(hash) < BigInt(difficulty)) {
    // Submit the nonce
    await contract.mine(nonce);
    break;
  }
}
```

## 🏗️ Architecture

### Core Functions

#### `mine(uint256 nonce)`
Submit a valid nonce to mine tokens. The hash must be below the current difficulty threshold.

#### `adjustDifficulty()`
Automatically adjusts mining difficulty every 100 blocks based on mining activity.

#### `checkHash(uint256 nonce)`
View function to verify if a nonce is valid before submitting a transaction.

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

## 📈 Difficulty Algorithm

The difficulty automatically adjusts every 100 blocks to maintain target mining rate:

```
Target: 50 successful mines per 100 blocks

If actual mines > target → Difficulty increases (harder to mine)
If actual mines < target → Difficulty decreases (easier to mine)

Max change per adjustment: ±20%
```

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
