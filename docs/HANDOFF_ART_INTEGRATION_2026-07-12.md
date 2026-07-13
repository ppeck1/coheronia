# Coheronia Art Integration Handoff — 2026-07-12

Status: active, verified working tree; the player-appearance mask correction
and world-anchor strip tranche are mechanically, runtime, and visually verified.
Changes remain intentionally uncommitted.

## Exact repository boundary

- Work only in `B:\dev\Coheronia\coheronia_fable_oneshot_repo`.
- `B:\dev\Coheronia` is a wrapper directory, not the repository.
- Branch: `main`.
- Nothing is staged. No commit or push was made.
- Before this handoff file was added, the tree contained 15 tracked modified files and 57 untracked files. The tracked diff was 790 insertions and 72 deletions; that statistic excludes the new assets.
- `docs/HANDOFF.md` belongs to Fable's active work stream and was deliberately not edited for this art-only handoff.

The working tree combines Fable's unfinished FQ-09U3 music changes with the art integration described below. Do not replace whole shared files or treat every current diff as art work. Continue with narrow, disjoint hunks.

## Art delivered so far

There are 55 generated PNG assets in the repository:

| Category | Count | Delivered ids |
|---|---:|---|
| Backgrounds | 3 | `surface_sky`, `surface_far_terrain`, `surface_mid_silhouette` |
| Back walls | 2 | `dirt_wall`, `stone_wall` |
| Blocks | 11 | `berry_bush`, `dirt`, `grass`, `lantern`, `ore`, `stone`, `torch`, `town_hall_core`, `tree_leaves`, `tree_trunk`, `wood` |
| Enemies | 12 | `surface_slime`, `cave_crawler`, and `raider_basic`, each with base plus `_01`, `_02`, and `_03` variants |
| Items | 16 | `armor`, `axe`, `berry_bush`, `dirt`, `food`, `grass`, `lantern`, `ore`, `pick`, `slime_gel`, `stone`, `sword`, `tiny_core`, `torch`, `wet_fiber`, `wood` |
| Players | 10 | human, dwarf, elf, goblin, and orc, each with default and `_female` body variants |
| Structures | 1 | `town_hall` |

Important art decisions already applied:

- Base player bodies wear simple clothing and no armor. Equipped armor is a separate overlay concern.
- The female dwarf has no beard.
- The female goblin has visible hair.
- Ore was revised to read more distinctly from ordinary stone at play scale.
- Enemy variants are slight silhouette/palette/detail variations rather than unrelated redesigns.
- Elf appearance masks were corrected so Pale, Umber, and Ash recolor skin only;
  clothing stays unchanged.
- `art/generated/player_gear/` contains only `.gitkeep`; actual gear-overlay PNGs have not been authored yet.
- `art/generated/ui/` and `art/generated/opening/` do not yet contain delivered PNGs.

## Runtime integration now present

### Player bodies, equipment, and animation

- `data/player_visuals.json` defines body ids, palettes, and optional gear naming.
- `scripts/player/player_visual.gd` loads the 16x32 body art, performs constrained species/appearance recoloring, resolves body-specific or generic gear overlays, and retains procedural gear fallbacks.
- `scenes/player/Player.tscn` contains the `PlayerVisual` child.
- Character creation and save/load preserve the selected default/female body variant.
- Facing and a three-phase raise/mid/strike swing are wired for the pick and axe. This supports visible arm/tool action today. A later appendage-separated rig can improve articulation without changing the current input/action contract.
- The player collision shape remains 12x28; visual art did not change gameplay collision.

Optional gear files follow:

`art/generated/player_gear/<item_id>_<body_id>.png`, then the generic fallback `art/generated/player_gear/<item_id>.png`.

Missing gear art uses code-drawn presentation and never hides the body. Keep the base bodies unarmored when real helmet/torso/feet overlays are created.

### Town Hall and world anchors

- `scripts/settlement/town_hall.gd` loads `structures/town_hall`, uses nearest filtering, and draws it at `Rect2(-28, -48, 56, 48)`.
- The procedural Hall remains the missing-art fallback.
- Damage overlays are still drawn after the Hall art, and redraws occur after damage, repair, and load.
- `town_hall_core` remains a separate seamless 16x16 block asset.
- `scripts/world/world_backdrop.gd` now sets nearest filtering locally.
- Backdrop texture strips use their native dimensions. Camera2D zoom supplies the sole 2x scale; this fixes the earlier accidental 4x strip scaling while leaving procedural fallback heights unchanged.
- `data/visual_assets.json`, `scripts/world/block_registry.gd`, the validator, and smoke coverage know about players, player gear, structures, and the delivered background contract.

Current world-anchor hashes:

| Asset | Contract | SHA-256 |
|---|---|---|
| `art/generated/structures/town_hall.png` | 56x48 RGBA | `D76750C7803807BCD4CD2FA2606466927BAEAE2243DD72FDE066ABF8A2352F6D` |
| `art/generated/blocks/town_hall_core.png` | 16x16 RGBA, opaque, exact horizontal and vertical seams | `C3D3A0999521A8EDA4FE2B22A4F9F21617FAE0B7E2FF8D8CBF9BFC962394C80D` |
| `art/generated/backgrounds/surface_sky.png` | 640x360 opaque RGB, seven broad contiguous bands | `72ECE768BDD6AEB99D967D01628A2A6E5B26F2E2D0CE8D84047647933D9AA672` |
| `art/generated/backgrounds/surface_far_terrain.png` | 640x36 RGBA, hard alpha, opaque bottom, exact horizontal seam | `0ED60AC2FE9EA48218C918645EA4C3F2343A80B99B10881061A4D0E8CDF731B6` |
| `art/generated/backgrounds/surface_mid_silhouette.png` | 640x20 RGBA, hard alpha, opaque bottom, exact horizontal seam | `4F539A9001A3B068C35731D3C995A9B636DE43C749D5DA7FF78E2FBC31028D7D` |

## Verification evidence

Latest verified state before this handoff:

- `scripts/validate_repo.py`: PASS, including Town Hall structure, Town Hall core, surface sky, player visual, and generated-art contracts.
- `git diff --check`: PASS; only expected LF-to-CRLF notices were emitted.
- Repository index: empty.
- Latest full engine smoke: 256 passed of 257 total.
- Sole latest smoke failure: existing Fable check `fq09u3_events_fire_stingers`.
- All new art checks passed, including `town_hall_core_image_contract`, `town_hall_image_contract`, `town_hall_procedural_fallback`, `town_hall_damage_overlay_preserved`, and the 640x360 surface-sky backdrop contract.
- A prior run also showed the existing `fq09u1_live_clip_switch` timing flake, but it passed in the latest run. Do not broaden the art tranche into audio repair.
- The smoke result used for that evidence is at `C:\Users\peckm\.codex\visualizations\2026\07\10\019f4e28-3d25-7770-909f-3fc30075b617\smoke_appdata_7\Godot\app_userdata\Coheronia\smoke_results.json`.

Known QA limitation: a headless screenshot tour blocked on `RenderingServer.frame_post_draw` and its Godot process was terminated. Use a hidden/windowed rendered run or a dedicated proof scene for final visual screenshots. Do not report headless screenshot coverage as complete.

Follow-up verification after far/mid strip landing:

- `scripts/validate_repo.py`: PASS, including exact surface far/mid strip
  contracts.
- Direct strip audit: both far and mid use alpha values 0/255 only, have fully
  opaque bottom rows, exact first/last columns, and transparent RGB zeroed.
- `git diff --check`: PASS; only existing LF-to-CRLF warnings were emitted.
- Project Ops Capsule doctor: healthy.
- Fresh full engine smoke: 256 passed of 257 total.
- Sole smoke failure remains `fq09u3_events_fire_stingers`.
- Fresh smoke result path:
  `C:\Users\peckm\AppData\Local\Temp\coheronia_smoke_appdata_20260712_161408\Godot\app_userdata\Coheronia\smoke_results.json`
  with timestamp `2026-07-12T16:14:28`.
- FQ-09W smoke detail confirmed backdrop runtime sizes:
  `sky=(640.0, 360.0) far=(640.0, 36.0) mid=(640.0, 20.0)`.
- Engine-rendered hidden/windowed QA produced 12 rendered screenshots plus a
  contact sheet at
  `C:\Users\peckm\AppData\Local\Temp\coheronia_world_anchor_qa_appdata_20260712_160558\Godot\app_userdata\Coheronia\world_anchor_qa\world_anchor_visual_qa_contact_sheet.png`.
- Rendered QA covered Hall damage at 0%, 50%, and 100%, plus day/night/storm
  parallax frames at three camera offsets. Visual inspection found the Hall art
  readable under damage, far/mid strips readable under all tints, foreground
  readability preserved, and no obvious strip seam or scaling regression.
- QA report checks confirmed `backdrop_z=-10`, `walls_z=-2`, `blocks_z=0`,
  nearest filtering, `sky_size=[640,360]`, `far_size=[640,36]`,
  `mid_size=[640,20]`, and `hall_art=true`.
- Elf appearance-mask audit rendered a fixed contact sheet at
  `C:\Users\peckm\AppData\Local\Temp\coheronia_player_appearance_contact_sheet_fixed.png`;
  Pale, Umber, and Ash each changed 18 in-mask pixels and 0 outside-mask pixels.
- Protected Fable file hashes still match the table below after removing the
  transient QA hook used to capture the rendered screenshots.

## Protected Fable state

These are checkpoint fingerprints for the shared unfinished Fable work. Recompute them after any continuation; a changed value requires explaining the exact intended hunk.

| File | SHA-256 |
|---|---|
| `data/music_manifest.json` | `31800502EBAEA8C1799C529805B1091B4E5C4D058A479017A1256516BF57DFED` |
| `scripts/audio/adaptive_music_director.gd` | `BD1E5D8519D01301F98F1035DF56C02794DE1C18823FC3C1606EE284722CADDC` |
| `scripts/audio/music_manifest.gd` | `85D40149035ED43B30E4EB8975339E09FA975208BB792D83B9FDB486FEFF8938` |
| `scripts/main/game_root.gd` | `464361E097FB90094F58273765AF0DBA617DA241CC151ABC571C71B108EAFAD7` |
| `scripts/audio/audio_settings.gd` | `AA795033574868E2BD17146B5838B1110D1B060D9131D3F73263481B23D5FE82` |
| `scripts/player/player.gd` | `6BAAD1BCE16BACA7957A5D13165FDF05A44DA0D3C922E1CB795141106386FEBE` |
| `scripts/shell/shell_ui.gd` | `FC1B52E20DE0FE1B8C05A7C578F8722DDE3466C7110B4C369D2AB0F4D6617BBE` |

Shared-file boundary checks:

- Normalized FQ-09U3 block in `scripts/main/smoke_test.gd`: `add2d55685cffa8e0069223db0634aaa76476b42af62c5eab25bcfa6bd2274f9`.
- Normalized FQ-09U3 block in `scripts/validate_repo.py`: `0d8c99f6c850c11154931bbfb4940a69293390e2287a3fecbe06683529c4671a`.
- Player's protected Fable signal/emit anchors were at lines 8 and 485 at the last audit.
- Shell's protected `AudioSettings` preload/volume anchors were at lines 15 and 223 at the last audit.

Line numbers can move as narrow tests are inserted; fingerprints and semantic anchors are the boundary, not absolute line positions.

## Exact continuation point

The world-anchor tranche is complete: player appearance masks, player body
integration, Town Hall art, sky, far strip, and mid strip are landed and
verified. The previous raw far source remains available for audit:

- Raw far-ridge source: `C:\Users\peckm\.codex\visualizations\2026\07\10\019f4e28-3d25-7770-909f-3fc30075b617\coheronia_world_anchor_qa\surface_far_terrain_raw.png`
- Raw dimensions: 1672x941.
- Source character: chroma-green field with restrained layered blue-gray ridges touching the bottom edge.
- QA/build helper: `C:\Users\peckm\.codex\visualizations\2026\07\10\019f4e28-3d25-7770-909f-3fc30075b617\coheronia_world_anchor_qa\world_anchor_tools.py`
- Chroma helper: `C:\Users\peckm\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py`

The helper currently handles Hall, core, and sky candidate building. The far/mid
normalization was performed from the same visual pipeline conventions, but the
helper has not yet been persistently extended with explicit far-strip and
mid-strip commands.

## Current review state

World-anchor convergence reviews are complete:

1. Code/contract review: validator and FQ-09W smoke cover the exact backdrop
   texture sizes, nearest filtering, z-order, Hall art presence, and fallback
   contracts.
2. Visual review: rendered day/night/storm frames and Hall damage frames were
   inspected from the contact sheet and representative full-size captures.
3. Boundary/Fable-drift review: protected Fable hashes still match after the
   transient QA hook was removed; no commit, push, or staging was performed.

## Subsequent sprite backlog

After the world-anchor tranche, the recommended production order is:

1. Real player gear overlays: pick, axe, sword, helmet, torso, and feet, aligned to the ten current body ids. Keep bodies in simple clothing and show armor only when equipped.
2. Remaining live equipment/item icons: `pick_basic`, `pick_forged`, `axe_crude`, `sword_crude`, `helmet_crude`, `torso_crude`, `feet_crude`, `ring_band`, `amulet_focus`.
3. Opening cinematic cels, in storyboard order: `opening_01_first_star` through `opening_08_title_card`; preserve wordless imagery and the engine-owned text band.
4. Enemy expansion when its gameplay/data consumer lands: `thornrat`, `ore_tick`, `raider_torchbearer`, then `broodmother_crawler` and `bandit_standard_bearer`; each should receive slight variants only after the base silhouette is approved.
5. Later enemy set: `ash_wasp`, `mudling`, `hollow_stag`, `lantern_leech`, `stoneback_beetle`, `sporekin`, `burrow_maw`, `raider_sapper`, `hungry_deserter`, `false_taxman`, followed by the larger `hollow_king` and `world_worm` bosses.
6. Future block/system families only alongside their implementations: copper/iron/coal/tin/silver/crystal ores; workbench/furnace/anvil; ingots; seeds/crops/tilled soil; ore/fungal/crystal/timber back walls; cave/deep-cavern backdrops; and the planned deeper ancestry bodies.
7. Appendage-separated player animation only when higher articulation is needed. Preserve the current action/facing/three-phase pose interface so tool swings, equipped overlays, saves, and collision do not regress during a future rig upgrade.

Do not generate UI-category art before a consumer exists. Do not create armor baked into any base body. Do not produce future-system assets early unless the same increment lands their data/runtime path.

## Repeatable command sequence

Run from PowerShell:

```powershell
$repo = 'B:\dev\Coheronia\coheronia_fable_oneshot_repo'
$python = 'C:\Users\peckm\AppData\Local\Programs\Python\Python311\python.exe'
$godot = 'B:\dev\Coheronia\project.godot\Godot_v4.6.1-stable_win64.exe'
Set-Location $repo

& $python .\scripts\validate_repo.py
git diff --check
& $python .\_protocol\Project_Ops_Capsule\scripts\capsule_doctor.py . --profile public_repo
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$env:COHERONIA_SMOKE = '1'
$env:APPDATA = Join-Path $env:TEMP "coheronia_smoke_appdata_$stamp"
$env:GODOT_USER_HOME = Join-Path $env:TEMP "coheronia_smoke_home_$stamp"
New-Item -ItemType Directory -Force -Path $env:APPDATA
New-Item -ItemType Directory -Force -Path $env:GODOT_USER_HOME
Start-Process -FilePath $godot -ArgumentList @('--headless','--path',$repo) -Wait -PassThru -WindowStyle Hidden
git status --short
```

Do not trust the Godot process exit alone. Read the newly written `smoke_results.json`, confirm its timestamp, passed/total counts, and exact failed-check list. The Godot binary used by the launcher is `B:\dev\Coheronia\project.godot\Godot_v4.6.1-stable_win64.exe`.

## Paste-ready continuation prompt

```text
Continue the Coheronia art integration in the exact repo
B:\dev\Coheronia\coheronia_fable_oneshot_repo on branch main.

Read docs/HANDOFF_ART_INTEGRATION_2026-07-12.md completely before changing files.
The outer B:\dev\Coheronia directory is only a wrapper. Fable's unfinished
FQ-09U3 work shares this dirty tree; preserve every protected hash and normalized
block recorded in the handoff, and use narrow disjoint hunks only. Do not commit
or push unless explicitly asked.

The player/body, Town Hall, sky, far strip, and mid strip tranche is complete.
Do not redo that work. Start from the subsequent sprite backlog: real player
gear overlays first, then the remaining live equipment icons, then opening cels.
Keep base bodies unarmored, align overlays to the ten current body ids, and
preserve the current action/facing/three-phase pose interface.

Before calling any next tranche complete, run validator, git diff --check,
Project Ops Capsule doctor, full smoke, protected-boundary hashes, and rendered
visual QA for the new art. Accept no new failures; the existing Fable
fq09u3_events_fire_stingers race may remain only if it is still the sole failure
and protected Fable code is byte-identical.
```
