//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/IERC777RecipientUpgradeable.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "./interfaces/IPERC20Vault.sol";
import "./lib/Utils.sol";


contract ChainGuardiansPortalsNative is ERC721HolderUpgradeable, IERC777RecipientUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    IERC1820Registry private _erc1820;
    bytes32 private constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    address public cgt;
    address public erc777;
    address public vault;
    address public chainGuardiansPortalsHost;
    uint256 public minTokenAmountToPegIn;

    event Minted(uint256 id, address to);
    event MinTokenAmountToPegInChanged(uint256 minTokenAmountToPegIn);
    event ChainGuardiansPortalsHostChanged(address chainGuardiansPortalsHost);
    event ERC777Changed(address erc777);
    event VaultChanged(address vault);

    function setMinTokenAmountToPegIn(uint256 _minTokenAmountToPegIn) external onlyOwner {
        minTokenAmountToPegIn = _minTokenAmountToPegIn;
        emit MinTokenAmountToPegInChanged(minTokenAmountToPegIn);
    }

    function setChainGuardiansPortalsHost(address _chainGuardiansPortalsHost) external onlyOwner {
        chainGuardiansPortalsHost = _chainGuardiansPortalsHost;
        emit ChainGuardiansPortalsHostChanged(chainGuardiansPortalsHost);
    }

    function setERC777(address _erc777) external onlyOwner {
        erc777 = _erc777;
        emit ERC777Changed(erc777);
    }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;
        emit VaultChanged(vault);
    }

    function tokensReceived(
        address, /*_operator*/
        address _from,
        address, /*_to,*/
        uint256, /*_amount*/
        bytes calldata _userData,
        bytes calldata /*_operatorData*/
    ) external override {
        if (_msgSender() == erc777 && _from == vault) {
            (, bytes memory userData, , address originatingAddress) = abi.decode(_userData, (bytes1, bytes, bytes4, address));
            require(originatingAddress == chainGuardiansPortalsHost, "ChainGuardiansPortalsNative: Invalid originating address");
            (uint256 id, address to) = abi.decode(userData, (uint256, address));
            IERC721(cgt).safeTransferFrom(address(this), to, id);
        }
    }

    function initialize(
        address _cgt,
        address _erc777,
        address _vault
    ) public {
        cgt = _cgt;
        erc777 = _erc777;
        vault = _vault;
        _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
        __ERC721Holder_init();
        __Ownable_init();
    }

    function wrap(uint256 _tokenId, address _to) public returns (bool) {
        IERC721(cgt).safeTransferFrom(_msgSender(), address(this), _tokenId);
        if (IERC20(erc777).balanceOf(address(this)) < minTokenAmountToPegIn) {
            IERC20(erc777).safeTransferFrom(_msgSender(), address(this), minTokenAmountToPegIn);
        }
        bytes memory data = abi.encode(_tokenId, _to);
        IERC20(erc777).safeApprove(vault, minTokenAmountToPegIn);
        IPERC20Vault(vault).pegIn(minTokenAmountToPegIn, erc777, Utils.toAsciiString(chainGuardiansPortalsHost), data);
        emit Minted(_tokenId, _to);
        return true;
    }
}
