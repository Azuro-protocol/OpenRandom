// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract OpenRandom {
    enum States {
        NEW,
        EXECUTED,
        REJECTED
    }

    struct Request {
        uint256 result;
        uint128 blockNumber;
        uint80 responseRoundId;
        States state;
    }

    event FeedChanged(address indexed feed);
    event RoundDeltaChanged(uint80 roundDelta);
    event MaxResponseChanged(uint256 MaxResponse);

    error IncorrectAddress();
    error IncorrectValue();
    error IncorrectRequest();

    mapping(uint256 => Request) public requests;

    uint256 public nextRequestId;

    // must be initialized
    AggregatorV3Interface public feed;
    uint256 public maxResponse;
    uint80 public roundDelta;

    function getRequestResult(
        uint256 requestId
    ) public view returns (uint256, States) {
        Request storage request = requests[requestId];
        return (request.result, request.state);
    }

    /**
     * @notice response to a pending request
     * @param requestId to fill up response
     * @return filled returns 
               true - if request filled (executed or rejected)
               false - too early for response (try later)
     */
    function _fillResponse(uint256 requestId) internal returns (bool) {
        Request storage request = requests[requestId];
        uint128 requestBlock = request.blockNumber;

        // no request or executed
        if (requestBlock == 0 || request.state != States.NEW)
            revert IncorrectRequest();

        (, int256 answer, , uint256 updatedAt, ) = feed.getRoundData(
            request.responseRoundId
        );

        // no feed data
        if (updatedAt == 0) {
            // feed not responded or next phase
            if (block.number > requestBlock + maxResponse) {
                request.state = States.REJECTED;
                return true;
            }
            // too early (try later)
            return false;
        }

        request.state = States.EXECUTED;
        request.result = uint256(
            keccak256(
                abi.encode(
                    requestId,
                    answer,
                    updatedAt,
                    blockhash(requestBlock)
                )
            )
        );
        return true;
    }

    /**
     * @notice request random number
     */
    function _requestRandom() internal returns (uint256 requestId) {
        requestId = nextRequestId++;
        Request storage request = requests[requestId];
        request.blockNumber = uint128(block.number);
        (uint80 roundId, , , , ) = feed.latestRoundData();
        request.responseRoundId = roundId + roundDelta;
    }

    function _setFeed(address newFeed) internal {
        if (newFeed == address(0)) revert IncorrectAddress();
        feed = AggregatorV3Interface(newFeed);
        emit FeedChanged(newFeed);
    }

    function _setRoundDelta(uint80 newRoundDelta) internal {
        if (newRoundDelta == 0) revert IncorrectValue();
        roundDelta = newRoundDelta;
        emit RoundDeltaChanged(newRoundDelta);
    }

    function _setMaxResponse(uint256 newMaxResponse) internal {
        if (newMaxResponse == 0) revert IncorrectValue();
        maxResponse = newMaxResponse;
        emit MaxResponseChanged(newMaxResponse);
    }
}
