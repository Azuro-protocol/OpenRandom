const { expect } = require("chai");
const { BigNumber } = require("@ethersproject/bignumber");
const { ethers } = require("hardhat");

const BIGZERO = BigNumber.from(0);
const MULTIPLIER = BigNumber.from(1e12);
const WINMULTIPLIER = MULTIPLIER.mul(2);
const ROUNDDELTA = 1;
const MAXRESPONSE = 100;
const ROUNDSHIFT = 11;
const MINTABLEAMOUNTUSDC = tokensDec(1_000_000, 6);
const ADDRESSZERO = ethers.constants.AddressZero;
const INITVALUE = tokensDec(100_000, 6);
const BET_100 = tokensDec(100, 6);
const BET_200 = tokensDec(200, 6);

async function addLiquidity(hilo, user, amount) {
  await hilo.connect(user).addLiquidity(amount);
}

async function blockShiftBy(ethers, blockDelta) {
  let time = await getBlockTime(ethers);
  for (const iterator of Array(blockDelta).keys()) {
    await network.provider.send("evm_setNextBlockTimestamp", [++time]);
    await network.provider.send("evm_mine");
  }
}

async function deployContractsBase(owner, users) {
  // deploy and fill up AggregatorMock
  let { aggregator, rounds } = await deployAndFillAggregatorMock();

  // prepare native bet token
  const USDC = await ethers.getContractFactory("USDC");
  const usdc = await USDC.deploy("USDC token", "USDC");
  await usdc.deployed();

  // make owner balance
  await usdc.connect(owner).mint(owner.address, MINTABLEAMOUNTUSDC);

  const HILO = await ethers.getContractFactory("HiLo");
  const hilo = await upgrades.deployProxy(HILO, [
    usdc.address,
    WINMULTIPLIER,
    aggregator.address,
    ROUNDDELTA,
    MAXRESPONSE,
  ]);
  await hilo.deployed();

  // make balances, approves
  await usdc.connect(owner).approve(hilo.address, MINTABLEAMOUNTUSDC);

  for (const i of users.keys()) {
    await usdc.connect(users[i]).approve(hilo.address, INITVALUE);
    await usdc.connect(owner).transfer(users[i].address, INITVALUE);
  }

  // add liquidity
  await addLiquidity(hilo, owner, INITVALUE);

  return { hilo, aggregator, rounds, usdc };
}

async function deployAndFillAggregatorMock() {
  const AGGREGATOR = await ethers.getContractFactory("AggregatorMock");
  const aggregator = await AGGREGATOR.deploy();
  await aggregator.deployed();

  let time = await getBlockTime(ethers);

  // fill up mock with changing phase (phase 1 - 6 rounds, phase 2 - 4 rounds)
  let rounds = [
    {
      answer: 2234470290000,
      startedAt: 0,
      updatedAt: time + ROUNDSHIFT,
      answeredInRound: "36893488147423572307",
    },
    {
      answer: 2233828079000,
      startedAt: 0,
      updatedAt: time + 2 * ROUNDSHIFT,
      answeredInRound: "36893488147423572308",
    },
    {
      answer: 2233828010000,
      startedAt: 0,
      updatedAt: time + 3 * ROUNDSHIFT,
      answeredInRound: "36893488147423572309",
    },
    {
      answer: 2233958305999,
      startedAt: 0,
      updatedAt: time + 4 * ROUNDSHIFT,
      answeredInRound: "36893488147423572310",
    },
    {
      answer: 2233300000000,
      startedAt: 0,
      updatedAt: time + 5 * ROUNDSHIFT,
      answeredInRound: "36893488147423572311",
    },
    {
      answer: 2233440000000,
      startedAt: 0,
      updatedAt: time + 6 * ROUNDSHIFT,
      answeredInRound: "36893488147423572312",
    },
    // <----------- new phase ---------------->
    {
      answer: 2234440000000,
      startedAt: 0,
      updatedAt: time + 7 * ROUNDSHIFT,
      answeredInRound: "55340232221128654848",
    },
    {
      answer: 2234500000000,
      startedAt: 0,
      updatedAt: time + 8 * ROUNDSHIFT,
      answeredInRound: "55340232221128654849",
    },
    {
      answer: 2234040000000,
      startedAt: 0,
      updatedAt: time + 9 * ROUNDSHIFT,
      answeredInRound: "55340232221128654850",
    },
    {
      answer: 2234010000000,
      startedAt: 0,
      updatedAt: time + 10 * ROUNDSHIFT,
      answeredInRound: "55340232221128654851",
    },
  ];
  return { aggregator, rounds };
}

async function getBlockTime(ethers) {
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const time = blockBefore.timestamp;
  return time;
}

async function getEventFromTx(rush, tx, eventName) {
  const receipt = await tx.wait();
  let iface = new ethers.utils.Interface(
    rush.interface.format(ethers.utils.FormatTypes.full).filter((x) => {
      return x.includes(eventName);
    })
  );

  let event;
  for (const log of receipt.logs) {
    if (log.topics[0] == iface.getEventTopic(iface.fragments[0])) {
      event = iface.parseLog(log).args;
      break;
    }
  }

  const gas = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice);
  return [event, gas];
}

async function makeBet(hilo, user, isHigh, amount) {
  let tx = await hilo.connect(user).bet(isHigh, amount);
  let [event, gas] = await getEventFromTx(hilo, tx, "Bet");
  return {
    account: event.account,
    betId: event.betId,
    isHighBet: event.isHighBet,
    requests: event.requests,
    gasUsed: gas,
  };
}

async function makeBetCheck(hilo, user, isHigh, amount, betId, requests) {
  let res = await makeBet(hilo, user, isHigh, amount);
  expect(res.account).to.be.eq(user.address);
  expect(res.betId).to.be.eq(betId);
  expect(res.isHighBet).to.be.eq(isHigh);
  expect(res.requests[0]).to.be.eq(requests[0]);
  expect(res.requests[1]).to.be.eq(requests[1]);
}

async function makeWithdrawPayout(hilo, user, betId) {
  let tx = await hilo.connect(user).withdrawPayout(betId);
  let [event, gas] = await getEventFromTx(hilo, tx, "Paid");
  return {
    account: event.account,
    betId: event.betId,
    amount: event.amount,
    results: event.results,
    gasUsed: gas,
  };
}

async function makeWithdrawPayoutCheck(hilo, user, betId, isHigh, expected) {
  let res = await makeWithdrawPayout(hilo, user, betId);
  expect(res.account).to.be.eq(user.address);
  expect(res.betId).to.be.eq(betId);
  // if won got prize or if rejected got back stake
  if ((isHigh && res.results[0].gte(res.results[1])) || (!isHigh && res.results[0].lt(res.results[1]))) {
    expect(res.amount).to.be.eq(expected);
  } else {
    expect(res.amount).to.be.eq(BIGZERO);
  }
}

async function prepareUsers(ethers) {
  // users
  let users = [];
  let [owner, user1, user2, user3, user4, user5, user6] = await ethers.getSigners();
  users.push(user1);
  users.push(user2);
  users.push(user3);
  users.push(user4);
  users.push(user5);
  users.push(user6);
  return { owner, users };
}

async function prepareWithUSDC() {
  // users
  let { owner, users } = await prepareUsers(ethers);

  let { hilo, aggregator, rounds, usdc } = await deployContractsBase(owner, users);

  return { hilo, aggregator, rounds, usdc, owner, users };
}

async function timeShiftBy(ethers, timeDelta) {
  let time = (await getBlockTime(ethers)) + timeDelta;
  await network.provider.send("evm_setNextBlockTimestamp", [time]);
  await network.provider.send("evm_mine");
}

function tokens(val) {
  return tokensDec(val, 18);
}

function tokensDec(val, dec) {
  return BigNumber.from(val).mul(BigNumber.from("10").pow(dec));
}

module.exports = {
  expect,
  blockShiftBy,
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
};
