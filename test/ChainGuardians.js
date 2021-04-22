const { use, expect } = require('chai')
const { BN, encode } = require('./utils')
const { ethers, upgrades } = require('hardhat')
const { solidity } = require('ethereum-waffle')
const singletons = require('./utils/singletons')
use(solidity)

let chainGuardiansPortalsNative,
  chainGuardiansPortalsHost,
  cgt,
  cgtStorage,
  owner,
  account1,
  account2,
  pnetwork,
  nativeToken,
  vault,
  pToken

const PROVABLE_CHAIN_IDS = {
  ethereumMainnet: '0x005fe7f9',
  ethereumRinkeby: '0x0069c322',
  ethereumRopsten: '0x00f34368',
  bitcoinMainnet: '0x01ec97de',
  bitcoinTestnet: '0x018afeb2',
  telosMainnet: '0x028c7109',
  eosMainnet: '0x02e7261c',
  bscMainnet: '0x00e4b170',
}

const TOKEN_ID = 0
const ATTRIBUTES = [0, 2]
const BASE_URI = 'https://api.chainguardians.io/api/opensea/'

describe('ChainGuardians (ChainGuardiansPortalsNative and ChainGuardiansPortalsHost)', () => {
  beforeEach(async () => {
    const ChainGuardiansPortalsNative = await ethers.getContractFactory('ChainGuardiansPortalsNative')
    const ChainGuardiansPortalsHost = await ethers.getContractFactory('ChainGuardiansPortalsHost')
    const ChainGuardiansStorage = await ethers.getContractFactory('ChainGuardiansStorage')
    const ChainGuardiansToken = await ethers.getContractFactory('ChainGuardiansToken')
    const Standard777Token = await ethers.getContractFactory('Standard777Token')
    const MockPToken = await ethers.getContractFactory('MockPToken')
    const MockVault = await ethers.getContractFactory('MockVault')

    const accounts = await ethers.getSigners()
    owner = accounts[0]
    account1 = accounts[1]
    pnetwork = accounts[2]

    // NOTE: host blockchain (evm compatible) accounts
    account2 = accounts[3]

    await singletons.ERC1820Registry(owner)

    vault = await MockVault.deploy(pnetwork.address)
    nativeToken = await Standard777Token.deploy('Native Token', 'NTKN')
    pToken = await MockPToken.deploy('Host Token (pToken)', 'HTKN', [], pnetwork.address)
    cgtStorage = await ChainGuardiansStorage.deploy()
    cgt = await ChainGuardiansToken.deploy(cgtStorage.address, BASE_URI)

    chainGuardiansPortalsHost = await upgrades.deployProxy(
      ChainGuardiansPortalsHost,
      [pToken.address, 'Chain Guardians Token', 'CGT', BASE_URI],
      {
        initializer: 'initialize',
      }
    )

    chainGuardiansPortalsNative = await upgrades.deployProxy(
      ChainGuardiansPortalsNative,
      [cgt.address, nativeToken.address, vault.address],
      {
        initializer: 'initialize',
      }
    )

    // NOTE: init all stuff nedeed in order to work correctly
    await chainGuardiansPortalsNative.setMinTokenAmountToPegIn(BN(1, 18))
    await nativeToken.send(pnetwork.address, BN(1000, 10), '0x')
    await nativeToken.send(chainGuardiansPortalsNative.address, BN(1000, 18), '0x')
    await cgtStorage.transferOwnership(cgt.address)
  })

  it('should be able to set minimum amount to pegin', async () => {
    await expect(chainGuardiansPortalsNative.setMinTokenAmountToPegIn(BN(0.05, 18)))
      .to.emit(chainGuardiansPortalsNative, 'MinTokenAmountToPegInChanged')
      .withArgs(BN(0.05, 18))
  })

  it('should not be able to set minimum amount to pegin', async () => {
    const chainGuardiansNativeAccount1 = chainGuardiansPortalsNative.connect(account1)
    await expect(chainGuardiansNativeAccount1.setMinTokenAmountToPegIn(BN(0.05, 18))).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
  })

  it('should be able to set chainGuardiansPortalsHost', async () => {
    const uriedNftHostAddress = '0x0000000000000000000000000000000000000001'
    await expect(chainGuardiansPortalsNative.setChainGuardiansPortalsHost(uriedNftHostAddress))
      .to.emit(chainGuardiansPortalsNative, 'ChainGuardiansPortalsHostChanged')
      .withArgs(uriedNftHostAddress)
  })

  it('should not be able to set chainGuardiansPortalsHost', async () => {
    const uriedNftHostAddress = '0x0000000000000000000000000000000000000001'
    const chainGuardiansNativeAccount1 = chainGuardiansPortalsNative.connect(account1)
    await expect(chainGuardiansNativeAccount1.setMinTokenAmountToPegIn(uriedNftHostAddress)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
  })

  it('should be able to set erc777', async () => {
    const erc777 = '0x0000000000000000000000000000000000004321'
    await expect(chainGuardiansPortalsNative.setERC777(erc777))
      .to.emit(chainGuardiansPortalsNative, 'ERC777Changed')
      .withArgs(erc777)
  })

  it('should be able to set vault', async () => {
    const newVault = '0x0000000000000000000000000000000000004444'
    await expect(chainGuardiansPortalsNative.setVault(newVault))
      .to.emit(chainGuardiansPortalsNative, 'VaultChanged')
      .withArgs(newVault)
  })

  it('should not be able to set erc777', async () => {
    const erc777 = '0x0000000000000000000000000000000000004321'
    const chainGuardiansNativeAccount1 = chainGuardiansPortalsNative.connect(account1)
    await expect(chainGuardiansNativeAccount1.setERC777(erc777)).to.be.revertedWith('Ownable: caller is not the owner')
  })

  it('should not be able to set vault', async () => {
    const newVault = '0x0000000000000000000000000000000000004444'
    const chainGuardiansNativeAccount1 = chainGuardiansPortalsNative.connect(account1)
    await expect(chainGuardiansNativeAccount1.setVault(newVault)).to.be.revertedWith('Ownable: caller is not the owner')
  })

  it('should be able to set baseUri', async () => {
    await chainGuardiansPortalsHost.setBaseURI(BASE_URI + '1')
    await expect(await chainGuardiansPortalsHost.baseURI()).to.be.equal(BASE_URI + '1')
  })

  it('should not be able to set baseUri', async () => {
    const chainGuardiansHostAccount1 = chainGuardiansPortalsHost.connect(account1)
    await expect(chainGuardiansHostAccount1.setBaseURI('hello')).to.be.revertedWith('Ownable: caller is not the owner')
  })

  it('should be able to set pToken', async () => {
    const pToken = '0x0000000000000000000000000000000000004321'
    await expect(chainGuardiansPortalsHost.setPtoken(pToken))
      .to.emit(chainGuardiansPortalsHost, 'PtokenChanged')
      .withArgs(pToken)
  })

  it('should not be able to set pToken', async () => {
    const pToken = '0x0000000000000000000000000000000000004321'
    const chainGuardiansHostAccount1 = chainGuardiansPortalsHost.connect(account1)
    await expect(chainGuardiansHostAccount1.setPtoken(pToken)).to.be.revertedWith('Ownable: caller is not the owner')
  })

  it('should be able to retrieve minAmountToPegIn and chainGuardiansPortalsHost after a contract upgrade', async () => {
    await chainGuardiansPortalsNative.setMinTokenAmountToPegIn(BN(0.05, 18))
    await chainGuardiansPortalsNative.setChainGuardiansPortalsHost(chainGuardiansPortalsHost.address)
    await chainGuardiansPortalsHost.setChainGuardiansPortalsNative(chainGuardiansPortalsNative.address)
    const ChainGuardiansPortalsNative = await ethers.getContractFactory('ChainGuardiansPortalsNative')
    const testNativePortalsNativeUpgraded = await upgrades.upgradeProxy(
      chainGuardiansPortalsNative.address,
      ChainGuardiansPortalsNative
    )
    const minTokenAmountToPegIn = await testNativePortalsNativeUpgraded.minTokenAmountToPegIn()
    const uriedNftHostAddress = await testNativePortalsNativeUpgraded.chainGuardiansPortalsHost()
    expect(minTokenAmountToPegIn).to.be.equal(BN(0.05, 18))
    expect(uriedNftHostAddress).to.be.equal(chainGuardiansPortalsHost.address)
  })

  it('should not be able to mint tokens on the host chain with a wrong token', async () => {
    const MockPToken = await ethers.getContractFactory('MockPToken')
    const data = encode(['uint256', 'string'], [0, account2.address])
    const wrongPtoken = await MockPToken.deploy('Host Token (pToken)', 'HTKN', [], pnetwork.address)
    const wrongPtokenPnetwork = wrongPtoken.connect(pnetwork)
    await expect(wrongPtokenPnetwork.mint(chainGuardiansPortalsHost.address, BN(1, 10), data, '0x')).to.not.emit(
      chainGuardiansPortalsHost,
      'Transfer'
    )
  })

  it('should be able to wrap and unwrap', async () => {
    await cgt.create(TOKEN_ID, ATTRIBUTES.length, ATTRIBUTES, owner.address)

    const peginData = encode(['uint256', 'address'], [TOKEN_ID, account2.address])
    const pegoutData = encode(['uint256', 'address'], [TOKEN_ID, owner.address])
    const initialBalance = await cgt.balanceOf(owner.address)

    await chainGuardiansPortalsNative.setChainGuardiansPortalsHost(chainGuardiansPortalsHost.address)
    await chainGuardiansPortalsHost.setChainGuardiansPortalsNative(chainGuardiansPortalsNative.address)

    // P E G   I N
    await cgt.approve(chainGuardiansPortalsNative.address, TOKEN_ID)
    await expect(chainGuardiansPortalsNative.wrap(TOKEN_ID, account2.address))
      .to.emit(chainGuardiansPortalsNative, 'Minted')
      .withArgs(0, account2.address)

    // at this point let's suppose that a pNetwork node processes the pegin...

    const hostTokenPnetwork = pToken.connect(pnetwork)
    const enclavePeginMetadata = encode(
      ['bytes1', 'bytes', 'bytes4', 'address'],
      ['0x01', peginData, PROVABLE_CHAIN_IDS.bscMainnet, chainGuardiansPortalsNative.address]
    )
    await expect(hostTokenPnetwork.mint(chainGuardiansPortalsHost.address, BN(1, 10), enclavePeginMetadata, '0x'))
      .to.emit(chainGuardiansPortalsHost, 'Transfer')
      .withArgs('0x0000000000000000000000000000000000000000', account2.address, TOKEN_ID)
    expect(await chainGuardiansPortalsHost.balanceOf(account2.address)).to.be.equal(1)

    // P E G   O U T
    const chainGuardiansPortalsHostAccount2 = chainGuardiansPortalsHost.connect(account2)
    await expect(chainGuardiansPortalsHostAccount2.unwrap(TOKEN_ID, owner.address))
      .to.emit(chainGuardiansPortalsHostAccount2, 'Burned')
      .withArgs(TOKEN_ID, owner.address)
    expect(await chainGuardiansPortalsHost.balanceOf(account2.address)).to.be.equal(0)

    const vaultPnetwork = vault.connect(pnetwork)
    const enclavePegoutMetadata = encode(
      ['bytes1', 'bytes', 'bytes4', 'address'],
      ['0x01', pegoutData, PROVABLE_CHAIN_IDS.bscMainnet, chainGuardiansPortalsHost.address]
    )
    await vaultPnetwork.pegOut(
      chainGuardiansPortalsNative.address,
      nativeToken.address,
      TOKEN_ID,
      enclavePegoutMetadata
    )
    expect(await cgt.balanceOf(owner.address)).to.be.equal(initialBalance)
  })

  it('should not be able to mint on the host blockchain if the originating address is not the correct one', async () => {
    await cgt.create(TOKEN_ID, ATTRIBUTES.length, ATTRIBUTES, owner.address)
    const peginData = encode(['uint256', 'address', 'string'], [TOKEN_ID, account2.address, BASE_URI])

    // NOTE: an user calls pegin with correct metadata without using native portals contract
    await nativeToken.approve(vault.address, BN(1000, 18))
    await vault.pegIn(BN(1000, 18), nativeToken.address, chainGuardiansPortalsHost.address.toLowerCase(), '0x')

    // NOTE: at this point let's suppose that a pNetwork node processes the pegin...

    const hostTokenPnetwork = pToken.connect(pnetwork)
    const enclavePeginMetadata = encode(
      ['bytes1', 'bytes', 'bytes4', 'address'],
      ['0x01', peginData, PROVABLE_CHAIN_IDS.bscMainnet, account2.address]
    )
    await expect(
      hostTokenPnetwork.mint(chainGuardiansPortalsHost.address, BN(1, 10), enclavePeginMetadata, '0x')
    ).to.be.revertedWith('ChainGuardiansPortalsHost: Invalid originating address')
  })

  it('only pnetwork is able to mint tokens on the host blockchain', async () => {
    await pToken.connect(pnetwork).mint(owner.address, 1000, '0x', '0x')
    await expect(pToken.send(chainGuardiansPortalsHost.address, 1000, '0x')).to.not.emit(
      chainGuardiansPortalsHost,
      'Transfer'
    )
  })
})
