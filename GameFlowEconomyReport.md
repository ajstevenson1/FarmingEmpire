# Farming Empire Game Flow and Economy Report

## Scope

This report is based on the visible Rojo code and assumes the Studio objects referenced by the scripts exist. The largest tree is `CyberTree` at 10,000,000,000 cash. The largest mill is `DeepSpaceMill` at 7,200,000,000 cash. Beating the current economy is treated as reaching enough cash to afford both at once: 17,200,000,000 cash.

Actual placement density can change if Studio `PlacementBox` sizes differ from the code fallback sizes. The estimates below assume the configured economy values, average cider sale price, reliable harvesting/collection, and enough plot space to place the buildings being modeled.

## Core Game Flow

1. New players start with 250 cash and a `Scythe`.
2. The tutorial makes the first `OakTree` and first `CiderMill` free, so the baseline start after tutorial is 250 cash, 1 tree, and 1 mill.
3. Trees produce apples into local tree storage every 1 second.
4. Players harvest trees to move apples into player resources.
5. Mills consume player apples and produce stored cider at a 1 apple -> 1 cider ratio.
6. Players walk over mills to collect cider.
7. Cider sells for a random market price from 5 to 15 cash per cider. The baseline estimate uses the average price: 10 cash per cider.
8. Offline earnings grant pending cider, not cash. The player still has to claim and sell the cider.

## Production Formulas

Online cider per second:

```text
online cider/sec = min(total harvested apple/sec, total mill output/sec)
cash/sec = online cider/sec * cider sell price
```

Offline cider per second:

```text
offline cider/sec per mill = mill output/sec * 2
offline cider/sec per tree = tree apple/sec * 0.25
offline cider/sec = sum(building offline rates * plot multiplier)
```

Offline time is capped at 12 hours. The curve boosts short absences above real time, then reaches exactly 12 effective hours at the cap.

| Real offline time | Effective time | Notes |
| --- | ---: | --- |
| 1 hour | 1.6 hours | 163% of real time |
| 4 hours | 5.7 hours | 142% of real time |
| 8 hours | 9.5 hours | 118% of real time |
| 12 hours | 12.0 hours | cap reached |
| 24 hours | 12.0 hours | still capped |

## Tier Baseline

This table pairs each tree tier with the same-index mill tier. Online cider/sec is the direct active-play cider rate for one pair. Offline cider/sec is the current derived offline rate for one pair.

| Tier | Tree / Mill | Pair Cost | Online Cider/sec | Offline Cider/sec | Online Payback at 10 Cash/Cider |
| ---: | --- | ---: | ---: | ---: | ---: |
| 1 | OakTree / CiderMill | 200 | 1 | 2.50 | 0.3 min |
| 2 | BirchTree / CopperCiderMill | 1,000 | 2 | 5.25 | 0.8 min |
| 3 | CherryTree / SteelCiderMill | 4,300 | 4 | 11.00 | 1.8 min |
| 4 | GoldenTree / PlatinumCiderMill | 14,500 | 8 | 20.50 | 3.0 min |
| 5 | EmeraldTree / DiamondCiderMill | 41,000 | 12 | 30.25 | 5.7 min |
| 6 | SapphireTree / RoyalCiderMill | 180,000 | 20 | 48.25 | 15.0 min |
| 7 | DiamondTree / IndustrialCiderMill | 505,000 | 28 | 66.50 | 30.1 min |
| 8 | InfernoTree / AdvancedCiderMill | 1,390,000 | 35 | 83.75 | 1.10 hr |
| 9 | FrostbiteTree / MagmaCiderMill | 3,800,000 | 45 | 106.25 | 2.35 hr |
| 10 | VoidfruitTree / WastelandCiderMill | 18,500,000 | 58 | 134.75 | 8.86 hr |
| 11 | FalloutTree / AncientCiderMill | 68,000,000 | 70 | 162.50 | 1.12 days |
| 12 | RainbowPrismTree / TitanCiderMill | 340,000,000 | 92 | 211.50 | 4.28 days |
| 13 | GhostwoodTree / QuantumReactorMill | 1,210,000,000 | 115 | 261.25 | 12.18 days |
| 14 | CandyTree / DyingForgeMill | 3,350,000,000 | 140 | 317.50 | 27.70 days |
| 15 | CyberTree / DeepSpaceMill | 17,200,000,000 | 200 | 450.00 | 99.54 days |

## Beat-Time Estimates

Baseline route:

- Complete tutorial for the free tier 1 pair.
- Buy one tree and one mill per tier.
- Keep all previous buildings.
- Stop after owning tiers 1 through 14, then save up 17,200,000,000 cash to afford tier 15.
- Sell cider at the average market price of 10 cash.

### Active Play Only

Without plot production boosts, reaching the final affordability target takes about 1,086 active hours, or 45.2 days of continuous perfect play.

With all production effectively on triple-production tiles, the same route takes about 362 active hours, or 15.1 days of continuous perfect play.

The triple-production estimate is realistic only if the player can fit or move the productive buildings onto triple tiles. The code makes this likely because the full paid plot expansion cost is only 108,000 cash, and the triple row alone costs 75,000 cash.

### Active Plus Offline Earnings

For a casual baseline with one 12-hour offline claim per day:

| Scenario | Estimate to Afford Final Pair |
| --- | ---: |
| No plot boosts, 0 hours active/day | 41 days |
| No plot boosts, 1 hour active/day | 40 days |
| Triple-production placement, 0 hours active/day | 15 days |
| Triple-production placement, 1 hour active/day | 15 days |

For two 12-hour offline claims per day:

| Scenario | Estimate to Afford Final Pair |
| --- | ---: |
| No plot boosts, 0 hours active/day | 21 days |
| No plot boosts, 1 hour active/day | 21 days |
| Triple-production placement, 0 hours active/day | 8 days |
| Triple-production placement, 1 hour active/day | 8 days |

The reason active play barely changes these day counts is that late-game offline income is very strong compared with active income.

### State Before Final Pair

After buying one pair from tiers 1 through 14:

| Metric | No Boosts | Triple Tiles |
| --- | ---: | ---: |
| Tree apple production | 807 apples/sec | 2,421 apples/sec |
| Mill throughput | 630 cider/sec | 1,890 cider/sec |
| Active cash/sec at avg price | 6,300 | 18,900 |
| Offline cider/sec | 1,461.75 | 4,385.25 |
| 12-hour offline cider | 63,147,600 | 189,442,800 |
| 12-hour offline cash at avg price | 631,476,000 | 1,894,428,000 |
| 12-hour offline cash at max price | 947,214,000 | 2,841,642,000 |

## Findings

### 1. Mills are the online bottleneck

For same-tier pairs, mills output less cider/sec than trees produce apples/sec on every tier except the final tier. By tier 14, one-of-each production makes 807 apples/sec but only processes 630 cider/sec. That leaves 177 apples/sec unused unless the player buys extra mills or higher-tier mills.

This is not automatically bad, but it means tree upgrades can feel weaker than their price implies because cash progression is mill-limited.

### 2. Offline earnings are much stronger than active earnings

Offline grants double mill output plus an extra 25% of tree apple output as cider. For the same-tier pairs, offline income is usually more than 2x the active cider rate before even considering the short-absence curve.

This makes offline claims the main late-game progression path. If that is intended, the game is more idle than active. If the goal is active farming, offline should be toned down.

### 3. The offline config values in `ProgressionConfig` are not used

Each tree and mill tier defines `offlineCiderPerSecond`, and `BuildingCatalog` stores it in `offlineEarningsConfig`. However, `OfflineCiderRateCalculator` ignores `offlineEarningsConfig` and derives offline rates from live production instead.

This creates large mismatches. For example, `DeepSpaceMill` is configured with `offlineCiderPerSecond = 36.3`, but the current calculator awards `200 * 2 = 400` offline cider/sec before plot multipliers.

### 4. `ciderPerSecondSnapshot` is saved but not used for awards

Offline data stores `ciderPerSecondSnapshot`, but login awards call the current rate calculator instead of using the saved snapshot. That means balance changes or building calculation changes can retroactively affect offline rewards for time already spent away.

### 5. Plot expansion pricing is extremely generous

All paid plot tiles cost 108,000 cash total. The triple-production row costs 75,000 cash total. That is cheaper than the tier 6 pair at 180,000 cash and massively stronger than most early purchases.

Because the boost is 3x production, plot expansion is a must-buy and compresses progression heavily.

### 6. The late game has very large jumps

The tier 14 pair costs 3.35B. The tier 15 pair costs 17.2B, a 5.13x jump for only a 1.43x same-pair online output increase. This creates a long final wall:

- About 31.6 active days of perfect unboosted play after tier 14 just to afford tier 15.
- About 10.5 active days if all tier 1-14 production is tripled.
- About 9.1 full 12-hour triple-boosted offline claims after tier 14 at average sale price.

### 7. Playtime and daily rewards only matter early

The rewards are helpful for onboarding, especially free Oak and Birch trees, but they become negligible once prices enter millions and billions.

### 8. Waiting for high market price is very valuable

The average cider sale price is 10, but max price is 15. Selling at 15 instead of average increases cash by 50%. Because the market rerolls every 30 seconds, optimal players will likely wait for high prices before selling large offline claims.

## Recommendations

1. Decide whether offline should be config-driven or formula-driven. If config-driven, update `OfflineCiderRateCalculator` to use `offlineEarningsConfig.ciderPerSecond`.
2. Consider making offline effective time linear or below real time. The current curve makes short offline sessions unusually rewarding.
3. Raise plot expansion prices or reduce production multipliers if triple tiles are meant to be mid/late-game upgrades.
4. Smooth tier 10 through tier 15 pricing. The final pair is especially harsh relative to its output gain.
5. Give excess apples a purpose if trees are supposed to stay ahead of mills. Examples: apple selling, recipes, upgrades, quests, or temporary boost crafting.
6. If active play should matter late-game, add active-only bonuses such as harvest streaks, manual processing boosts, or sell bonuses that offline earnings cannot trigger.

