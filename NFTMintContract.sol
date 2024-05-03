// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface CustomERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IStarNFT {
    function mint(address account, uint256 cid) external returns (uint256);
}

contract NFTMintContract {
    // Constants
    uint256 public constant MINT_COST = 340000 * (10**18); // Cost in ZLT to mint the NFT
    uint256 public constant tokenId = 1; // Define the tokenId for minting the NFT
    uint256 public constant REFERRAL_BONUS = 20400 * (10**18); // Referral bonus in ZLT
    uint256 public constant MAX_UNIQUE_MINTS = 1300; // Maximum number of unique mints allowed

    // Immutable variables
    address public immutable nftContractAddress; // Address of the Zeroloss AOT NFT contract
    address public immutable zltTokenAddress; // Address of the ZLT token contract
    address public immutable owner; // Contract owner
    address public immutable zerolossBNBAddress; // Only this address can withdraw ZLT

    // State variables
    uint256 public totalMints; // Total number of mints
    uint256 public totalUniqueMints; // Total number of unique mints
    mapping(uint256 => bool) private isNFTMinted; // Mapping to track whether an NFT has been minted or not
    mapping(address => bool) private hasMinted; // Mapping to track minted wallets
    mapping(address => address) private referrerOf; // Mapping to store referrer addresses
    mapping(address => uint256) private referrerCount; // Mapping to track the number of referrals made by each user

    // Events
    event NFTMinted(address indexed user, address indexed referrer);
    event ReferralBonusTransferred(address indexed referrer, uint256 amount);

    // Modifier to restrict access to the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Constructor to initialize immutable variables
    constructor(address _nftContractAddress, address _zltTokenAddress, address _zerolossBNBAddress) {
        nftContractAddress = _nftContractAddress;
        zltTokenAddress = _zltTokenAddress;
        owner = msg.sender; // Set the contract deployer as the owner
        zerolossBNBAddress = _zerolossBNBAddress;
    }

    // Function for users to mint the NFT by paying the specified amount
    function mintZerolossOatNFT(address referrer) external {
        require(referrer != msg.sender, "Cannot refer yourself");
        require(!hasMinted[msg.sender], "Already minted");
        require(totalUniqueMints < MAX_UNIQUE_MINTS, "Maximum unique mints reached");

        // Check if the mint is valid and the correct amount of ZLT is sent
        require(CustomERC20(zltTokenAddress).transferFrom(msg.sender, address(this), MINT_COST), "Transfer failed");

        // Mint the NFT to the user
        uint256 newTokenId = totalUniqueMints + 1; // Increment token ID for each unique mint
        require(IStarNFT(nftContractAddress).mint(msg.sender, newTokenId) > 0, "NFT minting failed");

        // Mark the NFT as minted
        isNFTMinted[newTokenId] = true;

        // Increment total mints and total unique mints
        totalMints++;
        totalUniqueMints++;

        // Mark user as minted
        hasMinted[msg.sender] = true;

        // Process referral
        if (referrer != address(0) && referrer != owner) {
            referrerCount[referrer]++;
            referrerOf[msg.sender] = referrer;
            
            // Check if the referrer has minted the NFT and the referred person has also minted the NFT
            if (hasMinted[referrer] && hasMinted[msg.sender]) {
                // Transfer referral bonus in ZLT tokens to the referrer's address
                require(
                    CustomERC20(zltTokenAddress).transfer(referrer, REFERRAL_BONUS),
                    "Referral bonus transfer failed"
                );

                // Emit event
                emit ReferralBonusTransferred(referrer, REFERRAL_BONUS);
            }
        }

        // Emit event
        emit NFTMinted(msg.sender, referrer);
    }

    // Function to check if an NFT with a given ID has been minted
    function isNFTAlreadyMinted(uint256 _tokenId) external view returns (bool) {
        return isNFTMinted[_tokenId];
    }

    // Function to get the referrer of a user
    function getReferrerOf(address _user) external view returns (address) {
        return referrerOf[_user];
    }

    // Function for the owner to withdraw ZLT
    function withdrawZLT(uint256 amount) external onlyOwner {
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(CustomERC20(zltTokenAddress).balanceOf(address(this)) >= amount, "Insufficient balance");

        // Transfer ZLT tokens to designated address
        require(CustomERC20(zltTokenAddress).transfer(zerolossBNBAddress, amount), "Transfer failed");
    }
}
