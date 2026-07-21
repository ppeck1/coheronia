# Release Foundations Work Order

## Purpose

This work order follows the completed Presentation Recovery code lane
(PR-00..PR-08, verified at 346/346). Its goal is to make Coheronia
exportable, save-safe, reproducibly verified, and ready for later player-facing
work. It is a seams-first sequence, not a rewrite.

## Scope boundary

- Code-lane work may change runtime code, data manifests, tests, build tooling,
  docs, and diagnostics.
- Code-lane work must **not** generate, edit, redraw, replace, or promote final
  PNGs, audio, video, or HUD art.
- PR-09 skill expansion remains planning-only. PR-10 HUD chrome, iron gear,
  sword frames, and other image-production rows remain art-lane work owned by
  the operator/Codex image workflow.
- One row or tightly coupled sub-row per branch/commit sequence. Do not combine
  export, persistence, test decomposition, and gameplay work in one change.

## Current evidence and risks

| ID | Finding | Evidence | Risk | Disposition |
|---|---|---|---|---|
| RF-01 | Imported runtime visuals are loaded through raw file APIs. | `scripts/world/block_registry.gd` uses `FileAccess.file_exists` and `Image.load_from_file` for `res://` PNGs. | Imported source PNGs can be absent or remapped in an exported PCK while editor/plain-project runs still work. | **RESOLVED by R-01 (2026-07-21).** R-00 proved the exported failure; `_texture_from_file` is now import-aware (`ResourceLoader` -> rebuilt `ImageTexture`, non-imported fallback). Exported `.exe` loads canonical art. |
| RF-02 | Runtime music/stingers use raw OGG file loading. | `scripts/audio/music_manifest.gd` checks `FileAccess` and calls `AudioStreamOggVorbis.load_from_file`. | Export behavior has not been proven for adaptive audio. | **RESOLVED by R-01 (2026-07-21).** R-00 proved music was disabled in the export; `MusicManifest` now loads via `ResourceLoader` and duplicates streams before stamping loop/BPM/grid. Exported `.exe` plays 4 loops / 6 stems / 5 stingers, no hang. |
| RF-03 | No committed export preset exists. | `.gitignore` excludes `export_presets.cfg`; none is present. | There is no reproducible distributable-build path. | **RESOLVED by R-01 (2026-07-21).** A minimal Windows `export_presets.cfg` is committed and tracked (`.gitignore` updated); `4.6.1.stable` templates installed; a real `.exe` was built and launched. |
| RF-04 | Save writes overwrite live files directly. | `scripts/shell/game_state.gd` opens `user://shell.json` and world files with `FileAccess.WRITE`. | A partial write can hide or destroy a usable profile/world. | R-02. |
| RF-05 | Invalid save JSON defaults silently in key load paths. | `GameState.load_shell` and world loading accept only parsed dictionaries and otherwise return defaults/empty data. | Corruption can look like lost progress rather than a recoverable error. | R-02. |
| RF-06 | Smoke is coupled to the normal `user://` profile. | Historical smoke failures included stale `shell.json` HUD geometry/profile state. | A green run can depend on or contaminate local player data. | R-03. |
| RF-07 | Verification is primarily workstation-sequenced. | Static scripts exist, but no declared Python environment, one-command verifier, or CI workflow is present. | External reproducibility and merge confidence are weak. | R-04. |
| RF-08 | Repository hygiene has remaining release concerns. | `.gitignore` has legacy import rules; large/historical media and generated/history material require a public-release decision. | Clone size, import noise, and public-facing clarity suffer. | R-05. |
| RF-09 | `hud.gd` and `game_root.gd` are concentrated ownership points. | Current HUD/session behavior spans large controllers. | Future features become increasingly coupled. | Later R-06, after release foundations. |
| RF-10 | Baseline player controls and visible settlement labor remain incomplete. | Current backlog already names pause/settings/keybinds, save UX, build feedback, and subjects. | The game remains harder to play and less legible than its systems warrant. | R-07 onward, after release foundations. |

## Ordered work matrix

| Order | Work order | Scope | Why this order | Acceptance / exit gate |
|---|---|---|---|---|
| R-00 | Export-readiness audit | Commit an appropriate Windows export preset; make one clean temporary export; launch it; audit one asset from each runtime category: bodies, gear, blocks/items, HUD, backdrop, prologue, music, stingers. Record exact loader/path evidence and propose R-01 only. | Establishes the real exported failure surface before a loader refactor. | Export result and artifact path documented; every category is pass/fail; validator, Capsule Doctor, waited Godot smoke, and `git diff --check` run; no runtime migration, no art changes, no commit without approval. |
| R-01 | Export-safe runtime resources | Migrate imported runtime visual loading to `ResourceLoader`/import-aware loading. Replace convention-based runtime discovery with explicit manifest pools where export requires it. Address audio only where R-00 proves a fault. Add focused export smoke. | An exported game is the immediate release blocker. | A clean exported Windows build displays and plays all canonical asset families, including adaptive music/stingers; procedural fallbacks remain fallback-only; export smoke records the result. |
| R-02 | Save integrity | Introduce atomic write/validate/replace with `.bak`; quarantine malformed saves; surface errors; preserve/migrate current schemas; make failed world creation observable. | Safe player progress is more important than feature breadth. | Tests cover truncated shell/world JSON, failed replacement, backup restoration, unsupported schema, and failed world creation; no corruption silently appears as a new empty profile. |
| R-03 | Isolated verification | Make persistence root injectable; move smoke to a fresh test root; split result reporting by shell/save/world/UI/presentation/progression/audio while retaining one final full-game smoke. | Removes profile contamination and makes failures localizable. | Ten consecutive clean runs are stable; intentionally dirty normal profiles do not affect results; smoke leaves no normal-profile changes; results state suite/check/duration/commit. **Export-fixture item (from R-01): the six temp-art fixture checks that write PNGs into `res://` (`fq07_block_renders_from_image`, `fq07_item_renders_from_image`, `fq09v_variant_pools_resolve`, `fq09c_cel_shot_hook`, `fq09w_wall_art_hook`, `fq21_hud_theme_asset_fallback`) are moved to an injected writable test root, OR skipped only under exported-smoke mode (where `res://` is read-only) — their source-run assertions must not be weakened.** |
| R-04 | CI and release automation | Add declared Python dependencies, one verifier command, pinned Godot setup, static/import/smoke/export jobs, and build metadata. | Converts local claims into reproducible evidence. | A clean runner validates and exports an artifact; failures block the workflow; build reports commit/version. |
| R-05 | Public repository and release cleanup | Decide media policy; remove obsolete/orphaned media as separately approved; add `.gitattributes`, license, contributing guidance; remove duplicate/stale prompt material; replace workstation paths; use `.gdignore` only after confirming runtime exclusions. | Makes the public project readable and distributable without accidental loss. | Public-safety scan passes; no local paths/private classifications/duplicate root prompts; clone/import/release contents are intentional. |
| R-06 | Incremental ownership decomposition | Extract HUD and session services one subsystem at a time. Retire historical HUD fallback paths only after export verification. | Necessary for extension, but not a prerequisite to a safe build. | No behavior/save-format regression; each extracted component has focused coverage; full suite remains green. |
| R-07 | Playability baseline | Pause/settings/keybinds, save-management UI, build preview + reasoned invalid-placement feedback, then crafting navigation. | Turns reliable systems into understandable player workflows. | Player can pause/configure/save/recover/build/craft without hidden controls; each change has focused tests. |
| R-08 | Subject labor MVP | One visible subject plus farmhand and hauler/repairer jobs; bounded movement/targeting; save identity/assignment. | The strongest next product feature after reliability. | Subject visibly completes useful work, affects real settlement state, consumes food, persists across save/load, and has deterministic smoke coverage. |
| R-09 | Contracts and balance | Data-defined contracts plus fixed-seed local session reporting and tuning. | Adds directed goals after visible actors exist. | Real-state contracts cannot double-pay and persist; balance report records observations and data changes. |
| R-10 | Presentation art follow-up | Iron gear, sword/tool authored frames, HUD chrome, backdrop art direction, weather readability. | Valuable polish, deliberately downstream of export/save stability. | Produced through the image-production matrix and reviewed in the exported build. |

## Progress

- **R-00 (Export-readiness audit) — DONE 2026-07-21.** Created a Windows export
  preset, ran a clean `--export-pack`, and audited via an isolated `--main-pack`
  run. Finding: imported PNG/OGG resources loaded through raw file APIs
  (`Image.load_from_file`, `AudioStreamOggVorbis.load_from_file`,
  `FileAccess.file_exists` on the source `res://` path) fail from a packed build
  because imported resources are remapped, while `data/*.json` (no importer)
  loads normally. Result in the default export: all authored art fell back to
  procedural and adaptive music was disabled (context loops < 4/4), which also
  hung the real-time music-lane check. Per-category loader/path evidence was
  recorded; R-01 was proposed as the smallest centralized migration.

- **R-01 (Export-safe runtime resources) — DONE 2026-07-21.**
  - `scripts/world/block_registry.gd` `_texture_from_file`: import-aware —
    `ResourceLoader.exists/load` (export-safe) rebuilt into a CPU-resident
    `ImageTexture` (consumers such as `world.gd:_normalize_art(ImageTexture)` and
    the appearance recolor's `get_image().get_pixel()` require a manipulable
    `ImageTexture`, not the import `CompressedTexture2D`), with a
    `FileAccess`/`Image.load_from_file` fallback for non-imported/temp files
    (runtime test art, or a plain-project run before the import pass; never
    present in an exported PCK). Cache, null-miss, variant pools, and recoloring
    preserved.
  - `scripts/audio/music_manifest.gd`: a shared `_load_stream()` helper loads via
    `ResourceLoader` and **duplicates** the stream before the caller stamps
    loop/BPM/grid, so the shared cached import resource is never mutated;
    contexts, stems, and stingers all route through it.
  - `export_presets.cfg`: a minimal committed Windows Desktop preset (now tracked;
    `.gitignore` updated to un-ignore it and to ignore `/build/`). No special
    source-file include filters were needed — the import-aware loaders resolve
    everything through the normal `all_resources` export.
  - `scripts/main/smoke_test.gd`: `r01_export_safe_visual_resources` and
    `r01_export_safe_audio_resources` run through the runtime loaders (so the
    packed/exe run exercises the same path).
  - **Evidence.** Source waited-GUI smoke **348/348** (two new checks green).
    `4.6.1.stable` export templates installed; a real Windows executable was
    built to a temporary ignored directory — `coheronia.exe` (95.9 MB) +
    `coheronia.pck` (9.6 MB) — and launched with the export smoke: canonical art
    loads (enemy pools 3/3, UI/HUD kit assembled, backdrop, bodies/gear), all
    **4 context loops + 6 stems + 5 stingers** load with **music enabled and no
    hang**, and appearance recoloring is correct in the export.
  - **Known export-only failures (not shipped-content faults).** Six smoke checks
    write temp fixture PNGs into `res://`, which is **read-only in an exported
    PCK**, so their fixtures cannot be created there: `fq07_block_renders_from_image`,
    `fq07_item_renders_from_image`, `fq09v_variant_pools_resolve`,
    `fq09c_cel_shot_hook`, `fq09w_wall_art_hook`, `fq21_hud_theme_asset_fallback`.
    They are **green in source** and exercise a dev-only hot-reload capability,
    not shipped game content. Their fix is the explicit R-03 acceptance item
    above (injected writable test root or exported-smoke skip; source assertions
    unchanged).

## Technical decisions already made

1. Treat `RF-01` as confirmed risk: Godot documentation recommends
   `ResourceLoader` for imported project resources because raw `FileAccess` can
   fail after export. Do not retain raw loaders merely because editor runs work.
2. Do not blindly change import sidecar policy. This project uses Godot 4-era
   `.godot/` import cache behavior; review `*.import` only as part of R-05 with
   the installed Godot version and clean-export evidence. The current
   `*.import` recommendation from older project conventions is not accepted as
   a standalone change.
3. Separate R-02 and R-03 into distinct commits: the storage abstraction should
   land with save recovery tests before smoke-suite reorganization consumes it.
4. Art is not a fallback assignment for code agents. Diagnostic contact sheets
   and screenshots are allowed; final asset production is not.

## R-00 handoff text

```text
Start R-00: Export-readiness audit only.

Read README.md, docs/HANDOFF.md, docs/FABLE_TASK_QUEUE.md, and
docs/WORK_ORDER_RELEASE_FOUNDATIONS.md. The presentation recovery code lane is
complete at 346/346. Do not start PR-09 or PR-10.

Do not generate, edit, replace, or promote any final PNG, audio, video, or HUD
art. Code/data/docs/diagnostics only.

Create a Windows export preset suitable for the project's installed Godot
version, then make one clean local export to a temporary ignored output
directory. Launch it and run a focused export audit covering player bodies,
gear overlays, block/item art, HUD kit, backdrop, prologue, music loops, and
stingers. Record the artifact path and pass/fail evidence for every category.

Inspect the raw runtime loaders in BlockRegistry and MusicManifest, but do not
migrate them in R-00. Propose the smallest R-01 file set and acceptance checks
from the audit evidence.

Run validator, Capsule Doctor, a freshness-checked waited Godot smoke, and
git diff --check. Do not commit or push. Report exact evidence, any export
failures with the responsible loader/path, and the proposed R-01 change set.
```

## Not next

Do not begin more ancestry/enemy data, inactive skill lanes, a full HUD redesign,
large-scale controller decomposition, general pathfinding, new final art, or a
full civic simulation before R-00 through R-03 establish a reliable build/save/
verification base.
