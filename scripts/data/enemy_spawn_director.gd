extends RefCounted
## EnemySpawnDirector: the stateless decision seam for enemy encounters. It answers
## "how many / whether / which" for the surface, raid, and cave contexts so that
## logic no longer lives inside game_root's per-enemy growth functions.
##
## game_root still gathers the live context (day, stockpile, difficulty, positions),
## performs the RNG roll at its original call site, and does the spawn / positioning
## / logging — so RNG order and the effective balance are UNCHANGED. Only the
## eligibility / selection / count / cap decisions move here, where they can be unit
## checked directly.
##
## DENSITY FIELDS ARE DESIGN-ONLY: enemies.json `density` / `region_density` are
## authored target populations per region, NOT runtime inputs — no spawner reads
## them. Runtime surface pressure comes from night_spawn_count(); raid/cave pressure
## from the per-enemy spawn_rule thresholds and the difficulty density_mult. See
## docs/VARIABLE_MATRIX.md.


## Surface night count: scale the rule's base count by the difficulty density_mult
## and clamp to [1, 5]; a zero base (darkness rule off / peaceful) yields zero.
static func surface_spawn_count(base_count: int, density_mult: float) -> int:
	if base_count <= 0:
		return 0
	return clampi(int(round(float(base_count) * density_mult)), 1, 5)


## A raid unit is eligible once the day threshold is reached OR the stockpile has
## grown past its lure threshold (a fat stockpile draws raiders early).
static func raid_eligible(day_count: int, day_threshold: int, stock: int, stock_threshold: int) -> bool:
	return day_count >= day_threshold or stock >= stock_threshold


## The threshold the caller rolls randf() against: base chance × difficulty
## density_mult × the enemy-difficulty axis. Identical to the previously inlined
## product; kept here so every spawn rolls against one documented formula.
static func roll_threshold(base_chance: float, density_mult: float, difficulty: float) -> float:
	return base_chance * density_mult * difficulty


## True when live underground enemies are at or over the cave cap.
static func cave_at_cap(underground_count: int, cap: int) -> bool:
	return underground_count >= cap


## Which underground enemy belongs at a cave spawn: a lava dweller in molten rock,
## an ore tick beside a vein, else the default cave crawler — skipping any variant
## the registry cannot spawn (fail closed) and falling back to the crawler.
static func select_cave_enemy_id(lava_near: bool, ore_near: bool, registry) -> String:
	if lava_near and registry.is_spawnable("lava_slime"):
		return "lava_slime"
	if ore_near and registry.is_spawnable("ore_tick"):
		return "ore_tick"
	return "cave_crawler"
