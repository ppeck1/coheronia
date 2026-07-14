# Run Ledger: 20260714_coheronia_fq13p2_ui_placeholders

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Opus 4.8) implementation lead, remote-control session |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-13P2 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-14T09:40:00-04:00 |
| Ended At | 2026-07-14T09:55:00-04:00 |

## User Request

"proceed with P2-P4" — continue the FQ-13P arc. This run is FQ-13P2 (deliberate
UI placeholder art + the first live hook).

## What Shipped (implementation commit `8bb4eb1`)

- **`scripts/gen_ui_placeholders.py`** — generates the fifteen reserved UI hook
  ids as recognizable 32×32 RGBA glyphs into `art/generated/ui/`: framed slots
  (normal/selected/invalid), health/attunement orb rings + fill mask, dock
  backplate, six nav buttons (backpack/helmet/hall/skill-star/scroll/gear), and
  valid/invalid drag cursors. One shared palette + 1px border language,
  nearest-friendly, deterministic and idempotent. The generated PNGs are
  committed.
- **`scripts/ui/hud.gd`** — the hotbar slots now frame with `slot_inventory` /
  `slot_inventory_selected` via `_make_slot_style` → `StyleBoxTexture`, falling
  back to the original `StyleBoxFlat` when the image is absent (missing art is
  never an error). The `_slot_normal_sb` / `_slot_selected_sb` types widened to
  `StyleBox`.
- **`scripts/asset_audit.py`** — UI-aware classification: `UI_CONSUMED`
  (`slot_inventory*`) report `LIVE`; the rest are `PLACEHOLDER_AUTHORED`
  (reserved for the HUD redesign, not orphans); the reserved-hook report splits
  authored vs still-missing. Audit: 0 findings, 0 data bugs.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0 |
| `python scripts/asset_audit.py --strict` | PASS | exit 0 (0 findings, 0 data bugs; 15 UI at 32×32) |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 291/291 | 3 new `fq13p2_*` checks green |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

The 3 `fq13p2_*` checks: `fq13p2_ui_placeholders_present` (slot/button/orb load
through the `ui` convention), `fq13p2_slot_frame_consumed` (the live hotbar slot
uses a `StyleBoxTexture` — normal, selected, and slot 0), and
`fq13p2_missing_ui_falls_back` (a bogus ui id → `visual_texture` null and the
code-drawn `StyleBoxFlat` fallback). Suite 288 -> 291.

## Placeholder Policy Compliance

The placeholders are **deliberate generated placeholders** (spec category 2):
recognizable function glyphs, one shared palette + border language,
nearest-friendly, stable ids/paths, listed in `docs/UI_ASSET_GAPS.md`, and
replaceable without touching gameplay code — not ambiguous temporary artwork and
not meaningless colored squares. A scaled contact sheet was visually reviewed
before commit.

## Acceptance vs FQ-13P2 scope

- Reserve/consume stable UI ids. [done — `RESERVED_UI_IDS` authority; the ui
  convention picks up the files]
- Deliberate generated placeholders, not colored squares, with a shared palette
  and border language. [done — 15 glyphs, visually reviewed]
- Every UI asset has a code-drawn/generated fallback; missing art never appears
  as a broken box. [done — `_make_slot_style` `StyleBoxFlat` fallback;
  `fq13p2_missing_ui_falls_back`]
- First live consumption proves the hook end-to-end. [done — hotbar slot
  frames]

Deferred to FQ-13P3+/HUD redesign: consuming the orb/nav-button/dock/cursor
placeholders (the current HUD has bars, not orbs, and no nav dock).

## Review

Self-reviewed the diff (no agent spawned). Verified: the slot placeholder is
consumed only when present (StyleBoxTexture) and degrades to the exact prior
StyleBoxFlat otherwise (no visual regression risk on missing art); the selected/
normal swap still works with the widened `StyleBox` type; `--strict` enforces
the 32×32 UI dimension so a bad regen fails CI; the audit no longer reports the
authored placeholders as problems.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260714_coheronia_fq13p2_ui_placeholders.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260714_coheronia_fq13p2_ui_placeholders.json`

## Git Closeout

Implementation commit `8bb4eb1` (generator, 15 PNGs, hud, audit, smoke, docs),
then this evidence-only commit. Pushed to origin/main after evidence.

## Remaining Risks

- The orb/nav/dock/cursor placeholders are authored but unconsumed until the HUD
  redesign; they are validated (32×32) and documented, not wired.
- The slot frame is a 9-sliced 32×32 texture stretched over the 42×46 slot;
  visual polish (exact margins) is tunable in `_make_slot_style`.

## Next Action

FQ-13P3 — player full-body cosmetic pool (design locked in P0: character-owned
`visual_variant`, presentation-only, never saved). Then FQ-13P4 (opening
variant-vs-animation-frame distinction + block/item variation follow-through).
