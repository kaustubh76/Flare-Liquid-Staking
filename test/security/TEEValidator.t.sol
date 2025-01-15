// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/security/TEEValidator.sol";
import "src/libraries/DataTypes.sol";
import "src/libraries/Errors.sol";
import "src/libraries/Constants.sol";

/**
 * @title TEEValidatorTest
 * @notice Tests the Trusted Execution Environment validation functionality,
 * including attestation management and verification
 */
contract TEEValidatorTest is Test {
    TEEValidator public teeValidator;
    
    // Test accounts
    address public admin;
    address public validator1;
    address public validator2;
    address public user1;
    
    // Test constants
    bytes constant TEST_PUBLIC_KEY = hex"1234567890abcdef";
    bytes constant TEST_ATTESTATION_DATA = hex"deadbeef";
    uint256 constant VALIDITY_PERIOD = 30 days;

    // Events
    event AttestationRegistered(bytes32 indexed id, address indexed validator, bytes publicKey);
    event AttestationRevoked(bytes32 indexed id, string reason);
    event AttestationRenewed(bytes32 indexed id, uint256 newExpiryTime);

    function setUp() public {
        // Initialize test accounts
        admin = makeAddr("admin");
        validator1 = makeAddr("validator1");
        validator2 = makeAddr("validator2");
        user1 = makeAddr("user1");

        // Deploy contract
        vm.startPrank(admin);
        teeValidator = new TEEValidator();
        
        // Setup roles
        teeValidator.grantRole(teeValidator.VALIDATOR_ROLE(), validator1);
        teeValidator.grantRole(teeValidator.VALIDATOR_ROLE(), validator2);
        vm.stopPrank();
    }

    function testInitialization() public {
        assertTrue(teeValidator.hasRole(teeValidator.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(teeValidator.hasRole(teeValidator.VALIDATOR_ROLE(), validator1));
        assertTrue(teeValidator.hasRole(teeValidator.VALIDATOR_ROLE(), validator2));
    }

    function testAttestationRegistration() public {
        vm.startPrank(validator1);
        
        // Register attestation
        vm.expectEmit(true, true, false, true);
        emit AttestationRegistered(bytes32(0), validator1, TEST_PUBLIC_KEY);
        
        bytes32 attestationId = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );
        
        // Verify attestation details
        DataTypes.TEEAttestation memory attestation = teeValidator.getAttestation(attestationId);
        assertEq(attestation.validator, validator1);
        assertEq(attestation.publicKey, TEST_PUBLIC_KEY);
        assertTrue(attestation.isValid);
        assertEq(attestation.expiryTime, block.timestamp + VALIDITY_PERIOD);
        vm.stopPrank();
    }

    function testAttestationVerification() public {
        // Register attestation
        vm.prank(validator1);
        bytes32 attestationId = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );
        
        // Generate and verify proof
        bytes memory proof = generateAttestationProof(attestationId);
        bool isValid = teeValidator.verifyAttestation(attestationId, proof);
        assertTrue(isValid);
    }

    function testAttestationRenewal() public {
        // Register initial attestation
        vm.startPrank(validator1);
        bytes32 attestationId = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );

        // Move time forward
        vm.warp(block.timestamp + VALIDITY_PERIOD / 2);

        // Renew attestation
        uint256 newValidityPeriod = VALIDITY_PERIOD * 2;
        vm.expectEmit(true, false, false, true);
        emit AttestationRenewed(attestationId, block.timestamp + newValidityPeriod);
        
        teeValidator.renewAttestation(attestationId, newValidityPeriod);

        // Verify renewed attestation
        DataTypes.TEEAttestation memory attestation = teeValidator.getAttestation(attestationId);
        assertEq(attestation.expiryTime, block.timestamp + newValidityPeriod);
        vm.stopPrank();
    }

    function testAttestationRevocation() public {
        // Register attestation
        vm.prank(validator1);
        bytes32 attestationId = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );

        // Revoke attestation
        string memory reason = "Security compromise";
        vm.startPrank(validator1);
        vm.expectEmit(true, false, false, true);
        emit AttestationRevoked(attestationId, reason);
        
        teeValidator.revokeAttestation(attestationId, reason);

        // Verify attestation is revoked
        DataTypes.TEEAttestation memory attestation = teeValidator.getAttestation(attestationId);
        assertFalse(attestation.isValid);
        vm.stopPrank();
    }

    function testFailureCases() public {
        // Test registration by unauthorized account
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(
            AccessControl.AccessControlUnauthorizedAccount.selector,
            user1,
            teeValidator.VALIDATOR_ROLE()
        ));
        teeValidator.registerAttestation(TEST_PUBLIC_KEY, TEST_ATTESTATION_DATA, VALIDITY_PERIOD);
        vm.stopPrank();

        // Register valid attestation
        vm.prank(validator1);
        bytes32 attestationId = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );

        // Test revocation by non-owner
        vm.startPrank(validator2);
        vm.expectRevert("TEEValidator: not attestation owner");
        teeValidator.revokeAttestation(attestationId, "Unauthorized revocation");
        vm.stopPrank();

        // Test verification of non-existent attestation
        bytes memory proof = generateAttestationProof(bytes32(uint256(999)));
        assertFalse(teeValidator.verifyAttestation(bytes32(uint256(999)), proof));
    }

    function testAttestationExpiry() public {
        // Register attestation
        vm.prank(validator1);
        bytes32 attestationId = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );

        // Move time past validity period
        vm.warp(block.timestamp + VALIDITY_PERIOD + 1);

        // Verify expired attestation
        bytes memory proof = generateAttestationProof(attestationId);
        assertFalse(teeValidator.verifyAttestation(attestationId, proof));
    }

    function testBatchAttestationOperations() public {
        vm.startPrank(validator1);

        // Register multiple attestations
        uint256 batchSize = 3;
        bytes32[] memory attestationIds = new bytes32[](batchSize);
        
        for (uint256 i = 0; i < batchSize; i++) {
            bytes memory publicKey = abi.encodePacked(TEST_PUBLIC_KEY, uint256(i));
            bytes memory attestationData = abi.encodePacked(TEST_ATTESTATION_DATA, uint256(i));
            
            attestationIds[i] = teeValidator.registerAttestation(
                publicKey,
                attestationData,
                VALIDITY_PERIOD
            );
        }

        // Verify all attestations
        for (uint256 i = 0; i < batchSize; i++) {
            bytes memory proof = generateAttestationProof(attestationIds[i]);
            assertTrue(teeValidator.verifyAttestation(attestationIds[i], proof));
        }
        vm.stopPrank();
    }

    function testFuzzingAttestationData(bytes[] calldata publicKeys, bytes[] calldata attestationData) public {
        vm.assume(publicKeys.length == attestationData.length);
        vm.assume(publicKeys.length > 0 && publicKeys.length <= 10);
        
        vm.startPrank(validator1);
        for (uint256 i = 0; i < publicKeys.length; i++) {
            bytes memory publicKey = publicKeys[i];
            bytes memory data = attestationData[i];
            
            if (publicKey.length > 0 && data.length > 0) {
                bytes32 attestationId = teeValidator.registerAttestation(
                    publicKey,
                    data,
                    VALIDITY_PERIOD
                );
                
                DataTypes.TEEAttestation memory attestation = teeValidator.getAttestation(attestationId);
                assertEq(attestation.publicKey);
                assertEq(attestation.publicKey, publicKey);
                assertEq(attestation.attestationData, data);
                assertTrue(attestation.isValid);
            }
        }
        vm.stopPrank();
    }

    function testValidatorKeyRotation() public {
        vm.startPrank(validator1);
        
        // Register initial attestation
        bytes32 initialAttestationId = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );

        // Generate new key and attestation data
        bytes memory newPublicKey = hex"98765432abcdef";
        bytes memory newAttestationData = hex"cafebabe";

        // Register new attestation with new key
        bytes32 newAttestationId = teeValidator.registerAttestation(
            newPublicKey,
            newAttestationData,
            VALIDITY_PERIOD
        );

        // Revoke old attestation
        teeValidator.revokeAttestation(initialAttestationId, "Key rotation");

        // Verify old attestation is invalid and new is valid
        bytes memory oldProof = generateAttestationProof(initialAttestationId);
        bytes memory newProof = generateAttestationProof(newAttestationId);

        assertFalse(teeValidator.verifyAttestation(initialAttestationId, oldProof));
        assertTrue(teeValidator.verifyAttestation(newAttestationId, newProof));
        vm.stopPrank();
    }

    function testAttestationStateTransitions() public {
        vm.startPrank(validator1);

        // Register attestation
        bytes32 attestationId = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );

        // Initial state check
        DataTypes.TEEAttestation memory attestation = teeValidator.getAttestation(attestationId);
        assertTrue(attestation.isValid);
        assertEq(attestation.expiryTime, block.timestamp + VALIDITY_PERIOD);

        // Update through renewal
        uint256 newValidityPeriod = VALIDITY_PERIOD * 2;
        teeValidator.renewAttestation(attestationId, newValidityPeriod);
        attestation = teeValidator.getAttestation(attestationId);
        assertEq(attestation.expiryTime, block.timestamp + newValidityPeriod);

        // Revoke attestation
        teeValidator.revokeAttestation(attestationId, "State transition test");
        attestation = teeValidator.getAttestation(attestationId);
        assertFalse(attestation.isValid);

        vm.stopPrank();
    }

    function testConcurrentValidators() public {
        // Register attestations from different validators
        vm.prank(validator1);
        bytes32 attestationId1 = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );

        vm.prank(validator2);
        bytes32 attestationId2 = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );

        // Verify both attestations are valid
        bytes memory proof1 = generateAttestationProof(attestationId1);
        bytes memory proof2 = generateAttestationProof(attestationId2);

        assertTrue(teeValidator.verifyAttestation(attestationId1, proof1));
        assertTrue(teeValidator.verifyAttestation(attestationId2, proof2));
    }

    function testValidityPeriodBounds() public {
        vm.startPrank(validator1);

        // Test minimum validity period
        vm.expectRevert("TEEValidator: invalid validity period");
        teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            1 days - 1 // Less than minimum
        );

        // Test maximum validity period
        vm.expectRevert("TEEValidator: invalid validity period");
        teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            366 days // More than maximum
        );

        // Test valid period
        bytes32 attestationId = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            30 days
        );
        assertTrue(attestationId != bytes32(0));

        vm.stopPrank();
    }

    function testAttestationModification() public {
        vm.startPrank(validator1);

        // Register initial attestation
        bytes32 attestationId = teeValidator.registerAttestation(
            TEST_PUBLIC_KEY,
            TEST_ATTESTATION_DATA,
            VALIDITY_PERIOD
        );

        // Attempt to modify attestation data (should fail)
        vm.expectRevert("TEEValidator: attestation immutable");
        teeValidator.modifyAttestationData(
        attestationId,
        hex"6D6F6469666965645F64617461"  // properly encoded hex string for "modified_data"
);

        // Verify original data remains unchanged
        DataTypes.TEEAttestation memory attestation = teeValidator.getAttestation(attestationId);
        assertEq(attestation.attestationData, TEST_ATTESTATION_DATA);

        vm.stopPrank();
    }

    function testBulkOperations() public {
        vm.startPrank(admin);

        // Register multiple validators
        address[] memory validators = new address[](3);
        for (uint256 i = 0; i < validators.length; i++) {
            validators[i] = makeAddr(string(abi.encodePacked("validator", i)));
            teeValidator.grantRole(teeValidator.VALIDATOR_ROLE(), validators[i]);
        }

        // Each validator registers multiple attestations
        uint256 attestationsPerValidator = 2;
        bytes32[][] memory attestationIds = new bytes32[][](validators.length);

        for (uint256 i = 0; i < validators.length; i++) {
            attestationIds[i] = new bytes32[](attestationsPerValidator);
            
            vm.startPrank(validators[i]);
            for (uint256 j = 0; j < attestationsPerValidator; j++) {
                bytes memory publicKey = abi.encodePacked(TEST_PUBLIC_KEY, i, j);
                bytes memory attestationData = abi.encodePacked(TEST_ATTESTATION_DATA, i, j);
                
                attestationIds[i][j] = teeValidator.registerAttestation(
                    publicKey,
                    attestationData,
                    VALIDITY_PERIOD
                );
            }
            vm.stopPrank();
        }

        // Verify all attestations
        for (uint256 i = 0; i < validators.length; i++) {
            for (uint256 j = 0; j < attestationsPerValidator; j++) {
                bytes32 attestationId = attestationIds[i][j];
                DataTypes.TEEAttestation memory attestation = teeValidator.getAttestation(attestationId);
                assertTrue(attestation.isValid);
                assertEq(attestation.validator, validators[i]);
            }
        }

        vm.stopPrank();
    }

    // Helper function to generate test attestation proof
    function generateAttestationProof(bytes32 attestationId) internal pure returns (bytes memory) {
        return abi.encodePacked(attestationId, "VALID_ATTESTATION_PROOF");
    }

    receive() external payable {}
}