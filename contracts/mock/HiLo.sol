// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.17;

import "../OpenRandom.sol";
import "./OpenLiquidity.sol";
import "./libraries/FixedMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract HiLo is OwnableUpgradeable, OpenRandom, OpenLiquidity {
    using FixedMath for *;

    struct BetData {
        uint256 amount;
        uint256[2] results;
        uint256[2] requests;
        bool isHigh;
        bool isPaid;
    }

    event Bet(
        address indexed account,
        uint256 indexed betId,
        bool indexed isHighBet,
        uint256[2] requests
    );
    event Paid(
        address indexed account,
        uint256 indexed betId,
        uint256 amount,
        uint256[2] results
    );

    error PayoutAlreadyWithdrawn();
    error ResponseNotReady();

    mapping(address => mapping(uint256 => BetData)) public betData;

    uint256 public nextBetId;
    uint256 public winMultiplier;

    function initialize(
        address token_,
        uint256 winMultiplier_,
        address newFeed,
        uint80 newRoundDelta,
        uint256 newMaxResponse
    ) external initializer {
        __Ownable_init_unchained();
        winMultiplier = winMultiplier_;
        _setToken(token_);
        _setFeed(newFeed);
        _setRoundDelta(newRoundDelta);
        _setMaxResponse(newMaxResponse);
    }

    function changeFeed(address newFeed) external onlyOwner {
        _setFeed(newFeed);
    }

    function changeRoundDelta(uint80 newRoundDelta) external onlyOwner {
        _setRoundDelta(newRoundDelta);
    }

    function changeMaxResponse(uint256 newMaxResponse) external onlyOwner {
        _setMaxResponse(newMaxResponse);
    }

    function bet(bool isHigh, uint256 amount) external {
        _lockLiquidity(msg.sender, amount, winMultiplier);

        uint256[2] memory _requests;
        _requests[0] = _requestRandom();
        _requests[1] = _requestRandom();

        uint256 betId = nextBetId++;

        BetData storage _bet = betData[msg.sender][betId];
        _bet.requests[0] = _requests[0];
        _bet.requests[1] = _requests[1];
        _bet.amount = amount;
        _bet.isHigh = isHigh;

        emit Bet(msg.sender, betId, isHigh, _requests);
    }

    /**
     * @notice needed only to check _fillResponse call
     */
    function executeBet(address account, uint256 betId) external {
        BetData storage _bet = betData[account][betId];
        for (uint256 i = 0; i < 2; ++i) {
            _fillResponse(_bet.requests[i]);
        }
    }

    /**
     * @notice needed only to check _fillResponse requests call
     */
    function executeBetRequests(uint256 requests0, uint256 requests1) external {
        _fillResponse(requests0);
        _fillResponse(requests1);
    }

    function getPayout(
        address account,
        uint256 betId
    ) public returns (uint256 payout, uint256[2] memory results) {
        BetData storage _bet = betData[account][betId];
        if (_bet.isPaid) return (payout, results);

        uint256 result_;
        States state;
        uint256 requestId;
        for (uint256 i = 0; i < 2; ++i) {
            requestId = _bet.requests[i];
            (result_, state) = getRequestResult(requestId);

            if (state == States.NEW) {
                if (!_fillResponse(_bet.requests[i])) revert ResponseNotReady();
                (result_, state) = getRequestResult(requestId);
            }

            if (state == States.REJECTED) return (_bet.amount, results);

            results[i] = result_ % 52;
            _bet.results[i] = results[i];
        }
        if (
            (_bet.isHigh && results[0] >= results[1]) ||
            (!_bet.isHigh && results[0] < results[1])
        ) {
            payout = _bet.amount.mul(winMultiplier);
        }
    }

    function withdrawPayout(uint256 betId) external {
        (uint256 payout, uint256[2] memory results) = getPayout(
            msg.sender,
            betId
        );

        BetData storage _bet = betData[msg.sender][betId];

        if (_bet.isPaid) revert PayoutAlreadyWithdrawn();
        _bet.isPaid = true;

        // payout and return back locked liquidity
        _unlockLiquidity(_bet.amount, winMultiplier);

        emit Paid(msg.sender, betId, payout, results);
    }
}
