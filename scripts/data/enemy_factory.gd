extends RefCounted
## EnemyFactory: the single construction/configuration path for a live hostile
## actor. Given a LIVE def (from EnemyRegistry) it instantiates and fully
## configures a SimpleThreat — stats, loot, presentation, collision, and behavior
## references — and returns it. Given an empty or non-live def it returns null
## (explicit failure): a typo or an unknown/planned/boss id NEVER yields a default
## Surface Slime.
##
## Tree insertion and the `died` signal wiring stay with game_root, which owns the
## `threats` group and the defeat/lifecycle flow; the factory is the stateless
## "how is a live actor built and configured from data" seam.

const SimpleThreatScene := preload("res://scenes/entities/SimpleThreat.tscn")

## ctx supplies the handles + resolved scalars the configuration reads:
##   world, town_hall, player (Nodes);
##   base_hp    (int)   = game_root.threat_hp() — the shared day/difficulty HP baseline;
##   difficulty (float) = config().difficulty("enemy");
##   loot_mult  (float) = the difficulty profile's loot scaling.
static func build(def: Dictionary, pos: Vector2, ctx: Dictionary) -> Node:
	# Fail closed: only a live def builds an actor. This is the one place that
	# turns "unknown/planned id" into "no enemy" instead of a silent default.
	if def.is_empty() or str(def.get("status", "")) != "live":
		return null
	var threat := SimpleThreatScene.instantiate()
	threat.world = ctx.get("world")
	threat.town_hall = ctx.get("town_hall")
	threat.player = ctx.get("player")
	threat.position = pos
	threat.enemy_id = str(def.get("id", ""))
	threat.family = str(def.get("family", "surface"))
	# Copy the loot table so the actor can never mutate the registry authority.
	threat.drops = (def.get("drops", []) as Array).duplicate(true)
	threat.loot_mult = float(ctx.get("loot_mult", 1.0))
	# FQ-13: per-def hp_mult scales the shared threat_hp baseline; a FRESH enemy
	# spawns at full health (max_hp == hp) so a frail enemy never shows a partial
	# bar. The load path overrides hp/max_hp after _ready, so saved damage survives.
	var base_hp: int = int(ctx.get("base_hp", 3))
	threat.hp = maxi(1, int(round(float(base_hp) * float(def.get("hp_mult", 1.0)))))
	threat.max_hp = threat.hp
	var difficulty: float = float(ctx.get("difficulty", 1.0))
	# FQ-13: hall_dps_mult lets a torchbearer burn structures faster than the base rate.
	threat.hall_dps = 4.0 * difficulty * float(def.get("hall_dps_mult", 1.0))
	threat.targets_crops = bool(def.get("targets_crops", false))
	# FQ-01: data-driven contact damage/speed; contact scales with difficulty like hall_dps.
	threat.contact_damage = float(def.get("contact_damage", threat.PLAYER_DAMAGE)) * difficulty
	threat.move_speed = float(def.get("speed", threat.SPEED))
	threat.breaks_walls = bool(def.get("breaks_walls", false))   # M4-A raider_sapper
	threat.emits_bubbles = bool(def.get("emits_bubbles", false))   # M4-B lava_slime
	threat.lava_immune = bool(def.get("lava_immune", false))
	# S-07.1c: presentation-only carried torch light (raider_torchbearer).
	threat.visual_light = def.get("visual_light", {})
	# S-08.0 lifecycle: explicit dawn-persistence, defaulting to the underground
	# family's behavior (cave dwellers survive dawn; surface/raid do not). A def may
	# override with an explicit `dawn_persistent` without touching game_root.
	threat.dawn_persistent = bool(def.get("dawn_persistent",
		str(def.get("family", "")) == "underground"))
	return threat
