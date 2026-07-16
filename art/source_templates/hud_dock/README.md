# Coheronia HUD dock kit

This directory is the authored boundary for the primary bottom HUD. Runtime
exports use the same filenames in `art/generated/ui_painted/`.

All files are native-size RGBA layers. Runtime values, item icons, quantities,
hotkeys, selected/cooldown states, and resource levels must remain separate
Godot children. `hud_dock_layout.json` is the sole source of positioned dock
rectangles, including slot icon/count/hotkey zones and button
icon/visible-label zones. Placeholder art can be replaced one-for-one without
changing code.

Contract v2 also exposes `decorative_layers`: a new non-interactive chrome
layer can be added by declaring its PNG, native rectangle, role, and z-index.
New interactive controls still require an explicitly registered runtime action;
art never defines gameplay behavior.

Drop replacement PNGs into this directory, keeping the exact filename, RGBA
canvas size, and transparency contract. Do not run the placeholder builder after
authored replacements are present. Validate one replacement with:

`python scripts/art/sync_hud_kit.py --check --asset <filename.png>`

Promote it to the runtime directory with:

`python scripts/art/sync_hud_kit.py --sync --asset <filename.png>`

Verify that source and runtime are byte-identical with:

`python scripts/art/sync_hud_kit.py --verify-runtime`

Optional visual themes use `<base-stem>__<theme-id>.png`, such as
`slot_normal__dwarf.png` or `dock_foreground_trim__winter.png`. Theme ids are
lowercase letters, digits, and underscores. Every themed file is validated
against its required base asset, including size, alpha rules, keep-outs, mask
relationships, and state-family silhouette. Packs may be partial: missing or
invalid themed members fall back individually to the required base PNG.
Whole-kit sync removes stale themed runtime copies that no longer have an
authored source.

Regenerate the two authoring aids after any accepted source change:

`python scripts/art/preview_hud_kit.py`

- `hud_dock_runtime_guide.png` shows runtime-content zones and trim keep-outs.
- `hud_dock_composite_preview.png` shows the current chrome with representative
  fills, values, icons, counts, hotkeys, labels, and UI states.

The foreground trim's occupied alpha must terminate at native `y=50`, the
upper backplate-rail edge. Environmental dressing extends upward from that
baseline; it must never be positioned on the lower rail.

`DockForegroundTrim` is currently disabled with `enabled: false` in the layout.
The present dressing still appears visually detached in-game and needs a new
fit/anchoring pass. Keep the asset and contract intact until that replacement
is reviewed; re-enable it only after a fresh runtime capture passes.

These two review PNGs are attachments/templates only and are never loaded by
the game.

The complete image-model brief and a ready-to-paste prompt for every file are
in `docs/wiki/hud_asset_replacement_studio.md`.

The legacy blueprint slicer remains available only as a runtime fallback while
this kit is being replaced with final art.
