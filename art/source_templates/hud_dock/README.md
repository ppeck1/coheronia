# Coheronia HUD dock kit

This directory is the authored boundary for the primary bottom HUD. Runtime
exports use the same filenames in `art/generated/ui_painted/`.

All files are native-size RGBA layers. Runtime values, item icons, quantities,
hotkeys, selected/cooldown states, and resource levels must remain separate
Godot children. `hud_dock_layout.json` is the sole source of positioned dock
rectangles. Placeholder art can be replaced one-for-one without changing code.

The legacy blueprint slicer remains available only as a runtime fallback while
this kit is being replaced with final art.
