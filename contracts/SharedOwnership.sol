pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";


/// @title Shared Ownership
/// @author Mathieu Lecoq
/// @notice Allows multiple addresses to share ownership of the contract
/// owners are able to transfer their ownership and renounce to it
contract SharedOwnership is Context {

    /// @dev Storage of MADE token owners
    address[] internal owners;

    /// @dev Storage ownership transfers, current_owner => future_owner => relinquishment_token 
    mapping(address => mapping(address => bytes32)) internal relinquishmentTokens;

    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor(address[] memory _owners) {
        owners = _owners;
    }

    /// @dev forbidden zero address check
    modifier validAddress(address addr) {
        require(addr != address(0), 'invalid address');
        _;
    }

    /// @dev owner right check
    modifier onlyOwner() {
        require(isOwner(_msgSender()), 'access denied');
        _;
    }

    /// @dev check if an address is one of the owners
    function isOwner(address addr) public view returns(bool isOwnerAddr) {
        for (uint i = 0; i < owners.length; i++) {
            if (address(owners[i]) == address(addr)) 
            isOwnerAddr = true;
        }
    }

    /// @dev internally add a new owner to `owners`
    function addOwner(address _owner) internal validAddress(_owner) {
        owners.push(_owner);
    }

    /// @dev internally remove an owner from `owners`
    function removeOwner(address _owner) internal validAddress(_owner) {
        require(isOwner(_owner), 'address is not an owner');

        uint afterLength = (owners.length - 1);

        for (uint ownerIndex = 0; ownerIndex < owners.length; ownerIndex++) {
            if (address(owners[ownerIndex]) == address(_owner)) {
                if (ownerIndex >= owners.length) return;

                for (uint i = ownerIndex; i < owners.length-1; i++){
                    owners[i] = owners[i+1];
                }

                owners.pop();
            }
        }

        require(owners.length == afterLength, 'owner can not be removed');

    }


    /// @dev Allows any current owner to relinquish its part of control over the contract
    /// @notice the calling contract owner must call this method to get the `relinquishmentToken` 
    /// prior calling `renounceOwnership` method and definitively loose his ownership
    /// @param _newOwner address of the futur new owner
    /// @return _relinquishmentToken bytes32 ownership transfer key for msg.sender => _newOwner
    function preTransferOwnership(address _newOwner) public onlyOwner returns(bytes32 _relinquishmentToken) {
        address stillOwner = _msgSender();
        uint salt = uint(keccak256(abi.encodePacked(block.timestamp, stillOwner)));
        bytes32 _rToken = bytes32(salt);
        relinquishmentTokens[stillOwner][_newOwner] = _rToken;
        _relinquishmentToken = _rToken;
    }

    /// @dev Retrieve the ownership transfer key preset by a current owner to a new owner
    /// preTransferOwnership method must be called prior to calling this method
    function getRelinquishmentToken(address _newOwner) public onlyOwner view returns (bytes32 _rToken) {
        _rToken = relinquishmentTokens[_msgSender()][_newOwner];
    }

    /// IRREVERSIBLE ACTION
    /// @dev Allows any current owner to definitively and safely relinquish its part of control over the contract to a new address
    function transferOwnership(bytes32 _relinquishmentToken, address _newOwner) public onlyOwner {
        address previousOwner = _msgSender();
        bytes32 rToken = relinquishmentTokens[previousOwner][_newOwner];
        
        // make sure provided _relinquishmentToken matchs sender storage for _newOwner
        require(
            ((rToken != bytes32(0)) && (rToken == _relinquishmentToken)), 
            'denied : a relinquishment token must be pre-set calling the preTransferOwnership method'
        );

        // transfer contract ownership
        removeOwner(previousOwner);
        addOwner(_newOwner);

        // remove relinquishment token from storage
        relinquishmentTokens[previousOwner][_newOwner] = bytes32(0);

        emit OwnershipTransferred(previousOwner, _newOwner);

    }


    
    
}