# Character Rendering Contract

Status: authority for how a Coheronia character is resolved and composed into
pixels. It exists so that **every** consumer that draws a character -- the live
in-world `PlayerVisual`, the character-creation preview, and the Character HUD
panel -- produces the same figure from the same inputs, instead of each one
re-deriving the rules.

This document records the behavior that already ships in
`scripts/player/player_visual.gd`. It is a description, not a redesign: PR-02
introduced **no rendering change**. The runtime is the implementation; this is
the contract other consumers may depend on.

## Inputs

A character's presentation is fully determined by five character-owned fields
(all in `user://shell.json`, none in world saves):

| Field | Meaning |
|---|---|
| `species` | one of the live species (`human`, `dwarf`, `elf`, `goblin`, `orc`) |
| `body_variant` | canonical `masculine` / `feminine` (legacy `default`/`female` are aliased -- see the Terminology Contract in `docs/PRESENTATION_RECOVERY_MATRIX.md`) |
| `visual_variant` | cosmetic "Look" index (0 = canonical body, k>0 = pool entry) |
| `appearance` | skin/trim palette id from `data/character_data.json` `appearances` |
| equipped gear | the character's equipment slots (`weapon`, `helmet`, `torso`, `feet`, `accessory` are the drawn slots) |

Equipment **state and effects** are owned by the player/character; this
contract covers only how the equipped ids are *presented*.

## Body Resolution

`requested_body_id()` = `BlockRegistry.player_body_id(species, body_variant)`:

1. Body variant is normalized through `BlockRegistry.normalize_body_variant`
   (canonical `masculine`/`feminine`; `default`/`female` aliased; invalid ->
   canonical default `masculine`).
2. The canonical id maps to the existing PNG filename via
   `player_visuals.json` `body_variant_asset_suffix`
   (`masculine -> <species>`, `feminine -> <species>_female`). No art was renamed.

`_resolve_body_texture()` then resolves, in order:

1. the requested body id's texture (with the cosmetic Look applied);
2. otherwise the **same species' default (masculine) body** -- resolution may
   step down only within the species, never to another species;
3. otherwise `null`, and `_draw` paints the **procedural body** fallback.

`resolved_body_id` and `using_body_art()` report the outcome.

## Cosmetic Variant (Look)

`_select_body_texture()`: `visual_variant` 0 (or an empty pool) uses the
canonical `<body_id>.png`; index k>0 uses the k-th entry of the body's variant
pool (`art/generated/players/<body_id>_NN.png`), wrapping by pool size so any
stored index resolves. The Look is presentation-only and never enters world
saves.

## Appearance Recolor

Until authored skin-mask images exist, appearance is an **exact-palette skin
bridge**: the `Tan` appearance returns the source art byte-for-byte; `Pale`,
`Umber`, and `Ash` remap only the rig's declared skin-palette entries inside
the rig's `skin_regions`, preserving each pixel's relative light/shadow. Cloth
and gear pixels are never recolored. `appearance_recolored()` reports whether a
remap was applied. The recolor copies the image payload so a character's
appearance can never poison the registry's cached source texture.

## Gear Resolution

For each drawn slot, `_gear_texture(item_id)` resolves in order:

1. body-specific overlay `player_gear/<item_id>_<resolved_body_id>.png`;
2. generic overlay `player_gear/<item_id>.png`;
3. `null` -> the slot's code-drawn procedural fallback (the body is never
   hidden).

`gear_uses_procedural_fallback(item_id)` reports whether a slot fell through to
the procedural path.

## Tool Swing Resolution

While a mining swing is active (`swing_phase() >= 0`), `_tool_swing_texture`
resolves `player_gear/<tool_id>_<resolved_body_id>_swing_<phase>.png`, then
`player_gear/<tool_id>_swing_<phase>.png`, then the code-drawn arm + tool.
`active_tool_id()` picks the axe item when the mining target is axe-preferred
and an axe is carried, else the pick for the current tool tier.

## Facing

Only the `PlayerVisual` child is mirrored: `facing_sign` sets `scale.x` to
`+1`/`-1`, leaving collision, camera, and world UI in the original coordinate
system. Facing follows the active mining target, else horizontal movement, else
the last direction.

## Compositing Order

`_draw` paints back to front in `CHARACTER_LAYER_ORDER`:

1. `accessory`
2. `body` (resolved body texture, else procedural body)
3. `feet`
4. `torso`
5. `weapon_or_swing` (the swing overlay while swinging, otherwise the idle
   weapon)
6. `helmet`

`scripts/player/player_visual.gd` `CHARACTER_LAYER_ORDER` is the single source
of truth for this sequence; `_draw` and that constant must move together, and
the smoke contract check fails if they drift.

## Presentation Snapshot

`presentation_snapshot()` is the machine-readable surface of this contract. A
consumer reproducing the character reads it rather than the private draw state.
It returns:

`species`, `body_variant`, `visual_variant`, `requested_body_id`,
`resolved_body_id`, `using_body_art`, `appearance_recolored`, `facing_sign`,
`swing_phase`, `active_tool_id`, `visible_gear`, `layer_order`.

`visible_gear` maps each non-empty drawn slot (`weapon`, `helmet`, `torso`,
`feet`, `accessory`) to its equipped item id. `layer_order` equals
`CHARACTER_LAYER_ORDER`.

## Guarantees

- Every resolution step has a safe fallback; a missing image degrades to a
  lower tier and finally to procedural drawing, never a crash or an empty
  figure.
- Presentation state (facing, swing, resolved textures, Look) is transient and
  never written to world or character saves.
- This contract documents current behavior; changing it is a deliberate,
  separately reviewed presentation change, not an incidental edit.
