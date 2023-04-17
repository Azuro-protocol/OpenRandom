// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract AggregatorMock is AggregatorV3Interface {
    struct Round {
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    uint8 public decimals;
    string public description;
    uint256 public version;

    mapping(uint80 => Round) internal rounds;
    uint80 lastRound;

    constructor() {
        decimals = 8;
        description = "mock price aggregator";
        version = 1;
    }

    function addRoundsData(Round[] calldata rounds_) external {
        uint80 roundsCount = uint80(rounds_.length);
        for (uint80 i = 0; i < roundsCount; ++i) {
            rounds[rounds_[i].answeredInRound] = rounds_[i];
        }
        lastRound = rounds_[roundsCount - 1].answeredInRound;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        Round storage round = rounds[_roundId];
        return (
            _roundId,
            round.answer,
            round.startedAt,
            round.updatedAt,
            answeredInRound
        );
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        Round storage round = rounds[lastRound];
        return (
            lastRound,
            round.answer,
            round.startedAt,
            round.updatedAt,
            answeredInRound
        );
    }
}
