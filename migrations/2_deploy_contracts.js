const Pixsale = artifacts.require("./Pixsale.sol");
const Web3 = require('web3');
const web3 = new Web3(Web3.givenProvider);
const fs = require('fs');


/////// SET HERE ///////
// @proceed : SET true or false to allow deployment a new FieldCoin contract
const { DEPLOY_PIXSALE } = process.env;
////////////////////////

const TESTNET_OWNERS = [
  "0xaD3D069E8b45BaF4ba0277Ee0C2610d22e97AD20",
  "0xA364555826ec79Be3573ADC71faA2d99099c879B"
];

const LIVE_OWNERS = [
  '0xe70D9D77DC5ED0Bd45E15f8B81C02694e1051f98',
  '0xA364555826ec79Be3573ADC71faA2d99099c879B'
];

/**
 * @dev Contract Deployer
 * @notice run the "truffle deploy" command
 * @see readme.md 
 */
module.exports = async (deployer, network) => {
  if (DEPLOY_PIXSALE) {
    const isTestNet = await Promise.resolve(
      (network.indexOf('bsctest') >= 0)
      || (network.indexOf('rinkeby') >= 0)
    );
    const OWNERS = await Promise.resolve(
      isTestNet
      ? TESTNET_OWNERS
      : LIVE_OWNERS
    )
    await deployer.deploy(Pixsale, OWNERS);
    // const { abi, address } = Pixsale;
    //await fs.writeFile(`${address}.json`, JSON.stringify(abi, null, 4), console.log);
    
  }
};
