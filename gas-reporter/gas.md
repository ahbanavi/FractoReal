## Methods
| **Symbol** | **Meaning**                                                                              |
| :--------: | :--------------------------------------------------------------------------------------- |
|    **◯**   | Execution gas for this method does not include intrinsic gas overhead                    |
|    **△**   | Cost was non-zero but below the precision setting for the currency display (see options) |

|                                 |       Min |        Max |       Avg | Calls | usd avg |
| :------------------------------ | --------: | ---------: | --------: | ----: | ------: |
| **ChargeManagement**            |           |            |           |       |         |
|        *castVote*               |    66,531 |     83,631 |    69,131 |    24 |    1.24 |
|        *finalizeElection*       |         - |          - |   222,167 |     3 |    4.00 |
|        *payFee*                 |    53,195 |     56,189 |    54,692 |     4 |    0.98 |
|        *registerCandidate*      |   101,896 |    118,996 |   107,596 |     6 |    1.94 |
|        *setFeeAmount*           |         - |          - |    46,812 |     2 |    0.84 |
|        *spendFee*               |         - |          - |    34,935 |     2 |    0.63 |
|        *startElection*          |         - |          - |    44,674 |     2 |    0.80 |
|        *startVoting*            |         - |          - |    49,980 |     2 |    0.90 |
| **FractoRealFractions**         |           |            |           |       |         |
|        *castVote*               |    79,397 |    103,400 |    89,910 |     8 |    1.62 |
|        *executeProposal*        |    69,069 |     69,214 |    69,127 |     5 |    1.24 |
|        *rebuildNFT*             |         - |          - |   114,963 |     2 |    2.07 |
|        *safeTransferFrom*       |    50,246 |    153,490 |   128,464 |     5 |    2.31 |
|        *setURI*                 |         - |          - |    46,980 |     1 |    0.85 |
|        *splitRent*              |    94,224 |    116,509 |   105,367 |     4 |    1.90 |
|        *submitProposal*         |   291,540 |    311,680 |   305,891 |     4 |    5.51 |
|        *withdrawNonSharesRents* |         - |          - |    30,676 |     2 |    0.55 |
|        *withdrawRent*           |         - |          - |    35,697 |     4 |    0.64 |
| **FractoRealNFT**               |           |            |           |       |         |
|        *batchMint*              |   677,571 | 11,467,033 | 3,376,640 |     6 |   60.81 |
|        *fractionize*            |         - |          - |   260,444 |     1 |    4.69 |
|        *mint*                   |   102,789 |    148,201 |   147,370 |   108 |    2.65 |
|        *payRent*                |    55,062 |     72,162 |    63,612 |     4 |    1.15 |
|        *phaseOneMint*           |   152,574 |    158,174 |   155,370 |     8 |    2.80 |
|        *setBaseURI*             |         - |          - |    46,688 |     1 |    0.84 |
|        *setErc1155Address*      |         - |          - |    46,150 |     5 |    0.83 |
|        *setMeterages*           |    47,712 |  2,295,015 |   993,548 |     6 |   17.89 |
|        *setPhaseOneStartTime*   |         - |          - |    29,784 |    17 |    0.54 |
|        *setPhaseTwoStartTime*   |         - |          - |    29,795 |     6 |    0.54 |
|        *setResident*            |    48,103 |     48,115 |    48,114 |    11 |    0.87 |
|        *startPhaseTwoMint*      | 5,049,713 |  8,319,165 | 6,684,439 |     2 |  120.38 |
|        *withdraw*               |         - |          - |    30,461 |     1 |    0.55 |

## Deployments
|                         |       Min |      Max  |       Avg | Block % | usd avg |
| :---------------------- | --------: | --------: | --------: | ------: | ------: |
| **ChargeManagement**    |         - |         - | 1,003,205 |     2 % |   18.07 |
| **FractoRealFractions** | 2,929,346 | 2,929,358 | 2,929,348 |   5.9 % |   52.76 |
| **FractoRealNFT**       |         - |         - | 2,490,672 |     5 % |   44.86 |

## Solidity and Network Config
| **Settings**        | **Value**       |
| ------------------- | --------------- |
| Solidity: version   | 0.8.20          |
| Solidity: optimized | true            |
| Solidity: runs      | 500             |
| Solidity: viaIR     | false           |
| Block Limit         | 50,000,000      |
| L1 Gas Price        | 10 gwei         |
| Token Price         | 1800.92 usd/eth |
| Network             | ETHEREUM        |
| Toolchain           | hardhat         |

