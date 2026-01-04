// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract JobsTokenVestingERC20 is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant VESTING_ADMIN_ROLE = keccak256("VESTING_ADMIN_ROLE");

    IERC20 public immutable token;

    struct Vesting {
        uint128 total;
        uint128 claimed;
        uint64  start;
        uint64  cliff;    // timestamp
        uint64  duration; // seconds
        bool    revoked;
    }

    mapping(address => Vesting[]) public vestings;

    event VestingCreated(address indexed beneficiary, uint256 indexed id, uint256 total, uint256 start, uint256 cliff, uint256 duration);
    event Claimed(address indexed beneficiary, uint256 indexed id, uint256 amount);
    event Revoked(address indexed beneficiary, uint256 indexed id, uint256 refund);

    error ZeroAddress();
    error BadParams();
    error NothingToClaim();

    constructor(address token_, address admin_) {
        if (token_ == address(0) || admin_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(VESTING_ADMIN_ROLE, admin_);
    }

    function createVesting(
        address beneficiary,
        uint256 total,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration
    ) external onlyRole(VESTING_ADMIN_ROLE) nonReentrant returns (uint256 id) {
        if (beneficiary == address(0) || total == 0) revert BadParams();
        if (duration == 0 || cliffDuration > duration) revert BadParams();

        uint256 cliffTs = start + cliffDuration;

        // prefund: admin mora imati allowance prema ovom ugovoru
        token.safeTransferFrom(msg.sender, address(this), total);

        vestings[beneficiary].push(
            Vesting({
                total: uint128(total),
                claimed: 0,
                start: uint64(start),
                cliff: uint64(cliffTs),
                duration: uint64(duration),
                revoked: false
            })
        );

        id = vestings[beneficiary].length - 1;
        emit VestingCreated(beneficiary, id, total, start, cliffTs, duration);
    }

    function vestedAmount(address beneficiary, uint256 id) public view returns (uint256) {
        Vesting memory v = vestings[beneficiary][id];
        if (v.revoked) {
            // kad je revoked, vested se računa do trenutka revoke? (jednostavna verzija: tretiramo kao “stop” na revoke time)
            // Za striktno, spremi revokeTime u struct. Ako želiš, dodam ti to u V2.
        }

        uint256 t = block.timestamp;

        if (t < v.cliff) return 0;
        if (t >= uint256(v.start) + uint256(v.duration)) return v.total;

        uint256 elapsed = t - v.start;
        return (uint256(v.total) * elapsed) / v.duration;
    }

    function claim(uint256 id) external nonReentrant {
        Vesting storage v = vestings[msg.sender][id];
        require(!v.revoked, "Revoked");

        uint256 vested = vestedAmount(msg.sender, id);
        uint256 claimable = vested - v.claimed;

        if (claimable == 0) revert NothingToClaim();

        v.claimed += uint128(claimable);
        token.safeTransfer(msg.sender, claimable);

        emit Claimed(msg.sender, id, claimable);
    }

    // Optional revoke (admin vraća ne-vestani dio sebi)
    function revoke(address beneficiary, uint256 id) external onlyRole(VESTING_ADMIN_ROLE) nonReentrant {
        Vesting storage v = vestings[beneficiary][id];
        require(!v.revoked, "Already revoked");

        uint256 vested = vestedAmount(beneficiary, id);
        uint256 unclaimedVested = vested - v.claimed;
        uint256 refund = uint256(v.total) - vested;

        v.revoked = true;

        // isplati beneficiary-u što je već vested ali neclaimed
        if (unclaimedVested > 0) {
            v.claimed = uint128(vested);
            token.safeTransfer(beneficiary, unclaimedVested);
            emit Claimed(beneficiary, id, unclaimedVested);
        }

        // vrati adminu ne-vestani dio
        if (refund > 0) {
            token.safeTransfer(msg.sender, refund);
        }

        emit Revoked(beneficiary, id, refund);
    }

    function vestingCount(address beneficiary) external view returns (uint256) {
        return vestings[beneficiary].length;
    }
}
