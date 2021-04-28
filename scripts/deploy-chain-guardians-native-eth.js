const { ethers, upgrades } = require('hardhat')

const main = async () => {
  const ChainGuardiansPortalsNative = await ethers.getContractFactory('ChainGuardiansPortalsNative')

  console.info('Deploying ChainGuardiansPortalsNative...')
  const cgt = '0x3CD41EC039c1F2DD1f76144bb3722E7b503f50ab'
  const pnt = '0x89Ab32156e46F46D02ade3FEcbe5Fc4243B9AAeD'
  const vault = '0xAB83bD5169F58e753d291223dCaBa4F7644aD3a9'

  const { address } = await upgrades.deployProxy(ChainGuardiansPortalsNative, [cgt, pnt, vault], {
    initializer: 'initialize',
  })

  console.info('ChainGuardiansPortalsNative deployed to:', address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
