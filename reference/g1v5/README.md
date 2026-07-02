COHERONIA MVP (Godot 4)
========================

This is a clean, production-ready *layout* for the MVP spec:
- 2D side-view sandbox (placeholder world)
- Settlement layer (C/L/R scaffold + tick)
- Enemy base classes + Raider/Slime/Crawler stubs
- HUD (C/L/R bars)
- Save scaffolding (schema + manager stubs)
- Data-driven JSON placeholders (items/recipes/enemies/buildings)

IMPORTANT
---------
This project intentionally ships with placeholder visuals and a *non-TileMap* ground collider,
so the game runs even without a TileSet. Once you add a TileSet, you can turn on tile placement.

How to run
----------
1) Open this folder in Godot 4.x.
2) Press Play. You should spawn on a ground platform and can move/jump.
3) Press T near the TownHall marker to toggle the Town Hall panel (basic).
4) Enemy stubs exist; raid director is included but disabled by default.

Controls
--------
- A/D or Arrow keys: move (Godot defaults for ui_left/ui_right)
- Space: jump
- E: interact (reserved)
- T: toggle town panel

Next build steps (recommended)
------------------------------
1) Add TileSet + TileMap mining/placing (World/tilemap_adapter.gd already prepared).
2) Add basic combat + damage.
3) Enable RaidDirector night checks once day/night cycle exists.
