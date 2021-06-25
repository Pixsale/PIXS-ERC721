pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import './SharedOwnership.sol';


abstract contract OpenSeaERC721Metadatas is ERC721, SharedOwnership {
    using Strings for string;

    string _baseTokenURI;

    event BaseTokenUriUpdated(string uri); 

    /**
     * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     */
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }

    function strConcat(string memory _a, string memory _b) internal pure returns (string memory) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory ab = new string(_ba.length + _bb.length);
        bytes memory ba = bytes(ab);
        uint k = 0;

        for (uint i = 0; i < _ba.length; i++) ba[k++] = _ba[i];
        for (uint i = 0; i < _bb.length; i++) ba[k++] = _bb[i];
        
        return string(ba);
    }

    function _baseURI() internal override view returns (string memory) {
        return _baseTokenURI;
    }
    
    /**
    * @dev Retrieve all NFTs base token uri 
    */
    function baseTokenURI() public view returns (string memory) {
        return _baseURI();
    }

    /**
    * @dev Set the base token uri for all NFTs
    */
    function setBaseTokenURI(string memory uri) public onlyOwner {
        _baseTokenURI = uri;
        emit BaseTokenUriUpdated(uri);
    }

    /**
    * @dev Retrieve the uri of a specific token 
    * @param _tokenId the id of the token to retrieve the uri of
    * @return computed uri string pointing to a specific _tokenId
    */
    function tokenURI(uint256 _tokenId) public override view returns (string memory) {
        return strConcat(
            baseTokenURI(),
            Strings.toString(_tokenId)
        );
    }

    

}