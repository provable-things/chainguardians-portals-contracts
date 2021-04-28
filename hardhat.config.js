require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
require('@openzeppelin/hardhat-upgrades')
require('@nomiclabs/hardhat-etherscan')
require('@nomiclabs/hardhat-waffle')
require('hardhat-gas-reporter')

const getEnvironmentVariable = (_envVar) =>
  process.env[_envVar]
    ? process.env[_envVar]
    : console.error(
        '✘ Cannot migrate!\n',
        '✘ Please provide an infura api key as and an\n',
        '✘ account private key as environment variables:\n',
        '✘ MAINNET_PRIVATE_KEY\n',
        '✘ ROPSTEN_PRIVATE_KEY\n',
        '✘ ETH_MAINNET_NODE\n',
        '✘ BSC_MAINNET_NODE\n',
        '✘ ROPSTEN_NODE\n',
        '✘ ETHERSCAN_API_KEY\n',
        '✘ BSCSCAN_API_KEY\n',
        '✘ BSC_MAINNET_PRIVATE_KEY\n'
      )

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.7.3',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    ropsten: {
      url: `${getEnvironmentVariable('ROPSTEN_NODE')}`,
      accounts: [getEnvironmentVariable('ROPSTEN_PRIVATE_KEY')],
      gas: 6e6,
      gasPrice: 30e9,
      websockets: true,
    },
    mainnet: {
      url: `${getEnvironmentVariable('ETH_MAINNET_NODE')}`,
      accounts: [getEnvironmentVariable('MAINNET_PRIVATE_KEY')],
      gas: 4e6,
      gasPrice: 45e9,
      websockets: true,
      timeout: 1000 * 60 * 20,
    },
    bsc: {
      url: getEnvironmentVariable('BSC_MAINNET_NODE'),
      accounts: [getEnvironmentVariable('BSC_MAINNET_PRIVATE_KEY')],
      gas: 3e6,
      gasPrice: 7e9,
      websockets: true,
    },
  },
  etherscan: {
    apiKey: getEnvironmentVariable('ETHERSCAN_API_KEY'),
  },
  gasReporter: {
    enabled: true,
  },
  mocha: {
    timeout: 200000,
  },
}
