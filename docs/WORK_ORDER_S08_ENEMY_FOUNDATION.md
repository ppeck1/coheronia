# Work Order — S-08.0 Enemy Expansion Foundation

**Status:** ACTIVE (opened after `v0.7-alpha`, release commit `f1509b7`).
**Type:** Behavior-preserving foundation / refactor. **Not** a content or balance arc.
**Authority order:** this document sits at rung 5 of the source-of-truth hierarchy in
[`CLAUDE.md`](../CLAUDE.md); the running game + smoke suite, `data/*.json`,
`docs/VARIABLE_MATRIX.md`, and `docs/HANDOFF.md` outrank it.

## 1. Purpose and hard boundary

S-08.0 builds the smallest useful modular seam set so that *later* enemies can be added
cleanly. This foundation slice is **parity-only**. It must not:

- **Activate any planned enemy** or add a new one. The live set stays **exactly the
  current eight**.
- Add new enemy mechanics, subsystems, effect keys, or effect consumers.
- Change balance: existing enemies keep their measured runtime HP, contact damage, Hall
  DPS, speed, severity, spawn eligibility/caps, dawn policy, and loot scaling.
- Add world content or generation changes.
- Bump `SAVE_VERSION` (`0.6`) or `gen_version` (`5`), or change persistent save formats. A
  behavior-specific saved-state *extension point* may be **defined**, but nothing that
  changes the on-disk format ships here. A real migration is a STOP-and-ask decision.
- Rename or change the meaning of any existing smoke `_check`. New checks are additive;
  the count only rises.

If any requirement here would force a balance, save-format, or mechanic change, **stop and
raise a decision packet** instead of guessing.

## 2. Current live enemy set (the eight)

Authored in [`data/enemies.json`](../data/enemies.json) with `status: "live"`. Values below
are the **authored data**, not the measured runtime effective values (see §4).

| ID | Family | Contact dmg | Speed | `hp_mult` | `hall_dps_mult` | Special (live behavior) |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `surface_slime` | surface | 8 | 38 | 1.0 | — | baseline surface pressure |
| `thornrat` | surface | 4 | 66 | 0.7 | — | `targets_crops`; `spawn_rule` day≥2 |
| `cave_crawler` | underground | 8 | 38 | 1.0 | — | cave ambush |
| `ore_tick` | underground | 3 | 30 | 0.7 | — | ore-vein proximity |
| `lava_slime` | underground | 10 | 26 | 1.2 | — | `lava_immune`; `emits_bubbles` (presentation) |
| `raider_basic` | raider | 8 | 38 | 1.0 | — | raid unit; `spawn_rule` day≥5, stockpile≥25 |
| `raider_torchbearer` | raider | 10 | 34 | 1.5 | 2.5 | `visual_light` (presentation); day≥8, stockpile≥40 |
| `raider_sapper` | raider | 9 | 32 | 1.3 | 1.5 | `breaks_walls`; day≥10, stockpile≥50 |

Everything else in `enemies.json` (`ash_wasp`, `mudling`, `hollow_stag`, `lantern_leech`,
`stoneback_beetle`, `sporekin`, `burrow_maw`, `hungry_deserter`, `false_taxman`, the three
`mini_bosses`, and the two `bosses`) is `status: "planned"` and **must remain non-spawnable**
(see §7).

## 3. Confirmed current-runtime facts (verified against `f1509b7`)

- **HP is not read from `enemies.json.hp`.** `game_root.gd:1787` computes
  `threat.hp = max(1, round(float(threat_hp()) * hp_mult))`, where `threat_hp()`
  (`game_root.gd:1474`) is the shared day-scaled baseline. The `hp` integers in the data are
  therefore **decorative/inert** today.
- **Severity is a shared constant**, not per-definition: `simple_threat.gd:19`
  `const SEVERITY := 10.0` (plus `NIGHT_BASE_SEVERITY`/`STORM_SEVERITY` in `game_root.gd`).
- **Hall DPS** default `4.0`, scaled by `difficulty("enemy") * hall_dps_mult`
  (`game_root.gd:1797`).
- **`density` / `region_density` do not drive spawning** — spawn counts/eligibility live in
  enemy-ID-specific `game_root` growth and `spawn_rule`, not the density blocks.
- **`location` / `role` are descriptive prose**, not implemented logic.
- **Behavior is carried on the shared actor via one-off flags**: `targets_crops`,
  `breaks_walls`, `lava_immune`, `emits_bubbles`, `visual_light`, `hall_dps_mult`.
- **Saved threats** carry only position, HP, max HP, and enemy ID.

These are the truthfulness gaps S-08.0 reconciles — **without changing the effective
numbers**.

## 4. Baseline measurement (first implementation step)

Before touching code, the implementation run must capture the **measured effective runtime
values at `normal` difficulty** for all eight live enemies and pin them in this section:
HP, speed, contact damage, Hall DPS, severity, spawn route, dawn policy, loot, collision
bounds, and special behavior. Those measured numbers become the parity oracle; the refactor
must preserve them exactly at the agreed comparison points.

> Measured-baseline table: **TBD at S-08.0 implementation start** (do not fill with
> un-measured numbers).

## 5. Responsibility map (target seams)

Smallest useful decomposition — do not replace one monolith with another. Each seam is a
clean, stateless-where-possible module with a stable public shim where `game_root`/smoke
depend on it.

1. **Enemy definition / registry** — parse + validate definitions; hand out immutable/copied
   defs by ID; classify `live` / `planned` / `mini-boss` / `boss`; **fail closed** on
   unknown/incomplete/planned. A typo must never silently yield a Surface Slime. Validates
   duplicate IDs, legal families/categories, required live fields, numeric ranges, loot
   refs, behavior/controller refs, spawn refs, and incompatible config.
2. **Enemy factory** — the single construction/configuration path for a live hostile actor
   (stats, loot, presentation, collision, lifecycle, behavior refs). Explicit failure on an
   unknown/non-live ID. Preserves the shims `game_root`/smoke call today.
3. **Shared enemy actor** — common concerns only: health, damage, death, loot dispatch,
   shared render hooks, group membership, serialization delegation. No new ID conditionals
   or growing boolean set. Keeps the `threats` group while consumers depend on it.
4. **Behavior / movement seam** — isolate targeting/movement/obstacle behavior from
   health/rendering via small strategies. Must reproduce, with no gameplay change: ordinary
   Hall pressure, crop targeting, structural wall breaking, lava immunity, lava-slime bubble
   presentation, carried-light presentation. Gameplay abilities stay separate from
   presentation-only effects. **No flying/burrowing/summoning/auras/dialogue/boss phases.**
5. **Encounter / spawn director** — move eligibility + selection out of ID-specific
   `game_root` growth; evaluate explicit context (night/surface, farm pressure, raid, cave,
   ore proximity, lava proximity, day, stockpile, difficulty, active caps). Random selection
   stays injectable/seedable for deterministic tests. Preserve current effective spawn
   behavior and caps; leave delegating `game_root` shims where smoke needs them. **Make the
   density fields truthful inputs or explicitly relabel them design-only** — do not keep
   presenting unused fields as live logic.
6. **Lifecycle / defeat contract** — give each definition an explicit lifecycle/despawn
   policy instead of deriving everything from family; emit enough defeat identity/context
   (XP, contracts, future unlocks, encounter completion) without teaching the shared actor
   about every enemy; define the behavior-specific saved-state extension point (format
   unchanged in this slice).

## 6. Migration plan (parity-preserving, incremental)

1. Measure and pin the §4 baseline; add the parity regression checks in §8 **first** (they
   must pass against current code before any extraction).
2. Introduce the definition/registry as a read-through over `enemies.json` with fail-closed
   classification; route existing reads through it behind shims.
3. Introduce the factory as the sole live-actor constructor; make `_spawn_enemy_at`, test
   spawning, and save restoration go through it and **fail closed** on unknown/planned IDs.
4. Extract the behavior seam strategy-by-strategy (crop, wall-break, lava-immunity,
   bubbles, carried-light), each guarded by its existing smoke check.
5. Extract the spawn director; reconcile density fields (truthful or relabelled).
6. Add the lifecycle/defeat contract + saved-state extension point (no format bump).

Each step: run the focused checks, then the static gate, then windowed source smoke; a seam
that can't be lifted without behavior change is left in place and documented, never forced.

## 7. Social-encounter boundary

`hungry_deserter` and `false_taxman` are **choice-driven encounter/NPC concepts**, not
hostile threat actors, and the repository has **no verified choice-driven encounter system**
today. They must **not** be forced into the hostile actor. They stay `planned` and are
documented here as future encounter/NPC work.

## 8. Acceptance criteria (additive regression checks)

Prove through the **running game** (not source inspection) that:

- The live enemy set is exactly the current eight; each is constructed via the factory.
- Unknown IDs fail closed and create no actor; planned IDs cannot spawn via normal runtime
  or save restoration.
- Each enemy retains its measured HP/damage/speed/Hall-DPS behavior.
- Surface, crop, raid, cave, ore-near, and lava-near eligibility remain correct; difficulty
  scaling is applied exactly once; per-context and per-family caps stay bounded.
- Dawn cleanup preserves underground threats and removes the applicable surface/raid threats
  exactly as before.
- Crop eating, wall breaking, lava immunity, bubbles, and carried light still work.
- Loot still becomes a ground drop with existing collection/hauler behavior.
- Enemy ID, HP, and max HP still round-trip through saves.
- Perception/resonance still hide and reveal hostile actors correctly.
- Player and defender attacks still work through the shared damage contract.
- Existing smoke check names and meanings are preserved; new checks are additive; the count
  only rises.

## 9. Compatibility constraints

- `SAVE_VERSION` `0.6` and `gen_version` `5` unchanged; save ownership split (character vs
  world) preserved; serialized character key stays `role`.
- Public `game_root`/smoke shims stay stable; the `threats` group is preserved.
- One documented source of truth for base HP and one centralized difficulty/day scaling
  function; the same for contact damage, Hall DPS, speed, severity, spawn eligibility/caps,
  dawn persistence, and loot-chance scaling.

## 10. Per-enemy completion contract (for every future activation)

An enemy becomes gameplay-ready only when it has **all** of: approved gameplay role; spawn
context + cap; behavior/controller; complete runtime stats; lifecycle/save policy; an
authored canonical sprite + variants (or an explicitly approved temporary fallback);
collision + targeting bounds; loot metadata; at least one meaningful loot consumer (or
explicitly approved future-use status); a defeat consequence/unlock; static validation;
focused engine smoke; and visual inspection in representative lighting, fog, resonance, and
combat conditions. Data or artwork existing does **not** make an enemy ready.

## 11. Deferred planned-enemy capability matrix

All entries below are `status: "planned"` and blocked on §10. Foundation work only makes
them *possible*, never *active*.

| ID | Category | Family | Capability needed beyond foundation | Notes |
| --- | --- | --- | --- | --- |
| `ash_wasp` | planned | surface | nest spawner (deferred) | burned-forest nest |
| `mudling` | planned | surface | swamp biome/spawn context | swamp construction/weaving loot |
| `hollow_stag` | planned | surface | rare-spawn tuning | premium food source |
| `lantern_leech` | planned | underground | carried-light reuse | cave-pool dweller |
| `stoneback_beetle` | planned | underground | armored/rare cavern spawn | stone-plate loot |
| `sporekin` | planned | underground | cluster spawn | fungal-cave cluster |
| `burrow_maw` | planned | underground | **burrowing** (out of scope) | mine-shaft ambush |
| `hungry_deserter` | planned (encounter) | raider | **choice-driven encounter system** (none exists) | §7 social boundary |
| `false_taxman` | planned (encounter) | raider | **choice-driven encounter system** (none exists) | §7 social boundary |
| `broodmother_crawler` | mini-boss | underground | **summoning** + nest state + mini-boss lifecycle | first planned mini-boss candidate |
| `bandit_standard_bearer` | mini-boss | raider | **aura buff** + raid-frequency influence | organized-raid leader |
| `rotroot_boar` | mini-boss | surface | farm/fence destruction escalation | agricultural threat |
| `hollow_king` | boss | surface | **boss phases** + summon + civic unlocks | governance boss |
| `world_worm` | boss | underground | **burrowing** + terrain destruction + quakes | deep-mining boss |

### Decisions required before Broodmother Crawler (or any planned enemy) can be built

1. **HP authority:** confirm the reconciled base-HP source (keep `threat_hp()` baseline ×
   `hp_mult`, or make per-def `hp` authoritative) — must not change the eight's effective HP.
2. **Save-state extension:** approve the behavior-specific saved-state shape (e.g. nest link,
   summon count) and confirm whether it can ride the existing format or needs a gated
   migration (STOP-and-ask if the latter).
3. **New capability authorization:** summoning (Broodmother), auras (Standard-Bearer),
   burrowing (World-Worm/Burrow Maw), and boss phases (Hollow King) are **explicitly out of
   S-08.0** and each needs its own authorized mechanic slice.
4. **Encounter system:** the social encounters (`hungry_deserter`, `false_taxman`) need a
   verified choice-driven encounter/NPC system before activation.
5. **Loot consumers:** each planned drop needs at least one meaningful consumer or an
   approved future-use status before the enemy ships.
