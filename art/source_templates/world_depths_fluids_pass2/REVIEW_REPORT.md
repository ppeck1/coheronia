# World Depths and Fluids - Pass 2 Review

This is a preview-only second art-direction pass. The original exploratory package is preserved unchanged at `art/source_templates/world_depths_fluids_pass1_archived/`; no file in `art/generated/`, registry, world-generation, or fluid-runtime code is modified.

## Package

Review the numbered sheets in `review_sheets/` individually. They are intentionally separated so native-scale readability, enlarged pixel composition, tiling, neighbors, and liquid fills can be judged without a dense master board.

## Approved Promotion Set

| Target | Promoted source | Live path |
| --- | --- | --- |
| Deepstone | SUPERSEDED — reauthored as mottled dark blue-grey rock by `scripts/art/gen_depth_rock_blocks.py` | `deepstone_01..._06.png` (+ `deepstone.png` icon) |
| Bedrock | fused plates / sealed masses / ancient anchor pool | `bedrock_01.png`, `bedrock_02.png`, `bedrock_03.png` (+ `bedrock.png` icon) |
| Hellstone | SUPERSEDED — reauthored as mottled ember-veined rock by `scripts/art/gen_depth_rock_blocks.py` | `hellstone_01/_02/_03.png` (+ `hellstone.png` icon) |
| Obsidian | SUPERSEDED — reauthored as mottled glassy-facet rock by `scripts/art/gen_depth_rock_blocks.py` | `obsidian_01/_02/_03.png` (+ `obsidian.png` icon) |
| Water | clear depth / bank reflection / cold pool | `water_01.png`, `water_02.png`, `water_03.png` (+ `water.png` icon) |
| Lava | sparse dark-slurry pool | `lava_01.png`, `lava_02.png`, `lava_03.png` (+ `lava.png` icon) |
| Bucket | `bucket_empty_B` | `art/generated/items/bucket.png` |

Every World Depths block now has a genuine three-tile in-world pool (`_01/_02/_03`, hashed per cell) plus a representative `<id>.png` icon, exactly matching the established dirt/stone convention. Liquid partial fills crop their selected source tile directly, without an injected bright surface line. The water- and lava-filled bucket state candidates remain preview-only: current inventory data has no state-specific icon hook.

## Validation

- All authored block candidates are 16x16 RGBA and fully opaque.
- All bucket candidates are 16x16 RGBA with hard transparency only.
- Every liquid candidate is shown at 25%, 50%, 75%, and 100%, in unequal-adjacent cells, with exposed surface and stone/deepstone contact.
- The world and reaction mockups are review-only composites.
