// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./OpenSeaERC721Metadatas.sol";

/**                        
 * @title PIXSMarket
 * @author Mathieu L
 * @dev Established on JUNE 23rd, 2021    
 * @dev Deployed with solc version 0.8.4
 * @dev Contact us at go@pixsale.io                                  
*/
contract PIXSMarket is OpenSeaERC721Metadatas, ReentrancyGuard {

    /// @notice token Id => sale price
    mapping (uint => uint) public salePrices;

    /// @notice token Id => owner => buyer => price
    mapping (uint => mapping(address => mapping(address => uint))) public privateSalePrices;

    /// @dev Event firing when an offer has been made by a user to buy a specific token at proposed price
    event IsOffering(uint indexed tokenId, address indexed offerer, uint amount);

    /// @dev Check that caller is owner of a spacific token
    function onlyOwnerOf(uint tokenId) internal view returns(address tokenOwner) {
        address tOwner = ownerOf(tokenId);
        require(address(tOwner) == address(_msgSender()), 'denied : token not owned');
        tokenOwner = tOwner;
    }

    constructor(address[] memory _owners) ERC721('Pixsale', 'PIXS') SharedOwnership(_owners) {}
    
    /// @dev Allows holders to sell their PIXS at chosen price to anyone
    function sell(uint _tokenId, uint _amount) public {
        onlyOwnerOf(_tokenId);
        salePrices[_tokenId] = _amount;
    }

    /// @dev Allows holders to sell their PIXS at chosen price to a specific address
    function privateSellTo(uint _tokenId, uint _amount, address _buyer) public {
        address tokenOwner = onlyOwnerOf(_tokenId);
        privateSalePrices[_tokenId][tokenOwner][_buyer] = _amount;
    }

    /// @dev Remove a token from public sale or remove a private buyer from approved private buyers
    /// @param _tokenId token Id to remove from sale OR to remove `_optBuyer` from sale
    /// @param _optBuyer *optional* if a valid buyer address is provided, 
    /// the buyer will be removed from allowedBuyers
    function removeFromSale(uint _tokenId, address _optBuyer) public {
        address tokenOwner = onlyOwnerOf(_tokenId);

        if (
            (address(_optBuyer) != address(0))
            && privateSalePrices[_tokenId][tokenOwner][_optBuyer] != 0
        ) {
            privateSalePrices[_tokenId][tokenOwner][_optBuyer] = 0;
        }
        else if(salePrices[_tokenId] != 0) {
            salePrices[_tokenId] = 0;
        }
    }

    function _getTokenPrice(uint _tokenId, address _tokenOwner, address _sender) internal view returns(uint tokenPrice) {

        uint pubSale = salePrices[_tokenId];
        uint privateSale = privateSalePrices[_tokenId][_tokenOwner][_sender];

        bool isPrivateSale = privateSale > 0;

        tokenPrice = (
            (isPrivateSale)
            ? privateSale
            : pubSale
        );
    }

    function getTokenPrice(uint _tokenId, address _sender) public view returns(uint tokenPrice) {
        address _tokenOwner = ownerOf(_tokenId);
        tokenPrice = _getTokenPrice(_tokenId, _tokenOwner, _sender);
    }

    // /// @dev Allow users to buy PIXS tokens if on sale
    // function buy(uint _tokenId) public payable nonReentrant {
    //     address sender = _msgSender();
    //     address tokenOwner = ownerOf(_tokenId);

    //     require(tokenOwner != sender, 'cant buy to self');

    //     uint tokenPrice = _getTokenPrice(_tokenId, tokenOwner, sender);

    //     require(
    //         tokenPrice > 0, 
    //         'PIXS must be on sale'
    //     );

    //     require(
    //         msg.value >= tokenPrice 
    //     );

    //     payable(address(tokenOwner)).sendValue(tokenPrice);
        
    //     // transfer and clear old owner approvals
    //     _transfer(tokenOwner, sender, _tokenId);

    //     // remove from public sale
    //     salePrices[_tokenId] = 0;

    // }



    /// @dev Allow users to propose a price for the purchase of a token that is or not for sale
    /// @param _tokenId Token targeted by sender
    /// @param _amount amount in MATIC that sender proposes to buy the token
    function makeOffer(uint _tokenId, uint _amount) external {
        emit IsOffering(_tokenId, _msgSender(), _amount);
    }




}