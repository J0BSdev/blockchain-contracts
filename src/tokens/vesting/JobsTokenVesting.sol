// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract JobsTokenVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice ERC20 token koji se vest-a (tvoj JobsTokenFull)
    IERC20 public immutable token;

    /// @notice Staking kontrakt koji smije kreirati vesting schedule
    address public staking;

    struct Schedule {
        uint128 total;      // ukupno dodijeljeno
        uint128 released;   // već isplaćeno
        uint64 start;       // timestamp početka vestinga
        uint64 duration;    // trajanje vestinga u sekundama
        bool revoked;       // ako je schedule poništen od strane ownera
    }

    /// @notice korisnik => lista vesting schedule-ova
    mapping(address => Schedule[]) public schedules;

    event VestingCreated(
        address indexed beneficiary,
        uint256 indexed index,
        uint256 total,
        uint64 start,
        uint64 duration
    );

    event TokensReleased(
        address indexed beneficiary,
        uint256 indexed index,
        uint256 amount
    );

    event VestingRevoked(
        address indexed beneficiary,
        uint256 indexed index,
        uint256 unreleased
    );

    event StakingSet(address indexed staking);

    constructor(address token_) Ownable(msg.sender) {
        require(token_ != address(0), "Token zero");
        token = IERC20(token_);
    }

    // --- MODIFIERI ---

    modifier onlyStaking() {
        require(msg.sender == staking, "Not staking");
        _;
    }

    // --- ADMIN FUNKCIJE ---

    /// @notice Postavlja adresu staking kontrakta (samo jednom)
    function setStaking(address staking_) external onlyOwner {
        require(staking == address(0), "Staking already set");
        require(staking_ != address(0), "Staking zero");
        staking = staking_;
        emit StakingSet(staking_);
    }

    /// @notice Owner može spasiti tokene u slučaju bug-a ili viška
    function rescueTokens(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "To zero");
        token.safeTransfer(to, amount);
    }

    /// @notice Owner može ručno revoke-at schedule (ako želiš tu opciju)
    function revoke(address beneficiary, uint256 index) external onlyOwner {
        Schedule storage s = schedules[beneficiary][index];
        require(!s.revoked, "Already revoked");

        uint256 unreleased = s.total - s.released;
        s.revoked = true;

        emit VestingRevoked(beneficiary, index, unreleased);
        // tokeni ostaju u kontraktu, owner ih kasnije može rescue-at
    }

    // --- GLAVNA API FUNKCIJA KOJU ZOVE STAKING KONTRAKT ---

    /// @notice Kreira novi vesting schedule (smije zvati SAMO staking kontrakt)
    function createVesting(
        address beneficiary,
        uint128 amount,
        uint64 start,
        uint64 duration
    ) external onlyStaking returns (uint256 index) {
        require(beneficiary != address(0), "Beneficiary zero");
        require(amount > 0, "Zero amount");
        require(duration > 0, "Zero duration");

        index = schedules[beneficiary].length;

        schedules[beneficiary].push(
            Schedule({
                total: amount,
                released: 0,
                start: start,
                duration: duration,
                revoked: false
            })
        );

        emit VestingCreated(beneficiary, index, amount, start, duration);
    }

    // --- VIEW FUNKCIJE ---

    function releasable(address beneficiary, uint256 index)
        public
        view
        returns (uint256)
    {
        Schedule memory s = schedules[beneficiary][index];
        if (s.revoked) return 0;
        if (block.timestamp <= s.start) return 0;

        uint256 elapsed = block.timestamp - s.start;

        if (elapsed >= s.duration) {
            // sve je vestano
            return s.total - s.released;
        } else {
            uint256 vestedTotal = (uint256(s.total) * elapsed) / s.duration;
            return vestedTotal - s.released;
        }
    }

    // --- USER FUNKCIJA ---

    /// @notice User povlači trenutno otključani dio za jedan schedule
    function release(uint256 index) external nonReentrant {
        uint256 amount = releasable(msg.sender, index);
        require(amount > 0, "Nothing releasable");

        Schedule storage s = schedules[msg.sender][index];
        s.released += uint128(amount);

        token.safeTransfer(msg.sender, amount);

        emit TokensReleased(msg.sender, index, amount);
    }
}
