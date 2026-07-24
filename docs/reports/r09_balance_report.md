# R-09.3 Contract Balance Report

- Scenario: `r09_fixed_seed_steward_policy`
- Policy: Steward bootstrap: store stone, build workbench, craft torches, survive and hunt
- World seed: `90240724`
- Days simulated: `4`
- Scope: Deterministic evidence under one scripted policy; not global balance proof.

## Daily Summary

| Day | Inflow | Outflow | Actions | Pressure C/R/L/T | Reward value | Bottlenecks |
|---|---|---|---|---|---|---|
| 1 | coal:2, food:3, stone:12, wood:10 | coal:1, wood:1 | craft_torch | 41.0 / 70.5 / 59.0 / 2.0 | 4 | - |
| 2 | food:2, stone:15, wood:8 | coal:1, stone:6, wood:13 | build_workbench, craft_torch, defeat_enemy | 65.0 / 72.0 / 30.0 / 8.0 | 39 | - |
| 3 | coal:1, food:4, stone:4 | - | defeat_enemy | 79.0 / 81.5 / 24.0 / 12.0 | 14 | - |
| 4 | food:3, stone:3, wood:4 | - | stabilize_stockpile | 88.0 / 100.0 / 19.0 / 2.0 | 0 | - |

## Completion Latency

| Contract | Days from activation to completion | Final status |
|---|---|---|
| `first_hunt` | 2 | `claimed` |
| `second_dawn` | 1 | `claimed` |
| `stone_reserve` | 1 | `claimed` |
| `torch_order` | 0 | `claimed` |
| `torch_practice` | 1 | `claimed` |
| `workbench_charter` | 1 | `claimed` |

## Proposed Tuning

- No automatic balance mutation. Under this policy every R-09.2 contract reaches claimed by day 4.
- Keep `first_hunt` at 2 defeats for now; it completes later than the setup contracts and supplies the intended combat pacing contrast.
