extends RefCounted

## S-07.3 shared smoke context (plumbing-only ctx seam — work order §11).
##
## Bundles the stable handles the extracted `smoke_*.gd` modules need, plus a
## `scratch` bag for cross-section locals that outlive a single section (e.g. a
## Callable that cannot be recomputed in-module). Behaviour-neutral: the
## coordinator populates these fields at the exact points the handles already
## become available, and each module unpacks what it declares. No `_check`
## name, count, or ordering changes.
##
## `harness` is the smoke_test.gd node — it owns the assertion + helper API
## (`_check` / `_skip` / `_find_block` / `_mine_cell` / `_r08_clear_ground_drops`),
## so modules call `ctx.harness._check(...)` rather than duplicating it.

var harness
var root
var world
var player
var hall
var settlement
var hud
var scratch: Dictionary = {}
