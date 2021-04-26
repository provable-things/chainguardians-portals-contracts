//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

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
