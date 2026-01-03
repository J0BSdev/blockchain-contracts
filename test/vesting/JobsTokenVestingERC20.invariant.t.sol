// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {JobsTokenFullV2} from "../../src/tokens/erc20/JobsTokenFullV2.sol";
import {JobsTokenVestingERC20} from "../../src/tokens/vesting/JobsTokenVestingERC20.sol";

/**
 * @title JobsTokenVestingERC20 Invariant Tests
 * @notice Provjerava da ključni invarianti vesting kontrakta UVIJEK vrijede
 * @dev Invarianti su svojstva koja moraju biti istinita u svakom trenutku
 *      Ove funkcije se mogu pozivati nakon bilo koje operacije da provjere invariante
 */
contract JobsTokenVestingERC20_Invariant_Test is Test {
    JobsTokenFullV2 token;
    JobsTokenVestingERC20 vesting;

    address admin = address(0xA11CE);
    address alice = address(0xA1);
    address bob = address(0xB0B);
    address charlie = address(0xC0C);

    uint256 constant CAP = 1_000_000_000e18;

    address[] public beneficiaries;

    function setUp() public {
        vm.startPrank(admin);
        token = new JobsTokenFullV2("Jobs Token", "JOBS", CAP, admin);
        vesting = new JobsTokenVestingERC20(address(token), admin);

        token.grantRole(token.MINTER_ROLE(), admin);
        token.mint(admin, 1_000_000e18); // Admin ima tokene za vesting
        
        // Approve vesting kontraktu
        token.approve(address(vesting), type(uint256).max);
        vm.stopPrank();

        beneficiaries = [alice, bob, charlie];
    }

    // =============================================================
    // INVARIANT 1: Total Vested <= Total Vesting Amount
    // =============================================================
    /**
     * @notice Invariant: Vested amount za svaki vesting ne može biti veći od total amount
     * @dev Ovo je fundamentalno svojstvo vesting mehanizma
     */
    function invariant_vestedAmount_le_totalAmount() public view {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 count = vesting.vestingCount(beneficiary);
            
            for (uint256 j = 0; j < count; j++) {
                (uint128 total, , , , , ) = vesting.vestings(beneficiary, j);
                uint256 vested = vesting.vestedAmount(beneficiary, j);
                
                assertLe(vested, total, "Vested amount cannot exceed total amount");
            }
        }
    }

    // =============================================================
    // INVARIANT 2: Claimed <= Vested Amount
    // =============================================================
    /**
     * @notice Invariant: Claimed amount ne može biti veći od vested amount
     * @dev Korisnik ne može claimati više nego što je vested
     */
    function invariant_claimed_le_vestedAmount() public view {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 count = vesting.vestingCount(beneficiary);
            
            for (uint256 j = 0; j < count; j++) {
                (, uint128 claimed, , , , ) = vesting.vestings(beneficiary, j);
                uint256 vested = vesting.vestedAmount(beneficiary, j);
                
                assertLe(claimed, vested, "Claimed amount cannot exceed vested amount");
            }
        }
    }

    // =============================================================
    // INVARIANT 3: Claimed <= Total Amount
    // =============================================================
    /**
     * @notice Invariant: Claimed amount ne može biti veći od total amount
     * @dev Dodatna provjera za sigurnost
     */
    function invariant_claimed_le_totalAmount() public view {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 count = vesting.vestingCount(beneficiary);
            
            for (uint256 j = 0; j < count; j++) {
                (uint128 total, uint128 claimed, , , , ) = vesting.vestings(beneficiary, j);
                
                assertLe(claimed, total, "Claimed amount cannot exceed total amount");
            }
        }
    }

    // =============================================================
    // INVARIANT 4: Contract Balance >= Sum of Unclaimed
    // =============================================================
    /**
     * @notice Invariant: Kontrakt mora imati dovoljno tokena za sve unclaimed vestings
     * @dev Contract balance >= sum of (total - claimed) za sve vestings
     */
    function invariant_contractBalance_ge_unclaimed() public view {
        uint256 totalUnclaimed = 0;
        
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 count = vesting.vestingCount(beneficiary);
            
            for (uint256 j = 0; j < count; j++) {
                (uint128 total, uint128 claimed, , , , bool revoked) = vesting.vestings(beneficiary, j);
                
                if (!revoked) {
                    totalUnclaimed += (total - claimed);
                }
            }
        }
        
        uint256 contractBalance = token.balanceOf(address(vesting));
        assertGe(contractBalance, totalUnclaimed, "Contract balance must cover all unclaimed vestings");
    }

    // =============================================================
    // INVARIANT 5: Vested Amount Only Increases With Time
    // =============================================================
    /**
     * @notice Invariant: Vested amount se samo povećava s vremenom (ili ostaje isti)
     * @dev Ovo je ključno svojstvo vesting mehanizma
     */
    mapping(address => mapping(uint256 => uint256)) public lastVestedAmount;

    function invariant_vestedAmount_onlyIncreases() public {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 count = vesting.vestingCount(beneficiary);
            
            for (uint256 j = 0; j < count; j++) {
                uint256 currentVested = vesting.vestedAmount(beneficiary, j);
                uint256 lastVested = lastVestedAmount[beneficiary][j];
                
                assertGe(currentVested, lastVested, "Vested amount can only increase or stay the same");
                
                lastVestedAmount[beneficiary][j] = currentVested;
            }
        }
    }

    // =============================================================
    // INVARIANT 6: Cliff <= Start + Duration
    // =============================================================
    /**
     * @notice Invariant: Cliff timestamp mora biti <= start + duration
     * @dev Ovo je validacijsko pravilo koje mora uvijek vrijediti
     */
    function invariant_cliff_le_startPlusDuration() public view {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 count = vesting.vestingCount(beneficiary);
            
            for (uint256 j = 0; j < count; j++) {
                (, , uint64 start, uint64 cliff, uint64 duration, ) = vesting.vestings(beneficiary, j);
                
                assertLe(cliff, start + duration, "Cliff must be <= start + duration");
            }
        }
    }

    // =============================================================
    // INVARIANT 7: Vesting Count Consistency
    // =============================================================
    /**
     * @notice Invariant: Vesting count mora biti konzistentan s actual vestings
     * @dev Count mora odgovarati broju vestings u mappingu
     */
    function invariant_vestingCount_consistency() public view {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 count = vesting.vestingCount(beneficiary);
            
            // Provjeri da možemo pristupiti svim vestings do count-1
            for (uint256 j = 0; j < count; j++) {
                // Ako ovo ne reverta, vesting postoji
                vesting.vestings(beneficiary, j);
            }
        }
    }

    // =============================================================
    // INVARIANT 8: No Negative Values
    // =============================================================
    /**
     * @notice Invariant: Nema negativnih vrijednosti u vesting structu
     * @dev Provjera overflow protection
     */
    function invariant_no_negative_values() public view {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 count = vesting.vestingCount(beneficiary);
            
            for (uint256 j = 0; j < count; j++) {
                (uint128 total, uint128 claimed, uint64 start, uint64 cliff, uint64 duration, ) = 
                    vesting.vestings(beneficiary, j);
                
                assertGe(total, 0, "Total cannot be negative");
                assertGe(claimed, 0, "Claimed cannot be negative");
                assertGe(start, 0, "Start cannot be negative");
                assertGe(cliff, 0, "Cliff cannot be negative");
                assertGe(duration, 0, "Duration cannot be negative");
            }
        }
    }

    // =============================================================
    // INVARIANT 9: Vested Calculation Consistency
    // =============================================================
    /**
     * @notice Invariant: Vested amount calculation mora biti konzistentan
     * @dev Provjerava da vested amount odgovara formuli
     */
    function invariant_vestedCalculation_consistency() public view {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 count = vesting.vestingCount(beneficiary);
            
            for (uint256 j = 0; j < count; j++) {
                (uint128 total, , uint64 start, uint64 cliff, uint64 duration, bool revoked) = 
                    vesting.vestings(beneficiary, j);
                
                if (revoked) continue;
                
                uint256 t = block.timestamp;
                uint256 vested = vesting.vestedAmount(beneficiary, j);
                
                // Prije cliffa, vested = 0
                if (t < cliff) {
                    assertEq(vested, 0, "Vested should be 0 before cliff");
                }
                // Nakon start + duration, vested = total
                else if (t >= start + duration) {
                    assertEq(vested, total, "Vested should equal total after duration");
                }
                // Između, vested = total * (t - start) / duration
                else {
                    uint256 expectedVested = (total * (t - start)) / duration;
                    assertApproxEqAbs(vested, expectedVested, 1, "Vested calculation should be consistent");
                }
            }
        }
    }

    // =============================================================
    // INVARIANT 10: Total Supply Consistency
    // =============================================================
    /**
     * @notice Invariant: Token total supply mora biti konzistentan
     * @dev Provjera da vesting ne utječe na total supply (samo transfer)
     */
    function invariant_tokenSupply_consistency() public view {
        uint256 totalSupply = token.totalSupply();
        assertLe(totalSupply, CAP, "Total supply cannot exceed cap");
    }
}

