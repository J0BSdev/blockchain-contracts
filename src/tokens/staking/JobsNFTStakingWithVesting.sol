// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {JobsTokenVesting} from "../vesting/JobsTokenVesting.sol";


contract JobsNFTStakingWithVesting is Ownable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    IERC721 public immutable nft;
    IERC20 public immutable rewardToken;
    JobsTokenVesting public immutable vesting;

    // reward po sekundi po NFT-u (u token decimalama)
    uint256 public rewardRatePerSecond;

    // basis points za instant isplatu: 10000 = 100%, 2000 = 20%
    uint16 public immediateBp;
    // trajanje vestinga za preostali dio (sekunde)
    uint64 public vestingDuration;

    struct UserInfo {
        uint256 stakedCount;
        uint256 rewardDebt;    // akumulirani reward, ne-claiman
        uint256 lastUpdate;    // zadnji update timestamp
    }

    // tko je staker kojeg NFT-a
    mapping(uint256 => address) public stakerOf;
    mapping(address => UserInfo) public users;

    event Staked(address indexed user, uint256 indexed tokenId);
    event Unstaked(address indexed user, uint256 indexed tokenId);
    event RewardClaimed(address indexed user, uint256 amountImmediate, uint256 amountVested);
    event RewardRateUpdated(uint256 newRate);
    event VestingParamsUpdated(uint16 immediateBp, uint64 duration);

    constructor(
        address nft_,
        address rewardToken_,
        address vesting_,
        uint256 rewardRatePerSecond_,
        uint16 immediateBp_,
        uint64 vestingDuration_
    ) Ownable(msg.sender) {
        require(nft_ != address(0), "NFT zero");
        require(rewardToken_ != address(0), "Reward zero");
        require(vesting_ != address(0), "Vesting zero");
        require(immediateBp_ <= 10000, "BP > 100%");

        nft = IERC721(nft_);
        rewardToken = IERC20(rewardToken_);
        vesting = JobsTokenVesting(vesting_);

        rewardRatePerSecond = rewardRatePerSecond_;
        immediateBp = immediateBp_;
        vestingDuration = vestingDuration_;
    }

    // --- ADMIN FUNKCIJE ---

    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardRatePerSecond = newRate;
        emit RewardRateUpdated(newRate);
    }

    function setVestingParams(uint16 immediateBp_, uint64 vestingDuration_) external onlyOwner {
        require(immediateBp_ <= 10000, "BP > 100%");
        immediateBp = immediateBp_;
        vestingDuration = vestingDuration_;
        emit VestingParamsUpdated(immediateBp_, vestingDuration_);
    }

    function rescueRewardTokens(address to, uint256 amount) external onlyOwner {
        rewardToken.safeTransfer(to, amount);
    }

    // --- STAKING LOGIKA ---

    function stake(uint256[] calldata tokenIds) external nonReentrant {
        require(tokenIds.length > 0, "No tokens");

        _updateUser(msg.sender);

        UserInfo storage user = users[msg.sender];

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            // moraš prije toga pozvati setApprovalForAll(staking, true) na NFT kontraktu
            nft.safeTransferFrom(msg.sender, address(this), tokenId);

            stakerOf[tokenId] = msg.sender;
            user.stakedCount += 1;

            emit Staked(msg.sender, tokenId);
        }
    }

    function unstake(uint256[] calldata tokenIds) external nonReentrant {
        require(tokenIds.length > 0, "No tokens");

        _updateUser(msg.sender);

        UserInfo storage user = users[msg.sender];

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            require(stakerOf[tokenId] == msg.sender, "Not staker");

            stakerOf[tokenId] = address(0);
            user.stakedCount -= 1;

            nft.safeTransferFrom(address(this), msg.sender, tokenId);

            emit Unstaked(msg.sender, tokenId);
        }
    }

    function claimRewards() external nonReentrant {
        _updateUser(msg.sender);

        UserInfo storage user = users[msg.sender];
        uint256 amount = user.rewardDebt;
        require(amount > 0, "Nothing to claim");

        user.rewardDebt = 0;

        (uint256 immediate, uint256 vested) = _payout(msg.sender, amount);

        emit RewardClaimed(msg.sender, immediate, vested);
    }

    function pendingRewards(address userAddr) external view returns (uint256) {
        UserInfo memory user = users[userAddr];
        if (user.stakedCount == 0) {
            return user.rewardDebt;
        }

        uint256 timeDiff = block.timestamp - user.lastUpdate;
        uint256 additional = timeDiff * user.stakedCount * rewardRatePerSecond;

        return user.rewardDebt + additional;
    }

    // --- INTERNAL ---

    function _updateUser(address userAddr) internal {
        UserInfo storage user = users[userAddr];

        if (user.stakedCount > 0) {
            uint256 timeDiff = block.timestamp - user.lastUpdate;
            uint256 additional = timeDiff * user.stakedCount * rewardRatePerSecond;
            user.rewardDebt += additional;
        }

        user.lastUpdate = block.timestamp;
    }

    // split: dio odmah, dio u vesting
    function _payout(address userAddr, uint256 amount) internal returns (uint256 immediate, uint256 vested) {
        if (amount == 0) return (0, 0);

        immediate = (amount * immediateBp) / 10000;
        vested = amount - immediate;

        if (immediate > 0) {
            rewardToken.safeTransfer(userAddr, immediate);
        }

        if (vested > 0) {
            // pošalji tokene u vesting kontrakt
            rewardToken.safeTransfer(address(vesting), vested);

            uint64 start = uint64(block.timestamp);
            vesting.createVesting(
                userAddr,
                uint128(vested),
                start,
                vestingDuration
            );
        }
    }

    // IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
