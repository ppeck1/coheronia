# Coheronia Authored Sprite Coverage Handoff - 2026-07-14

Status: post-FQ-15 authored-art run on `main`, based on commit `1b19ad1`.
Run id: `20260714_coheronia_authored_sprite_coverage`.

This supersedes `docs/HANDOFF_ART_INTEGRATION_2026-07-12.md` for current art
coverage and production order. The earlier document remains useful historical
evidence for the first 55-PNG integration.

## Scope and result

The run closed every canonical image gap reachable in the current game and
then populated the already-live variety mechanisms:

| Category | Before | Added/replaced | Current result |
|---|---:|---:|---|
| Blocks | 11 PNGs | 9 canonicals + 51 variants | 20 canonicals; 17 pools of three |
| Items | 16 canonicals | 27 canonicals | 43/43 inventory and live-drop ids authored |
| Enemies | 12 PNGs | 3 canonicals + 9 variants | 6 canonicals; six pools of three |
| Players | 12 PNGs | 18 new variants + 2 demo replacements | 10 canonicals; ten pools of two |
| Other art | 21 PNGs | none | structure, UI placeholders, backgrounds, walls unchanged |
| Total | 72 PNGs | 117 net-new PNGs + 2 replacements | 189 runtime PNGs |

The 39 missing canonicals were nine FQ-10/FQ-12 block ids, twenty-seven
inventory/live-drop icons, and three FQ-13 enemies. The item total includes
five live cave/raider drops that the old audit missed because they appeared in
`enemies.json` but not `items.json`: `chitin`, `silk`, `eyes`, `coins`, and
`scrap_weapons`. Those five now also have display metadata in `items.json`.

## Authored files

### Canonicals added

- Blocks: `coal`, `copper_ore`, `tin_ore`, `iron_ore`, `silver_ore`,
  `crystal`, `farm_soil`, `crop_seedling`, `crop_ripe`.
- Items: the same ore/farm material ids; `crop_seeds`; five metal ingots;
  `meat`, `thorn_quill`, `hide_scrap`, `ore_flecks`, `shell`, `oil_rags`,
  `torch_heads`, `chitin`, `silk`, `eyes`, `coins`, `scrap_weapons`.
- Enemies: `thornrat`, `ore_tick`, `raider_torchbearer`.

### Variety pools added

- Three block looks each: `dirt`, `grass`, `stone`, `ore`, `wood`,
  `tree_trunk`, `tree_leaves`, `berry_bush`, `coal`, `copper_ore`, `tin_ore`,
  `iron_ore`, `silver_ore`, `crystal`, `farm_soil`, `crop_seedling`,
  `crop_ripe`.
- Three enemy looks each: `thornrat`, `ore_tick`, `raider_torchbearer`. The
  three earlier enemy families already had three-entry pools.
- Two player looks beyond canonical for every body id. The old hue-only human
  demo outputs were replaced with reviewed authored looks; the other nine body
  ids received `_01` and `_02`.

Items intentionally have no variant pools. `BlockRegistry.item_icon` is cached,
so canonical-only icons keep each stack visually stable.

## Runtime and contract corrections

- `scripts/asset_audit.py` now includes live enemy drops in the item-id set,
  recognizes the real player-gear consumers, and fails pools above the runtime
  maximum of eight in strict mode.
- `shell_ui.gd` no longer offers hard-coded Look values 0-7. It reads the
  selected body's actual pool size, clamps the value, and disables the control
  if a future body has no authored alternatives.
- `scripts/main/smoke_test.gd` now asserts the authored thornrat, dwarf, stone,
  and dirt pools instead of asserting their former fallback-only state. The
  temp explicit-pool test uses `town_hall_core`, which remains canonical-only.
- `data/visual_assets.json` and this documentation now describe opening pools
  truthfully: multiple frames loop at 8 fps for the scene; one frame is static.
- `scripts/gen_player_variants.py` preserves reviewed variants by default and
  only overwrites them with the legacy hue demo when `--force-demo` is explicit.
- `scripts/art/restore_player_skin_palette.py` maps generated player skin tones
  back to each rig's exact configured palette before promotion. This preserves
  the live Pale/Umber/Ash recolor bridge across all twenty alternate Looks.

## Production mode and prompt contract

Tool mode: built-in image generation. Canonical assets and block variants used
one distinct generation call per output. To reduce generation cost while
preserving reviewability, actor variants used one family strip per creature or
body, followed by deterministic splitting into individual outputs. Canonical
assets and category contact sheets were supplied as identity/style references.
Cutouts were generated on flat chroma magenta, processed by the installed
imagegen `remove_chroma_key.py`, then normalized with
`scripts/art/prepare_pixel_asset.py`. Opaque sources were normalized directly.

Shared prompt pattern:

> Coheronia Mythic Frontier Pixel Diorama; genuinely low-resolution side-view
> pixel art; crisp square clusters; no antialiasing; restrained 12-16 color
> palette; dark readable outline; upper-left warm light and lower-right cool
> shadow; preserve the attached canonical identity; no text, logo, UI, bloom,
> gradient, particles, ground, cast shadow, or extra objects.

Per-output notes then fixed material/creature/body identity and required a
single centered asset. Variants changed clusters, markings, outfit details, or
small pose cues rather than relying on hue swaps alone.

Mechanical normalization contract:

- exact native dimensions (16x16 or 16x32);
- no more than 16 visible colors;
- cutouts use only alpha 0/255 and have transparent corners;
- homogeneous terrain uses matching opposite edges;
- grass matches horizontally but preserves its distinct green crown/top;
- character feet are bottom-aligned and gameplay silhouettes remain unchanged.
- every player body and Look contains the full rig skin palette inside the
  configured skin regions, so non-default appearances never become a no-op.

The new `scripts/art/verify_pixel_assets.py` enforces these rules across the
repo. `scripts/art/prepare_pixel_asset.py` is the repeatable source-to-runtime
normalizer and supports both full and axis-specific tile-edge locking;
`scripts/art/make_contact_sheets.py` renders integer-zoom category reviews.

## Deliberately deferred image work

1. **Player gear overlays.** The hook is live, but generic 16x32 overlays are
   not safe across the ten materially different body rigs. Keep the rig-aware
   procedural fallback until body-specific `<item_id>_<body_id>.png` overlays
   and three-phase tool swings can be reviewed as a coordinated set.
2. **Equipment item icons.** Equipment panels are text-only; those icons have
   no live consumer yet.
3. **Final UI replacement art.** Fifteen deliberate placeholders exist, but
   only two slot frames are consumed. FQ-14 goals and FQ-15 map surfaces are
   code-drawn and expose no image id.
4. **Opening cels.** The eight-scene hook is live but optional. The plotted,
   wordless opening is complete and remains the permanent fallback.
5. **Future systems.** Do not produce planned enemies, stations, deep ancestry
   bodies, or cave planes before their data/runtime consumers land.

## Verification gate

Final 2026-07-14 closeout evidence:

- strict runtime-asset audit clean: no fallback-only live ids, findings, or
  data bugs;
- pixel verifier passed all 186 applicable PNGs, including exact player skin
  palettes and canonical-scale Look envelopes;
- repo validator, public-repo capsule doctor, and `git diff --check` passed;
- isolated waited Godot smoke passed 306/306; the expanded appearance check
  reported `variant_failures=[]` across all twenty alternate Looks;
- isolated hidden/windowed screenshot tour wrote nine frames, all visually
  reviewed; terrain/flora variety, item icons, character creation, and cave
  lighting rendered without layout or chroma artifacts.

The verification loops rejected and corrected over-flat dirt/stone variants,
under-width tree trunks, full-height dwarf/goblin alternatives, and player
skin colors that looked plausible but did not satisfy the runtime's exact
appearance-palette bridge.

Run from the inner repo root:

```powershell
python scripts/asset_audit.py --strict
python scripts/art/verify_pixel_assets.py
python scripts/validate_repo.py
python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo
git diff --check
```

Then run Godot smoke with isolated `APPDATA` and `GODOT_USER_HOME`, and read the
fresh `smoke_results.json`; process exit alone is not evidence. Regenerate and
review category contact sheets plus a runtime screenshot before promotion.

Do not commit source generations or chroma intermediates. Only approved native
PNGs under `art/generated/` belong in the public repo.
