extends Node
## S-07.3 smoke domain module - crafting stations, farming, and attunement
## (FQ-11 workbench/furnace/anvil chain, FQ-12 till/plant/grow/harvest, FQ-05
## attunement resource/hooks/pulse). Order-preserving extraction from
## smoke_test.gd _run(); the harness owns _check(); this module holds only these
## three consecutive section bodies, run in place by the coordinator.


func run(ctx) -> void:
	# S-07.3 ctx seam (work order §11): unpack the handles this cluster uses.
	var harness = ctx.harness
	var root = ctx.root
	var world = ctx.world
	var player = ctx.player
	var hall = ctx.hall
	# --- FQ-11: workbench/furnace/anvil station chain ---
	hall.stockpile = {"wood": 40, "stone": 80, "coal": 40,
		"copper_ore": 12, "tin_ore": 12, "iron_ore": 60, "silver_ore": 6}
	hall.stations_built = {"workbench": false, "furnace": false, "anvil": false}

	# (a) gating: station recipes are locked until their station is built, and a
	# station cannot be built before its prerequisite is standing.
	var _fq11_smelt_locked: bool = hall.craft_station("smelt_iron", player)
	var _fq11_furnace_early: bool = hall.build_station("furnace")
	var _fq11_anvil_early: bool = hall.build_station("anvil")
	harness._check("fq11_station_gating",
		not _fq11_smelt_locked and not _fq11_furnace_early and not _fq11_anvil_early
		and not hall.station_built("furnace"),
		"smelt_locked=%s furnace_early=%s anvil_early=%s" % [
			str(_fq11_smelt_locked), str(_fq11_furnace_early), str(_fq11_anvil_early)])

	# (b) build workbench -> furnace, spending build costs from the stockpile.
	var _fq11_wood0: int = int(hall.stockpile.get("wood", 0))
	var _fq11_stone0: int = int(hall.stockpile.get("stone", 0))
	var _fq11_wb: bool = hall.build_station("workbench")
	var _fq11_fn: bool = hall.build_station("furnace")
	harness._check("fq11_build_chain",
		_fq11_wb and _fq11_fn and hall.station_built("workbench")
		and hall.station_built("furnace")
		and int(hall.stockpile.get("wood", 0)) == _fq11_wood0 - 12
		and int(hall.stockpile.get("stone", 0)) == _fq11_stone0 - 6 - 16,
		"wb=%s fn=%s wood %d->%d stone %d->%d" % [str(_fq11_wb), str(_fq11_fn),
			_fq11_wood0, int(hall.stockpile.get("wood", 0)),
			_fq11_stone0, int(hall.stockpile.get("stone", 0))])

	# (c) the furnace smelts raw ore + coal into an ingot placed in the stockpile
	# (never the player's inventory).
	var _fq11_ore0: int = int(hall.stockpile.get("iron_ore", 0))
	var _fq11_coal0: int = int(hall.stockpile.get("coal", 0))
	var _fq11_smelt: bool = hall.craft_station("smelt_iron", player)
	harness._check("fq11_furnace_smelts_ore",
		_fq11_smelt and int(hall.stockpile.get("iron_ingot", 0)) == 1
		and int(hall.stockpile.get("iron_ore", 0)) == _fq11_ore0 - 2
		and int(hall.stockpile.get("coal", 0)) == _fq11_coal0 - 1
		and player.inventory.count("iron_ingot") == 0,
		"ingots=%d ore %d->%d coal %d->%d" % [int(hall.stockpile.get("iron_ingot", 0)),
			_fq11_ore0, int(hall.stockpile.get("iron_ore", 0)),
			_fq11_coal0, int(hall.stockpile.get("coal", 0))])

	# (d) the anvil forges iron gear from ingots. Build it (costs 3 iron_ingot),
	# top up ingots, then forge the iron sword into the weapon slot.
	for _fq11_i in range(8):
		hall.craft_station("smelt_iron", player)
	var _fq11_av: bool = hall.build_station("anvil")
	var _fq11_forge: bool = hall.craft_station("anvil_iron_sword", player)
	harness._check("fq11_anvil_forges_iron_gear",
		_fq11_av and _fq11_forge
		and str(player.equipped_dict().get("weapon", "")) == "sword_iron"
		and player.attack_damage() == 5,
		"anvil=%s forge=%s weapon=%s atk=%d" % [str(_fq11_av), str(_fq11_forge),
			str(player.equipped_dict().get("weapon", "")), player.attack_damage()])

	# (e) metal gate: clear the weapon, drain ingots, leave only raw ore — the
	# anvil cannot conjure the sword from ore.
	player.equip_item("weapon", "")
	hall.stockpile.erase("iron_ingot")
	hall.stockpile["iron_ore"] = 20
	var _fq11_ore_only: bool = hall.craft_station("anvil_iron_sword", player)
	harness._check("fq11_metal_gate_no_ore_shortcut",
		not _fq11_ore_only and str(player.equipped_dict().get("weapon", "")) == "",
		"forged_from_ore=%s" % str(_fq11_ore_only))

	# (f) bronze alloy: smelt copper + tin, then alloy them at the furnace.
	hall.craft_station("smelt_copper", player)
	hall.craft_station("smelt_tin", player)
	var _fq11_bronze: bool = hall.craft_station("alloy_bronze", player)
	harness._check("fq11_bronze_alloy",
		_fq11_bronze and int(hall.stockpile.get("bronze_ingot", 0)) == 2
		and int(hall.stockpile.get("copper_ingot", 0)) == 0
		and int(hall.stockpile.get("tin_ingot", 0)) == 0,
		"bronze=%d copper=%d tin=%d" % [int(hall.stockpile.get("bronze_ingot", 0)),
			int(hall.stockpile.get("copper_ingot", 0)), int(hall.stockpile.get("tin_ingot", 0))])

	# (h) metal ladder: the anvil/workbench expansion forges the bronze/obsidian/
	# hellstone tiers, the ember amulet capstone, and cascades rings across slots.
	# All three stations are already built here and the weapon slot is clear.
	# ml_bronze_sword: 3 bronze_ingot -> sword_bronze (attack 4).
	player.equip_item("weapon", "")
	hall.stockpile["bronze_ingot"] = 20
	var _ml_bsword: bool = hall.craft_station("anvil_bronze_sword", player)
	harness._check("ml_bronze_sword",
		_ml_bsword and str(player.equipped_dict().get("weapon", "")) == "sword_bronze"
		and player.attack_damage() == 4,
		"forge=%s weapon=%s atk=%d" % [str(_ml_bsword),
			str(player.equipped_dict().get("weapon", "")), player.attack_damage()])

	# ml_bronze_armor: 5 bronze_ingot -> full bronze set (armor 2+3+2 = 7).
	player.equip_item("weapon", "")
	hall.stockpile["bronze_ingot"] = 20
	var _ml_barmor: bool = hall.craft_station("anvil_bronze_armor", player)
	harness._check("ml_bronze_armor",
		_ml_barmor
		and str(player.equipped_dict().get("helmet", "")) == "helmet_bronze"
		and str(player.equipped_dict().get("torso", "")) == "torso_bronze"
		and str(player.equipped_dict().get("feet", "")) == "feet_bronze"
		and int(player.armor_total()) == 7,
		"forge=%s h=%s t=%s f=%s armor=%d" % [str(_ml_barmor),
			str(player.equipped_dict().get("helmet", "")),
			str(player.equipped_dict().get("torso", "")),
			str(player.equipped_dict().get("feet", "")), int(player.armor_total())])

	# ml_obsidian_sword: obsidian + iron_ingot -> sword_obsidian (attack 7).
	player.equip_item("weapon", "")
	hall.stockpile["obsidian"] = 20
	hall.stockpile["iron_ingot"] = 20
	var _ml_osword: bool = hall.craft_station("anvil_obsidian_sword", player)
	harness._check("ml_obsidian_sword",
		_ml_osword and str(player.equipped_dict().get("weapon", "")) == "sword_obsidian"
		and player.attack_damage() == 7,
		"forge=%s weapon=%s atk=%d" % [str(_ml_osword),
			str(player.equipped_dict().get("weapon", "")), player.attack_damage()])

	# ml_hellstone_armor: hellstone + iron_ingot -> apex armor set (3+6+3 = 12).
	player.equip_item("helmet", "")
	player.equip_item("torso", "")
	player.equip_item("feet", "")
	hall.stockpile["hellstone"] = 20
	hall.stockpile["iron_ingot"] = 20
	var _ml_harmor: bool = hall.craft_station("anvil_hellstone_armor", player)
	harness._check("ml_hellstone_armor",
		_ml_harmor and int(player.armor_total()) == 12,
		"forge=%s armor=%d" % [str(_ml_harmor), int(player.armor_total())])

	# ml_ember_amulet_capstone: hellstone + obsidian + crystal -> amulet_ember at
	# the workbench (rings + amulets host there; keeps the anvil's raw-ore gate
	# strict). Its attunement_bonus (12) lifts the gear attunement total.
	player.equip_item("amulet", "")
	var _ml_att0: float = player.attunement_bonus_from_gear()
	hall.stockpile["hellstone"] = 20
	hall.stockpile["obsidian"] = 20
	hall.stockpile["crystal"] = 20
	var _ml_amulet: bool = hall.craft_station("craft_ember_amulet", player)
	harness._check("ml_ember_amulet_capstone",
		_ml_amulet and str(player.equipped_dict().get("amulet", "")) == "amulet_ember"
		and player.attunement_bonus_from_gear() - _ml_att0 >= 12.0,
		"forge=%s amulet=%s att %.1f->%.1f" % [str(_ml_amulet),
			str(player.equipped_dict().get("amulet", "")),
			_ml_att0, player.attunement_bonus_from_gear()])

	# ml_ring_slot_cascade: two workbench ring recipes both target ring_1, but
	# town_hall cascades an occupied ring into the next free slot (ring_1..ring_4),
	# so three crafts fill ring_1, ring_2, ring_3 with silver/crystal rings.
	player.equip_item("ring_1", "")
	player.equip_item("ring_2", "")
	player.equip_item("ring_3", "")
	player.equip_item("ring_4", "")
	hall.stockpile["silver_ingot"] = 20
	hall.stockpile["crystal"] = 20
	var _ml_r1: bool = hall.craft_station("craft_silver_ring", player)
	var _ml_r2: bool = hall.craft_station("craft_silver_ring", player)
	var _ml_r3: bool = hall.craft_station("craft_attuned_ring", player)
	var _ml_rd: Dictionary = player.equipped_dict()
	var _ml_ring_ids := ["ring_silver", "ring_crystal"]
	harness._check("ml_ring_slot_cascade",
		_ml_r1 and _ml_r2 and _ml_r3
		and str(_ml_rd.get("ring_1", "")) != "" and str(_ml_rd.get("ring_2", "")) != ""
		and str(_ml_rd.get("ring_3", "")) != ""
		and _ml_ring_ids.has(str(_ml_rd.get("ring_1", "")))
		and _ml_ring_ids.has(str(_ml_rd.get("ring_2", "")))
		and _ml_ring_ids.has(str(_ml_rd.get("ring_3", ""))),
		"r1=%s r2=%s r3=%s slots=[%s,%s,%s]" % [str(_ml_r1), str(_ml_r2), str(_ml_r3),
			str(_ml_rd.get("ring_1", "")), str(_ml_rd.get("ring_2", "")),
			str(_ml_rd.get("ring_3", ""))])

	# (g) built stations round-trip through save/load (pre-FQ-11 saves default
	# to nothing built).
	root.save_manager.save_game()
	hall.stations_built = {"workbench": false, "furnace": false, "anvil": false}
	root.load_game()
	harness._check("fq11_stations_persist",
		hall.station_built("workbench") and hall.station_built("furnace")
		and hall.station_built("anvil"),
		"wb=%s fn=%s av=%s" % [str(hall.station_built("workbench")),
			str(hall.station_built("furnace")), str(hall.station_built("anvil"))])

	# Clear any forged gear so later FQ-01/FQ-05 checks see an unarmored player.
	player.equip_item("weapon", "")
	player.equip_item("offhand_weapon", "")
	player.equip_item("helmet", "")
	player.equip_item("torso", "")
	player.equip_item("feet", "")
	player.equip_item("ring_1", "")
	player.equip_item("ring_2", "")
	player.equip_item("ring_3", "")
	player.equip_item("ring_4", "")
	player.equip_item("amulet", "")
	player.equip_item("accessory", "")
	player.health = player.max_health

	# --- FQ-12: farming (till, plant, grow, harvest, no-float, save/load) ---
	var _fq12_soil := Vector2i(40, 40)
	var _fq12_crop := Vector2i(40, 39)
	var _fq12_stone := Vector2i(42, 40)
	var _fq12_float := Vector2i(42, 39)
	world.cells[_fq12_soil] = "dirt"; world.deltas[_fq12_soil] = "dirt"
	world.cells[_fq12_stone] = "stone"; world.deltas[_fq12_stone] = "stone"
	world.cells.erase(_fq12_crop); world.deltas[_fq12_crop] = "air"
	world.cells.erase(_fq12_float); world.deltas[_fq12_float] = "air"
	world.crop_growth.clear()

	# (a) till: dirt -> farm_soil; stone cannot be tilled.
	var _fq12_till: bool = world.till_soil(_fq12_soil)
	var _fq12_till_stone: bool = world.till_soil(_fq12_stone)
	harness._check("fq12_till_soil",
		_fq12_till and world.block_at(_fq12_soil) == "farm_soil"
		and not _fq12_till_stone and world.block_at(_fq12_stone) == "stone",
		"tilled=%s now=%s stone_tillable=%s" % [str(_fq12_till),
			world.block_at(_fq12_soil), str(_fq12_till_stone)])

	# (b) planting needs tilled soil directly below — crops never float.
	var _fq12_plant_float: bool = world.plant_crop(_fq12_float)   # below is stone
	var _fq12_plant: bool = world.plant_crop(_fq12_crop)          # below is farm_soil
	harness._check("fq12_plant_on_soil_only",
		_fq12_plant and world.block_at(_fq12_crop) == "crop_seedling"
		and world.crop_growth.has(_fq12_crop) and not _fq12_plant_float
		and world.block_at(_fq12_float) == "air",
		"planted=%s floating_allowed=%s" % [str(_fq12_plant), str(_fq12_plant_float)])

	# (c) a seedling on tilled soil ripens once its timer elapses.
	world.crop_growth[_fq12_crop] = 0.01
	world._tick_crop_growth(0.02)
	harness._check("fq12_crop_ripens",
		world.block_at(_fq12_crop) == "crop_ripe"
		and not world.crop_growth.has(_fq12_crop),
		"crop=%s" % world.block_at(_fq12_crop))

	# (d) harvest: breaking the ripe crop yields food + a seed.
	var _fq12_drops: Dictionary = world.break_block(_fq12_crop)
	harness._check("fq12_harvest_yields_food",
		int(_fq12_drops.get("food", 0)) >= 1
		and int(_fq12_drops.get("crop_seeds", 0)) >= 1
		and world.block_at(_fq12_crop) == "air",
		"drops=%s" % str(_fq12_drops))

	# (e) no float / no wrong regrow: removing the tilled soil under a seedling
	# removes the crop — it never floats and never becomes a berry bush.
	world.plant_crop(_fq12_crop)
	world.break_block(_fq12_soil)
	world._tick_crop_growth(0.0)
	harness._check("fq12_no_float_no_regrow",
		world.block_at(_fq12_crop) == "air"
		and not world.crop_growth.has(_fq12_crop)
		and not world.bush_regrow.has(_fq12_crop),
		"crop=%s in_bush_regrow=%s" % [world.block_at(_fq12_crop),
			str(world.bush_regrow.has(_fq12_crop))])

	# (f) crops + their growth timers round-trip through save/load.
	world.cells[_fq12_soil] = "dirt"; world.deltas[_fq12_soil] = "dirt"
	world.till_soil(_fq12_soil)
	world.cells.erase(_fq12_crop); world.deltas[_fq12_crop] = "air"
	world.plant_crop(_fq12_crop)
	world.crop_growth[_fq12_crop] = 42.0
	root.save_manager.save_game()
	world.crop_growth.clear()
	root.load_game()
	harness._check("fq12_crop_saves",
		world.block_at(_fq12_crop) == "crop_seedling"
		and world.crop_growth.has(_fq12_crop),
		"crop=%s timer_restored=%s" % [world.block_at(_fq12_crop),
			str(world.crop_growth.has(_fq12_crop))])

	# (g) the food-yard score counts tilled soil + crops and is exposed to UI.
	var _fq12_farm: int = world.farm_tile_count()
	harness._check("fq12_farm_score",
		_fq12_farm >= 2 and "farm" in root.summary(),
		"farm_tiles=%d summary_has_farm=%s" % [_fq12_farm, str("farm" in root.summary())])

	# (h) plant onto soil directly: the farm action aimed at the tilled SOIL
	# plants in the open cell above it (the natural gesture, not only aiming at
	# the empty air), and a backing wall behind the bed never blocks it.
	world.cells[_fq12_soil] = "dirt"; world.deltas[_fq12_soil] = "dirt"
	world.till_soil(_fq12_soil)
	world.cells.erase(_fq12_crop); world.deltas[_fq12_crop] = "air"
	world.crop_growth.clear()
	player.global_position = world.cell_center(_fq12_soil) + Vector2(0.0, -8.0)
	player.inventory.add("crop_seeds", 1)
	var _fq12_seeds_before: int = player.inventory.count("crop_seeds")
	var _fq12_soil_plant: bool = player.try_farm(_fq12_soil)   # aim at the soil block
	harness._check("fq12_plant_onto_soil_aim",
		_fq12_soil_plant and world.block_at(_fq12_crop) == "crop_seedling"
		and player.inventory.count("crop_seeds") == _fq12_seeds_before - 1,
		"planted=%s above=%s seeds=%d" % [str(_fq12_soil_plant),
			world.block_at(_fq12_crop), player.inventory.count("crop_seeds")])

	# --- FQ-05: attunement resource, hooks, pulse, save/load ---

	# (a) data-driven defaults: base max 50, current within bounds.
	harness._check("fq05_attunement_defaults",
		absf(player.max_attunement() - 50.0) < 0.001
		and player.attunement > 0.0 and player.attunement <= player.max_attunement(),
		"attunement=%.1f max=%.1f" % [player.attunement, player.max_attunement()])

	# (b) the light pulse spends attunement, lights up, and respects its cooldown.
	player.attunement = player.max_attunement()
	player._pulse_cooldown = 0.0
	var _fq05_max: float = player.max_attunement()
	var _fq05_fired: bool = player._try_attune_pulse()
	var _fq05_after_pulse: float = player.attunement
	var _fq05_light_on: bool = player._pulse_light != null \
		and player._pulse_light.enabled and player._pulse_light.energy > 0.0
	var _fq05_second: bool = player._try_attune_pulse()   # cooldown active
	harness._check("fq05_pulse_spends_and_cools",
		_fq05_fired and absf(_fq05_after_pulse - (_fq05_max - 15.0)) < 0.001
		and _fq05_light_on and not _fq05_second
		and absf(player.attunement - _fq05_after_pulse) < 0.001,
		"fired=%s attunement %.1f→%.1f light=%s second_blocked=%s" % [str(_fq05_fired),
			_fq05_max, _fq05_after_pulse, str(_fq05_light_on), str(not _fq05_second)])

	# (c) insufficient attunement blocks the pulse without spending.
	player.attunement = 5.0
	player._pulse_cooldown = 0.0
	var _fq05_blocked: bool = not player._try_attune_pulse()
	harness._check("fq05_pulse_blocked_when_insufficient",
		_fq05_blocked and absf(player.attunement - 5.0) < 0.001,
		"blocked=%s attunement=%.1f" % [str(_fq05_blocked), player.attunement])

	# (d) attunement regenerates over time (no safety gate).
	player.attunement = 10.0
	for _fq05_i in range(65):
		player._update_attunement_regen(1.0 / 60.0)
	harness._check("fq05_attunement_regenerates", player.attunement > 10.0,
		"attunement 10.0→%.2f after ~1s" % player.attunement)

	# (e) ancestry and equipment hooks raise the maximum; removing them clamps.
	player.apply_ancestry_effects({"attunement_bonus": 20.0, "attunement_regen_mult": 2.0})
	var _fq05_anc_max: float = player.max_attunement()
	var _fq05_regen_mult: float = player.attunement_regen_mult
	var _fq05_amulet_ok: bool = player.equip_item("amulet", "amulet_focus")
	var _fq05_gear_max: float = player.max_attunement()
	# Restore: reset ancestry to the real character and remove the amulet.
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species(str(GameState.current_character.get("species", "")))
	player.equip_item("amulet", "")
	harness._check("fq05_ancestry_and_gear_hooks",
		absf(_fq05_anc_max - 70.0) < 0.001 and absf(_fq05_regen_mult - 2.0) < 0.001
		and _fq05_amulet_ok and absf(_fq05_gear_max - 80.0) < 0.001
		and absf(player.max_attunement() - 50.0) < 0.001
		and player.attunement <= player.max_attunement(),
		"ancestry_max=%.1f gear_max=%.1f restored_max=%.1f regen_mult=%.1f" % [
			_fq05_anc_max, _fq05_gear_max, player.max_attunement(), _fq05_regen_mult])

	# (f) current attunement rides the world save next to health — including
	# a surplus above the base max from gear (review fix: the load path must
	# not clamp against the pre-gear cap and destroy the surplus).
	player.equip_item("amulet", "amulet_focus")   # max 60
	player.attunement = 55.0
	root.save_manager.save_game()
	player.equip_item("amulet", "")               # max back to 50; clamps to 50
	player.attunement = 10.0
	root.load_game()                              # re-equips the amulet from the record
	harness._check("fq05_attunement_saves_and_loads",
		absf(player.attunement - 55.0) < 0.01
		and absf(player.max_attunement() - 60.0) < 0.001,
		"attunement after load=%.2f (expected 55.0) max=%.1f" % [
			player.attunement, player.max_attunement()])
	player.equip_item("amulet", "")
	player.attunement = player.max_attunement()
	root.save_manager.save_game()   # persist the amulet removal for later sections
