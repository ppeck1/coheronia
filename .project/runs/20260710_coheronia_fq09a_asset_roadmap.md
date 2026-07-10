# Run Ledger: 20260710_coheronia_fq09a_asset_roadmap

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) implementation lead + 2 haiku read-only scouts + haiku read-only verifier |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09A (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-10T12:20:00-04:00 |
| Ended At | 2026-07-10T13:00:00-04:00 |

## User Request

"push and proceed" — FQ-09W was pushed; FQ-09A (future asset manifest and
prompt packs) is the queue head.

## Agent Protocol Notes

Two haiku scouts ran read-only inventory in parallel: (1) every LIVE
renderable id and its fallback across blocks/items/enemies/equipment/UI
plus the drawn-shape actors with no art path (player, town hall, pulse),
(2) every PLANNED id with citations (FQ-10..FQ-15 queue items, enemies.json
planned/expansion/boss entries, storyboard scene ids, background-template
paths, ancestry phases, future-progression districts). The lead authored
the roadmap and prompt packs. A haiku verifier fact-checked the finished
document id-by-id against the data files: NO FINDINGS across all nine
items (block/item/enemy/equipment sets exact, scene ids exact, wired
background/wall ids exact, validator phrase locks matching, docs
consistent, ancestry claims correct).

## What Shipped (implementation commit `0142e33`, docs-only)

- **`docs/ASSET_ROADMAP.md`** — the FQ-09A authority:
  - Pipeline facts for any art agent: convention paths, no import step,
    fallback-always semantics, FQ-09V variant pools (block variety / 8 fps
    opening cel frames), INFO-only validator gaps, the absolute
    no-baked-text rule, author-at-100% guidance, P1-P3 priorities.
  - Live tables (id, path, size, transparency, current fallback, priority,
    prompt note): 11 blocks, 16 item icons, 3 live enemies, 9 equipment
    icons, 2 back walls, 3 backdrop layers, and the 8 opening cel-frame
    scene ids with their locked rules.
  - Drawn-shape actors needing a renderer extension before art can land:
    player (appearance-colored rects today; per-ancestry sprites with
    recolor masks planned), town hall, attunement pulse.
  - Honest planned tables keyed to queue items: FQ-10 ore families, FQ-11
    stations/ingots, FQ-12 farming, FQ-13+ enemies in mvp_expansion_order
    plus the data-planned roster and bosses, FQ-09M action effects, cave
    walls/backgrounds, phase C-E ancestry sprites (6 dragonkin types),
    FQ-14/15 UI. "Do not produce before the system exists" stated.
  - Per-category prompt packs (blocks/walls, items, enemies, ancestry
    sprites, opening cel frames, scenic backgrounds) under one shared
    preamble compressing the canon bible's palette roles, production rules,
    tone, and avoid list; review gate pointing at the template checklists.
- **Decision**: no `data/asset_manifest.json`. The FQ-09A scope adds a
  machine manifest only if code/validation will consume it; nothing does —
  the runtime resolves all art by convention. The roadmap is the manifest.
  `art/generated/ui/` documented as reserved (no consumer yet).
- `scripts/validate_repo.py`: roadmap required + phrase lock ("Live
  Assets", "Planned Assets", "Prompt Packs", "Never bake words into any
  image"). HANDOFF/VARIABLE_MATRIX/FABLE_TASK_QUEUE updated (FQ-09A Done,
  FQ-09M next).

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. the new roadmap file + phrase locks |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS 210/210 | at 2026-07-10T12:04:53 — docs-only change, suite unchanged as expected |
| `git diff --check` | PASS | exit 0 |
| haiku read-only verifier | NO FINDINGS | roadmap fact-checked id-by-id against blocks/items/enemies/equipment/ancestries data, prologue SCENES, backdrop/wall wiring, validator locks, doc consistency |

## Acceptance vs FQ-09A

- The roadmap separates live assets from planned assets (validator-locked
  headings; planned items marked with their gating queue item).
- Naming and prompt instructions are specific enough for another LLM to
  create candidates without repo archaeology (paths, sizes, transparency,
  per-id notes, category packs, shared preamble, review gate).
- Planned coverage includes ores, furnace/anvil/workbench, crops, enemies,
  tools/armor icons, UI icons, player/ancestry sprites, and action visuals.
- Opening, scenic-background, and backing-wall entries follow their locked
  dimensions, transparency, fallback, layering, and no-baked-text rules.
- Validator remains green; no machine-readable manifest schema was
  introduced (decision documented), so none needed validation.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260710_coheronia_fq09a_asset_roadmap.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260710_coheronia_fq09a_asset_roadmap.json`

## Git Closeout

Implementation commit `0142e33`, then this evidence-only commit. Pushed to
origin/main (operator instruction "push and proceed" governs this session).

## Remaining Risks

- The roadmap is a point-in-time inventory: future queue items must add
  their new ids to it (called out in the doc's own rules) or it drifts.
- Player/town-hall/pulse art remains blocked on small renderer extensions;
  the roadmap flags that the code change ships with the sprites.
- Priorities encode the operator-visible-win-first heuristic (terrain,
  player, hall); the operator may reorder at art time.

## Next Action

FQ-09M (lightweight action animation pass) is the queue head. Art
production can now run in parallel with any increment using the roadmap's
prompt packs.
