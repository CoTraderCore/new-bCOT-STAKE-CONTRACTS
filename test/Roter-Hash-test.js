import { BN, fromWei, toWei } from 'web3-utils'
import ether from './helpers/ether'
import EVMRevert from './helpers/EVMRevert'
import { duration } from './helpers/duration'
const BigNumber = BN
const timeMachine = require('ganache-time-traveler')

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

// real contracts
const UniswapV2Factory = artifacts.require('./UniswapV2Factory.sol')
const UniswapV2Router = artifacts.require('./UniswapV2Router02.sol')
const UniswapV2Pair = artifacts.require('./UniswapV2Pair.sol')


const PairHash = "0xc84da477d7d2e754b95ea0021236517e3592e08dfe083630d97b7c28511bf9a8"

let uniswapV2Factory,
    uniswapV2Router


contract('Pair-hash', function([userOne, userTwo, userThree]) {

  async function deployContracts(){
    // deploy contracts
    uniswapV2Factory = await UniswapV2Factory.new(userOne)
  }

  beforeEach(async function() {
    await deployContracts()
  })

  describe('INIT', function() {
    it('PairHash correct', async function() {
      assert.equal(
        String(await uniswapV2Factory.pairCodeHash()).toLowerCase(),
        String(PairHash).toLowerCase(),
      )
    })
  })
  //END
})
