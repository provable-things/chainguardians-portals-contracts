const { ethers, upgrades } = require('hardhat')

const main = async () => {
  const ChainGuardiansPortalsHost = await ethers.getContractFactory('ChainGuardiansPortalsHost')
  const ChainGuardiansStorage = await ethers.getContractFactory('ChainGuardiansStorage')
  console.info('Deploying ChainGuardiansStorage...')
  const chainGuardiansStorage = await ChainGuardiansStorage.deploy()
  console.info('ChainGuardiansStorage deployed to:', chainGuardiansStorage.address)

  console.info('Deploying ChainGuardiansPortalsHost...')
  const pnt = '0xdaacb0ab6fb34d24e8a67bfa14bf4d95d4c7af92'
  const baseUri = 'https://api.chainguardians.io/api/opensea/'
  const chainGuardiansPortalsHost = await upgrades.deployProxy(
    ChainGuardiansPortalsHost,
    [pnt, baseUri, chainGuardiansStorage.address],
    {
      initializer: 'initialize',
    }
  )

  console.info('ChainGuardiansPortalsHost deployed to:', chainGuardiansPortalsHost.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
