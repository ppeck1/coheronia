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
| RF-04 | Save writes overwrite live files directly. | `scripts/shell/game_state.gd` opens `user://shell.json` and world files with `FileAccess.WRITE`. | A partial write can hide or destroy a usable profile/world. | **RESOLVED by R-02 (2026-07-21).** All saves go through `_atomic_write_json` (validated temp -> `.bak` -> rename; restores `.bak` if the final rename fails). |
| RF-05 | Invalid save JSON defaults silently in key load paths. | `GameState.load_shell` and world loading accept only parsed dictionaries and otherwise return defaults/empty data. | Corruption can look like lost progress rather than a recoverable error. | **RESOLVED by R-02 (2026-07-21).** `_load_json_recover` quarantines a corrupt primary to `.corrupt`, restores from `.bak`, and surfaces `shell_load_status`/`world_load_status`; no corrupt save silently becomes a fresh empty profile. |
| RF-06 | Smoke is coupled to the normal `user://` profile. | Historical smoke failures included stale `shell.json` HUD geometry/profile state. | A green run can depend on or contaminate local player data. | **RESOLVED by R-03 (2026-07-21).** `GameState.persistence_root` is injectable and auto-routes test/capture runs to `user://smoke_root/`; the smoke never reads or writes the real profile (verified: the Metis test character survives smoke runs). |
| RF-07 | Verification is primarily workstation-sequenced. | Static scripts exist, but no declared Python environment, one-command verifier, or CI workflow is present. | External reproducibility and merge confidence are weak. | **RESOLVED by R-04 (2026-07-22).** `requirements.txt` pins the Python environment, `scripts/ci/verify.py` is a single verifier command, and `.github/workflows/ci.yml` runs static + pinned-Godot smoke/export on a clean runner with any failure blocking the merge. |
| RF-08 | Repository hygiene has remaining release concerns. | `.gitignore` has legacy import rules; large/historical media and generated/history material require a public-release decision. | Clone size, import noise, and public-facing clarity suffer. | **RESOLVED by R-05 (2026-07-22).** Raw private evidence untracked, orphaned media removed, split license + `.gitattributes` + `CONTRIBUTING.md` added, workstation paths and duplicate prompt removed; the legacy `*.import` ignore is intentionally retained (export proven). |
| RF-09 | `hud.gd` and `game_root.gd` are concentrated ownership points. | Current HUD/session behavior spans large controllers. | Future features become increasingly coupled. | Later R-06, after release foundations. |
| RF-10 | Baseline player controls and visible settlement labor remain incomplete. | Current backlog already names pause/settings/keybinds, save UX, build feedback, and subjects. | The game remains harder to play and less legible than its systems warrant. | R-07 onward, after release foundations. |

## Ordered work matrix

| Order | Work order | Scope | Why this order | Acceptance / exit gate |
|---|---|---|---|---|
| R-00 | Export-readiness audit | Commit an appropriate Windows export preset; make one clean temporary export; launch it; audit one asset from each runtime category: bodies, gear, blocks/items, HUD, backdrop, prologue, music, stingers. Record exact loader/path evidence and propose R-01 only. | Establishes the real exported failure surface before a loader refactor. | Export result and artifact path documented; every category is pass/fail; validator, Capsule Doctor, waited Godot smoke, and `git diff --check` run; no runtime migration, no art changes, no commit without approval. |
| R-01 | Export-safe runtime resources | Migrate imported runtime visual loading to `ResourceLoader`/import-aware loading. Replace convention-based runtime discovery with explicit manifest pools where export requires it. Address audio only where R-00 proves a fault. Add focused export smoke. | An exported game is the immediate release blocker. | A clean exported Windows build displays and plays all canonical asset families, including adaptive music/stingers; procedural fallbacks remain fallback-only; export smoke records the result. |
| R-02 | Save integrity | Introduce atomic write/validate/replace with `.bak`; quarantine malformed saves; surface errors; preserve/migrate current schemas; make failed world creation observable. | Safe player progress is more important than feature breadth. | Tests cover truncated shell/world JSON, failed replacement, backup restoration, unsupported schema, and failed world creation; no corruption silently appears as a new empty profile. |
| R-03 | Isolated verification | Make persistence root injectable; move smoke to a fresh test root; split result reporting by shell/save/world/UI/presentation/progression/audio while retaining one final full-game smoke. | Removes profile contamination and makes failures localizable. | Ten consecutive clean runs are stable; intentionally dirty normal profiles do not affect results; smoke leaves no normal-profile changes; results state suite/check/duration/commit. **Export-fixture item (from R-01): the six temp-art fixture checks that write PNGs into `res://` (`fq07_block_renders_from_image`, `fq07_item_renders_from_image`, `fq09v_variant_pools_resolve`, `fq09c_cel_shot_hook`, `fq09w_wall_art_hook`, `fq21_hud_theme_asset_fallback`) are moved to an injected writable test root, OR skipped only under exported-smoke mode (where `res://` is read-only) — their source-run assertions must not be weakened.** |
| R-04 | CI and release automation | Add declared Python dependencies, one verifier command, pinned Godot setup, static/import/smoke/export jobs, and build metadata. | Converts local claims into reproducible evidence. | A clean runner validates and exports an artifact; failures block the workflow; build reports commit/version. **DONE 2026-07-22** (`requirements.txt`, `scripts/ci/verify.py`, `.github/workflows/ci.yml`, `Linux/X11` preset). |
| R-05 | Public repository and release cleanup | Decide media policy; remove obsolete/orphaned media as separately approved; add `.gitattributes`, license, contributing guidance; remove duplicate/stale prompt material; replace workstation paths; use `.gdignore` only after confirming runtime exclusions. | Makes the public project readable and distributable without accidental loss. | Public-safety scan passes; no local paths/private classifications/duplicate root prompts; clone/import/release contents are intentional. **DONE 2026-07-22** (`386117b`, `899be08`, `5f90a2e`, `73d3ee3`, `62ee507`, `81fdd6c`). |
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

- **R-02 (Save integrity) — DONE 2026-07-21.** `scripts/shell/game_state.gd`:
  - `_atomic_write_json(path, payload)`: write a `.tmp`, validate it re-parses to
    a non-empty object, back the current file up to `.bak`, then rename the temp
    into place; if the final rename fails, restore the `.bak` so the live file is
    never left missing. `save_shell` and `_write_world` route through it.
  - `_load_json_recover(path)`: a corrupt primary is quarantined to `.corrupt`
    (never blind-deleted), the `.bak` is tried, and a status is returned
    (`missing`/`ok`/`recovered`/`quarantined`). `load_shell`/`load_world_file`
    use it and surface the outcome via `shell_load_status` / `world_load_status`;
    `list_worlds` tolerates a corrupt file without mutating it; a recovered save
    re-persists to heal the primary.
  - `_schema_supported()` surfaces an unknown/future `shell_version` as
    `unsupported_schema` while still loading best-effort — data is never
    destroyed.
  - `create_world` returns `""` on a failed write (observable); the shell
    world-create flow (`shell_ui.gd`) and `ensure_play_context` guard `""` so a
    world that was never persisted is never entered.
  - **Evidence.** Source waited-GUI smoke **350/350** with
    `r02_atomic_write_backup_recover_quarantine` (backup + validate + recover +
    quarantine + write-failure primitive) and `r02_shell_world_integrity` (shell
    recovers from `.bak` and is surfaced, unsupported schema surfaced, world file
    recovers, world creation observable). validator + Capsule Doctor + wiki links
    + `git diff --check` green.

- **R-03 (Isolated verification) — DONE 2026-07-21.**
  - **Injectable persistence root** (`scripts/shell/game_state.gd`):
    `persistence_root` derives `shell_path()` / `worlds_dir()`;
    `set_persistence_root()` re-points and reloads; `_ready` honors
    `COHERONIA_PERSIST_ROOT`, else auto-routes any automated/capture flag
    (`COHERONIA_SMOKE`/`SMOKE_FOCUS`/`HUD_QA`/`SHOTS`) to `user://smoke_root/`. A
    normal launch still uses the real `user://` profile. Verified: the Metis test
    character in the real profile is untouched across smoke/export runs, and a
    non-empty (dirty) real profile does not affect results.
  - **Split reporting** (`scripts/main/smoke_test.gd`): `_suite_for` categorizes
    each check into `shell`/`save`/`world`/`ui`/`presentation`/`progression`/
    `audio`; results carry per-suite `{passed, failed, skipped}`, `skipped` +
    `skipped_names`, `duration_sec`, `commit` (from `COHERONIA_COMMIT`), and
    `persistence_root` alongside the one final full-game pass/fail.
  - **Export-fixture handling**: the six checks that write fixture PNGs into
    `res://` use `_check_res_fixture` — **skipped** under an exported build
    (read-only `res://`), run with their assertions unchanged in source/editor.
  - **Evidence.** Source waited-GUI smoke **351/351** (0 skipped; consecutive
    isolated runs stable and idempotent); the exported `.exe` smoke is **345/345
    + 6 skipped** (fully green — closing the R-01 deferred fixture item). Smoke
    `r03_isolated_verification` pins isolation + re-point + reporting. validator +
    Capsule Doctor + wiki links + `git diff --check` green.

- **R-04 (CI and release automation) — DONE 2026-07-22.**
  - **Declared Python environment** (`requirements.txt`): `Pillow>=10.0,<12` is the
    only third-party dependency; every validator/verifier step is otherwise
    stdlib, so a clean runner reproduces the gate from one pinned file.
  - **One verifier command** (`scripts/ci/verify.py`): runs the full static gate
    (`validate_repo`, strict `asset_audit`, HUD-kit runtime hashes, gear
    alignment, Capsule Doctor `public_repo`, wiki links) and, when `--godot` is
    supplied, the in-engine waited **source** smoke plus (with `--export`) a real
    export whose artifact is then **launched in smoke mode** (`COHERONIA_SMOKE=1`,
    an absolute `COHERONIA_RESULTS_PATH` outside `user://`). Source and exported
    results are kept in separate files (`build/source_smoke_results.json`,
    `build/export_smoke_results.json`). It prints the per-suite breakdown, stamps
    `build_info.json` (commit / built-at / godot / preset), and exits non-zero so
    CI blocks. **Source** must be `351/351` with **zero** skips; the **exported**
    run must launch, pass every non-skipped check, and skip **exactly** the six
    read-only `res://` fixtures (`fq07_block_renders_from_image`,
    `fq07_item_renders_from_image`, `fq09v_variant_pools_resolve`,
    `fq09c_cel_shot_hook`, `fq09w_wall_art_hook`, `fq21_hud_theme_asset_fallback`)
    — any skip outside that allowlist, any missing allowlist skip, a non-skipped
    failure, or a failure to launch fails the verifier.
  - **Results path override** (`scripts/main/smoke_test.gd`): `_write_result_file`
    honors `COHERONIA_RESULTS_PATH`, letting the verifier collect source and
    exported results at known absolute paths without disturbing the smoke's
    isolated root.
  - **Pinned CI** (`.github/workflows/ci.yml`): a `static` job (Python 3.11 +
    `requirements.txt` + `verify.py --static-only`) gates a `godot` job that pins
    **Godot 4.6.1-stable**, installs the matching export templates, imports under
    `xvfb`, and runs `verify.py --godot … --export --export-preset "Linux/X11"` —
    i.e. it **runs the exported Linux artifact**, not merely builds it. Both
    result files, the artifact (`coheronia` + `.pck`), and `build_info.json` are
    uploaded. The smoke/export step and the job carry finite `timeout-minutes`
    (20 / 30) so a future hang fails rather than consuming an unbounded runner.
    Any failing step blocks the workflow.
  - **Export preset** (`export_presets.cfg`): added a native `Linux/X11` preset
    (`all_resources`, x86_64) so the Linux runner produces a clean runnable
    artifact without cross-compilation; the existing Windows Desktop preset is
    unchanged.
  - **Evidence.** `verify.py --static-only` PASS (validator healthy, wiki 5710
    links / 369 files). Full local run against Godot 4.6.1 (`--godot … --export`,
    Windows preset standing in for the identical export→launch path): **source
    smoke 351/351** (0 skipped; world 174 / ui 51 / presentation 66 / audio 25 /
    progression 18 / save 15 / shell 2), export **OK**, then the **exported
    artifact launched** → **export smoke 345/345 with exactly the six allowlist
    skips** (verified set-equal, no unexpected/missing), `build_info.json` stamped
    (commit `cd06e77`, godot `4.6.1.stable`). Workflow YAML parses; `build/`
    remains gitignored.

- **R-05 (Public repository and release cleanup) — DONE 2026-07-22.**
  - **Private evidence untracked** (`386117b`): `git rm --cached` on the 165 raw
    ledgers (`.project/runs/*.md`, `.project/atlas_outbox/*.json`,
    `.project/boh_outbox/*.json`) that the `public_repo` profile forbids, with
    precise `.gitignore` rules; the `.gitkeep` directory skeletons are kept so the
    Ops Capsule directory-exists checks pass on a fresh clone. Files remain on
    disk; Git history is not rewritten.
  - **Duplicate prompt + workstation paths** (`899be08`): deleted the
    byte-identical `coheronia_claude_code_prompt.md` (kept the validator-required
    `PROMPT_FOR_CLAUDE_CODE.md`) and replaced every workstation path in tracked
    docs with portable placeholders (`<repo-root>`, `<godot-binary>`, `<python>`,
    `<workstation-path>`) — no tracked file contains a `B:\dev` or `C:\Users\peckm`
    path.
  - **Hygiene + licensing** (`5f90a2e`, `73d3ee3`, `62ee507`): added
    `.gitattributes` (LF normalization + binary asset handling) and a concise
    `CONTRIBUTING.md`, then the split license — `LICENSE` (MIT for source code,
    tooling, and engineering/configuration material) and `LICENSE-ASSETS.md`
    (art/audio/video/screenshots/reference media and authored creative/narrative
    content reserved; data schemas and generic config are MIT; engineering/process
    docs stay MIT unless they carry reserved creative content).
  - **Media** (`81fdd6c`): removed the orphaned 64 MB gameplay `.mp4` (zero tracked
    references; README uses the YouTube link); the linked prologue clip is kept.
    No `.gdignore` added (no runtime-excluded source dirs); the legacy `*.import`
    ignore is intentionally retained (export proven with sidecars regenerated on
    import, R-01).
  - **Evidence.** Content scan clean (no secrets; no local paths; no forbidden
    tracked evidence dirs; repo confirmed public). Static gate healthy, wiki links
    green (5710 / 369). Suite green with the PR-07 correctness follow-up
    (`a33e03a`): source smoke **352/352**, exported smoke **346/346 + 6 skipped**,
    zero backdrop triangulation errors.

- **R-07 (Playability baseline) — all four slices done (local; slices 1-2 pushed).** Control model
  unchanged (left click = mine/attack, right click = place/use).
  - **Slice 1 (pause/settings/keybinds), pushed `0160ada`.** `scripts/ui/pause_menu.gd`
    is a `PROCESS_MODE_ALWAYS` CanvasLayer; Escape (after closing any open panel)
    opens it and freezes the sim via `get_tree().paused`. Resume / Settings / Save /
    Save & Quit (Save & Quit leaves only on a successful save). Settings covers
    Music/SFX volume (`audio_settings`) and keyboard rebinding
    (`scripts/shell/input_settings.gd`; overrides in `profile["keybinds"]`;
    `rebind`/`apply` ignore non-`REBINDABLE`; duplicate keys rejected; mouse-bound
    actions shown fixed). Fits down to a 640x360 logical viewport (Reset/Back always
    reachable).
  - **Slice 2 (save management), pushed `183a311`.** Shell world/character deletes
    route through a `ConfirmationDialog` (`shell_ui.gd`); the pause menu gains a
    visible **Restore Save** (confirm -> `game_root.load_game()`) so recovery needs
    no hidden F9.
  - **Slice 3 (build preview + reasoned placement feedback), local.**
    `player.place_reason(cell, block_id)` is the single validity authority (""=valid,
    else a specific reason); `try_place` emits it via `player_event` on failure (no
    silent fails). `scripts/world/build_preview.gd` draws a translucent ghost of the
    selected placeable block at the aim cell (green valid / red invalid, 1px border),
    on its own `follow_viewport` CanvasLayer so the world day/night/cave
    `CanvasModulate` never dims it. No build mode, no flipped actions, no
    instructional text, no art assets.
  - **Slice 4 (crafting navigation), local.** `scripts/ui/craft_panel.gd` is a
    unified Crafting panel (C toggles it, Esc closes it) grouping every recipe by
    source -- Hand, Town Hall, Workbench, Furnace, Anvil -- plus a Build row for
    each unbuilt station; inputs show have/need from the right source (inventory
    for hand, stockpile for stations) and Craft/Build is disabled when short.
    `game_root` routes each craft by station, including the Town Hall gear recipes
    to their special `forge_*` methods (empty-output `craft_axe` etc. would no-op
    via `craft_from_stockpile`). A `GameState.craft_panel_open` flag freezes player
    input while open (no click-through). The Town Hall panel is trimmed to
    deposit/status/**Repair**; the dead forge/lantern/station-build signals,
    handlers, and station-section rebuild plumbing were removed with it (rg-verified
    no callers). C is the only entry point for now; the hardcoded C=torch is gone.
  - **Evidence.** 15 `r07_` smoke checks (pause freeze/resume, rebind apply/reset,
    duplicate reject, persist->reset->apply, save-and-quit-requires-success, settings
    fit 640x360, REBINDABLE contract, mouse-fixed rows, delete-requires-confirm,
    restore-reloads-save, place-reason feedback matrix, preview-active-for-placeable,
    craft-panel routes hand/town/build, craft-panel gating+source, town-panel
    crafting removed, craft-panel toggle+modal). Source smoke **368/368**, exported
    **362/362 + 6 skipped**, VERIFY PASS; dark-cave preview + crafting-panel captures
    reviewed. **All four R-07 slices complete** (pause/settings/keybinds,
    save-management, build preview + feedback, crafting navigation).

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
