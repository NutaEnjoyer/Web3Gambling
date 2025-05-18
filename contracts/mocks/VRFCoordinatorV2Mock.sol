// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract VRFCoordinatorV2Mock is VRFCoordinatorV2Interface {
    mapping(uint64 => address) public subscriptionOwners;
    mapping(uint64 => address[]) public consumers;
    mapping(uint64 => uint256[]) public pendingRequests;

    constructor() {}

    function createSubscription() external override returns (uint64 subId) {
        subId = uint64(block.timestamp);
        subscriptionOwners[subId] = msg.sender;
        return subId;
    }

    function getSubscription(uint64 subId)
        external
        view
        override
        returns (
            uint96 balance,
            uint64 reqCount,
            address owner,
            address[] memory consumersList
        )
    {
        owner = subscriptionOwners[subId];
        consumersList = consumers[subId];
        return (0, 0, owner, consumersList);
    }

    function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner)
        external
        override
    {
        require(subscriptionOwners[subId] == msg.sender, "Not owner");
        subscriptionOwners[subId] = newOwner;
    }

    function acceptSubscriptionOwnerTransfer(uint64 subId) external override {
        require(subscriptionOwners[subId] == msg.sender, "Not new owner");
    }

    function addConsumer(uint64 subId, address consumer) external override {
        require(subscriptionOwners[subId] == msg.sender, "Not owner");
        consumers[subId].push(consumer);
    }

    function removeConsumer(uint64 subId, address consumer) external override {
        require(subscriptionOwners[subId] == msg.sender, "Not owner");
        for (uint256 i = 0; i < consumers[subId].length; i++) {
            if (consumers[subId][i] == consumer) {
                consumers[subId][i] = consumers[subId][consumers[subId].length - 1];
                consumers[subId].pop();
                break;
            }
        }
    }

    function cancelSubscription(uint64 subId, address to) external override {
        require(subscriptionOwners[subId] == msg.sender, "Not owner");
        delete subscriptionOwners[subId];
        delete consumers[subId];
    }

    function pendingRequestExists(uint64 subId) external view override returns (bool) {
        return pendingRequests[subId].length > 0;
    }

    function getRequestConfig()
        external
        pure
        override
        returns (
            uint16,
            uint32,
            bytes32[] memory
        )
    {
        return (3, 200000, new bytes32[](0));
    }

    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external override returns (uint256 requestId) {
        requestId = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
        pendingRequests[subId].push(requestId);
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, address consumer, uint256[] memory randomWords) external {
        (bool success, ) = consumer.call(
            abi.encodeWithSignature("fulfillRandomWords(uint256,uint256[])", requestId, randomWords)
        );
        require(success, "Fulfillment failed");
    }
}