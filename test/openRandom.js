const { BigNumber } = require("ethers");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const {
  blockShiftBy,
  expect,
  getBlockTime,
  makeBet,
  makeBetCheck,
  makeWithdrawPayout,
  makeWithdrawPayoutCheck,
  prepareWithUSDC,
  timeShiftBy,
  ADDRESSZERO,
  BET_100,
  BET_200,
  MAXRESPONSE,
  ROUNDDELTA,
  WINMULTIPLIER,
} = require("../utils/utils");

describe("OpenRandom main tests", function () {
  it("try init again", async () => {
    const { hilo, aggregator, usdc } = await loadFixture(prepareWithUSDC);
    await expect(
      hilo.initialize(usdc.address, WINMULTIPLIER, aggregator.address, ROUNDDELTA, MAXRESPONSE)
    ).to.be.revertedWith("Initializable: contract is already initialized");
  });
  it("try incorrect settings", async () => {
    const { hilo, owner } = await loadFixture(prepareWithUSDC);
    await expect(hilo.connect(owner).changeFeed(ADDRESSZERO)).to.be.revertedWithCustomError(hilo, "IncorrectAddress");
    await expect(hilo.connect(owner).changeRoundDelta(0)).to.be.revertedWithCustomError(hilo, "IncorrectValue");
    await expect(hilo.connect(owner).changeMaxResponse(0)).to.be.revertedWithCustomError(hilo, "IncorrectValue");
  });
  it("simple bet", async () => {
    const { hilo, aggregator, rounds, users } = await loadFixture(prepareWithUSDC);
    const ALICE = users[0];
    const HIGHER = true;
    const INCORRECTREQUEST0 = 1000;
    const INCORRECTREQUEST1 = 1001;

    // set first round
    await aggregator.addRoundsData(rounds.slice(0, 1));

    for (const i of Array(10).keys()) {
      let requests = [i * 2, i * 2 + 1];
      let betId = i;
      await makeBetCheck(hilo, ALICE, HIGHER, BET_100, betId, requests);
    }

    // set rest of rounds
    await aggregator.addRoundsData(rounds.slice(1));

    for (const i of Array(10).keys()) {
      let betId = i;
      await makeWithdrawPayoutCheck(hilo, ALICE, betId, HIGHER, BET_200);
    }

    // try calc payout again
    await expect(hilo.executeBet(ALICE.address, 0)).to.be.revertedWithCustomError(hilo, "IncorrectRequest");

    // try incorrect request
    await expect(hilo.executeBetRequests(INCORRECTREQUEST0, INCORRECTREQUEST1)).to.be.revertedWithCustomError(
      hilo,
      "IncorrectRequest"
    );

    // try again
    await expect(makeWithdrawPayoutCheck(hilo, ALICE, 0, HIGHER)).to.be.revertedWithCustomError(
      hilo,
      "PayoutAlreadyWithdrawn"
    );
  });
  it("test with feed changed phase", async () => {
    /**     
      phase  |          1            |        2
      -------+-----------------------+----------------
      rounds | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
                                   
                                   ^   ^
                                   |   |
 
                  bet betId0, betId1   |
                                       rejected betId0, betId1
     */
    const { hilo, aggregator, rounds, users } = await loadFixture(prepareWithUSDC);
    const ALICE = users[0];
    const HIGHER = true;
    let betId0 = 0;
    let betId1 = 1;
    let requests0 = [0, 1];
    let requests1 = [2, 3];

    // pass to last round before phase change
    await aggregator.addRoundsData(rounds.slice(0, 6));

    // make bets just before phase change
    await makeBetCheck(hilo, ALICE, HIGHER, BET_100, betId0, requests0);
    await makeBetCheck(hilo, ALICE, HIGHER, BET_100, betId1, requests1);

    // passed rounds of the new phase
    await aggregator.addRoundsData(rounds.slice(6));

    // too early check
    await expect(makeWithdrawPayoutCheck(hilo, ALICE, betId0, HIGHER, BET_200)).to.be.revertedWithCustomError(
      hilo,
      "ResponseNotReady"
    );

    // pass MAXRESPONSE blocks
    await blockShiftBy(ethers, MAXRESPONSE);

    // Rejected bets, get stakes back
    await makeWithdrawPayoutCheck(hilo, ALICE, betId0, HIGHER, BET_100);
    await makeWithdrawPayoutCheck(hilo, ALICE, betId1, HIGHER, BET_100);
  });
});
