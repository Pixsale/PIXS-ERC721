require('chai').use(require('chai-as-promised')).should();
const EVMRevert = require('./helpers/VMExceptionRevert');
const timeMachine = require('ganache-time-traveler');

const Pixsale = artifacts.require('../contracts/Pixsale.sol');

const Web3 = require('web3');
let web3 = new Web3(Web3.givenProvider || "ws://localhost:8545");

const pixelsFromCoords = coords => (
	(coords[2] - coords[0]) * (coords[3] - coords[1])
);

const proxyRegistryAddress = '0x58807baD0B376efc12F5AD86aAc70E78ed67deaE';
const baseTokenUri = 'https://pixsale.herokuapp.com/token/';


contract('Pixsale', async(accounts) => {
	
	let pixsale;
	let snapshotId;

	const pixelPrice = (0.0015 * 1e18);
	const pixelsAmount = 10000; 			// 10 000 pixels
	const coords = [ 10, 20, 110, 120 ]; 	// 100x100 squared space possible
	// 			   [ 10, 120, 110, 220 ]	t < B
	const www = 'https://pixsale.io';
	const image = 'https://securise.io/static/media/logo.c5134e8c.png';
	const tDescription = 'Pixsale, Buy pixels, reach targets, sell space, get rewarded';

	const owner1 = accounts[0];
	const owner2 = accounts[1];
	const team = accounts[2];
	const user3 = accounts[3];
	const user2 = accounts[4];
	const user1 = accounts[5];
	const user4 = accounts[6];

	const constructorArgs = [
		[owner1, owner2],
		proxyRegistryAddress,
		baseTokenUri
	];

	const minter = async(l, t, r, b, from) => await pixsale.mint(
		pixelsFromCoords([l, t, r, b]),							
		[l, t, r, b],	
		www,
		image,
		tDescription,
		{ from, value: pixelPrice * pixelsFromCoords([l, t, r, b]) }
	);

	beforeEach(async () => {
		// record evm timer
		let snapshot = await timeMachine.takeSnapshot();
       	snapshotId = snapshot['result'];

		// set pixsale test contract
		pixsale = await Pixsale.new(
			...constructorArgs,
			{ from: owner1 }
		);

	});

	afterEach(async() => {
		await timeMachine.revertToSnapshot(snapshotId);
	});

	
	it('checks if contract implements interfaces right', async () => {
		const erc165 = '0x01ffc9a7';
		const erc721 = '0x80ac58cd';
		const erc721enumerable = '0x780e9d63';
		const erc721metadata = '0x5b5e139f';
		const wrongInterface = '0x5b5e139d';
		(await pixsale.supportsInterface(erc165)).toString().should.equal('true');
		(await pixsale.supportsInterface(erc721)).toString().should.equal('true');
		(await pixsale.supportsInterface(erc721enumerable)).toString().should.equal('false');
		(await pixsale.supportsInterface(erc721metadata)).toString().should.equal('true');
		(await pixsale.supportsInterface(wrongInterface)).toString().should.equal('false');
	});

	it('checks token details (name, symbol)', async () => {
		(await pixsale.name()).toString().should.equal('Pixsale');
		(await pixsale.symbol()).toString().should.equal('PIXS');
	});

	it('checks that an owner can transfer its ownership part of the contract (multiple possible owners)', async () => {
		const wrongToken = '0x51bb523c9f629b017f8fda6078e83480e968f648b6f6f2e3f94ef9daa13fb75f';
		(await pixsale.isOwner(owner1)).toString().should.equal('true');
		(await pixsale.isOwner(owner2)).toString().should.equal('true');
		(await pixsale.isOwner(user2)).toString().should.equal('false');
		(await pixsale.isOwner(team)).toString().should.equal('false');
		await pixsale.transferOwnership(wrongToken, user2, { from: owner1 }).should.be.rejectedWith(EVMRevert);
		await pixsale.transferOwnership(wrongToken, user2, { from: user1 }).should.be.rejectedWith(EVMRevert);
		await pixsale.preTransferOwnership(user2,{ from: user1 }).should.be.rejectedWith(EVMRevert);
		await pixsale.preTransferOwnership(user2,{ from: owner1 }).should.be.fulfilled;
		const rToken = await pixsale.getRelinquishmentToken(user2, { from: owner1 });
		await pixsale.transferOwnership(rToken, user2, { from: user1 }).should.be.rejectedWith(EVMRevert);
		await pixsale.transferOwnership(rToken, user2, { from: owner1 }).should.be.fulfilled;
		(await pixsale.isOwner(user2)).toString().should.equal('true');
		(await pixsale.isOwner(owner1)).toString().should.equal('false');
		(await pixsale.isOwner(owner2)).toString().should.equal('true');
		});

	it('checks that anyone can buy pixels minting PIXS token', async() => {
		
		await pixsale.mint(
			pixelsAmount,							
			coords,	
			image,
			www,
			tDescription,
			{ from: user1, value: pixelPrice * 10000 }
		).should.be.fulfilled;
		
		(await pixsale.balanceOf(user1)).toString().should.equal('1');
		(await pixsale.soldPixels()).toString().should.equal('10000');
		(await pixsale.totalSupply()).toString().should.equal('1');
		(await pixsale.pixelsOf(user1)).toString().should.equal(pixelsAmount.toString())
	})

	it('checks that token metadatas can be post-edited', async() => {
		await pixsale.mint(
			25,							
			[0, 0, 5, 5],	
			www,
			image,
			tDescription,
			{ from: user1, value: pixelPrice * 25 }
		).should.be.fulfilled;
		let pixs1 = (await pixsale.getPixs("1"));
		await pixsale.editPixsMetadatas(
			//tokenId
			'1', 
			// tDes
			'Edited, this pixs title has been edited',
			// image
			'',
			// link
			'',
			{ from: owner1 }
		).should.be.rejectedWith(EVMRevert);

		await pixsale.editPixsMetadatas(
			//tokenId
			'1', 
			// tDes
			'Edited, this pixs title has been edited',
			// image
			'',
			// link
			'',
			{ from: user1 }
		).should.be.fulfilled;
		let pixs1After = (await pixsale.getPixs("1"));
		(pixs1After.owner === pixs1.owner).toString().should.equal('true');
		(pixs1After.image === pixs1.image).toString().should.equal('true');
		(pixs1After.link === pixs1.link).toString().should.equal('true');
		(pixs1After.titledDescription === 'Edited, this pixs title has been edited').toString().should.equal('true');
		
	})

	it('checks that requesting a bad amount of pixels leads the transaction to fail', async() => {
		await pixsale.mint(
			pixelsAmount + 1,					// 10 000 pixels + unwanted 1				
			coords,	
			image,
			www,
			tDescription,
			{ from: user1, value: pixelPrice * (pixelsAmount+1) }
		).should.be.rejectedWith(EVMRevert);
	})

	it('checks that the transaction fails if the total amount of pixels computed from coords does not match the requested amount of pixels', async() => {
		await pixsale.mint(
			pixelsAmount,					// 10 000 pixels + unwanted 1				
			[10, 20, 110, 121],	
			www,
			image,
			tDescription,
			{ from: user1, value: pixelPrice * (pixelsAmount+1) }
		).should.be.rejectedWith(EVMRevert);
	})

	it('checks that sale amounts are distributed as planned and reflection occurs', async() => {
		/// @notice Distribution is organised as follow :
		/// - 34% to total reflection distributed among holders according to Pixsale reflection rules
		/// - 30% to owner 1
		/// - 30% to owner 2
		/// - 5% to com
		/// - 1% to final auction
		const preBalance1 = await Promise.resolve(parseInt((await web3.eth.getBalance(owner1)).toString()));
		const preBalance2 = await await Promise.resolve(parseInt((await web3.eth.getBalance(owner2)).toString()));
		const tReflection1 = await Promise.resolve(parseInt((await pixsale.totalReflection()).toString()));
		await pixsale.mint(
			pixelsAmount,							
			coords,	
			www,
			image,
			tDescription,
			{ from: user1, value: pixelPrice * pixelsFromCoords((coords)) }
		).should.be.fulfilled;
		const postBalance1_1 = await Promise.resolve(parseInt((await web3.eth.getBalance(owner1)).toString()));//await web3.eth.getBalance(owner1);
		const postBalance2_1 = await Promise.resolve(parseInt((await web3.eth.getBalance(owner2)).toString()));//await web3.eth.getBalance(owner2);
		const tReflection2 = await Promise.resolve(parseInt((await pixsale.totalReflection()).toString()));
		const pAmount = pixelsFromCoords([10, 120, 110, 220]);
		await pixsale.mint(
			pAmount,							
			[10, 121, 110, 221],
			www,
			image,
			tDescription,
			{ from: user2, value: pixelPrice * pAmount }
		).should.be.fulfilled;
		const postBalance1_2 = await Promise.resolve(parseInt((await web3.eth.getBalance(owner1)).toString()));
		const postBalance2_2 = await Promise.resolve(parseInt((await web3.eth.getBalance(owner2)).toString()));
		const tReflection3 = await Promise.resolve(parseInt((await pixsale.totalReflection()).toString()));
		(await Promise.resolve((postBalance1_1 > preBalance1) && (postBalance1_2 > postBalance1_1))).toString().should.equal('true');
		(await Promise.resolve((postBalance2_1 > preBalance2) && (postBalance2_2 > postBalance2_1))).toString().should.equal('true');
		(await Promise.resolve((tReflection2 > tReflection1) && (tReflection3 > tReflection2))).toString().should.equal('true');
		const comBalance = await Promise.resolve(parseInt((await pixsale.totalCom()).toString()));
		const finalAuctionBalance = await Promise.resolve(parseInt((await pixsale.totalAuction()).toString()));
		const finalBalance = await Promise.resolve(parseInt((await pixsale.thisBalance()).toString()));
		(await Promise.resolve(finalBalance == (tReflection3+comBalance+finalAuctionBalance))).toString().should.equal('true');
		const rBal1 = await Promise.resolve(parseInt((await pixsale.reflectionBalanceOf(user1)).toString()));
		const rBal2 = await Promise.resolve(parseInt((await pixsale.reflectionBalanceOf(user2)).toString()));
		const delta = (await Promise.resolve((tReflection3 - (rBal1+rBal2)) === 0)).toString();
		delta.should.equal('true');
	});


	it('checks that pixels can be traded and consumed to mint new PIXS', async() => {
		// owner giveaway pixels to user1
		await pixsale.transferPixels('100', user1, { from: user1 }).should.be.rejectedWith(EVMRevert);
		await pixsale.transferPixels('100', user1, { from: owner1 }).should.be.fulfilled;
		(await pixsale.pixelsBalance(user1)).toString().should.equal('100');

		// user1 transfer pixels to user2
		await pixsale.transferPixels('100', user2, { from: user2 }).should.be.rejectedWith(EVMRevert);
		await pixsale.transferPixels('100', user2, { from: user1 }).should.be.fulfilled;

		// balances are coherent
		(await pixsale.pixelsBalance(user1)).toString().should.equal('0');
		(await pixsale.pixelsBalance(user2)).toString().should.equal('100');

		// user2 consumes pixels to mint a new NFT
		await pixsale.mint(
			100,							
			[100, 100, 110, 110],
			www,
			image,
			tDescription,
			{ from: user2, value: 0 }
		).should.be.fulfilled; 

		(await pixsale.pixelsBalance(user2)).toString().should.equal('0');

		await pixsale.mint(
			25,							
			[1000, 1000, 1005, 1005],
			www,
			image,
			tDescription,
			{ from: user2, value: 0 }
		).should.be.rejectedWith(EVMRevert); 

		await pixsale.transferPixels('10', user2, { from: owner2 }).should.be.fulfilled;
		(await pixsale.pixelsBalance(user2)).toString().should.equal('10');

		await pixsale.mint(
			25,							
			[1000, 1000, 1005, 1005],
			www,
			image,
			tDescription,
			{ from: user2, value: 0 }
		).should.be.rejectedWith(EVMRevert);
		await pixsale.mint(
			25,							
			[1000, 1000, 1005, 1005],
			www,
			image,
			tDescription,
			{ from: user2, value: (pixelPrice * pixelsFromCoords([1000, 1000, 1005, 1005]) - (pixelPrice * 10)) }
		).should.be.fulfilled;
		(await pixsale.pixelsBalance(user2)).toString().should.equal('0');
	});

	it('checks that PIXSMarket features work as expected', async() => {
		await pixsale.mint(
			pixelsAmount,							
			coords,	
			www,
			image,
			tDescription,
			{ from: user1, value: pixelPrice * pixelsFromCoords((coords)) }
		).should.be.fulfilled;
		const startBalance = await Promise.resolve(parseInt((await pixsale.thisBalance()).toString()));
		const preBalanceUser1 = await Promise.resolve(parseInt((await web3.eth.getBalance(user1)).toString()));
		const preBalanceUser2 = await Promise.resolve(parseInt((await web3.eth.getBalance(user2)).toString()));
		
		await pixsale.sell('1', (0.1*1e18).toString(), { from: owner1 }).should.be.rejectedWith(EVMRevert);
		await pixsale.buy('1', { from: user2, value: (0.2*1e18).toString() }).should.be.rejectedWith(EVMRevert);
		await pixsale.sell('1', (0.1*1e18).toString(), { from: user1 }).should.be.fulfilled;
		await pixsale.buy('1', { from: user2, value: (0.09*1e18).toString() }).should.be.rejectedWith(EVMRevert);
		await pixsale.buy('1', { from: user2, value: (0.1*1e18).toString() }).should.be.fulfilled;
		(await pixsale.ownerOf('1')).toString().should.equal(user2);

		const postBalanceUser1 = await Promise.resolve(parseInt((await web3.eth.getBalance(user1)).toString()));
		const postBalanceUser2 = await Promise.resolve(parseInt((await web3.eth.getBalance(user2)).toString()));
		(await Promise.resolve((postBalanceUser1 > preBalanceUser1) && (preBalanceUser2 > postBalanceUser2))).toString().should.equal('true');
		// proof no fee is collected on public PIXS marketplace sales
		const endBalance = await Promise.resolve(parseInt((await pixsale.thisBalance()).toString()));
		endBalance.should.equal(startBalance);
		// cant by after owner change
		await pixsale.buy('1', { from: user3, value: (1*1e18).toString() }).should.be.rejectedWith(EVMRevert);
		/* private sell */
		const preBalanceUser3 = await Promise.resolve(parseInt((await web3.eth.getBalance(user3)).toString()));
		await pixsale.privateSellTo('1', (0.1*1e18).toString(), user3, {from: user3}).should.be.rejectedWith(EVMRevert);
		await pixsale.privateSellTo('1', (0.1*1e18).toString(), user3, {from: user2}).should.be.fulfilled;
		await pixsale.buy('1', { from: user4, value: (0.1*1e18).toString() }).should.be.rejectedWith(EVMRevert);
		await pixsale.buy('1', { from: user3, value: (0.095*1e18).toString() }).should.be.rejectedWith(EVMRevert);
		await pixsale.buy('1', { from: user3, value: (0.1*1e18).toString() }).should.be.fulfilled;
		(await pixsale.ownerOf('1')).toString().should.equal(user3);

		const postBalanceUser3 = await Promise.resolve(parseInt((await web3.eth.getBalance(user3)).toString()));
		const postBalanceUser2_2 = await Promise.resolve(parseInt((await web3.eth.getBalance(user2)).toString()));

		(await Promise.resolve((postBalanceUser2_2 > postBalanceUser2) && (preBalanceUser3 > postBalanceUser3))).toString().should.equal('true');

		// proof that no fee is collected when using the integrated PIXS marketplace sales mechanism
		const finalBalance = await Promise.resolve(parseInt((await pixsale.thisBalance()).toString()));
		finalBalance.should.equal(startBalance);

	});
	
	it('checks that coordinates cant collapse', async() => {

		await minter(0,0,10,10, user1).should.be.fulfilled;
		await minter(0,9,10,19, user2).should.be.rejectedWith(EVMRevert);
		await minter(10,10,15,15, user2).should.be.fulfilled;
		await minter(3831,0,3841,10, user3).should.be.rejectedWith(EVMRevert);
		await minter(3830,0,3840,10, user3).should.be.fulfilled;

		await minter(4,100,14,110, user4).should.be.rejectedWith(EVMRevert);
		await minter(5,100,15,110, user4).should.be.fulfilled;
		
		// min length 5px
		await minter(500,500,504,510, user4).should.be.rejectedWith(EVMRevert);
		await minter(500,500,505,510, user4).should.be.fulfilled;
	});

	
	it('checks that token reflection calculation and distribution occurs as planned', async() => {
		
		await minter(0, 0, 5, 5, user1).should.be.fulfilled;
		const clientReflection = await Promise.resolve(parseInt((await pixsale.reflectionBalanceOf(user1)).toString()));
		const tokenReflection = await Promise.resolve(parseInt((await pixsale.tokenReflection("1")).toString()));
		const totalReflection = await Promise.resolve(parseInt((await pixsale.totalReflection()).toString()));
		(await Promise.resolve(clientReflection === tokenReflection)).toString().should.equal('true');
		(await Promise.resolve(totalReflection === tokenReflection)).toString().should.equal('true');
		await minter(100, 100, 110, 110, user2).should.be.fulfilled;
		await minter(1000, 1000, 1005, 1015, user3).should.be.fulfilled;
		const clientReflection1After = await Promise.resolve(parseInt((await pixsale.reflectionBalanceOf(user1)).toString()));
		const clientReflection2 = await Promise.resolve(parseInt((await pixsale.reflectionBalanceOf(user2)).toString()));
		const clientReflection3 = await Promise.resolve(parseInt((await pixsale.reflectionBalanceOf(user3)).toString()));
		const totalReflection2 = await Promise.resolve(parseInt((await pixsale.totalReflection()).toString()));
		const refVerif1 = await Promise.resolve(
			(
				parseInt(clientReflection1After)
				+ parseInt(clientReflection2)
				+ parseInt(clientReflection3)
			) === totalReflection2
		);
		(await Promise.resolve(refVerif1.toString())).should.equal('true');
		await pixsale.holdersReflectionWithdraw({ from: user1 }).should.be.rejectedWith(EVMRevert);
		// advance the evm timer to one year
		const oneYearInScds = 31536000;
		// owners can abandon pixels sale after one year
		await timeMachine.advanceTimeAndBlock(oneYearInScds);
		// const blockTime = await web3.eth.getBlock('latest');

		// now that the EVM time is set in one year, lets try to abandon the project
		await pixsale.signProjectAbandonAndReflectionRelease({from: user1}).should.be.rejectedWith(EVMRevert);
		await pixsale.signProjectAbandonAndReflectionRelease({from: owner1}).should.be.fulfilled;
		await pixsale.signProjectAbandonAndReflectionRelease({from: user3}).should.be.rejectedWith(EVMRevert);
		await pixsale.unsignProjectAbandonAndReflectionRelease({from: owner1}).should.be.fulfilled;
		await pixsale.signProjectAbandonAndReflectionRelease({from: owner1}).should.be.fulfilled;

		(await pixsale.reflectionReleased()).toString().should.equal('false');
		await pixsale.signProjectAbandonAndReflectionRelease({from: owner2}).should.be.fulfilled;
		let rrt = await Promise.resolve(parseInt((await pixsale.reflectionReleaseTimestamp()).toString()));
		(await Promise.resolve(rrt > 0)).toString().should.equal('true');
		(await pixsale.reflectionReleased()).toString().should.equal('true');

		// users should be able to withdraw their part of reflection
		const balanceUser1 = await Promise.resolve(parseInt((await web3.eth.getBalance(user1)).toString()));
		const balanceUser2 = await Promise.resolve(parseInt((await web3.eth.getBalance(user2)).toString()));
		const balanceUser3 = await Promise.resolve(parseInt((await web3.eth.getBalance(user3)).toString()));

		await pixsale.holdersReflectionWithdraw({ from: user1 }).should.be.fulfilled;
		await pixsale.holdersReflectionWithdraw({ from: user2 }).should.be.fulfilled;
		await pixsale.holdersReflectionWithdraw({ from: user3 }).should.be.fulfilled;

		const aBalanceUser1 = await Promise.resolve(parseInt((await web3.eth.getBalance(user1)).toString()));
		const aBalanceUser2 = await Promise.resolve(parseInt((await web3.eth.getBalance(user2)).toString()));
		const aBalanceUser3 = await Promise.resolve(parseInt((await web3.eth.getBalance(user3)).toString()));

		(await Promise.resolve(
			(aBalanceUser1 > balanceUser1),
			(aBalanceUser2 > balanceUser2),
			(aBalanceUser3 > balanceUser3),
		)).toString().should.equal('true');

		await pixsale.holdersReflectionWithdraw({ from: user1 }).should.be.rejectedWith(EVMRevert);
		await pixsale.holdersReflectionWithdraw({ from: user2 }).should.be.rejectedWith(EVMRevert);
		await pixsale.holdersReflectionWithdraw({ from: user3 }).should.be.rejectedWith(EVMRevert);

		const comBalance = await Promise.resolve(parseInt((await pixsale.totalCom()).toString()));
		const finalAuctionBalance = await Promise.resolve(parseInt((await pixsale.totalAuction()).toString()));
		const finalBalance = await Promise.resolve(parseInt((await pixsale.thisBalance()).toString()));		

		// reflection amount is made available to all holders
		(await Promise.resolve(finalBalance == (comBalance+finalAuctionBalance))).toString().should.equal('true');

		const rBal1 = await Promise.resolve(parseInt((await pixsale.reflectionBalanceOf(user1)).toString()));
		const rBal2 = await Promise.resolve(parseInt((await pixsale.reflectionBalanceOf(user2)).toString()));
		const rBal3 = await Promise.resolve(parseInt((await pixsale.reflectionBalanceOf(user2)).toString()));

		(await Promise.resolve((rBal1+rBal2+rBal3) === 0)).toString().should.equal('true');
	
	});

	it('checks that marketing partner can withdraw com dedicated funds and that owners can spend funds dedicated to auction sale', async() => {
		await minter(0, 0, 5, 5, user1).should.be.fulfilled;
		await minter(100, 100, 110, 110, user2).should.be.fulfilled;
		await minter(1000, 1000, 1005, 1015, user3).should.be.fulfilled;

		const comBalance = await Promise.resolve(parseInt((await pixsale.totalCom()).toString()));
		await pixsale.setComWallet(user3, {from: owner1}).should.be.fulfilled;

		await pixsale.comPartnerWithdraw(comBalance.toString(), {from: user1}).should.be.rejectedWith(EVMRevert);
		await pixsale.comPartnerWithdraw((comBalance / 2).toString(), {from: user3}).should.be.fulfilled;

		(await pixsale.totalComWithdrawn()).toString().should.equal((comBalance / 2).toString());
		(await pixsale.totalComAvailable()).toString().should.equal((comBalance / 2).toString());


		await pixsale.comPartnerWithdraw(((comBalance / 2) + 1).toString(), {from: user3}).should.be.rejectedWith(EVMRevert);
		await pixsale.comPartnerWithdraw((comBalance / 2).toString(), {from: user3}).should.be.fulfilled;

		(await pixsale.totalComAvailable()).toString().should.equal('0');

		// advance the evm timer to one year
		const oneYearInScds = 31536000;
		await timeMachine.advanceTimeAndBlock(oneYearInScds);
		// release reflection
		await pixsale.signProjectAbandonAndReflectionRelease({from: owner1}).should.be.fulfilled;
		await pixsale.signProjectAbandonAndReflectionRelease({from: owner2}).should.be.fulfilled;

		// owners can spend auction sale organization budget after one year
		await pixsale.auctionWithdraw({from: user1}).should.be.rejectedWith(EVMRevert);
		await pixsale.auctionWithdraw({from: owner1}).should.be.fulfilled;

		const ttlAuction = await Promise.resolve(parseInt((await pixsale.totalAuction()).toString()));
		const ttlAuctionWithdrawn = await Promise.resolve(parseInt((await pixsale.totalAuctionWithdrawn()).toString()));
		(await Promise.resolve(ttlAuction === (comBalance / 5))).toString().should.equal('true');
		(await Promise.resolve(ttlAuctionWithdrawn === ttlAuction)).toString().should.equal('true');

		await pixsale.auctionWithdraw({from: owner1}).should.be.rejectedWith(EVMRevert);
		await pixsale.auctionWithdraw({from: owner2}).should.be.rejectedWith(EVMRevert);
	});

	it('checks that contract computes tokens uris well', async() => {

	})

	/***************** 
	 * ALL PASSING ✓ *
	 ****************/


});
