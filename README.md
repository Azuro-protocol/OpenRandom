# Open random project

**OpenRandom** provides a way for generating pseudo random numbers using external data sources and can be used in applications where randomness is important (games, lottery e.t.c). 
Random based on hashing of combined chainlink round's price feed data and hash of request block. Chainlink feed provides price data by different roundIds - core idea is to use it as part for randomness

**Getting random**
Getting random number consists of two steps: "request" and "result". Each request has `requestId` and will have one result random value. 
Both steps are separated in time and executed by different transactions. There can be many random numbers requests in one transaction.

***Step 1 Request***
Request can be done calling `_requiestRandom()` functon, returns value is unique `requestId`. Each request aims to be resolved after `responseRoundId` come.

***Step 2 Result***
Result must be done calling `_fillResponse(uint256 requestId)` function. This function reads request parameter, request chainlink feed data with exact roundId. Recieved data used for getting random value and write results into request structure for use and proof.

***Concept explanation***
```shell
                                                        hash(
                                                           requestId #1,
         response at 344 (343+roundDelta)                  prce 18001.1
         block #3                                          date 1680874160
App      requestId #1                                      blockhash(block #3)
Layer   _requestRandom()                                )
(user)          |                                _fillResponse()
                |                                       |
                |                                       |
                V                                       V
block #   ------3-----------4-------------5-------------6-----------7-----------8------------9---

chainlink ------*-------------------------*-------------------------*------------------------*---
round #        343                       344                       345                      346
price        18000.0                   18001.1                   18002.9                  18002.7
date      1680872934                1680874160                1680894231               1680917954
```    


```shell
npx hardhat test
```
