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


## Is a night-raid candidate eligible to even roll? (RNG-free, so game_root only
## consumes a randf() for eligible candidates — preserving RNG order/count.) A
## candidate with a stockpile lure spawns once day OR stockpile passes; one without
## (the thornrat) is day-gated only. `ctx` keys: day, day_threshold, uses_stock_lure,
## stock, stock_threshold.
static func raid_candidate_eligible(ctx: Dictionary) -> bool:
	var day: int = int(ctx.get("day", 0))
	var day_threshold: int = int(ctx.get("day_threshold", 0))
	if bool(ctx.get("uses_stock_lure", false)):
		return raid_eligible(day, day_threshold, int(ctx.get("stock", 0)),
			int(ctx.get("stock_threshold", 0)))
	return day >= day_threshold


## The spawn intent for an eligible night-raid candidate given an INJECTED roll:
## spawn iff roll <= base_chance × density_mult × difficulty (identical to the old
## `randf() > chance` early-return). Returns the selected enemy id + the threshold
## so game_root can position/log/construct the actor. `ctx` keys: enemy_id,
## base_chance, density_mult, difficulty.
static func raid_intent(ctx: Dictionary, roll: float) -> Dictionary:
	var threshold: float = roll_threshold(float(ctx.get("base_chance", 0.0)),
		float(ctx.get("density_mult", 1.0)), float(ctx.get("difficulty", 1.0)))
	return {
		"spawn": roll <= threshold,
		"enemy_id": str(ctx.get("enemy_id", "")),
		"threshold": threshold,
	}


## True when live underground enemies are at or over the cave cap.
static func cave_at_cap(underground_count: int, cap: int) -> bool:
	return underground_count >= cap


## Which underground enemy belongs at a cave spawn, in priority order: a lava dweller
## in molten rock, a lantern leech beside a cave pool (S-08.1; only when `water_near`
## and under its cap via `lantern_ok`), an ore tick beside a vein, else the default
## cave crawler — skipping any variant the registry cannot spawn (fail closed) and
## falling back to the crawler. `water_near`/`lantern_ok` default false so existing
## three-argument callers behave exactly as before.
static func select_cave_enemy_id(lava_near: bool, ore_near: bool, registry,
		water_near := false, lantern_ok := false, deep := false,
		stone_rare := false) -> String:
	if lava_near and registry.is_spawnable("lava_slime"):
		return "lava_slime"
	if water_near and lantern_ok and registry.is_spawnable("lantern_leech"):
		return "lantern_leech"
	if ore_near and registry.is_spawnable("ore_tick"):
		return "ore_tick"
	# S-08.2: a deep cave with no closer context is Sporekin territory (cluster).
	if deep and registry.is_spawnable("sporekin"):
		return "sporekin"
	# S-08.3: a rare stone-cavern nook is a Stoneback Beetle. This branch sits BELOW the
	# deep/sporekin branch, so sporekin's eligibility is byte-identical — the beetle only
	# ever carves a rare fraction out of the crawler fallback (as leech/ore/sporekin each
	# did). `stone_rare` folds in the beetle's own cap and the deterministic rarity gate;
	# it defaults false so existing six-argument callers behave exactly as before.
	if stone_rare and registry.is_spawnable("stoneback_beetle"):
		return "stoneback_beetle"
	return "cave_crawler"


## S-08.2: how many of a clustered cave enemy (Sporekin) to spawn at once —
## the desired cluster size, clamped to the remaining slots under the underground
## cap so the existing cap is never exceeded. Pure; game_root does the placement.
static func cluster_size(existing_underground: int, cap: int, desired: int) -> int:
	return maxi(0, mini(desired, cap - existing_underground))


## S-08.3: deterministic "rare stone cavern" gate for the Stoneback Beetle. A stable
## integer hash of the spawn cell is bucketed 1-in-`rarity`, so a genuinely uncommon
## subset of cave cells are beetle nooks WITHOUT drawing from the RNG stream — the
## fixed-seed balance report and every other cave-spawn roll stay byte-identical
## (S-08.1/S-08.2 added zero new RNG draws; this preserves that). `rarity <= 0`
## disables the gate; `rarity == 1` marks every cell (tuning/testing convenience).
## Pure and portable (explicit hash + posmod, not the engine `hash()`), so the smoke
## outcome is identical on the Linux and Windows CI targets.
static func stone_cavern_rare(cell: Vector2i, rarity: int) -> bool:
	if rarity <= 0:
		return false
	if rarity == 1:
		return true
	var h: int = (cell.x * 73856093) ^ (cell.y * 19349663)
	return posmod(h, rarity) == 0
