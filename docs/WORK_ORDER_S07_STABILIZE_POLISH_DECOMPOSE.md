# S-07 — Stabilize, Polish & Bounded Decomposition (Work Order)

**Status: LOCKED (operator, 2026-08-06) — 6 slices scoped from the 2026-08-06
architecture/polish review; decisions locked in §3. Canonical validation is the
**windowed** smoke run (clean); CI is the authoritative pass/fail evidence. The
`r06_texture_prep_delegates` check is **renderer-dependent** (dummy-renderer
texture scaling) and is skipped under the headless display server — not a
regression, see S-07.0. Per-slice commit SHAs and check counts below are
historical per-slice evidence; do not read them as the current head.**

> **Closeout A (this pass) — fail-closed truth boundary.** On top of the slices
> below: (1) `scripts/ci/verify.py` is now fail-closed (a crash, fatal marker,
> nonzero exit, stale/foreign, or inconsistent smoke result can no longer be
> masked by a PASS-shaped JSON), with `scripts/ci/test_verify.py`. (2) The
> runtime seven-goal onboarding contract is reconciled across README /
> PLAYTEST_CHECKLIST and the shipped crafting route, guarded by
> `s07_goal_contract` + `scripts/ci/test_onboarding_contract.py`. (3)
> `docs/wiki/skills.md` is generated from data and `generate_wiki.py --check` is a
> CI-blocking drift gate. (4) Root `CLAUDE.md` added; v0.1 prompt archived;
> volatile counts/SHAs replaced with nonvolatile language + CI evidence.

This is the **stabilization arc toward `v0.7-alpha`**, not a new mechanics arc.
Its authority is the 2026-08-06 review (findings ledger, §1). The through-line:
the game is behaviourally stable and honestly documented; the remaining risk is
**maintainability drift** (four concentrated ownership points) and **presentation
polish** (modal occlusion, panel density, swing art), plus one **balance
uncertainty** (Calling channel stacking) that must be measured before it is
touched. Every slice is green-to-green: no slice may leave a subsystem
half-migrated across a commit boundary, and existing check names/results are
preserved.

**Sequencing rule (from the review's recommended order):** cheap truth/polish
first, then measure balance, then structural decomposition — because
decomposition carries the most regression risk and benefits from a stable,
well-lit baseline. Structural slices (S-07.3–S-07.5) are explicitly gated by the
**R-06 lesson**: façade/file decomposition only pays where **portable stateless
logic** exists; node-mutation clusters whose internals are directly smoke-driven
are net-negative to lift and must be left in place (see
`docs/WORK_ORDER_R06_OWNERSHIP_DECOMPOSITION.md`, which already assessed and
closed the `game_root` and inventory-board lifts as not-beneficial). This arc
does **not** re-open those; it takes only the seams R-06 did not evaluate and the
new ones the 2026-08-06 review named.

---

## 1. Findings ledger (the review — this is the authority)

Line counts and callers verified against `origin/main == 10cafef`.

| # | Finding | Evidence (verified) | Slice |
|---|---|---|---|
| **F1** | `smoke_test.gd` is monolithic — the largest architectural liability | `scripts/main/smoke_test.gd` = **8,149 lines**, `_run()` linear-procedural, ~530 `_check()` calls, no registry; grouped only by `# ---` comment markers; checks already arc-prefixed (`wd_`/`r06_`/`fq*`/`pr*`/`shell_`/`save_`) and bucketed by `_suite_bucket` | S-07.3 |
| **F2** | `hud.gd` is a god object (HUD assembly, dock chrome, char panel, inventory, hotbar, Town Hall, stockpile, map, goals, events, skill panel, work-zone, layout edit, render refresh) | `scripts/ui/hud.gd` = **3,869 lines** | S-07.4 |
| **F3** | `game_root.gd` is becoming the second god object (time/weather, threats, cave spawn, citizens, contracts, saves, progression, Callings, crafting, settlement, HUD refresh) | `scripts/main/game_root.gd` = **2,379 lines**. Next seams named: `threat_director`, `progression_service`; **preserve the Calling resolver API** as the seam | S-07.4 |
| **F4** | `world.gd` owns too many concerns (terrain, render/tilesets, lighting, backing walls, crops/trees, mining/placement, liquid, serialization, spatial queries) | `scripts/world/world.gd` = **1,426 lines** | S-07.4 |
| **F5** | Two **unbounded full-grid** query methods scan the whole `cells` dict and have **no live callers** — a latent regression risk | `world.gd:714 nearest_ripe_crop`, `world.gd:772 nearest_plantable_soil`. Only references are the doc + the **bounded `*_in` variants** the perf fix already routes through (`nearest_ripe_crop_in`/`nearest_plantable_soil_in`). The unbounded originals are dead. | S-07.5 |
| **F6** | Modal presentation is unfinished — irrelevant HUD modules and the red placement-preview square show through behind modal panels | player-facing, in `known_issues.md` | S-07.1 |
| **F7** | Calling panel: horizontal scrollbar; text too dense; weak inspector hierarchy | player-facing | S-07.1 |
| **F8** | Town Hall panel: instructions too long; settler roster starved of vertical space; competing information | player-facing | S-07.1 |
| **F9** | 640×360 character-creation screen is legible-but-cramped | player-facing | S-07.1 |
| **F10** | Swing art: pick/axe/sword timing & direction are sound, but authored frames are too posed — combat feels mechanical | art, not code | S-07.1 |
| **F11** | **Balance risk (highest gameplay-quality risk):** some effects compressed onto shared scalar channels → several Paths feel repetitive; conditional stacking can reach ~4–5× on some channels. Documented honestly in the repo. **Measure before changing.** | `docs/CALLING_EFFECT_MATRIX.md`, `docs/VARIABLE_MATRIX.md` | S-07.2 |
| **F12** | **Doc freshness:** `HANDOFF.md` says screenshots were *not* regenerated after view-zoom and hedges on push status — but `10cafef` (on `main`) regenerated the tour and everything is pushed | `HANDOFF.md:28–32`; `HEAD == origin/main == 10cafef` confirmed | S-07.0 |

---

## 2. Design spine (the rules everything derives from)

1. **Behaviour is frozen; this arc moves implementation, tunes data, and polishes
   presentation — it does not add mechanics.** No new subsystem, no save-format
   change, no `SAVE_VERSION` bump, no `gen_version` bump. The one exception is
   S-07.2, which changes **balance numbers in data only** (no new channels, no new
   effect wiring) and is explicitly gated by playtest evidence.

2. **Existing check names and results are preserved.** The smoke split (S-07.3)
   and every extraction (S-07.4) must keep the exact `_check("<name>", …)` names
   and their pass/fail semantics. The count only ever goes **up** (new seam
   checks), never down, and no existing check is renamed or weakened. The
   coordinator emits one `smoke_results.json` in the same schema
   (`_suite_bucket` groupings unchanged).

3. **Decompose only along clean stateless seams (the R-06 gate).** A file/method
   is a valid extraction target **only** if the moved code is portable logic with
   a narrow interface. Clusters dominated by live-node mutation whose internals
   are directly smoke-driven are **left in place** — lifting them adds a wide
   façade + back-references = net-more coupling (R-06's documented finding). Each
   candidate in S-07.4 is profiled against this gate first; a candidate that fails
   it is recorded as CLOSED-not-beneficial, exactly as R-06.4/6.5/6.6 were.

4. **Player-facing polish before structure; measure balance before tuning it.**
   The order in §7 is deliberate: truth/polish (S-07.0/1) ship visible value
   cheaply and stabilize the baseline; balance (S-07.2) is a **measure-then-tune**
   loop, not a redesign; structure (S-07.3/4/5) lands last because it is the
   riskiest and benefits from a lit, stable, well-covered baseline.

5. **Existing coverage pins behaviour; new checks pin the new seam.** Every
   structural slice keeps the pre-existing checks green **untouched** (the
   regression proof) and adds a focused `s07_*` seam/guard check. A behaviour
   regression shows as a flipped existing check; a broken split/extraction shows
   as the new check.

6. **Docs reflect only shipped truth, updated after CI — never aspirational.**
   `HANDOFF.md`, `known_issues.md`, `README.md` smoke badge, and the relevant
   matrices are updated with **actual** evidence at each slice's closeout.

## 3. Operator decisions (LOCKED 2026-08-06)

Locked by the operator. These govern the arc; a slice may not silently deviate.

- **D1 — Headless smoke flake (S-07.0): LOCKED — windowed is canonical;
  document, don't chase.** Canonical validation is the **windowed** smoke run
  (clean; CI is the current evidence). `r06_texture_prep_delegates` is
  **documented as renderer-dependent** (texture scaling under the headless dummy
  renderer differs
  from a real surface) and is **not** asserted as a hard failure in headless —
  it is skipped/xfail there with a comment pointing here. We do **not** invest in
  making the texture-prep math renderer-independent for a cosmetic headless green.
- **D2 — Modal occlusion treatment (S-07.1, F6): LOCKED — full isolation.**
  Full-screen dimming scrim + hide the placement preview + suppress non-modal HUD
  input while a modal is open (the "most finished" option), gated behind an
  `is_modal_open` state.
- **D3 — Calling balance (S-07.2, F11): LOCKED — DEFERRED until hands-on
  playtest evidence.** S-07.2 is **measure-first**: extend the playtest checklist,
  run the 3-Calling playtest, and **record** the measured stacking. **No tuning
  is applied until that evidence exists.** Only then is the cap / channel
  de-duplication (re-pointing, never adding, effects) authored. The skill tree is
  **not** re-opened speculatively.
- **D4 — Swing / action-FX polish (S-07.1, F10): LOCKED — APPROVED, bounded.**
  A bounded **existing-system** swing/action-FX polish pass: improved authored
  frames + action feedback for the three existing tools (pick/axe/sword). **No**
  new weapon-animation system, no new mechanics. Art-lane; may run parallel.
- **D5 — Structural appetite (S-07.4): LOCKED — clean seams only, no broad
  refactor.** **No wholesale monolith rewrite.** Only **clean stateless seams**
  may be extracted, each profiled against the R-06 gate (§2.3). Every candidate
  is profiled; only the clean ones ship. A candidate failing the gate is recorded
  CLOSED-not-beneficial and **left in place** — never forced.

**Global lock (all slices): preserve all gameplay mechanics and save contracts.**
No behaviour change, no `SAVE_VERSION`/`gen_version` bump, no persisted-schema
touch. S-07.2 changes balance **data values** only (no new channels/wiring).

## 4. Files touched (by slice)

| Slice | Primary files | Kind |
|---|---|---|
| S-07.0 | `docs/HANDOFF.md`, `scripts/main/smoke_test.gd` (or CI runner) for the flake classification | docs + test-meta |
| S-07.1 | `scripts/ui/hud.gd` (modal gate, Calling/Town Hall panels), char-create screen script/scene, swing-art PNGs under `assets/…` | code + art |
| S-07.2 | `data/character_data.json`, `data/progression/perks.json`, `docs/CALLING_EFFECT_MATRIX.md`, `docs/PLAYTEST_CHECKLIST.md` | data + docs |
| S-07.3 | new `scripts/main/smoke/smoke_*.gd` files + thin `smoke_test.gd` coordinator | test |
| S-07.4 | new `scripts/ui/hud/hud_*_controller.gd`, `scripts/main/threat_director.gd`, `scripts/main/progression_service.gd`, `scripts/world/world_*.gd`; delegating shims in the god files | code (refactor) |
| S-07.5 | `scripts/world/world.gd` (remove/bound the 2 dead query methods) | code |

## 5. Slice matrix

| Slice | Scope | Exit gate | New check(s) |
|---|---|---|---|
| **S-07.0 — Truth & flake classification** ✅ DONE | Fix `HANDOFF.md` freshness (F12): state screenshots refreshed in `10cafef`, drop the "confirm before pushed" hedge (all on `main`). Classify the headless `r06_texture_prep_delegates` flake per D1. | **DONE:** `HANDOFF.md` reconciled to git reality; `smoke_test.gd` guards the seam under `DisplayServer.get_name() == "headless"` → `_skip(...)` with a comment citing D1. Headless run **531/531 passed, 1 skipped** (`skipped_names=[r06_texture_prep_delegates]`, `failed=[]`) — deterministically green. Windowed path unchanged (identical `_check` in the `else` branch → 532/532 holds). | (test-meta only) |
| **S-07.1a — Modal occlusion (functional)** ✅ DONE | F6 functional half of D2: one global flag `GameState.modal_panel_open` (set from the 4 modal toggle sites via `hud._refresh_modal_presentation()`) freezes gameplay input (`player.gd` shares the `craft_panel_open` gate) and suppresses the build-preview ghost (`build_preview.suppressed()`). No mining/placing through an open menu; the placement square no longer floats over a modal. | **DONE:** windowed **533/533** clean (canonical); headless 532 pass + 1 skip, 0 fail. Verified both paths. | `s07_modal_occludes_hud` ✅ |
| **S-07.1b — Visual/panel/art polish** ✅ DONE (operator-reviewed) | The taste/art half. **DONE (2026-08-09, operator-reviewed captures via `COHERONIA_HUD_QA=1` → `user://hud_qa`):** (1) **dim scrim** — full-viewport `ColorRect` (0.58 dark) ordered just under the active modal via `move_child` in `_refresh_modal_presentation()`, absorbs stray clicks; (2) **F7 Calling panel** — `SCROLL_MODE_DISABLED` on the horizontal axis + canvas min-width fixed to the exact content extent (the old `N*(col_w+gap)` overcounted one trailing gap → the h-scrollbar); two balanced cards, holds at 640×360; (3) **F8 Town Hall density** — trimmed stockpile instruction (small/dim), shortened Repair label, promoted "Settlers" header, reserved roster height + panel 320×360→330×400; QA harness spawns a crew so the roster shot is real; (4) **Town Hall roster reordered ABOVE the stockpile + action buttons** (operator-requested) — roster reads directly under the hall status ("who's here" before "what you can do"); actions move below via scroll. **REMAINDER NOW SHIPPED (art lane, operator-reviewed):** (5) **F9 responsive 640×360 char-create** — a physical-window-width trigger (≤900) raises logical type above `CC_FONT_FLOOR`, tightens margins/rows, reflows the preview beside the form, disables horizontal scroll, and pins Create/Back outside the vertical scroll; 1280×720 output unchanged (guard `s07_char_create_640_legibility_contract`). (6) **F6 scrim-strength taste knob** — `display_settings.gd` owns `modal_scrim_strength` (0.30/0.58/0.85), re-read each modal open, with a pause-menu "Modal Dim" slider (guard `s07_scrim_strength_knob`). (7) **F10 swing action-FX** — `action_fx.gd` `swing_arc` crescent spawned toward the aim on weapon/mine strikes (guard `s07_swing_arc_fx`). (8) **F10 sword swing family** — `scripts/art/gen_tool_swing_frames.py` generates authored swing overlays for all four sword tiers (`sword_crude/iron/bronze/obsidian`) across every body id/variant/phase (120 PNGs), resolved via `<tool>_<body>_swing_<phase>` (guard `s07_sword_swing_frames_authored`; `pr04_sword_uses_action_contract` updated to the authored-frame truth). **ONLY REMAINING (optional):** less-posed hand-authored pick/axe swing frames (D4 art-lane polish, not blocking). | Calling panel has no h-scroll and doesn't clip (✓ verified 1280 + 640×360); Town Hall trimmed + roster reserved; scrim behind every modal; char-create legible/operable at 640×360; sword renders authored swing frames. Windowed smoke 540/540 green. | `s07_calling_panel_no_hscroll` ✅, `s07_char_create_640_legibility_contract` ✅, `s07_scrim_strength_knob` ✅, `s07_swing_arc_fx` ✅, `s07_sword_swing_frames_authored` ✅ |
| **S-07.2 — Calling balance: measure then tune** | Extend `PLAYTEST_CHECKLIST.md` across all 3 Callings; run the hands-on playtest; **record measured stacking on the hot channels**; then apply the D3-locked tuning (data-only: cap stacking, de-dup the most repetitive channel by re-pointing effects). No new channels/wiring. | Playtest notes captured; measured worst-case stack documented; tuning applied in data with matrix updated; no effect goes inert; smoke green. | `s07_calling_stack_cap_holds` |
| **S-07.3 — Smoke suite decomposition** ⏸ PAUSED at 4/~10 clusters (operator switched 2026-08-07) — the 4 cleanly-separable clusters are shipped; the remaining tightly-coupled core (world-gen/player-combat/callings/ui-hud/persistence/assets) needs a shared `ctx.scratch` design before continuing. | Split `smoke_test.gd` (F1) into bounded per-domain files behind a **thin coordinator**. **DESIGN FINDING (2026-08-06 map):** the 7 domains are heavily **interleaved** and execution order is **load-bearing** (shared `world`/`GameState.current_config`/`current_character` mutation chain, `original_config` capture→restore 552→977, cross-section locals e.g. `wood_cell`). So this is an **ORDER-PRESERVING** coordinator — `_run()` becomes an ordered sequence of `await <module>.<section>(ctx)` calls in the **exact current order**; section bodies move to domain files (`smoke_world_generation/persistence/player_combat/callings/ui_hud/settlement_subjects/assets_and_rendering.gd`). A shared `ctx` carries `harness`+6 handles+`root`+a `scratch` dict for the ~8 cross-boundary locals. Clusters that MUST stay co-located: audio U1/2/3 (6581–7012), R-08 (5559–5921), R-09 (5922–6295), citizens M1/M3 (7915–8526), presentation `_pv` (4322–6580). Extracted **cluster-by-cluster**, each a verified-green commit (R-06 style: prove pattern on the safest seam first = the audio cluster). **PROGRESS:** (1) audio cluster (FQ-09U1/2/3, 24 checks) → `smoke_audio.gd` as `run(harness, root, player)` (2026-08-06). (2) contracts cluster (R-09, 19 checks) → `smoke_contracts.gd` as `run(harness, root, world, player, hall)` (2026-08-07). (3) settler-crew cluster (R-08 slices 1-3, 17 checks) → `smoke_settler_crew.gd` as `run(harness, root, world, player, hall, settlement, hud)` — `hall_cell` recomputed in-module (pure derived read), `_r08_clear_ground_drops` stays a harness helper (2026-08-07). (4) citizens cluster (Settlement Coherence M1-M5, 50 checks) → `smoke_citizens.gd` as `run(harness, root, world, player, hall, settlement, hud, _fq01_msg_conn)` — `_fq01_msg_conn` (a `player_event` Callable handle connected in the FQ-01 section, disconnected by this cluster's state-restore tail) is threaded in since a Callable can't be recomputed (2026-08-07). All four: coordinator calls in place → windowed **533/533** clean, names+count preserved. `smoke_test.gd` 8265→6966 lines. **Extraction-tooling lesson:** line-surgery must read/write **UTF-8-no-BOM** via .NET `File.ReadAllText`/`WriteAllText`; Windows-PowerShell `Get-Content -Raw`/`WriteAllText()` mojibake'd em-dashes and flipped 4 exact-copy checks. **Boundary lesson:** the R-09 block's *tail* was FQ-09W restore code (`root.storm_active = _fq09w_storm_was` + `fq09w_world_restored`) reading a local declared ~1200 lines earlier — a naive header-to-header cut leaked it and broke compile. Fix: cut at the true R-09 teardown; leave the fq09w tail in the coordinator. **VERIFY: read the raw Godot stdout for `SCRIPT ERROR`/`Compile Error`/`Nonexistent function` — a compile failure still writes a garbage `total=533 failed=0` JSON, so the JSON alone lies.** Each remaining cluster: scan the block for undeclared `_<prefix>` locals BEFORE cutting. **Correct scan (learned on the M-series):** for each `_ident` occurrence check the char IMMEDIATELY before it — if `.` it's a member access (safe), else it's a bare local ref; flag bare refs not declared (`var`/`for`) in the block and not a harness helper. Do NOT filter whole lines containing a dot — that hid `player.player_event.disconnect(_fq01_msg_conn)` (a real leak on a line that also has method calls). A genuine cross-section local that can't be recomputed (e.g. a Callable handle) is **threaded in as a `run()` parameter** (citizens' `_fq01_msg_conn`); pure derived reads (`hall_cell`) are recomputed in-module. | Coordinator runs all modules in original order; **check count and names identical** to pre-split (windowed **533/533**, diff the JSON name-set); no check lost/renamed; each file headers its domain. | `s07_smoke_coordinator_covers_all` (asserts the union of module-owned sections == the pre-split name-set) |
| **S-07.4 — Bounded controller extraction** | Profile each candidate against the R-06 gate (§2.3); extract **only** clean seams. Candidates: HUD panel controllers (`hud_inventory_controller`, `hud_town_controller`, `hud_character_controller`, `hud_map_goals_controller`, `hud_layout_controller`); `game_root` → `threat_director` + `progression_service` (**preserve the Calling resolver API** as the frozen seam); `world.gd` → split spatial-query / serialization / render helpers where stateless. Each shipped seam: one subsystem, separately committed, delegating shim in the god file, façade frozen. | Per shipped seam: façade signatures unchanged; existing checks green untouched; new `s07_*_delegates` check passes. Candidates failing the gate are recorded CLOSED-not-beneficial with the profiling note. | `s07_<seam>_delegates` per shipped seam |
| **S-07.5 — Remove/bound dead full-grid queries** ✅ DONE | Delete the unbounded `world.gd nearest_ripe_crop` + `nearest_plantable_soil` (F5), which had no live callers (only the bounded work-zone `*_in` variants are called, from `subject.gd` + `smoke_settler_crew.gd`). Fix stale doc refs. | **DONE (2026-08-07):** both dead methods removed (`world.gd` 1603→1569 lines); `nearest_crop`/`*_in` variants retained; current-authority docs corrected (`VARIABLE_MATRIX.md`, `WORK_ORDER_RELEASE_FOUNDATIONS.md`) — the two SUPERSEDED archives left as historical snapshots. Windowed **534/534** clean (behaviour identical — dead code). | `s07_no_unbounded_cell_scan` ✅ (asserts the unbounded methods are gone via `has_method` + the bounded `*_in` retained) |

Slices land in order. S-07.4 candidates are re-confirmed with the operator after
S-07.3, since a lit, split test suite makes the extraction seams easier to judge.
S-07.1's art lane (F10/D4) may run in parallel.

## 6. Acceptance tests (smoke) mapped to constraints

| Check | Proves | Slice |
|---|---|---|
| *(all existing checks, names/results preserved)* | behaviour + coverage unchanged across the arc — the regression proof | every |
| `s07_modal_occludes_hud` | opening a modal hides the placement preview and blocks non-modal HUD input | 1 |
| `s07_calling_panel_no_hscroll` | Calling panel content fits its width; no horizontal scrollbar instantiated | 1 |
| `s07_char_create_640_legibility_contract` | 640×360 char-create is legible/operable: vertical-only scroll, pinned action row, type floor, usable controls, in-form preview, all selectors, still creatable | 1 |
| `s07_scrim_strength_knob` | the modal dim-scrim strength is a clamped profile pref (default/clamp) and the HUD consumes it live | 1 |
| `s07_swing_arc_fx` | a weapon/mine strike spawns one directional swing-arc FX that carries the aim and self-frees | 1 |
| `s07_sword_swing_frames_authored` | the four sword tiers resolve authored `<tool>_<body>_swing_<phase>` overlays for live bodies (no code-arc fallback) | 1 |
| `s07_calling_stack_cap_holds` | conditional stacking on the hot channels stays under the D3-locked cap | 2 |
| `s07_smoke_coordinator_covers_all` | the union of the split domain files equals the pre-split check-name set (no check lost/renamed) | 3 |
| `s07_<seam>_delegates` (per shipped seam) | the god-file façade method delegates to the extracted collaborator with identical observable result | 4 |
| `s07_no_unbounded_cell_scan` | no query path performs a full-`cells` scan; dead methods removed/bounded | 5 |

## 7. Recommended order (from the review) → slice map

1. Fix the headless-only smoke discrepancy / classify it → **S-07.0**
2. Polish modal occlusion, Calling scrollbar, Town Hall density, 640×360 → **S-07.1**
3. Playtest and tune Calling stacking/repetition → **S-07.2**
4. Split the smoke suite into bounded files → **S-07.3**
5. Incrementally extract HUD & `game_root` responsibilities → **S-07.4**
6. Remove or bound the unused full-grid query methods → **S-07.5**

Doc-freshness cleanup (F12) is folded into S-07.0 as the "do immediately" quick
win. The `world.gd` concerns (F4) are addressed across S-07.4 (stateless helper
extraction) and S-07.5 (dead-query removal).

## 8. Invariants (must hold every slice)

- No new mechanics, no new subsystem, **no `SAVE_VERSION` / `gen_version` bump**
  (S-07.2 changes only balance **data**, no schema).
- Existing `_check` names and pass/fail semantics: **unchanged**; count only rises.
- God-file public signatures (`hud.gd`, `game_root.gd`, `world.gd`) touched by an
  extraction: **unchanged** (delegating shim preserves the façade). The **Calling
  resolver API is a frozen seam** and must survive the `game_root` split intact.
- Any extraction candidate failing the R-06 stateless-seam gate is **left in
  place and documented**, not forced.
- Docs/README/wiki/smoke-counts updated only with **actual** evidence, after CI.
- Commit only when the operator gates it; **never push unless told**.

## 9. Closeout standard (every slice)

1. `python scripts/validate_repo.py`
2. `python scripts/asset_audit.py --strict` (S-07.1 art / any asset path move)
3. `python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo`
4. Waited-GUI Godot smoke with a freshness-checked `smoke_results.json`
   (windowed authoritative; headless per S-07.0's classification) — pre-existing
   checks green + the slice's new `s07_*` check passing.
5. Update this work order's slice state, `docs/HANDOFF.md`, `known_issues.md`, and
   the README smoke badge with **actual** pass/fail evidence — never aspirational.
6. Commit only when the operator gates it; never push unless told.

## 10. Open questions (for the operator, non-blocking to planning)

- **Q1:** Should S-07.4 attempt the `world.gd` render/tileset helper extraction,
  or is that cluster (like the HUD inventory board in R-06) too node/state-coupled
  to lift cleanly? — decide after profiling in S-07.4.
- **Q2:** Is `v0.7-alpha` tagged at the end of this arc, or after an additional
  playtest pass following S-07.2's tuning? (The review frames this arc as the
  pre-`v0.7-alpha` stabilization.)
- **Q3:** Does the smoke split (S-07.3) also become the CI job boundary (per-domain
  parallel runs), or stay a single run with better file organization? Affects the
  coordinator's entry-point shape.

## 11. S-07.3 resume plan — the `ctx` seam (design)

S-07.3 is **paused at 4/~10 clusters** (audio, contracts, settler-crew, citizens).
Those four were extractable because each consumed the shared handles plus at most
one extra value that could be **recomputed in-module** (`hall_cell`) or **threaded
as a single `run()` param** (`_fq01_msg_conn`). The remaining core
(world-generation, player-combat, callings, ui-hud, persistence, assets/rendering)
is where the cross-section locals are **declared** and later **consumed** across
section boundaries, so per-call positional params stop scaling. This section is the
missing design the earlier notes called for; it is the thing to build **first** when
S-07.3 resumes. **Scope:** test-harness structure only — no `_check` name, count,
or pass/fail meaning changes; strictly order-preserving.

### 11.1 The `ctx` object

Add `scripts/main/smoke/smoke_ctx.gd` — a plain `RefCounted` (loaded as a `preload`
const in `smoke_test.gd`, per the class_name gotcha) carrying the stable handles and
a scratch bag:

```
# smoke_ctx.gd
extends RefCounted
var harness            # the smoke_test.gd node — owns _check/_skip/_find_block/_mine_cell
var root
var world
var player
var hall
var settlement
var hud
var scratch: Dictionary = {}   # cross-section locals, string-keyed (see 11.3)
```

`harness` stays the owner of the assertion + helper API (`_check`, `_skip`,
`_find_block`, `_mine_cell`, `_r08_clear_ground_drops`, …). Extracted sections call
`ctx.harness._check(...)` exactly as the current four modules already call
`harness._check(...)`; this is why `harness` is passed, not duplicated.

### 11.2 Coordinator shape

`_run()` builds one `ctx` at the top, populates the seven handles as they become
available (in the **current order** — `world`/`hall`/`settlement`/`hud` are still
assigned at the same points they are today), and then becomes an **ordered list of
`await <Module>.<section>(ctx)`** calls in the exact present sequence. No section is
reordered; the coordinator is a table of contents, not a regrouping.

### 11.3 `scratch` — the cross-section locals (the whole reason for `ctx`)

Every local that is declared in one section and read in a later one moves into
`ctx.scratch["<name>"]` at the **exact line it is first assigned today**, and each
later read becomes `ctx.scratch["<name>"]`. Known members (grep before cutting —
this list is a starting set, not exhaustive):

| scratch key | declared (today) | consumed (today) | note |
| --- | --- | --- | --- |
| `original_config` | `smoke_test.gd:643` | `:1068` (restore) | `WorldConfig`; capture→restore spans the persistence core |
| `wood_cell` | `:310` | `:597` (must stay air post-load) | `Vector2i`; world-gen → persistence |
| `hall_cell` | derived | multiple | pure derived read → **recompute in-module**, do not scratch |
| `_fq01_msg_conn` | `:7000` | citizens teardown | `Callable`; can't recompute → scratch (currently a `run()` param) |
| `_fq09w_storm_was` | FQ-09W head | R-09 tail | leave the reading tail in the coordinator, per the R-09 boundary lesson |
| `_pv` cluster | `:4322–6580` | within presentation | keep co-located; scratch only what escapes the block |

Rule of thumb: **pure derived reads recompute in-module; anything that can't be
recomputed (Callables, captured configs, mined-cell coordinates) goes in `scratch`.**

### 11.4 Migration order (each step one verified-green windowed commit)

1. **Plumbing-only first.** Add `smoke_ctx.gd`; build `ctx` in `_run()`; convert the
   **four already-extracted modules** from positional `run(harness, root, …)` to
   `run(ctx)` (reading `ctx.root`, `ctx.world`, …). Pure refactor, zero behaviour
   change — proves the seam on safe, already-lifted code before touching the core
   (the R-06 "prove the pattern on the safest seam first" discipline).
2. **Then cluster-by-cluster**, easiest remaining first, moving each block's escaping
   locals into `ctx.scratch` at their current declaration points. One green commit
   per cluster; never batch two.
3. Land guard **`s07_smoke_coordinator_covers_all`** (already specced): asserts the
   union of module-owned section names equals the pre-split name-set, so no check is
   silently lost or renamed.

### 11.5 Verification constraint (do not skip)

There is **no Godot binary on the current dev box**, and neither the Python static
gate nor any tool compiles GDScript — so a smoke-suite change is only truly verified
by **CI** (windowed under `xvfb`) or a **local editor smoke run**. Follow the
existing traps: a compile crash still writes a garbage `total=… failed=0` JSON, so
**delete `build/source_smoke_results.json` before each run** and **scan raw Godot
stdout** for `SCRIPT ERROR` / `Compile Error` / `Nonexistent function`; and do all
line surgery as **UTF-8-no-BOM** (.NET `File.ReadAllText`/`WriteAllText`) to avoid
em-dash mojibake flipping the exact-copy checks. Do not claim a cluster done on the
JSON alone.
