# World Depths and Fluids - Pass 2 Review

This is a preview-only second art-direction pass. The original exploratory package is preserved unchanged at `art/source_templates/world_depths_fluids_pass1_archived/`; no file in `art/generated/`, registry, world-generation, or fluid-runtime code is modified.

## Package

Review the numbered sheets in `review_sheets/` individually. They are intentionally separated so native-scale readability, enlarged pixel composition, tiling, neighbors, and liquid fills can be judged without a dense master board.

## Approved Promotion Set

| Target | Promoted source | Live path |
| --- | --- | --- |
| Deepstone | pressure layers / metamorphic / mineral dense pool | `deepstone_01.png`, `deepstone_02.png`, `deepstone_03.png` (+ `deepstone.png` icon) |
| Bedrock | fused plates / sealed masses / ancient anchor pool | `bedrock_01.png`, `bedrock_02.png`, `bedrock_03.png` (+ `bedrock.png` icon) |
| Hellstone | ember fissures / iron layers / heat pockets pool | `hellstone_01.png`, `hellstone_02.png`, `hellstone_03.png` (+ `hellstone.png` icon) |
| Obsidian | conchoidal / blue facets / violet shards pool | `obsidian_01.png`, `obsidian_02.png`, `obsidian_03.png` (+ `obsidian.png` icon) |
| Water | clear depth / bank reflection / cold pool | `water_01.png`, `water_02.png`, `water_03.png` (+ `water.png` icon) |
| Lava | sparse dark-slurry pool | `lava_01.png`, `lava_02.png`, `lava_03.png` (+ `lava.png` icon) |
| Bucket | `bucket_empty_B` | `art/generated/items/bucket.png` |

Every World Depths block now has a genuine three-tile in-world pool (`_01/_02/_03`, hashed per cell) plus a representative `<id>.png` icon, exactly matching the established dirt/stone convention. Liquid partial fills crop their selected source tile directly, without an injected bright surface line. The water- and lava-filled bucket state candidates remain preview-only: current inventory data has no state-specific icon hook.

## Validation

- All authored block candidates are 16x16 RGBA and fully opaque.
- All bucket candidates are 16x16 RGBA with hard transparency only.
- Every liquid candidate is shown at 25%, 50%, 75%, and 100%, in unequal-adjacent cells, with exposed surface and stone/deepstone contact.
- The world and reaction mockups are review-only composites.
