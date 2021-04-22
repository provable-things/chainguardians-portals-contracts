//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "@openzeppelin/contracts-upgradeable/token/ERC777/IERC777RecipientUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./lib/Utils.sol";
import "./interfaces/IPToken.sol";


contract ChainGuardiansPortalsHost is ERC721Upgradeable, IERC777RecipientUpgradeable, OwnableUpgradeable {
    IERC1820Registry private _erc1820;
    bytes32 private constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    address public pToken;
    address public chainGuardiansPortalsNative;

    event Burned(uint256 id, address to);
    event ChainGuardiansPortalsNativeChanged(address chainGuardiansPortalsNative);
    event PtokenChanged(address pToken);

    function setChainGuardiansPortalsNative(address _chainGuardiansPortalsNative) external onlyOwner {
        chainGuardiansPortalsNative = _chainGuardiansPortalsNative;
        emit ChainGuardiansPortalsNativeChanged(chainGuardiansPortalsNative);
    }

    function setPtoken(address _pToken) external onlyOwner {
        pToken = _pToken;
        emit PtokenChanged(pToken);
    }

    function setBaseURI(string memory _baseUri) external onlyOwner {
        _setBaseURI(_baseUri);
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
        if (_from == address(0) && _msgSender() == pToken) {
            (, bytes memory userData, , address originatingAddress) = abi.decode(_userData, (bytes1, bytes, bytes4, address));
            require(originatingAddress == chainGuardiansPortalsNative, "ChainGuardiansPortalsHost: Invalid originating address");
            (uint256 id, address to) = abi.decode(userData, (uint256, address));
            _mint(to, id);
        }
    }

    function initialize(
        address _pToken,
        string memory _name,
        string memory _symbol,
        string memory _baseUri
    ) public {
        pToken = _pToken;
        _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
        __Ownable_init();
        __ERC721_init(_name, _symbol);
        _setBaseURI(_baseUri);
    }

    function unwrap(uint256 _tokenId, address _to) public returns (bool) {
        require(ownerOf(_tokenId) == msg.sender, "ChainGuardiansPortalsHost:impossible to burn a token you don't own");
        _burn(_tokenId);
        bytes memory data = abi.encode(_tokenId, _to);
        IPToken(pToken).redeem(0, data, Utils.toAsciiString(chainGuardiansPortalsNative));
        emit Burned(_tokenId, _to);
        return true;
    }
}
