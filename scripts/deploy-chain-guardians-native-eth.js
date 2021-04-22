const { ethers, upgrades } = require('hardhat')

const main = async () => {
  const ChainGuardiansPortalsNative = await ethers.getContractFactory('ChainGuardiansPortalsNative')
  console.info('Deploying ChainGuardiansPortalsNative...')
  const { address } = await upgrades.deployProxy(
    ChainGuardiansPortalsNative,
    ['cgt token', 'erc777 supported by pNetwork', 'vault'],
    { initializer: 'initialize' }
  )
  console.info('ChainGuardiansPortalsNative deployed to:', address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
