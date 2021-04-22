const { ethers, upgrades } = require('hardhat')

const main = async () => {
  const ChainGuardiansPortalsHost = await ethers.getContractFactory('ChainGuardiansPortalsHost')
  console.info('Deploying ChainGuardiansPortalsHost...')
  const pnt = '0xdaacb0ab6fb34d24e8a67bfa14bf4d95d4c7af92'
  const { address } = await upgrades.deployProxy(ChainGuardiansPortalsHost, ['pnt', 'name', 'symbol', 'uri'], {
    initializer: 'initialize',
  })
  console.info('ChainGuardiansPortalsHost deployed to:', address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
