class_name WorldConfig
extends RefCounted
## A world's full simulation configuration. Gameplay systems read from
## this instead of hardcoding rules; data/world_settings.json is the
## authority for defaults, sizes, and presets.

var data: Dictionary = {}


static func settings() -> Dictionary:
	return BlockRegistry.world_settings


static func defaults() -> Dictionary:
	return _deep_copy(settings().get("defaults", {}))


## Builds a config dict from a preset id, overlaying preset values on
## the defaults. Unknown preset ids fall back to pure defaults.
static func from_preset(preset_id: String) -> Dictionary:
	var config: Dictionary = defaults()
	var preset: Dictionary = settings().get("presets", {}).get(preset_id, {})
	for section in ["difficulty", "rules", "generation"]:
		var overrides: Dictionary = preset.get(section, {})
		for key in overrides:
			config[section][key] = overrides[key]
	if preset.has("environment_danger"):
		config["environment_danger"] = preset["environment_danger"]
	config["preset"] = preset_id
	return config


static func _deep_copy(source: Dictionary) -> Dictionary:
	return source.duplicate(true)


func _init(config_data: Dictionary = {}) -> void:
	data = WorldConfig.defaults()
	# Overlay saved/custom values on defaults so old configs gain new keys.
	for key in config_data:
		if data.get(key) is Dictionary and config_data[key] is Dictionary:
			for sub_key in config_data[key]:
				data[key][sub_key] = config_data[key][sub_key]
		else:
			data[key] = config_data[key]


func world_name() -> String:
	return str(data.get("name", "New World"))


func seed_value() -> int:
	return int(data.get("seed", 0))


func size_id() -> String:
	return str(data.get("size", "medium"))


func size_dims() -> Dictionary:
	var sizes: Dictionary = WorldConfig.settings().get("sizes", {})
	return sizes.get(size_id(), {"width": 240, "height": 80, "surface_base": 30})


func rule(rule_name: String) -> bool:
	return bool(data.get("rules", {}).get(rule_name, false))


func difficulty(axis: String) -> float:
	return float(data.get("difficulty", {}).get(axis, 1.0))


func environment_danger() -> float:
	return float(data.get("environment_danger", 1.0))


func gen(key: String) -> float:
	return float(data.get("generation", {}).get(key, 1.0))


func to_dict() -> Dictionary:
	return data.duplicate(true)
