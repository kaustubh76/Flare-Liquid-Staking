// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/core/LiquidStakingToken.sol";

contract LiquidStakingTokenTest is Test {
    LiquidStakingToken public token;
    
    // Test accounts
    address public owner;
    address public user1;
    address public user2;
    address public minter;
    address public burner;

    // Constants for testing
    uint256 constant INITIAL_SUPPLY = 1000000e18;
    uint256 constant TEST_AMOUNT = 1000e18;

    // Events to test
    event TokensMinted(address indexed to, uint256 amount, uint256 timestamp);
    event TokensBurned(address indexed from, uint256 amount, uint256 timestamp);

    function setUp() public {
        // Initialize test accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        minter = makeAddr("minter");
        burner = makeAddr("burner");

        // Deploy token with initial settings
        vm.startPrank(owner);
        token = new LiquidStakingToken();
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        vm.stopPrank();
    }

    function testInitialization() public {
        assertEq(token.name(), "Flare Liquid Staking Token");
        assertEq(token.symbol(), "fLST");
        assertEq(token.totalSupply(), 0);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
        assertTrue(token.hasRole(token.BURNER_ROLE(), burner));
    }

    function testMinting() public {
        vm.startPrank(minter);
        
        // Test minting event emission
        vm.expectEmit(true, true, false, true);
        emit TokensMinted(user1, TEST_AMOUNT, block.timestamp);
        token.mint(user1, TEST_AMOUNT);

        // Verify minting results
        assertEq(token.balanceOf(user1), TEST_AMOUNT);
        assertEq(token.totalSupply(), TEST_AMOUNT);
        vm.stopPrank();
    }

    function testBurning() public {
        // First mint some tokens
        vm.prank(minter);
        token.mint(user1, TEST_AMOUNT);

        vm.startPrank(burner);
        // Test burning event emission
        vm.expectEmit(true, true, false, true);
        emit TokensBurned(user1, TEST_AMOUNT, block.timestamp);
        token.burn(user1, TEST_AMOUNT);

        // Verify burning results
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.totalSupply(), 0);
        vm.stopPrank();
    }

    function testPermitFunctionality() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        address spender = user2;
        
        uint256 value = TEST_AMOUNT;
        uint256 deadline = block.timestamp + 1 hours;
        uint8 v;
        bytes32 r;
        bytes32 s;
        
        // Generate permit signature
        bytes32 digest = token.getPermitDigest(
            owner,
            spender,
            value,
            token.nonces(owner),
            deadline
        );
        
        (v, r, s) = vm.sign(privateKey, digest);

        // Execute permit
        token.permit(owner, spender, value, deadline, v, r, s);

        // Verify permit results
        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), 1);
    }

    function testPauseAndUnpause() public {
        vm.startPrank(owner);
        
        // Test pause
        token.pause();
        assertTrue(token.paused());
        
        // Verify operations are blocked while paused
        vm.expectRevert("Pausable: paused");
        token.transfer(user2, 100);
        
        // Test unpause
        token.unpause();
        assertFalse(token.paused());
        
        vm.stopPrank();
    }

    function testFailureScenarios() public {
        // Test minting by unauthorized account
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                token.MINTER_ROLE()
            )
        );
        token.mint(user2, TEST_AMOUNT);
        vm.stopPrank();

        // Test burning by unauthorized account
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                token.BURNER_ROLE()
            )
        );
        token.burn(user2, TEST_AMOUNT);
        vm.stopPrank();

        // Test minting to zero address
        vm.startPrank(minter);
        vm.expectRevert("ERC20: mint to the zero address");
        token.mint(address(0), TEST_AMOUNT);
        vm.stopPrank();
    }

    function testVotingPower() public {
        // Test token delegation
        vm.startPrank(user1);
        
        // Mint tokens to user1
        vm.prank(minter);
        token.mint(user1, TEST_AMOUNT);

        // Self-delegate
        token.delegate(user1);
        
        // Check voting power
        assertEq(token.getVotes(user1), TEST_AMOUNT);
        
        // Delegate to user2
        token.delegate(user2);
        assertEq(token.getVotes(user2), TEST_AMOUNT);
        assertEq(token.getVotes(user1), 0);
        
        vm.stopPrank();
    }

    function testFuzzingTransfers(uint256 amount) public {
        // Bound amount to reasonable values
        amount = bound(amount, 0, INITIAL_SUPPLY);
        
        // Mint tokens to user1
        vm.prank(minter);
        token.mint(user1, amount);
        
        // Test transfer
        vm.prank(user1);
        token.transfer(user2, amount);
        
        assertEq(token.balanceOf(user2), amount);
        assertEq(token.balanceOf(user1), 0);
    }

    function testSnapshotMechanics() public {
        // Mint initial tokens
        vm.prank(minter);
        token.mint(user1, TEST_AMOUNT);

        // Take snapshot
        vm.prank(owner);
        uint256 snapshotId = token.snapshot();

        // Perform some transfers
        vm.prank(user1);
        token.transfer(user2, TEST_AMOUNT / 2);

        // Check balances at snapshot
        assertEq(token.balanceOfAt(user1, snapshotId), TEST_AMOUNT);
        assertEq(token.balanceOfAt(user2, snapshotId), 0);
    }
}