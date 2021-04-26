//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IChainGuardiansStorage.sol";


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

    function storeBulk(uint256[] calldata _tokenIds, uint256[] calldata _attributes) external override onlyOwner {
        uint256[] memory _componentIds;
        uint256 startIndex = allTokens.length;
        for (uint256 index = 0; index < _tokenIds.length; index++) {
            require(!exists(_tokenIds[index]));
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
        require(!exists(_tokenId));
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
