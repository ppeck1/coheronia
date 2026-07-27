# R-06 — Incremental Ownership Decomposition (Work Order)

**Status: IN PROGRESS — Slices R-06.1, R-06.2, R-06.3 DONE (2026-07-27).**

**R-06.3 (crest/vessel) shipped 2026-07-27 — scope adjusted; texture-prep seam.**
The crest/vessel *node* subsystem proved to be the worst child-node candidate:
its `update_*` methods are ~90% direct node mutation with almost no portable
math, the vessel nodes are directly smoke-driven (`hud._health_vessel_fill` ×7,
`_attunement_vessel_fill` ×6, `_health_fx` ×7, `update_health` ×11, plus
`vessel_socket`/`replace_vessel_fill`), and the vessel construction is embedded
in the native-kit assembly. Same finding class as R-06.2 — a node lift would add
net coupling. The one genuinely clean seam is the **presentation texture prep**:
`scaled_texture_from` (band tiling) and `glass_mask_from` (the vessel fill-mask
disk — home of the nine-patch-squash "health never drains" bug) moved into
`HudChrome` as pure CPU image builders; `hud.gd` keeps the per-instance caches
(`_scaled_tex_cache`, `_glass_mask_cache`) and the source lookup, delegating only
the build. Seam check `r06_texture_prep_delegates`. **Source smoke 406/406, 0
skipped; validator PASS; capsule healthy; `diff --check` clean; fq19 vessel
liquid/effects and fq21 masking-geometry confirmed byte-identical.**

**Arc note (2026-07-27):** the two biggest clean stateless seams (chrome/theme
resolver, edit geometry) plus vessel texture-prep are now extracted. The
remaining HUD clusters (inventory board, and the crest/vessel *nodes*) are
dominated by node mutation whose internals are directly smoke-driven, so they do
not decompose to child nodes without a wide preserved façade + many back-refs
(net-negative). R-06 is approaching diminishing returns; R-06.4/6.5 should be
weighed against that before starting.

**R-06.2 (edit-mode geometry) shipped 2026-07-27 — scope adjusted from the
original sketch.** During implementation the edit-mode cluster proved to be
bidirectionally coupled and its internals are part of the tested surface
(`smoke_test` drives `hud._hud_widgets` ×14, `hud._hud_widget_size` ×5,
`hud._resize_hud_widget`, `hud._save`/`_load_hud_layout`, `hud._hud_grip_rect`),
and it reaches into ~7 HUD nodes + flags + `_goal_visible` + shared helpers. A
full child-node controller would have required a **wide** preserved façade plus
~15 back-references into `hud` — net *more* coupling. Operator decision
(2026-07-27): extract only the **portable geometry math** into a stateless
helper (mirroring R-06.1), and leave the interactive controller (input,
overlay, drag/resize state, layout load/save/reset) in `hud.gd`. Delivered:
`scripts/ui/hud/hud_edit_geometry.gd` (`RefCounted` static — `widget_size`,
`natural_size`, `min_size`, `max_size`, `grip_rect`, `clamp_position`, plus the
4 geometry tuning consts). `hud.gd` keeps delegating wrappers (`_hud_widget_size`,
`_hud_natural_size`, `_hud_min_size`, `_hud_max_size`, `_hud_grip_rect`,
`_clamp_hud_widget`). Seam check `r06_edit_geometry_delegates`. **Source smoke
405/405, 0 skipped; validator PASS; capsule healthy; `git diff --check` clean;
fq17 grip/reset/clamp and fq21 dock-invariant confirmed byte-identical.**

**R-06.1 (Chrome & theme resolver) shipped 2026-07-27.** The stateless
painted-chrome / themed-PNG resolver and the slicer-geometry parsers were
lifted out of `hud.gd` into `scripts/ui/hud/hud_chrome.gd` (a `RefCounted`
static helper, no `class_name`, preloaded). `hud.gd` keeps thin delegating
wrappers for every symbol still called (`_painted_texture_for_theme`,
`_normalize_hud_visual_theme`, `_load_band_geometry`, `_load_hud_kit_layout`,
`_json_rect`, `_json_vec`); the purely-internal `_themed_texture_matches_fallback`
moved wholesale with no dead wrapper. No public signature, save format, or
behavior changed. Seam check `r06_chrome_resolver_delegates` added. **Source
waited-GUI smoke 404/404, 0 skipped; validator PASS; capsule healthy;
`git diff --check` clean.** (Export verification rides the R-04 push CI.)

This document is the row-level authority for R-06. `docs/HANDOFF.md`,
`docs/FABLE_TASK_QUEUE.md`, and `docs/WORK_ORDER_RELEASE_FOUNDATIONS.md` (R-06
row) point here. Operator approved R-06 as the next code-lane arc on 2026-07-27,
after R-09 (Contracts & Balance) shipped, and requested a design-first review
before any production code — matching how R-09 ran.

R-06 is a **pure structural refactor**: it moves implementation, not behavior.
There is **no new feature, no save-format change, and no smoke-count-driving
new gameplay** in this arc. The value is that `hud.gd` (3,990 lines) and
`game_root.gd` (1,705 lines) — the two concentrated ownership points named in
`WORK_ORDER_RELEASE_FOUNDATIONS.md` finding RF-09 — become extendable without
each future feature deepening the coupling.

---

## 1. Design spine (the rules everything derives from)

1. **The public surface is frozen; only implementation moves.** `hud.gd`
   remains the single Control/CanvasLayer object `game_root` and the smoke
   harness touch. Every one of its ~40 public methods (§4) keeps its exact
   signature and observable result. Extraction replaces a method **body** with
   a one-line delegation to an extracted collaborator — never a change to what a
   caller sees. Same for `game_root.gd`'s public surface in the session slice.

2. **No save-format change, no version bump.** Unlike R-09, R-06 touches no
   persisted schema. The only HUD-adjacent persisted state is the widget layout
   `hud.gd` writes into `shell.json` (via `reset_hud_layout` / edit-mode save).
   Its keys, value ranges, and round-trip behavior stay **byte-identical**.
   `save_manager.SAVE_VERSION` is unchanged. A refactor that would alter a saved
   key is out of scope and must be rejected in review.

3. **Extract along the seams the code already has, not new ones invented for
   tidiness.** Each extracted collaborator maps to one of the responsibility
   clusters `hud.gd` already documents in its own section headers (§4). We do
   not re-architect the HUD; we lift existing clusters behind a preserved
   façade.

4. **Existing coverage pins behavior; new checks pin the seam.** Every cluster
   already has focused smoke coverage (fq15/17/19/20/21, pr06/08, r07 — §4).
   Those checks **must stay green untouched** through each extraction — that is
   the regression proof. Each slice additionally adds one `r06_*` check that
   asserts the delegation seam itself (the façade forwards to, and reflects, the
   extracted collaborator).

5. **Historical fallback paths are retired only after export verification.**
   Pre–native-kit HUD fallback branches (dead under the shipped native kit) are
   removed only in the final slice, and only once an **exported** build has
   confirmed the native-kit path — never speculatively during an extraction.

## 2. Operator decisions (locked)

- **Façade-preserving extraction, not a rewrite.** `hud.gd` keeps `extends
  CanvasLayer` and its node identity; collaborators are instantiated and owned
  by `hud.gd`. Callers never learn the internal structure changed.
- **Collaborator kind by state ownership:**
  - Clusters that own **live scene nodes** (crest bars, inventory board,
    edit-mode overlay) extract to a **scripted child node** that `hud.gd`
    adds and delegates to (`scripts/ui/hud/<name>.gd`).
  - Clusters that are **stateless transforms** (painted-chrome/theme PNG
    resolution, slicer geometry math) extract to a **`RefCounted`/static
    helper** with no scene state.
- **One subsystem per slice; each slice separately committed and operator-gated;
  full suite green (source + exported) before the next slice starts.** No
  slice may leave `hud.gd` half-migrated across a commit boundary.
- **No behavior change is permitted to ride along.** If review finds a latent
  bug in a cluster being extracted, it is logged and fixed in a **separate**
  commit with its own coverage — never folded into the mechanical extraction,
  so a green→green extraction stays bisectable.
- **`game_root.gd` decomposition is included but sequenced last** (R-06.5),
  after the HUD seams are stable, because the HUD is the larger and more
  self-contained target and de-risks the pattern first.

## 3. Decomposition strategy (why this is safe)

`hud.gd` is already a **stable façade**: `game_root` drives it through a clear,
shallow API (§4 lists the exact call surface — every call is a method, none
reach into HUD internals). That property is what makes this refactor low-risk:

- The **coupling surface does not move**, so `game_root`, `shell_ui`, and the
  smoke harness are untouched by extractions R-06.1–R-06.4.
- Each extraction is a **mechanical lift**: move a cluster's fields + methods
  into a collaborator, replace the `hud.gd` bodies with delegations, wire the
  collaborator in `_ready`.
- **Green-to-green** is enforced per slice by the pre-existing cluster checks
  plus a new seam check. A behavior regression shows up as a flipped existing
  check; a broken seam shows up as the new `r06_*` check.

The end state: `hud.gd` shrinks to a thin composition root (node construction,
public façade, delegation) with the heavy logic in ~5 focused collaborators.

## 4. `hud.gd` responsibility map → extraction targets

Clusters are taken from `hud.gd`'s own section headers and its public surface.
"Pinned by" lists the existing checks that guard the cluster's behavior across
the lift.

| Cluster | Representative public surface | Origin | Pinned by (existing) | Slice |
|---|---|---|---|---|
| **Painted-chrome / theme resolver** (stateless): themed `<asset>__<theme>.png` lookup + fallback; slicer-measured orb/band geometry sidecars | `hud_visual_theme_id`; internal `_resolve_themed_texture`, orb/band geometry consts | FQ-20/21 | `fq21_hud_theme_asset_fallback`, `fq21_hud_masking_and_cushion_geometry` | R-06.1 |
| **Edit-mode controller**: drag / corner-grip resize, widget registry, natural-size defaults, layout reset + `shell.json` persistence, edit overlay draw | `toggle_hud_edit_mode`, `is_hud_edit_mode`, `reset_hud_layout` | FQ-17/20/22 | `fq17_hud_edit_direct_manipulation`, `fq20_docked_command_center`, `fq21_dock_layout_v5_invariant` | R-06.2 |
| **Crest / vessel subsystem**: health/attunement/settlement bars, vessel sockets + fills, attunement effects, crest resource rows | `update_health`, `update_attunement`, `update_settlement`, `update_progression`, `vessel_socket`, `replace_vessel_fill` | FQ-19/21 | `fq19_crest_goal_blueprint`, `fq19_vessel_liquid_and_effects`, `fq21_vessel_socket` | R-06.3 |
| **Inventory board / toolbelt**: hotbar tiles, inventory board, drag/drop sort, dock/backpack/equipment/stockpile grids | `update_inventory`, `toggle_inventory_panel`, `can_drop_inventory_slot`, `drop_inventory_slot`, the `*_grid_count` / `*_cell` / `dock_slot_*` accessors | FQ-07/09 | `fq09_inventory_board_drag_and_sort`, `fq07_*`, `r07_craft_panel_gating_and_source` | R-06.4 |
| **Session services (`game_root`)**: save/load orchestration, panel toggle routing, HUD event wiring, day/tick pushes | `game_root` internals; HUD `update_time` / `set_save_hint` / `notify_saved` call sites | RF-09 | `r07_pause_freezes_and_resumes`, `r07_pause_restore_reloads_save`, save/load smoke | R-06.5 |
| **Historical fallback retirement** (after export verify) | dead pre-native-kit branches | — | `fq21_hud_kit_primary` | R-06.6 |

Clusters intentionally **left inside `hud.gd` for now** (small, low-churn, no
extraction value this arc): goal panel (`update_goal`), mini-map
(`toggle_map`/`update_map`), Town Hall panel (`toggle_town_panel`), event log
(`log_event`), F3 debug overlay, and the interaction/pickup toasts
(`set_interaction_prompt`/`notify_pickup`/`notify_saved`). They may become a
later slice if they grow, but pulling them now adds risk without payoff.

## 5. Per-slice seam contract (the delegation shape)

Every extraction follows the same shape so review is uniform:

1. **Create the collaborator** `scripts/ui/hud/<cluster>.gd` owning the cluster's
   former fields and private methods verbatim (no logic edits).
2. **Instantiate + wire** it in `hud.gd._ready()` (child node) or hold it as a
   member (stateless helper). Give the collaborator a back-reference only if it
   already read those `hud.gd` fields; prefer passing what it needs.
3. **Replace each moved public method body** in `hud.gd` with a one-line
   delegation (`return _crest.update_health(h, max_h)`), preserving signature
   and return type.
4. **Signals**: HUD-owned signals (`deposit_requested`, etc.) stay declared on
   `hud.gd`; a collaborator that needs to emit does so via the façade or a
   forwarded connection, so external `connect()` sites are unchanged.
5. **Add `r06_<cluster>_delegates`**: asserts the façade method produces the
   same observable result now sourced from the collaborator (e.g. the crest
   collaborator exists as a child, and `update_health` moves the same bar the
   check read before).

## 6. Invariants (must hold every slice)

- Public method signatures on `hud.gd` and `game_root.gd`: **unchanged**.
- `shell.json` HUD-layout keys and round-trip: **byte-identical** (verify by
  save→reset→save diff in the seam check).
- `save_manager.SAVE_VERSION`: **unchanged** (no world/shell schema touch).
- Every pre-existing fq15/17/19/20/21, pr06/08, r07 check: **green, unedited**.
- No new gameplay, no data/asset changes (so `asset_audit` is untouched unless a
  slice genuinely moves an asset path — none is expected).
- Exported Windows smoke set-equal to today's 6-fixture skip allowlist; no new
  skips introduced by extraction.

## 7. Validation additions (`validate_repo.py`)

R-06 adds **no data schema**, so validator changes are minimal:

- If any script moves to a new path under `scripts/ui/hud/`, ensure the file
  presence/asset audits that enumerate `scripts/` still pass (the validator is
  path-tolerant today; confirm, do not weaken).
- No new required-file or vocab rule is expected. If a slice needs one, it is
  called out in that slice's commit, not pre-committed here.

## 8. Slice matrix

| Slice | Scope | Extracted collaborator | New seam check(s) |
|---|---|---|---|
| **R-06.1 — Chrome & theme resolver** ✅ DONE | Lift the stateless painted-chrome / themed-PNG resolver + slicer geometry math out of `hud.gd`. No live state moves. Proves the extraction pattern end-to-end on the safest seam. | `scripts/ui/hud/hud_chrome.gd` (`RefCounted`/static) | `r06_chrome_resolver_delegates` — **source 404/404** |
| **R-06.2 — Edit-mode geometry** ✅ DONE (scope adjusted) | Original sketch was a child-node controller; found net-negative coupling (see status note). Delivered instead: lift the **portable geometry math** (measure / min-max / grip / clamp) to a stateless helper; interactive controller stays in `hud.gd`. | `scripts/ui/hud/hud_edit_geometry.gd` (`RefCounted`/static) | `r06_edit_geometry_delegates` — **source 405/405** |
| **R-06.3 — Crest / vessel** ✅ DONE (scope adjusted) | Node subsystem is smoke-driven + embedded in kit assembly (net-negative to lift). Delivered instead: presentation **texture prep** (`scaled_texture_from` + `glass_mask_from`) into `HudChrome`; caches + node ownership stay in `hud.gd`. | `scripts/ui/hud/hud_chrome.gd` (extended) | `r06_texture_prep_delegates` — **source 406/406** |
| **R-06.4 — Inventory board / toolbelt** | Lift hotbar, inventory board, drag/drop sort, and all dock/backpack/equipment/stockpile grid accessors. Largest cluster. | `scripts/ui/hud/hud_inventory_board.gd` (child node) | `r06_inventory_board_delegates` |
| **R-06.5 — `game_root` session services** | After HUD seams settle, lift save/load orchestration + panel-toggle routing + HUD event wiring into a session service `game_root` owns. Public `game_root` surface preserved. | `scripts/main/session_services.gd` (child node / `RefCounted`) | `r06_session_services_delegates` |
| **R-06.6 — Retire historical fallbacks** | Remove pre–native-kit HUD fallback branches now dead under the native kit. **Only after** an exported build confirms the native-kit path in R-06.1–06.4. | (deletions) | `r06_no_dead_hud_fallback` (asserts kit-primary path is the only path) |

Slices land in order. R-06.5 and R-06.6 are re-confirmed with the operator
after R-06.4 ships, since their value depends on how clean the HUD seams end up.

## 9. Acceptance tests (smoke) mapped to constraints

| Check | Proves | Slice |
|---|---|---|
| *(all existing fq/pr/r07 HUD checks)* | behavior unchanged across the lift — the regression proof | every |
| `r06_chrome_resolver_delegates` | themed-PNG resolution + geometry come from the extracted helper; fallback still base-PNG | 1 |
| `r06_edit_geometry_delegates` | `_hud_widget_size`/`_hud_grip_rect` delegate identically; min/max/clamp math holds on fixed inputs (incl. no-slack band axis) | 2 |
| `r06_texture_prep_delegates` | glass-mask + scaled-texture build in HudChrome produce identical dimensions; null-safe; hud wrappers cache + delegate | 3 |
| `r06_inventory_board_delegates` | `update_inventory` + drag/drop + grid accessors route through the board node with identical counts | 4 |
| `r06_session_services_delegates` | save/load + panel routing run through the session service; `game_root` public surface unchanged | 5 |
| `r06_no_dead_hud_fallback` | native kit is the sole HUD path post-retirement; exported build confirmed first | 6 |

## 10. Constraint checklist

Public façade frozen ✓ · implementation-only movement (no behavior change) ✓ ·
no save-format change / no version bump ✓ · `shell.json` layout byte-identical ✓
· extract along existing clusters, not invented seams ✓ · existing cluster
checks stay green untouched (regression proof) ✓ · one seam check per slice ✓ ·
one subsystem per slice, separately committed + operator-gated ✓ · latent-bug
fixes split into their own commits (bisectable) ✓ · fallback retirement only
after export verification ✓ · `game_root` decomposition sequenced last ✓ · no
new gameplay / data / asset churn ✓ · exported skip allowlist unchanged ✓ ·
docs/README/wiki/smoke-counts updated only **after** CI ✓ · commit only when
gated, never push unless told ✓.

## 11. Closeout standard (every slice)

1. `python scripts/validate_repo.py`
2. `python scripts/asset_audit.py --strict` (only if a slice moves an asset path)
3. `python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo`
4. Waited-GUI Godot smoke with a freshness-checked `smoke_results.json`
   (source), plus the exported-build run per the R-04 CI verifier — the
   pre-existing HUD checks must stay green and the new `r06_*` seam check must
   pass.
5. Update this work order's slice state, `docs/HANDOFF.md`, and the queue with
   actual pass/fail evidence — never aspirational numbers.
6. Commit only when the operator gates it; never push unless told.
