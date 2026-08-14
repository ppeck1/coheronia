extends Node
## S-07.3 smoke domain module - equipment & first combat gear (FQ-03 gear slots
## data model, FQ-04 sword+armor). Order-preserving; harness owns _check().

func run(ctx) -> void:
	# S-07.3 ctx seam (work order §11): unpack the handles this cluster uses.
	var harness = ctx.harness
	var root = ctx.root
	var player = ctx.player
	var hall = ctx.hall
	var hud = ctx.hud
	# --- FQ-03: equipment data model and character-owned gear slots ---

	# (a) equipment.json loads with the expected slots, in order.
	var _fq03_expected: Array = ["weapon", "offhand_weapon", "axe", "pickaxe", "helmet", "torso",
		"feet", "ring_1", "ring_2", "ring_3", "ring_4", "amulet", "accessory"]
	var _fq03_slot_ids: Array = []
	for _fq03_slot in BlockRegistry.equipment_slots():
		_fq03_slot_ids.append(str(_fq03_slot.get("id", "")))
	harness._check("fq03_equipment_json_loads", _fq03_slot_ids == _fq03_expected,
		"slots=%s" % str(_fq03_slot_ids))

	# (b) a new character record carries default gear: basic pick, rest empty.
	var _fq03_char: Dictionary = GameState.create_character(
		{"name": "GearSmoke", "role": "homesteader"})
	var _fq03_equip: Dictionary = Dictionary(_fq03_char.get("equipment", {}))
	var _fq03_empty_count := 0
	for _fq03_sid in _fq03_equip:
		if str(_fq03_equip[_fq03_sid]) == "":
			_fq03_empty_count += 1
	harness._check("fq03_new_character_default_gear",
		_fq03_equip.size() == 13 and str(_fq03_equip.get("pickaxe", "")) == "pick_basic"
		and _fq03_empty_count == 12,
		"equipment=%s" % str(_fq03_equip))
	GameState.delete_character(str(_fq03_char["id"]))

	# (c) equipped tool slots mirror the live tool tiers both ways.
	player.tool_tier = 2
	player.axe_tier = 1
	var _fq03_geared: Dictionary = player.equipped_dict()
	player.tool_tier = 1
	player.axe_tier = 0
	var _fq03_bare: Dictionary = player.equipped_dict()
	harness._check("fq03_tool_slots_mirror_tiers",
		str(_fq03_geared.get("pickaxe", "")) == "pick_forged"
		and str(_fq03_geared.get("axe", "")) == "axe_crude"
		and str(_fq03_bare.get("pickaxe", "")) == "pick_basic"
		and str(_fq03_bare.get("axe", "")) == "",
		"tier2/1=%s|%s tier1/0=%s|%s" % [str(_fq03_geared.get("pickaxe")),
			str(_fq03_geared.get("axe")), str(_fq03_bare.get("pickaxe")),
			str(_fq03_bare.get("axe"))])
	player.tool_tier = 2
	player.axe_tier = 1

	# (d) slot/item fit is enforced; tool slots clear to tier 0 and restore
	# from item effects; equipping never touches the backpack.
	var _fq03_inv_total: int = player.inventory.total()
	var _fq03_pick_cleared: bool = player.equip_item("pickaxe", "") and player.tool_tier == 0
	var _fq03_pick_restored: bool = player.equip_item("pickaxe", "pick_forged") \
		and player.tool_tier == 2
	harness._check("fq03_equip_rejects_mismatch",
		not player.equip_item("helmet", "ring_band")
		and not player.equip_item("no_such_slot", "ring_band")
		and _fq03_pick_cleared
		and _fq03_pick_restored
		and player.equip_item("ring_2", "ring_band")
		and player.inventory.total() == _fq03_inv_total,
		"ring_2=%s pick=%d inv_total %d→%d" % [str(player.equipment.get("ring_2", "")),
			player.tool_tier, _fq03_inv_total, player.inventory.total()])

	# (e) an equipped item round-trips through the character save/load path;
	# empty slots stay valid alongside it.
	root.save_manager.save_game()
	player.apply_equipment({})   # wipe live gear; load must restore it
	var _fq03_wiped: Dictionary = player.equipped_dict()
	root.load_game()
	var _fq03_restored: Dictionary = player.equipped_dict()
	harness._check("fq03_equipped_item_round_trips",
		str(_fq03_wiped.get("ring_2", "")) == ""
		and str(_fq03_restored.get("ring_2", "")) == "ring_band"
		and str(_fq03_restored.get("amulet", "")) == ""
		and str(_fq03_restored.get("pickaxe", "")) == "pick_forged",
		"wiped_ring=%s restored_ring=%s pickaxe=%s" % [str(_fq03_wiped.get("ring_2")),
			str(_fq03_restored.get("ring_2")), str(_fq03_restored.get("pickaxe"))])

	# (f) inventory panel shows every gear slot; empty slots are visible.
	hud.toggle_inventory_panel()
	var _fq03_panel: String = hud.get_inventory_panel_text()
	hud.toggle_inventory_panel()
	harness._check("fq03_panel_shows_gear_slots",
		"EQUIPMENT" in _fq03_panel and "Pickaxe: Forged Pick" in _fq03_panel
		and "Ring 2: Plain Band" in _fq03_panel
		and "Ring 4: (empty)" in _fq03_panel and "Amulet: (empty)" in _fq03_panel,
		"panel_tail=%s" % _fq03_panel.right(180))

	# (g) a pre-FQ-03 character (no equipment key) migrates: tool tiers and
	# inventory preserved, gear derived from the tiers.
	var _fq03_leg: Dictionary = GameState.create_character(
		{"name": "GearLegacy", "role": "homesteader"})
	var _fq03_lid: String = str(_fq03_leg["id"])
	for _fq03_i in range(GameState.characters.size()):
		if str(GameState.characters[_fq03_i].get("id", "")) == _fq03_lid:
			GameState.characters[_fq03_i].erase("equipment")
			GameState.characters[_fq03_i]["carried_inventory"] = {"dirt": 3}
			GameState.characters[_fq03_i]["carried_tool_tiers"] = {"pick": 2, "axe": 1}
			GameState.characters[_fq03_i]["items_granted"] = true
			break
	GameState.save_shell()
	GameState.load_shell()
	var _fq03_prev_char: Dictionary = GameState.current_character
	GameState.current_character = GameState.get_character(_fq03_lid)
	root._load_character_carried_state({})
	var _fq03_mig_equip: Dictionary = player.equipped_dict()
	# Review fix: the migration must persist the equipment key onto the record
	# immediately, not just derive it in memory.
	var _fq03_lc_record: Dictionary = GameState.get_character(_fq03_lid)
	var _fq03_rec_equip: Dictionary = Dictionary(_fq03_lc_record.get("equipment", {}))
	harness._check("fq03_legacy_character_migrates",
		player.tool_tier == 2 and player.axe_tier == 1
		and player.inventory.count("dirt") == 3
		and str(_fq03_mig_equip.get("pickaxe", "")) == "pick_forged"
		and str(_fq03_mig_equip.get("axe", "")) == "axe_crude"
		and _fq03_lc_record.has("equipment")
		and str(_fq03_rec_equip.get("pickaxe", "")) == "pick_forged",
		"pick=%d axe=%d dirt=%d gear=%s|%s record_gear=%s" % [player.tool_tier,
			player.axe_tier, player.inventory.count("dirt"),
			str(_fq03_mig_equip.get("pickaxe")), str(_fq03_mig_equip.get("axe")),
			str(_fq03_rec_equip.get("pickaxe"))])
	GameState.current_character = _fq03_prev_char
	GameState.delete_character(_fq03_lid)
	# Restore the real character's carried state for the FQ-01 section below.
	root._apply_character_carried_state()
	player.tool_tier = 2
	player.axe_tier = 1

	# --- FQ-04: first combat gear slice — sword and armor ---

	# (a) bare-handed baseline: no weapon, no armor.
	harness._check("fq04_unarmed_baseline",
		player.attack_damage() == 1 and player.armor_total() == 0.0
		and str(player.equipped_dict().get("weapon", "")) == "",
		"attack=%d armor=%.0f" % [player.attack_damage(), player.armor_total()])

	# (b) forging the sword equips it, consumes stockpile, and cannot repeat.
	hall.stockpile["wood"] = 20
	hall.stockpile["stone"] = 20
	var _fq04_wood_before: int = int(hall.stockpile.get("wood", 0))
	var _fq04_stone_before: int = int(hall.stockpile.get("stone", 0))
	var _fq04_sword_ok: bool = hall.forge_sword(player)
	var _fq04_offhand_ok: bool = hall.forge_sword(player)
	harness._check("fq04_forge_sword_equips",
		_fq04_sword_ok and str(player.equipped_dict().get("weapon", "")) == "sword_crude"
		and _fq04_offhand_ok and str(player.equipped_dict().get("offhand_weapon", "")) == "sword_crude"
		and player.attack_damage() == 3
		and int(hall.stockpile.get("wood", 0)) == _fq04_wood_before - 4
		and int(hall.stockpile.get("stone", 0)) == _fq04_stone_before - 6
		and not hall.forge_sword(player),
		"attack=%d weapon=%s offhand=%s wood %d→%d stone %d→%d" % [player.attack_damage(),
			str(player.equipped_dict().get("weapon", "")),
			str(player.equipped_dict().get("offhand_weapon", "")),
			_fq04_wood_before, int(hall.stockpile.get("wood", 0)),
			_fq04_stone_before, int(hall.stockpile.get("stone", 0))])
	player.equip_item("offhand_weapon", "sword_iron")
	var _fq04_swap_to_iron: bool = player.swap_weapon()
	var _fq04_attack_iron: int = player.attack_damage()
	var _fq04_swap_back: bool = player.swap_weapon()
	harness._check("fq04_weapon_swap_uses_offhand",
		_fq04_swap_to_iron and _fq04_attack_iron == 5 and _fq04_swap_back
		and str(player.equipped_dict().get("weapon", "")) == "sword_crude"
		and str(player.equipped_dict().get("offhand_weapon", "")) == "sword_iron"
		and player.attack_damage() == 3,
		"active=%s offhand=%s attack_mid=%d attack_now=%d" % [
			str(player.equipped_dict().get("weapon", "")),
			str(player.equipped_dict().get("offhand_weapon", "")),
			_fq04_attack_iron, player.attack_damage()])

	# (c) the sword kills a 3 hp slime in one real hit-path strike.
	for _fq04_t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_fq04_t):
			_fq04_t.queue_free()
	await get_tree().process_frame
	var _fq04_slime: Node = root.spawn_enemy_for_test("surface_slime")
	_fq04_slime.hp = 3
	_fq04_slime.max_hp = 3
	player.global_position = _fq04_slime.global_position
	var _fq04_hit: bool = player._try_hit_threat(_fq04_slime.global_position)
	await get_tree().process_frame
	var _fq04_dead: bool = not is_instance_valid(_fq04_slime) \
		or _fq04_slime.is_queued_for_deletion()
	harness._check("fq04_sword_damages_enemy", _fq04_hit and _fq04_dead,
		"hit=%s dead_after_one_sword_strike=%s" % [str(_fq04_hit), str(_fq04_dead)])

	# (d) forging the armor set equips helmet/torso/feet and cannot repeat.
	var _fq04_armor_ok: bool = hall.forge_armor(player)
	var _fq04_after_armor: Dictionary = player.equipped_dict()
	harness._check("fq04_forge_armor_equips_set",
		_fq04_armor_ok
		and str(_fq04_after_armor.get("helmet", "")) == "helmet_crude"
		and str(_fq04_after_armor.get("torso", "")) == "torso_crude"
		and str(_fq04_after_armor.get("feet", "")) == "feet_crude"
		and player.armor_total() == 4.0
		and not hall.forge_armor(player),
		"armor=%.0f set=%s|%s|%s" % [player.armor_total(),
			str(_fq04_after_armor.get("helmet")), str(_fq04_after_armor.get("torso")),
			str(_fq04_after_armor.get("feet"))])

	# (e) armor reduces incoming damage by exactly the data-defined sum.
	player.health = player.max_health
	player._hurt_cooldown = 0.0
	var _fq04_expected_loss: float = 10.0 - player.armor_total()
	player.take_damage(10.0)
	harness._check("fq04_armor_reduces_damage",
		absf((player.max_health - player.health) - _fq04_expected_loss) < 0.001,
		"lost %.1f expected %.1f (armor %.0f)" % [player.max_health - player.health,
			_fq04_expected_loss, player.armor_total()])

	# (f) armor can never fully block: a landed hit chips at least 1 health.
	player.health = player.max_health
	player._hurt_cooldown = 0.0
	player.take_damage(2.0)
	harness._check("fq04_armor_minimum_chip_damage",
		absf((player.max_health - player.health) - 1.0) < 0.001,
		"lost %.1f from a 2.0 hit under %.0f armor" % [
			player.max_health - player.health, player.armor_total()])

	# (g) combat gear round-trips through character save/load and leaves
	# ancestry/trait max_health untouched.
	var _fq04_max_health_before: float = player.max_health
	root.save_manager.save_game()
	player.apply_equipment({})
	var _fq04_armor_wiped: float = player.armor_total()
	root.load_game()
	harness._check("fq04_gear_round_trips_ancestry_intact",
		_fq04_armor_wiped == 0.0
		and str(player.equipped_dict().get("weapon", "")) == "sword_crude"
		and str(player.equipped_dict().get("offhand_weapon", "")) == "sword_iron"
		and player.armor_total() == 4.0
		and absf(player.max_health - _fq04_max_health_before) < 0.001,
		"armor wiped=%.0f restored=%.0f max_health=%.1f (expected %.1f)" % [
			_fq04_armor_wiped, player.armor_total(),
			player.max_health, _fq04_max_health_before])

	# (h) the equipment UI shows weapon/armor state.
	hud.toggle_inventory_panel()
	var _fq04_panel: String = hud.get_inventory_panel_text()
	hud.toggle_inventory_panel()
	harness._check("fq04_ui_shows_weapon_and_armor",
		"Attack 3" in _fq04_panel and "Armor 4" in _fq04_panel
		and "Weapon: Crude Sword" in _fq04_panel
		and "Offhand: Iron Sword" in _fq04_panel
		and "Torso: Crude Cuirass" in _fq04_panel,
		"panel_head=%s" % _fq04_panel.left(60))

	# Clear combat gear so the FQ-01 exact-damage checks below see the same
	# unarmored player they were written against.
	player.equip_item("weapon", "")
	player.equip_item("offhand_weapon", "")
	player.equip_item("helmet", "")
	player.equip_item("torso", "")
	player.equip_item("feet", "")
	player.health = player.max_health
