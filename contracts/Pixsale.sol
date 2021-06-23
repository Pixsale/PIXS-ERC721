// SPDX-License-Identifier : GPL-v3-only
pragma solidity ^0.8.0;

import "./PIXSMarket.sol";

/**                 
 *      ▌ ▘ ▀ ▗ ▜    ▐    ▀       ▀    ▀ ▀▀▀ ▀ ▀        ▀       ▒           ▀ ▀ ▘▀ ▀ 
 *      ▀       ▓          ▀     ▀     ▒              ▀   ▚     ▀           ▓
 *      ▙ ▀ ▀▝▐ ▀    ▀       ▚ ▞       ▖ ▀ ▝ ▀ ▚    ▞      ▀    ░           ▀ ▂ ▂ ▂         
 *      ▀            ▀       ▞ ▚               ▀    ▀ ▀ ▔ ▀ ▟   ▆           ▀▝▝ ▀ ▀  
 *      ▀            ▓      ▀   ▀              ▀    ░       ▀   ▀           ▀
 *      ░            ▀    ▘       ▚    ▘ ▀ ▀ ▀▀▀    ▟       ▀   ▆ ▍▀▀ ▀ ▘   ▙ ▀ ▀ ▀ ▞ 
 *                                                          ▔
 *      VISIT HTTPS://PIXSALE.IO
 *      JOIN THE MAP !
 *             
 * @title Pixsale
 * @author Mathieu L
 * @dev Established on JUNE 23rd, 2021    
 * @dev Deployed with solc version 0.8.4
 * @dev Contact us at go@pixsale.io                                  
*/
contract Pixsale is PIXSMarket {
    using Address for address payable;

    /// @notice PIXS token properties
    struct PIXS {
        /// @dev address of owner
        address owner; 
        /// @dev total number of pixels used
        uint pixels;
        /// @dev position of the image fetched at `link` : left, top, right, bottom
        uint[] coords;       
        /// @dev url address pointing to an image
        string image;
        /// @dev url pointing to a website
        string link;
        /// @dev title and description 
        /// @notice format must contains a coma(,) 
        /// ex.:  My Project, catch phrase for my project
        string titledDescription;
    }

    /// @notice Token ids counter
    uint internal lastTokenId;

    /// @notice Date of birth of the smart-contract
    uint public birthTime;

    /// @notice Minimum pixel amount to purchase
    /// @dev PIXS tokens minimum pixels amount must be greater or equal 5px
    /// @dev value is immutable and can not be changed
    uint public immutable minimumPixelsAmount = 25;

    /// @notice Minimum pixel length
    /// @dev PIXS tokens widths and heights must be greater or equal 5px
    /// @dev value is immutable and can not be changed
    uint public immutable minimumPixelsLength = 5;
    
    /// @notice Total supply of available pixels
    uint public totalPixels = 8294400;
    
    /// @notice BNB price 0.0015 BNB / pixel
    uint public immutable pixelPrice = 1500000000000000;

    /// @notice Total Reflection to distribute among all holders prorata to the ratio totalPixels / balance
    uint public totalReflection;

    /// @dev TODO : Allow com wallet to withdraw in totalCom
    /// @notice Total received value dedicated to communication / marketing 
    uint public totalCom;

    /// @notice Total that has been withdrawn by marketing partner
    uint public totalComWithdrawn;

    /// @notice Total received value dedicated to final auction of the artwork
    uint public totalAuction;

    /// @notice Total that has been withdrawn from auction part
    uint public totalAuctionWithdrawn;

    /// @notice Total amount of pixels reserved to team members
    uint public teamPixelsSupply;

    /// @notice Total amount of pixels owners have gaveaway
    uint public totalPixelsGaveway;

    /// @notice Reflection release date
    uint public reflectionReleaseTimestamp;

    /// @notice Communication / Marketing partner wallet
    address public comWallet;

    /// @notice Track reflection withdraws
    /// @dev tokenId => boolean
    mapping (uint => bool) public reflectionWithdrawn;

    /// @notice Total number of pixels held from a giveaway
    mapping(address => uint) public pixelsBalance;

    /// @notice Signature for agreement between owners to abandon the project and release the reflection
    /// @dev Settable from one year after contract deployment
    mapping (address => bool) internal abandonOwnersSignatures;

    /// @notice all PIXS tokens
    PIXS[] public pixs;


    event Refunded(address indexed orderer, uint refundAmount);
    event ReflectionIsReleased();

    /// @dev Pixsale construction
    /// @param _owners : array of 2 addresses for shared ownership
    constructor(address[] memory _owners) PIXSMarket(_owners) {

        // reserve team pixels part
        teamPixelsSupply = 294400;

        birthTime = block.timestamp;
    }

    modifier reflectionIsReleased() {
        require(
            reflectionReleased(),
            'reflection must be released'
        );
        _;
    }

    function setComWallet(address _comAccount) public onlyOwner {
        comWallet = _comAccount;
    }

    function totalComAvailable() public view returns(uint ttlComAvail) {
        ttlComAvail = totalCom - totalComWithdrawn;
    }

    /// @notice Allow owners to withdraw the allocation of 1% dedicated to final artwork auction
    /// @notice funds are handled by owners in order to be able to pay the chosen art gallery with fiat
    function auctionWithdraw() public onlyOwner reflectionIsReleased {
        uint availableAuctionPart = totalAuction - totalAuctionWithdrawn;
        require(availableAuctionPart > 0, 'currently there is no available funds dedicated to final auction');

        totalAuctionWithdrawn += availableAuctionPart;
        payable(_msgSender()).sendValue(availableAuctionPart);
    }

    /// @notice Allow marketing/com partner to withdraw its allocation of 5%
    function comPartnerWithdraw(uint _amount) public {
        address sender = _msgSender();
        require(address(sender) == address(comWallet), 'reserved to marketing partner');
        require(_amount <= totalComAvailable(), 'not enough funds available for marketing');

        totalComWithdrawn += _amount;
        payable(address(comWallet)).sendValue(_amount);

    }

    function availableGivewayPixels() public view returns(uint aGiveawayPixels) {
        aGiveawayPixels = (teamPixelsSupply - totalPixelsGaveway);
    }

    /// @dev Transfer pixels from owner
    function _giveawayPixelsFromOwner(uint amount, address account) internal returns(bool trfFromOwner) {

        require(
            amount <= availableGivewayPixels(), 
            'pixels transfer from owner denied : owner pixels balance too low'
        );

        totalPixelsGaveway += amount;
        pixelsBalance[account] += amount;
        
        return true;
    }

    /// @dev Transfer pixels for non-owners
    function _transferPixels(uint amount, address account) internal returns(bool pixelsTrf) {
        address sender = _msgSender();
        
        require(pixelsBalance[sender] >= amount, 'pixels transfer denied : pixels balance too low');
        
        pixelsBalance[sender] -= amount;
        pixelsBalance[account] += amount;

        return true;
    }

    /// @dev Pixels holders can transfer pixels
    function transferPixels(uint amount, address account) public {
        

        // transfer pixels
        bool trf = isOwner(_msgSender())
        ? _giveawayPixelsFromOwner(amount, account)
        : _transferPixels(amount, account);

        require(trf, 'pixels transfer failed');
    }
    
    /// @dev Get the next available tokenId
    function nextId() internal view returns(uint nId) {
        nId = lastTokenId + 1;
    }

    /// @dev Get a fraction of a number from a percentage value (0-100)
    function fraction(uint amount, uint _percentage) internal pure returns(uint per) {
        require(_percentage < 100, 'bad fraction percentage');
        per = (amount / 100) * _percentage;
    }

    /// @dev Get one PIXS token from its id
    function getPixs(uint tokenId) public view returns(PIXS memory _pixs) {
        _pixs = pixs[tokenId-1];
    }

    /// @dev Get the total supply of PIXS NFT tokens
    function totalSupply() public view returns(uint tSupply) {
        tSupply = pixs.length;
    } 

    /// @dev Get the total number of PIXS token that have been sold / consumed
    function soldPixels() public view returns(uint totalPixelsSold) {
        uint totalSold;
        for (uint i = 0; i < pixs.length; i++) {
            // PIXS memory _pixs = pixs[i];
            totalSold += pixs[i].pixels;
        }
        totalPixelsSold = totalSold;
    }

    function availablePixels() public view returns(uint totalPixelsAvailable) {
        totalPixelsAvailable = totalPixels - teamPixelsSupply - soldPixels();
    }

    /// @dev Check that the number of `_pixels` equals the number of pixels computed from `_coords` values
    function consistentCoords(uint _pixels, uint[] memory _coords) internal pure {
        uint pixels = (
            (_coords[2] - _coords[0])
            * (_coords[3] - _coords[1])
        );

        require(pixels == _pixels, 'denied : coordinates pixels count must be equal to ordered pixels amount');

        // check that minimum amount of pixels is respected
        require(_pixels >= minimumPixelsAmount, 'minimum pixels amount to purchase must be greater or equal 25');
        // check that minimum amount of pixels on each length respects the preset `minimumPixelsLength`
        require(
            (
                ((_coords[2] - _coords[0]) >= minimumPixelsLength)
                && ((_coords[3] - _coords[1]) >= minimumPixelsLength)
            ),
            'denied : minimum coordinates length must be 5px'
        );
    }

    /// @dev Check pixels superposition with existing PIXS occupied space 
    function mapConflict(uint[] memory _coords) internal view {
        uint l = _coords[0]; 
        uint t = _coords[1]; 
        uint r = _coords[2]; 
        uint b = _coords[3];

        uint _limit = 5;

        // look for 4K map borders overflow (3840 x 2160 pixels) and check that space from nearest boundary is min 5 or 0
        require(
            (
                ((l == 0) || (l >= _limit)) 
                && ((t == 0) || (t >= _limit)) 
                && (
                    r >= _limit
                    && ((r == 3840) || (r <= (3840-_limit)))
                )
                && (
                    b >= _limit
                    && ((b == 2160) || (b <= (2160-_limit)))
                )
            ),
            'map borders overflow or not enough space of 5px'
        );

        // check that there is no conflict with existing coordinates
        uint i;
        for (i = 0; i < pixs.length; i++) {

            // PIXS memory _pixs = pixs[i];
            uint[] memory eCoords = pixs[i].coords;

            bool isOnLimit = (
                (l == (eCoords[2]-_limit)) 
                || (r == (eCoords[0]+_limit))
                || (t == (eCoords[3]-_limit))
                || (b == (eCoords[1]+_limit))
            );
            
            // check conflict on X axis
            bool xConflict = (
                (
                    isOnLimit 
                    ? false
                    : (
                        // L: left, R: right, n: new, e: existing
                        // nL < eL && nR > eL 
                        ((l < eCoords[0]) && (r > eCoords[0]))
                        // nR > eL && nL < eR
                        || ((r > eCoords[0]) && (l < eCoords[2]))     
                    )
                )
               
            );
            
            /// example :
            // EXISTING:       L    T   R    B
            //              [ 10, 20, 110, 120 ]
            // new:            l    t    r    b
            //              [ 10, 120, 110, 220 ]
            if (xConflict) {
                // and conflict on Y 
                bool yConflict = (
                    // T: top, B: bottom, n: new, e: existing
                    //     nT > eT && nB < eB
                    ((t > eCoords[1]) && ((b < eCoords[3])))
                    //  || nB > eT && nT < eB
                    || ((b > eCoords[1]) && (t < eCoords[3]))
                );

                require(!yConflict, 'denied : pixels position conflict');
            }
        }
    }

    /// @dev Spread NFT value according to the rules
    /// @notice Distribution is organised as follow :
    /// - 30% to owner 1
    /// - 30% to owner 2
    /// - 5% to com
    /// - 1% to final auction
    /// - 34% to total reflection distributed among holders according to Pixsale reflection rules (dont 4% pour la reflection influenceurs (giveway pixels))
    function spreadEthValue(uint _value) internal returns (bool trfok) {
        require(thisBalance() >= _value, 'contract balance too low to spread');

        uint onePerc = fraction(_value, 1);

        // to owners
        for (uint i = 0; i < 2; i++) {
            // to contract balance : use ownersWithdraw
            payable(address(owners[i])).sendValue((onePerc * 30));
        }

        // to reflection
        totalReflection += (onePerc * 34);

        // to com
        totalCom += (onePerc * 5);

        // to final auction
        totalAuction += onePerc;

        return true;

    }

    /// @notice mint a new PIXS NFT from ETH
    /// @dev consumes pixels from `totalPixels`
    /// @param _pixelsAmount is the amount of pixels sender wants to purchase
    /// @param _coords is an array of coordinates indicating where the pixels will be positioned on the map at https://pixsale.io
    /// @param _image is the url pointing to an image chosen by sender / owner
    /// @param _link is the url where users will be redirected when clicking on the to be consumed pixels
    /// @param _titledDescription is the text data associated with the PIXS token. it is formated this way :
    ///     title,(comma)description
    ///     ex. My Old Cars Project, collection cars dealer in Bruxelles, Belgium
    /// @param _owner address of the new created NFT holder/owner
    function _mintTo(
        uint _pixelsAmount, 
        uint[] memory _coords, 
        string memory _image, 
        string memory _link, 
        string memory _titledDescription, 
        address _owner
    ) internal validAddress(_owner) returns (uint _pixsId) {
        // check that there is enought available pixels
        // ISSUE HERE : ununsed giveway pixels will be locked after reflection release
        

        // check that _coords respects the number of requested pixels
        consistentCoords(_pixelsAmount, _coords);
        
        // check that space for `_coords` is available
        mapConflict(_coords);

        // check than sender has transferred enough value
        uint heldPixelsValue = pixelsBalance[_owner] * pixelPrice;

        uint purchaseEthPrice = pixelPrice * _pixelsAmount;

        uint priceToPay = (
            (heldPixelsValue >= purchaseEthPrice)
            ? 0
            : purchaseEthPrice - heldPixelsValue
        );

        require(
            (
                priceToPay > 0
                ? (
                    (priceToPay / pixelPrice) <= availablePixels()
                )
                : availablePixels() >= 25
            ),
            'Pixels sold out'
        );
        
        require(msg.value >= priceToPay, 'transferred eth value is too low to receive request amount of pixels');
       
        uint giveawayPixelsCost = (
            ((purchaseEthPrice - priceToPay) > 0)   // has pixels
            ? (
                // how many giveway pixels _owner will consume 
                (purchaseEthPrice - priceToPay) / pixelPrice
            )
            : 0
        );

        if (giveawayPixelsCost > 0) {
            // consume pixels
            pixelsBalance[_owner] -= giveawayPixelsCost;
        }

        PIXS memory _pixs = PIXS(_owner, _pixelsAmount, _coords, _image, _link, _titledDescription);

        if (spreadEthValue(priceToPay)) {

            uint tokenId = nextId();

            _mint(_owner, tokenId);

            // add to PIXS
            pixs.push(_pixs);

            // increment token ids
            lastTokenId++;

            // optionally refund 
            uint refund = msg.value - priceToPay;

            if (refund > 0) {
                payable(_msgSender()).transfer(refund);
                emit Refunded(_msgSender(), refund);
            }
            
            // release reflection
            if (allPixelsSold()) {
                releaseReflection();
            }

            // return the new created token id
            return(tokenId);
        }
    }

    /// @notice mint PIXS Pixsale NFT token to sender
    /// @dev see `_mintTo`
    function mint(
        uint _pixelsAmount, 
        uint[] memory _coords, 
        string memory _image, 
        string memory _link, 
        string memory _titledDescription
    ) public payable returns (uint pixsId) { 
        return _mintTo(_pixelsAmount, _coords, _image, _link, _titledDescription, _msgSender());
    }

    /// @notice mint PIXS Pixsale NFT token to a specific `owner` address
    /// @notice if any refund occurs, value goes back to sender (msg.sender) 
    /// @dev see `_mintTo`
    function mintTo(
        uint _pixelsAmount, 
        uint[] memory _coords, 
        string memory _image, 
        string memory _link, 
        string memory _titledDescription, 
        address _owner
    ) public payable returns (uint pixsIdTo) { 
        return _mintTo(_pixelsAmount, _coords, _image, _link, _titledDescription, _owner);
    }

    /// @dev Get the ether balance of the contract itself
    function thisBalance() public view returns(uint balance) {
        balance = payable(address(this)).balance;
    }

    /// @dev Get the total amount of pixels used by all PIXS tokens of an holder
    function pixelsOf(address _holder) public view returns (uint ownerPixels) {
        uint tPixs;

        for (uint i = 0; i < pixs.length; i++) {

            if (address(pixs[i].owner) == address(_holder)) {
                tPixs += pixs[i].pixels;
            }
        }

        ownerPixels = tPixs;
    }

    /// @dev Know weither or not holders can withdraw their part on total reflection 
    /// and owners can spend the allocation for the final artwork auction sale organization
    /// @dev Remaining space on `The Map` must be low enough not to be able to mint a new PIXS
    /// or project must have been abandoned by both owners
    function reflectionReleased() public view returns(bool released) {
        released = (
            allPixelsSold()
            || (reflectionReleaseTimestamp > 0)
        );
    }

    /// @notice Returns weither or not all pixels have been sold
    /// @dev minimum PIXS surface in pixels is 25
    function allPixelsSold() public view returns(bool noMorePixels) {
        noMorePixels = availablePixels() < 25;
    }

    /// @dev Get the reflection ether amount that an address is or will be able to withdraw 
    /// once 99.9997% of the pixels supply have been consumed
    function reflectionBalanceOf(address _holder) public view returns(uint rAmount) {
        return computeReflection(_holder);
    }

    /// @dev Returns the total prorata on total reflection for all PIXS
    function pixsProratas() internal view returns(uint totalProratas) {
        uint tPixs = pixs.length;
        uint _totalProratas;

        for (uint i = 0; i < tPixs; i++) {
            uint totalHoldersAfter = tPixs - i;
            uint prorata = (pixs[i].pixels * pixelPrice) * totalHoldersAfter;

            _totalProratas += prorata;
        }

        return _totalProratas;
    }

    /// @dev Simulate reflection calculation from pixels amount and tokenId (aka `position`)
    function simulateReflection(uint pixels, uint position) public view returns(uint pixelsReflection) {
        uint tPixs = pixs.length;
        uint multip = 1e18;
        uint totalHoldersAfter = tPixs - position;
        uint inflatedProrata = pixels * pixelPrice * totalHoldersAfter * multip;
        uint inflatedCoef = inflatedProrata / pixsProratas();
        
        return( (inflatedCoef * totalReflection) / multip );
    }

    /// @dev Compute reflection of a single token
    function tokenReflection(uint _tokenId) public view returns(uint tReflection) {
        if (reflectionWithdrawn[_tokenId]) 
            return 0;
        else {
            return simulateReflection(pixs[_tokenId-1].pixels, _tokenId-1);
        }
    }


    /// @dev Computes the reflection amount of a PIXS holder according to Pixsale reflection policy
    /// @notice Token with already withdrawn reflection are excluded from addition
    function computeReflection(address _holder) internal view returns(uint holderTotalReflectionBalance) {

        uint tPixs = pixs.length;
        uint multip = 1e18; 
        uint holderTotalRef = 0;

        uint totalProratas = pixsProratas();

        for (uint i = 0; i < tPixs; i++) {
            uint tokenId = i+1;
            
            if ((address(pixs[i].owner) == address(_holder)) && !reflectionWithdrawn[tokenId]) {
                uint totalHoldersAfter = tPixs - i;
                uint inflatedProrata = pixs[i].pixels * pixelPrice * totalHoldersAfter * multip;
                uint inflatedCoef = inflatedProrata / totalProratas;
                
                holderTotalRef += ( (inflatedCoef * totalReflection) / multip );

            }
        }

        return holderTotalRef;
            
    }

    /// @dev Computes the reflection tokens and 
    function setReflectionWithrawnForTokensOf(address _holder) internal returns(uint balCheck, uint pixelsCheck) {
        uint hBalanceCheck = 0;
        uint hPixelsCheck = 0;

        for (uint i = 0; i < pixs.length; i++) {
            uint tokenId = i+1;

            if ((address(pixs[i].owner) == address(_holder)) && !reflectionWithdrawn[tokenId]) {
               
                reflectionWithdrawn[tokenId] = true;
                hBalanceCheck += 1;
                hPixelsCheck += pixs[i].pixels;
            }

        }

        return(hBalanceCheck, hPixelsCheck);
        
    }
    
   
    /// @dev Allow holders to withdraw their part of the reflection after all pixels have been consumed
    function holdersReflectionWithdraw() public reflectionIsReleased nonReentrant {

        address sender = _msgSender();
        uint reflectionPart = computeReflection(sender);

        uint pixelsOfSender = pixelsOf(sender);
        uint balanceOfSender = balanceOf(sender);

        require(reflectionPart > 0, 'denied : no reflection allowance');

        (uint balCheck, uint pixelsCheck) = setReflectionWithrawnForTokensOf(sender);

        require(
            (
                (pixelsCheck >= 5) 
                && (pixelsCheck <= pixelsOfSender)
            ), 
            'cant withdraw more than held pixels'
        );
        require(
            (
                (balCheck >= 1)
                && (balCheck <= balanceOfSender)
            ),
            'PIXS tokens must be owned to withdraw reflection'
        );

        payable(address(sender)).sendValue(reflectionPart);

    }

    
    /// @dev Avoid locked BNB after reflection in the case of holders that did not withdraw within one year after the release of the reflection
    function ownersWithdrawOneYearAfterRelease() public onlyOwner reflectionIsReleased {
        uint oneYear = 31536000;
        if (block.timestamp >= (reflectionReleaseTimestamp + oneYear)) {

            uint ownerPart = thisBalance() / 2;

            // totalOwnersWithdrawn += 50 * 2
            for (uint i = 0; i < 2; i++) {
                payable(address(owners[i])).sendValue(ownerPart);
            }
        }
    }

    function releaseReflection() internal {
        reflectionReleaseTimestamp = block.timestamp;
        emit ReflectionIsReleased();
    }

    /// @dev Allow owners to abandon the project and release reflection 
    /// one year after Pixsale start time
    /// This feature avoid locking funds within the smart-contract
    /// @notice Pixels sale and PIXS minting will be definitely finished
    /// @notice Reflection will be released for all PIXS holders
    function signProjectAbandonAndReflectionRelease() public onlyOwner {
        uint oneYear = 31536000;
        require(block.timestamp >= (birthTime + oneYear), 'abandon is possible after one year of contract existence from deployment time');
        
        address sender = _msgSender();
        address otherOwner = (
            address(sender) == address(owners[0])
            ? owners[1]
            : owners[0]
        );

        // other owner has signed the agreement : release
        if (abandonOwnersSignatures[otherOwner]) {

            releaseReflection();
        } 
        // sign the agreement, wait other signature
        else {
            abandonOwnersSignatures[sender] = true;
        }
    }


    /// @notice Unsign pre-signed agreement to abandon Pixsale project by an owner
    function unsignProjectAbandonAndReflectionRelease() public onlyOwner{
        abandonOwnersSignatures[_msgSender()] = false;
    }


    /* PIXS INTEGRATED MARKET PUBLIC BUY */

    /// @dev Internal transfer for existing PIXS tokens
    function internalTransfer(address tOwner, uint tokenId, address receiver) 
    validAddress(receiver) internal returns(bool transferred) {
                
        if (address(pixs[tokenId-1].owner) == address(tOwner)) {
            pixs[tokenId-1].owner = receiver;
        }
    
        _transfer(tOwner, receiver, tokenId);

        return true;
        
    }


    /// @dev Allow users to buy PIXS tokens if on sale
    function buy(uint _tokenId) public payable nonReentrant {
        address buyer = _msgSender();
        address seller = ownerOf(_tokenId);

        require(seller != buyer, 'cant buy to self');

        uint tokenPrice = _getTokenPrice(_tokenId, seller, buyer);

        require(
            tokenPrice > 0, 
            'PIXS must be on sale'
        );

        require(
            msg.value >= tokenPrice 
        );

        payable(address(seller)).sendValue(tokenPrice);
        
        // transfer and clear old owner approvals
        internalTransfer(seller, _tokenId, buyer);

        // remove from public sale
        salePrices[_tokenId] = 0;

    }

    /// @dev Public PIXS transfer method
    function transfer(uint tokenId, address receiver) public returns(bool transferred) {
        
        address tOwner = onlyOwnerOf(tokenId);

        return internalTransfer(tOwner, tokenId, receiver);

    }

    function sameString(string memory a, string memory b) internal pure returns(bool sameStr) {
        sameStr = (
            keccak256(abi.encodePacked(a)) 
            == keccak256(abi.encodePacked(b))
        );
    }

    /// @dev Edit owned token metadatas titledDescription, image and link
    /// @notice pass empty strings ("") as arguments to keep existing value
    function editPixsMetadatas(uint tokenId, string memory tDes, string memory image, string memory link) public {
        onlyOwnerOf(tokenId);
        
        string memory emptyString = "";

        uint pixsIndex = tokenId-1;

        if (!sameString(tDes, emptyString)) {
            pixs[pixsIndex].titledDescription = tDes;
        }
        if (!sameString(image, emptyString)) {
            pixs[pixsIndex].image = image;
        }
        if (!sameString(link, emptyString)) {
            pixs[pixsIndex].link = link;
        }

    }

  




 

}

