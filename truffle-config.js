require('dotenv').config()

const HDWalletProvider = require('@truffle/hdwallet-provider');

const { MNEMONIC, INFURA_KEY } = process.env;

const solcStable = {
  version: '0.8.4',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
};

//const needsInfura = process.env.npm_config_argv && (process.env.npm_config_argv.includes('rinkeby') || process.env.npm_config_argv.includes('live'));

if (
  //needsInfura && 
  !(MNEMONIC && INFURA_KEY)) {
  console.error('Please set a mnemonic and infura key.');
  process.exit(0);
}

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    localtest: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*"
    },
    rinkeby: {
      provider: () => {
        return new HDWalletProvider(MNEMONIC, `https://rinkeby.infura.io/v3/${INFURA_KEY}`);
      },
      network_id: '*',
      networkCheckTimeout: 10000000,
      skipDryRun: true
    },
    live: {
      network_id: 1,
      provider: () => {
        return new HDWalletProvider(MNEMONIC, `https://mainnet.infura.io/v3/${INFURA_KEY}`);
      },
      gas: 3500000,   // 3216724
      gasPrice: 20000000000, // 30Gwei
      skipDryRun: true
    },
    // binance smart chain testnet
    bsctest: {
      provider: () => new HDWalletProvider(MNEMONIC, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true,
      gas: 5100000
    },
    // binance smart chain live
    bsc: {
      provider: () => new HDWalletProvider(MNEMONIC, `https://bsc-dataseed1.binance.org`),
      network_id: 56,
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true,
      gas: 5100000
    },
  },
  compilers: {
    solc: solcStable
  }
};