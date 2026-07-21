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

Gear and swing overlays resolve against the **effective body id**
(`effective_body_id()`): the resolved body when one loaded, otherwise the
character's intended `requested_body_id()`. This keeps authored body-specific
gear visible for a valid character whose body texture is momentarily unresolved
(a cleared cache or a once-missing load during a character/load/world-transition/
forge refresh) instead of silently dropping every overlay to the procedural
fallback. An unknown species has no body id, so its gear stays procedural.

For each drawn slot, `_gear_texture(item_id)` resolves in order:

1. body-specific overlay `player_gear/<item_id>_<effective_body_id>.png`;
2. generic overlay `player_gear/<item_id>.png`;
3. `null` -> the slot's code-drawn procedural fallback (the body is never
   hidden).

`gear_uses_procedural_fallback(item_id)` reports whether a slot fell through to
the procedural path.

## Overlay Alignment

Authored overlays are drawn full-frame over the 16x32 body, so each PNG carries
its own placement. When an overlay is baked for a generic head/body height it
can float on a shorter rig -- the crude helmet sat ~6px above the head on the
goblin and dwarf bodies. A data-owned per-rig, per-slot offset corrects this
without editing any PNG: `rigs.<species>.gear_offset` maps a drawn slot
(`helmet`/`torso`/`feet`/`accessory`/`weapon`) to an `[dx, dy]` pixel shift
applied to that slot's overlay draw rect (`gear_overlay_offset(slot)` /
`_gear_rect(slot)`). Absent or unlisted slots resolve to `[0, 0]`, so
already-aligned bodies never move. Goblin and dwarf carry a `helmet` nudge of
`[0, 5]`; every other body/slot is identity. `scripts/art/verify_gear_alignment.py`
enforces helmet/head contact (the helmet opaque top, after its offset, lands
within 4px of the body's opaque top) across all ten body ids. The non-human
crude *torso* overlays sit at the waist (a plausible loincloth style rather than
a clear placement bug); whether they should be re-authored for a chest garment
is left to the art lane, not a code transform.

## Refresh Boundaries

`refresh_presentation()` re-resolves the body from the current character fields
and repaints. It runs at the equipment/forge boundaries (`apply_equipment`,
`equip_item`, `swap_weapon`), and `apply_character` performs the equivalent on
character/world entry and load, so a cleared visual cache or a texture that was
missing at first resolve is picked up and the overlay re-resolves for the
current body. It is presentation only: equipment state, effects, and saves are
untouched.

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

## Action Animation

Tool and weapon use plays a data-driven **windup -> impact -> recovery** cycle
aimed at the target, not a uniform pose loop. The active action is `"mine"`
(pick/axe, a repeating cycle from `mine_progress`) or `"attack"` (the weapon, a
one-shot from the presentation-only `attack_swing` timer set when a melee hit
lands); attack takes priority. Each tool/weapon item owns an `action_profile`
in `data/equipment.json` -- `windup`/`impact`/`recovery` fractions of the swing
that sum to 1.0, an `arc_deg`, and a `direction_mode` -- with
`BlockRegistry.action_profile` merging a default for any item that omits it.

`swing_direction()` is the aim in the visual's mirror-aware space: the mining
target vector or the attack direction, so up/down/diagonal targets read
directionally (the forward x stays positive in the mirrored frame).
`swing_progress()` is the `[0,1)` cycle position, `swing_phase_kind()` reports
the profile segment (`windup`/`impact`/`recovery`), and `_swing_angle_offset()`
sweeps the tool through the arc (raise back on windup, snap through the target
on impact, ease home on recovery). Authored pick/axe swing frames are drawn
rotated toward the aim; anything without swing art (the sword) renders the same
arc procedurally through the same profile. All of this is presentation only: it
reads mining/attack state and never changes damage, mining time, or any
gameplay timing. `presentation_snapshot()` exposes `action_kind`, `action_item`,
`swing_phase_kind`, and `swing_direction`.

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
`swing_phase`, `active_tool_id`, `visible_gear`, `effective_body_id`,
`layer_order`.

`visible_gear` maps each non-empty drawn slot (`weapon`, `helmet`, `torso`,
`feet`, `accessory`) to its equipped item id. `effective_body_id` is the body
id gear resolves against (see Gear Resolution). `layer_order` equals
`CHARACTER_LAYER_ORDER`.

## Guarantees

- Every resolution step has a safe fallback; a missing image degrades to a
  lower tier and finally to procedural drawing, never a crash or an empty
  figure.
- Presentation state (facing, swing, resolved textures, Look) is transient and
  never written to world or character saves.
- This contract documents current behavior; changing it is a deliberate,
  separately reviewed presentation change, not an incidental edit.
