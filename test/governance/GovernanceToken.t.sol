// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/governance/GovernanceToken.sol";

/**
 * @title GovernanceTokenTest
 * @notice Comprehensive test suite for the GovernanceToken contract, covering voting,
 * delegation, and governance functionality
 */
contract GovernanceTokenTest is Test {
    GovernanceToken public govToken;
    
    // Test accounts
    address public admin;
    address public user1;
    address public user2;
    address public delegator;
    address public delegate;

    // Test constants
    uint256 constant INITIAL_SUPPLY = 1000000e18;
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 50400; // ~1 week

    // Events
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousVotes, uint256 newVotes);

    function setUp() public {
        // Initialize test accounts
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        delegator = makeAddr("delegator");
        delegate = makeAddr("delegate");

        // Deploy token with initial settings
        vm.startPrank(admin);
        govToken = new GovernanceToken(admin);
        
        // Initial token distribution
        govToken.mint(user1, INITIAL_SUPPLY / 2);
        govToken.mint(user2, INITIAL_SUPPLY / 4);
        govToken.mint(delegator, INITIAL_SUPPLY / 4);
        vm.stopPrank();
    }

    function testInitialization() public {
        assertEq(govToken.name(), "Flare Governance Token");
        assertEq(govToken.symbol(), "FGT");
        assertEq(govToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(govToken.owner(), admin);
    }

    function testDelegation() public {
        // Test self-delegation
        vm.startPrank(user1);
        govToken.delegate(user1);
        
        // Verify voting power
        assertEq(govToken.getVotes(user1), INITIAL_SUPPLY / 2);
        
        // Test delegation to another account
        govToken.delegate(user2);
        
        // Verify voting power transfer
        assertEq(govToken.getVotes(user1), 0);
        assertEq(govToken.getVotes(user2), INITIAL_SUPPLY / 2);
        vm.stopPrank();
    }

    function testVotingPowerCheckpoints() public {
        // Create initial delegation
        vm.prank(user1);
        govToken.delegate(user1);
        
        // Record block number
        uint256 blockNumber = block.number;
        
        // Transfer some tokens
        vm.prank(user1);
        govToken.transfer(user2, INITIAL_SUPPLY / 4);
        
        // Verify historical voting power
        assertEq(govToken.getPastVotes(user1, blockNumber), INITIAL_SUPPLY / 2);
        assertEq(govToken.getPastVotes(user1, block.number), INITIAL_SUPPLY / 4);
    }

    function testPermitFunctionality() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        address spender = user2;
        uint256 value = 1000e18;
        uint256 deadline = block.timestamp + 1 hours;
        uint8 v;
        bytes32 r;
        bytes32 s;
        
        // Mint some tokens to owner
        vm.prank(admin);
        govToken.mint(owner, value);
        
        // Generate permit signature
        bytes32 digest = govToken.getPermitDigest(
            owner,
            spender,
            value,
            govToken.nonces(owner),
            deadline
        );
        (v, r, s) = vm.sign(privateKey, digest);

        // Execute permit
        govToken.permit(owner, spender, value, deadline, v, r, s);

        // Verify permit results
        assertEq(govToken.allowance(owner, spender), value);
        assertEq(govToken.nonces(owner), 1);
    }

    function testDelegationScenarios() public {
        // Test delegation chain
        vm.startPrank(delegator);
        govToken.delegate(delegate);
        vm.stopPrank();

        vm.startPrank(delegate);
        govToken.delegate(user1);
        vm.stopPrank();

        // Verify voting power propagation
        assertEq(govToken.getVotes(user1), INITIAL_SUPPLY / 4);
        assertEq(govToken.getVotes(delegate), 0);
        assertEq(govToken.getVotes(delegator), 0);
    }

    function testVotingPowerTransfers() public {
        // Setup initial delegation
        vm.prank(user1);
        govToken.delegate(user1);

        uint256 initialVotingPower = govToken.getVotes(user1);

        // Transfer tokens
        vm.prank(user1);
        govToken.transfer(user2, INITIAL_SUPPLY / 4);

        // Verify voting power update
        assertEq(govToken.getVotes(user1), initialVotingPower - INITIAL_SUPPLY / 4);
    }

    function testFailureCases() public {
        // Test delegation to zero address
        vm.startPrank(user1);
        vm.expectRevert("ERC20Votes: delegate cannot be zero address");
        govToken.delegate(address(0));
        vm.stopPrank();

        // Test permit with expired deadline
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        vm.prank(admin);
        govToken.mint(owner, 1000e18);

        vm.expectRevert("ERC20Permit: expired deadline");
        govToken.permit(
            owner,
            user2,
            1000e18,
            block.timestamp - 1,
            0,
            bytes32(0),
            bytes32(0)
        );
    }

    function testVotingPowerSnapshots() public {
        // Setup initial state
        vm.prank(user1);
        govToken.delegate(user1);

        // Take multiple snapshots while changing voting power
        uint256[] memory blockNumbers = new uint256[](3);
        uint256[] memory expectedVotes = new uint256[](3);

        // Initial snapshot
        blockNumbers[0] = block.number;
        expectedVotes[0] = INITIAL_SUPPLY / 2;
        vm.roll(block.number + 1);

        // Transfer some tokens
        vm.prank(user1);
        govToken.transfer(user2, INITIAL_SUPPLY / 4);
        blockNumbers[1] = block.number;
        expectedVotes[1] = INITIAL_SUPPLY / 4;
        vm.roll(block.number + 1);

        // Receive some tokens
        vm.prank(user2);
        govToken.transfer(user1, INITIAL_SUPPLY / 8);
        blockNumbers[2] = block.number;
        expectedVotes[2] = INITIAL_SUPPLY * 3 / 8;

        // Verify all snapshots
        for (uint256 i = 0; i < blockNumbers.length; i++) {
            assertEq(
                govToken.getPastVotes(user1, blockNumbers[i]),
                expectedVotes[i]
            );
        }
    }

    function testFuzzingDelegation(address[] calldata delegates) public {
        vm.assume(delegates.length > 0);
        vm.startPrank(user1);

        for (uint256 i = 0; i < delegates.length; i++) {
            address delegate = delegates[i];
            if (delegate != address(0)) {
                govToken.delegate(delegate);
                assertEq(govToken.delegates(user1), delegate);
            }
        }
        vm.stopPrank();
    }
}