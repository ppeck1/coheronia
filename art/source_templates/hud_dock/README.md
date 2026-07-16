# Coheronia HUD dock kit

This directory is the authored boundary for the primary bottom HUD. Runtime
exports use the same filenames in `art/generated/ui_painted/`.

All files are native-size RGBA layers. Runtime values, item icons, quantities,
hotkeys, selected/cooldown states, and resource levels must remain separate
Godot children. `hud_dock_layout.json` is the sole source of positioned dock
rectangles. Placeholder art can be replaced one-for-one without changing code.

Drop replacement PNGs into this directory, keeping the exact filename, RGBA
canvas size, and transparency contract. Do not run the placeholder builder after
authored replacements are present. Validate one replacement with:

`python scripts/art/sync_hud_kit.py --check --asset <filename.png>`

Promote it to the runtime directory with:

`python scripts/art/sync_hud_kit.py --sync --asset <filename.png>`

The complete image-model brief and a ready-to-paste prompt for every file are
in `docs/wiki/hud_asset_replacement_studio.md`.

The legacy blueprint slicer remains available only as a runtime fallback while
this kit is being replaced with final art.
