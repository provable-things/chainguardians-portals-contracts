//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "@openzeppelin/contracts-upgradeable/token/ERC777/IERC777RecipientUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./lib/Utils.sol";
import "./interfaces/IPToken.sol";
import "./interfaces/IChainGuardiansStorage.sol";


contract ChainGuardiansPortalsHost is ERC721Upgradeable, IERC777RecipientUpgradeable, OwnableUpgradeable {
    IERC1820Registry private _erc1820;
    bytes32 private constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    IPToken public pToken;
    IChainGuardiansStorage public cgtStorage;
    address public chainGuardiansPortalsNative;

    event Unwrapped(uint256 tokenId, address to);
    event ChainGuardiansPortalsNativeChanged(address chainGuardiansPortalsNative);
    event PtokenChanged(address pToken);
    event CgtStorageChanged(address cgtStorage);

    function setChainGuardiansPortalsNative(address _chainGuardiansPortalsNative) external onlyOwner {
        chainGuardiansPortalsNative = _chainGuardiansPortalsNative;
        emit ChainGuardiansPortalsNativeChanged(chainGuardiansPortalsNative);
    }

    function setPtoken(address _pToken) external onlyOwner {
        pToken = IPToken(_pToken);
        emit PtokenChanged(_pToken);
    }

    function setBaseURI(string memory _baseUri) external onlyOwner {
        _setBaseURI(_baseUri);
    }

    function setCgtStorage(address _cgtStorage) external onlyOwner {
        cgtStorage = IChainGuardiansStorage(_cgtStorage);
        emit CgtStorageChanged(_cgtStorage);
    }

    /**
     *  @notice only pNetwork is able to mint pTokens so nobody else is able
     *          to call _mint because of _from == address(0) and the whitelisting
     *          of pToken
     *
     **/
    function tokensReceived(
        address, /*_operator*/
        address _from,
        address, /*_to,*/
        uint256, /*_amount*/
        bytes calldata _userData,
        bytes calldata /*_operatorData*/
    ) external override {
        if (_from == address(0) && _msgSender() == address(pToken)) {
            (, bytes memory userData, , address originatingAddress) = abi.decode(_userData, (bytes1, bytes, bytes4, address));
            require(originatingAddress == chainGuardiansPortalsNative, "ChainGuardiansPortalsHost: Invalid originating address");
            (uint256 tokenId, uint256 attrs, address to) = abi.decode(userData, (uint256, uint256, address));
            _mint(to, tokenId);
            cgtStorage.store(tokenId, attrs, new uint256[](0));
        }
    }

    function updateAttributes(
        uint256 _tokenId,
        uint256 _attributes,
        uint256[] calldata _componentIds
    ) external onlyOwner {
        cgtStorage.updateAttributes(_tokenId, _attributes, _componentIds);
    }

    function initialize(
        address _pToken,
        string memory _baseUri,
        address _cgtStorage
    ) public initializer {
        pToken = IPToken(_pToken);
        cgtStorage = IChainGuardiansStorage(_cgtStorage);
        _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
        __Ownable_init();
        __ERC721_init("ChainGuardiansToken", "CGT");
        _setBaseURI(_baseUri);
    }

    function unwrap(uint256 _tokenId, address _to) public returns (bool) {
        require(ownerOf(_tokenId) == msg.sender, "ChainGuardiansPortalsHost: impossible to burn a token you don't own");
        (uint256 attrs, ) = cgtStorage.getAttributes(_tokenId);
        bytes memory data = abi.encode(_tokenId, _to, attrs);
        cgtStorage.remove(_tokenId);
        _burn(_tokenId);
        pToken.redeem(0, data, Utils.toAsciiString(chainGuardiansPortalsNative));
        emit Unwrapped(_tokenId, _to);
        return true;
    }
}
