// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract OpenRandom {
    struct Request {
        uint256 result;
        uint128 blockNumber;
        uint80 responseRoundId;
        bool executed;
        bool rejected;
    }

    event FeedChanged(address indexed feed);
    event RoundDeltaChanged(uint80 roundDelta);
    event MaxResponseChanged(uint256 MaxResponse);

    error IncorrectAddress();
    error IncorrectValue();

    mapping(uint256 => Request) public requests;

    uint256 public nextRequestId;

    // must be initialized
    AggregatorV3Interface public feed;
    uint256 public maxResponse;
    uint80 public roundDelta;

    function getRequestResult(
        uint256 requestId
    ) public view returns (uint256 result, bool executed, bool rejected) {
        Request storage request = requests[requestId];
        result = request.result;
        executed = request.executed;
        rejected = request.rejected;
    }

    /**
     * @notice response to a pending request
     */
    function _fillResponse(uint256 requestId) internal {
        Request storage request = requests[requestId];
        uint128 requestBlock = request.blockNumber;

        // no request or executed
        if (requestBlock == 0 || request.executed) return;

        (, int256 answer, , uint256 updatedAt, ) = feed.getRoundData(
            request.responseRoundId
        );

        // no feed data (too early or feed phase changed)
        if (updatedAt == 0) {
            if (block.number > requestBlock + maxResponse) {
                request.executed = true;
                request.rejected = true;
            }
            return;
        }

        request.executed = true;
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

    function _setFeed(address newfeed) internal {
        if (newfeed == address(0)) revert IncorrectAddress();
        feed = AggregatorV3Interface(newfeed);
        emit FeedChanged(newfeed);
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
