//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IChainGuardiansStorage {
    function storeBulk(uint256[] calldata _tokenIds, uint256[] calldata _attributes) external;

    function store(
        uint256 _tokenId,
        uint256 _attributes,
        uint256[] calldata _componentIds
    ) external;

    function remove(uint256 _tokenId) external;

    function list() external view returns (uint256[] memory tokenIds);

    function getAttributes(uint256 _tokenId) external view returns (uint256 attrs, uint256[] memory compIds);

    function updateAttributes(
        uint256 _tokenId,
        uint256 _attributes,
        uint256[] calldata _componentIds
    ) external;

    function totalSupply() external view returns (uint256);
}


contract ChainGuardiansStorage is Ownable, IChainGuardiansStorage {
    using SafeMath for uint256;

    struct Token {
        uint256 tokenId;
        uint256 attributes;
        uint256[] componentIds;
        uint256 index;
    }

    uint256[] internal allTokens;

    mapping(uint256 => Token) internal tokens;

    event Stored(uint256 tokenId, uint256 attributes, uint256[] componentIds);
    event Removed(uint256 tokenId);

    constructor() {}

    function storeBulk(uint256[] calldata _tokenIds, uint256[] calldata _attributes) external override onlyOwner {
        uint256[] memory _componentIds;
        uint256 startIndex = allTokens.length;
        for (uint256 index = 0; index < _tokenIds.length; index++) {
            require(!this.exists(_tokenIds[index]));
            allTokens.push(_tokenIds[index]);
            tokens[_tokenIds[index]] = Token(_tokenIds[index], _attributes[index], _componentIds, startIndex + index);
            emit Stored(_tokenIds[index], _attributes[index], _componentIds);
        }
    }

    function store(
        uint256 _tokenId,
        uint256 _attributes,
        uint256[] calldata _componentIds
    ) external override onlyOwner {
        //require(!this.exists(_tokenId));
        allTokens.push(_tokenId);
        tokens[_tokenId] = Token(_tokenId, _attributes, _componentIds, allTokens.length - 1);
        emit Stored(_tokenId, _attributes, _componentIds);
    }

    function remove(uint256 _tokenId) external override onlyOwner {
        require(_tokenId > 0);
        require(exists(_tokenId));

        uint256 doomedTokenIndex = tokens[_tokenId].index;

        delete tokens[_tokenId];

        uint256 lastTokenIndex = allTokens.length.sub(1);
        uint256 lastTokenId = allTokens[lastTokenIndex];

        tokens[lastTokenId].index = doomedTokenIndex;

        allTokens[doomedTokenIndex] = lastTokenId;
        allTokens[lastTokenIndex] = 0;

        allTokens.length.sub(1);
        emit Removed(_tokenId);
    }

    function list() external view override returns (uint256[] memory tokenIds) {
        return allTokens;
    }

    function getAttributes(uint256 _tokenId) external view override returns (uint256 attrs, uint256[] memory compIds) {
        require(exists(_tokenId));
        return (tokens[_tokenId].attributes, tokens[_tokenId].componentIds);
    }

    function updateAttributes(
        uint256 _tokenId,
        uint256 _attributes,
        uint256[] calldata _componentIds
    ) external override onlyOwner {
        require(exists(_tokenId));
        require(_attributes > 0);
        tokens[_tokenId].attributes = _attributes;
        tokens[_tokenId].componentIds = _componentIds;
        emit Stored(_tokenId, _attributes, _componentIds);
    }

    function totalSupply() external view override returns (uint256) {
        return allTokens.length;
    }

    function exists(uint256 _tokenId) public view returns (bool) {
        return tokens[_tokenId].tokenId == _tokenId;
    }
}


library Roles {
    struct Role {
        mapping(address => bool) bearer;
    }

    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}


contract MinterRole {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor() {
        _addMinter(msg.sender);
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender), "MinterRole: caller does not have the Minter role");
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function addMinter(address account) public onlyMinter {
        _addMinter(account);
    }

    function renounceMinter() public {
        _removeMinter(msg.sender);
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}


contract ChainGuardiansToken is ERC721, MinterRole, Ownable {
    using SafeMath for uint256;
    IChainGuardiansStorage internal cgStorage;
    string internal uriPrefix;

    mapping(uint256 => address) internal tokenOwner;

    mapping(address => uint256[]) internal ownedTokens;

    mapping(uint256 => uint256) internal ownedTokenIndexes;

    uint256[] internal transferableTokens;

    mapping(uint256 => uint256) internal transferableIndexes;

    constructor(address _storage, string memory _uriPrefix) ERC721("ChainGuardiansToken", "CGT") Ownable() {
        cgStorage = IChainGuardiansStorage(_storage);
        uriPrefix = _uriPrefix;
    }

    function bulk(
        uint256[] calldata _tokenIds,
        uint256[] calldata _attributes,
        address[] calldata _owners
    ) external onlyOwner {
        for (uint256 index = 0; index < _tokenIds.length; index++) {
            ownedTokens[_owners[index]].push(_tokenIds[index]);
            ownedTokenIndexes[_tokenIds[index]] = ownedTokens[_owners[index]].length;
            tokenOwner[_tokenIds[index]] = _owners[index];
            emit Transfer(address(0), _owners[index], _tokenIds[index]);
        }
        cgStorage.storeBulk(_tokenIds, _attributes);
    }

    function create(
        uint256 _tokenId,
        uint256 _attributes,
        uint256[] calldata _componentIds,
        address _owner
    ) external onlyOwner {
        require(_owner != address(0));
        require(_attributes > 0);
        super._mint(_owner, _tokenId);
        addTokenTo(_owner, _tokenId);
        cgStorage.store(_tokenId, _attributes, _componentIds);
    }

    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        return ownedTokens[_owner];
    }

    function getProperties(uint256 _tokenId) external view returns (uint256 attrs, uint256[] memory compIds) {
        return cgStorage.getAttributes(_tokenId);
    }

    function updateAttributes(
        uint256 _tokenId,
        uint256 _attributes,
        uint256[] calldata _componentIds
    ) external {
        // require(owner == msg.sender || isController(msg.sender)); // NOTE: keep commented just for testing
        cgStorage.updateAttributes(_tokenId, _attributes, _componentIds);
    }

    function updateStorage(address _storage) external onlyOwner {
        cgStorage = IChainGuardiansStorage(_storage);
    }

    function listTokens() external view returns (uint256[] memory tokens) {
        return cgStorage.list();
    }

    function setURI(string calldata _uriPrefix) external onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory responseTokenUri) {
        require(_exists(_tokenId), "tokenId does not exist");
        return strConcat(uriPrefix, uintToString(_tokenId));
    }

    function mint(address to, uint256 tokenId) public onlyMinter returns (bool) {
        _mint(to, tokenId);
        return true;
    }

    function isTransferable(uint256 _tokenId) public view returns (bool) {
        return (transferableIndexes[_tokenId] > 0);
    }

    function getOwnedTokenData(address _owner)
        public
        view
        returns (
            uint256[] memory tokens,
            uint256[] memory attrs,
            uint256[] memory componentIds,
            bool[] memory isTransferable_
        )
    {
        uint256[] memory tokenIds = this.tokensOfOwner(_owner);
        uint256[] memory attribs = new uint256[](tokenIds.length);
        uint256[] memory firstCompIds = new uint256[](tokenIds.length);
        bool[] memory transferable = new bool[](tokenIds.length);

        uint256[] memory compIds;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            (attribs[i], compIds) = cgStorage.getAttributes(tokenIds[i]);
            transferable[i] = this.isTransferable(tokenIds[i]);
            if (compIds.length > 0) {
                firstCompIds[i] = compIds[0];
            }
        }
        return (tokenIds, attribs, firstCompIds, transferable);
    }

    function totalSupply() public view override returns (uint256) {
        return cgStorage.totalSupply();
    }

    function addTokenTo(address _to, uint256 _tokenId) internal {
        require(tokenOwner[_tokenId] == address(0));
        tokenOwner[_tokenId] = _to;
        ownedTokens[_to].push(_tokenId);
        ownedTokenIndexes[_tokenId] = ownedTokens[_to].length;
    }

    function removeTokenFrom(address _from, uint256 _tokenId) internal {
        uint256 lastTokenIndex = ownedTokens[_from].length;
        require(lastTokenIndex > 0, "lastTokenIndex = 0");
        lastTokenIndex--;
        require(ownerOf(_tokenId) == _from, "removeTokenFrom");
        tokenOwner[_tokenId] = address(0);
        uint256 tokenIndex = ownedTokenIndexes[_tokenId].sub(1);
        uint256 lastTokenId = ownedTokens[_from][lastTokenIndex];
        ownedTokens[_from][tokenIndex] = lastTokenId;
        ownedTokenIndexes[lastTokenId] = tokenIndex.add(1);
        ownedTokens[_from][lastTokenIndex] = 0;
        ownedTokens[_from].length.sub(1);
    }

    function strConcat(string memory _a, string memory _b) internal pure returns (string memory) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory ab = new string(_ba.length + _bb.length);
        bytes memory ba = bytes(ab);
        uint256 k = 0;
        uint256 i;
        for (i = 0; i < _ba.length; i++) ba[k++] = _ba[i];
        for (i = 0; i < _bb.length; i++) ba[k++] = _bb[i];
        return string(ba);
    }

    function uintToString(uint256 v) internal pure returns (string memory str) {
        uint256 maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint256 i = 0;
        uint256 v2 = v;
        while (v2 != 0) {
            uint256 remainder = v2 % 10;
            v2 = v2 / 10;
            reversed[i++] = bytes1(48 + uint8(remainder));
        }
        bytes memory s = new bytes(i);
        for (uint256 j = 0; j < i; j++) {
            s[j] = reversed[i - 1 - j];
        }
        str = string(s);
    }
}
