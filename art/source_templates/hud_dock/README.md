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

Regenerate the two authoring aids after any accepted source change:

`python scripts/art/preview_hud_kit.py`

- `hud_dock_runtime_guide.png` shows runtime-content zones and trim keep-outs.
- `hud_dock_composite_preview.png` shows the current chrome with representative
  fills, values, icons, counts, hotkeys, labels, and UI states.

These two review PNGs are attachments/templates only and are never loaded by
the game.

The complete image-model brief and a ready-to-paste prompt for every file are
in `docs/wiki/hud_asset_replacement_studio.md`.

The legacy blueprint slicer remains available only as a runtime fallback while
this kit is being replaced with final art.
