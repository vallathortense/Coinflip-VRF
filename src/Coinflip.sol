// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VRFv2DirectFundingConsumer} from "./VRFv2DirectFundingConsumer.sol";

interface LinkTokenInterface {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Coinflip is Ownable{
    // A map of the player and their corresponding random number request
    mapping(address => uint256) public playerRequestID;
    // A map that stores the users coinflip guess
    mapping(address => uint8) public bets;
    // An instance of the random number resquestor, client interface
    VRFv2DirectFundingConsumer private vrfRequestor;

    ///@dev we no longer use the seed, instead each coinflip should spawn its own VRF instance
    ///@notice This programming pattern is a factory model - a contract creating other contracts 
    constructor() Ownable(msg.sender) {
        vrfRequestor = new VRFv2DirectFundingConsumer();
    }

    ///@notice Fund the VRF instance with **2** LINK tokens.
    ///@return A boolean of whether funding the VRF instance with link tokens was successful or not
    ///@dev use the address of LINK token contract provided. Do not change the address!
    ///@custom:attention In order for this contract to fund another contract, which tokens does it require to have before calling this function?
    ///                  What **additional** functions does this contract need to receive these tokens itself?
    function fundOracle() external returns(bool){
        address Link_addr = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        // Require sufficient balance
        LinkTokenInterface link = LinkTokenInterface(Link_addr);
        // Require sufficient balance
        require(link.balanceOf(address(this)) >= 2e18, "Insufficient LINK balance");
        // Fund the VRF instance with **2** LINK tokens
        require(link.transfer(address(vrfRequestor), 2e18), "Failed to transfer LINK");
        return true;
    }

    ///@notice user guess only ONE flip either a 1 or a 0.
    ///@param Guess uint8 which is required to be 1 or 0
    ///@dev After validating the user input, store the user input in global mapping and fire off a request to the VRF instance
    ///@dev Then, store the requestid in global mapping
    function userInput(uint8 Guess) external {
        require(Guess == 0 || Guess == 1, "Guess must be either 0 or 1");
        // store result in global mapping
        bets[msg.sender] = Guess;
        // request to the VRF instance
        uint256 requestId = vrfRequestor.requestRandomWords();
        // store the requestid in global mapping
        playerRequestID[msg.sender] = requestId;
    }

    ///@notice due to the fact that a blockchain does not deliver data instantaneously, in fact quite slowly under congestion, allow
    ///        users to check the status of their request.
    ///@return fulfilled a boolean of whether the request has been fulfilled or not
    function checkStatus() external view returns(bool){
        uint256 requestId = playerRequestID[msg.sender];
        //return vrfRequestor.getRequestStatus(requestId).fulfilled;
        (, bool fulfilled, ) = vrfRequestor.getRequestStatus(requestId);
        return fulfilled;
    }

    ///@notice once the request is fulfilled, return the random result and check if user won
    ///@return a boolean of whether the user won or not based on their input
    ///@dev request the randomWord that is returned. Here you need to check the VRFcontract to understand what type the random word is returned in
    ///@dev simply take the first result, or you can configure the VRF to only return 1 number, and check if it is even or odd. 
    ///     if it is even, the randomly generated flip is 0 and if it is odd, the random flip is 1
    ///@dev compare the user guess with the generated flip and return if these two inputs match.
    function determineFlip() external view returns(bool){
        uint256 requestId = playerRequestID[msg.sender];
        // Get the fulfillment status, paid amount, and random words of the request
        (uint256 paid, bool fulfilled, uint256[] memory randomWords) = vrfRequestor.getRequestStatus(requestId);

        // Ensure that the request has been fulfilled
        require(fulfilled, "VRF request not fulfilled");
        // Ensure that the request was paid for
        require(paid > 0, "Request not paid for");
        // Consider the first random number in this example
        uint8 randomFlip = uint8(randomWords[0] % 2);
        // Compare the user's guess with the generated flip
        return bets[msg.sender] == randomFlip;
    }
}