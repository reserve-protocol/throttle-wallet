/** @type import('hardhat/config').HardhatUserConfig */
import '@nomicfoundation/hardhat-toolbox'
import "@nomicfoundation/hardhat-foundry"
import '@nomicfoundation/hardhat-ethers'
import '@typechain/hardhat'
import { useEnv } from './utils/env'
import { HardhatUserConfig } from 'hardhat/types'

const MAINNET_RPC_URL = useEnv(['MAINNET_RPC_URL', 'ALCHEMY_MAINNET_RPC_URL'])
const MNEMONIC = useEnv('MNEMONIC') ?? 'test test test test test test test test test test test junk'

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      // network for tests/in-process stuff
      forking: useEnv('FORK')
        ? {
            url: MAINNET_RPC_URL,
            blockNumber: Number(useEnv(`FORK_BLOCK`, '19292360')),
          }
        : undefined,
      gas: 0x1ffffffff,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
    },
    localhost: {
      // network for long-lived mainnet forks
      chainId: 31337,
      url: 'http://127.0.0.1:8546',
      gas: 0x1ffffffff,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
    },
    mainnet: {
      chainId: 1,
      url: MAINNET_RPC_URL,
      accounts: {
        mnemonic: MNEMONIC,
      },
      // gasPrice: 30_000_000_000,
      gasMultiplier: 2, // 100% buffer; seen failures on RToken deployment and asset refreshes otherwise
    },
  },
  paths: {
    sources: 'src',
  },
  solidity: "0.8.19",
};

export default config