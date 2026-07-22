extends RefCounted
## R-07: user key rebinding. Overrides are profile-level preferences stored in
## user://shell.json (like audio_settings), never in world or character saves:
##   profile["keybinds"] = { action: { "keycode": int, "physical": int } }
## Static helpers so the pause-menu settings screen and startup share one apply
## path. Only the gameplay actions below are rebindable; ui_* and debug_overlay
## are intentionally left alone. Only the KEYBOARD event of an action is
## replaced; any mouse/joypad events on the same action are preserved.

const REBINDABLE := [
	"move_left", "move_right", "jump", "mine", "place", "interact",
	"toggle_town", "craft", "eat_food", "attune_pulse", "swap_weapon",
	"farm_action", "toggle_inventory", "toggle_skills", "toggle_map",
	"toggle_goals", "save_game", "load_game",
]

const LABELS := {
	"move_left": "Move Left", "move_right": "Move Right", "jump": "Jump",
	"mine": "Mine", "place": "Place Block", "interact": "Interact",
	"toggle_town": "Town Hall", "craft": "Craft", "eat_food": "Eat Food",
	"attune_pulse": "Attune Pulse", "swap_weapon": "Swap Weapon",
	"farm_action": "Farm", "toggle_inventory": "Inventory",
	"toggle_skills": "Skills", "toggle_map": "Map", "toggle_goals": "Goals",
	"save_game": "Save", "load_game": "Load",
}

# Default keyboard event per action, captured once from the project InputMap so
# "reset to defaults" and "is this changed?" work after any override is applied.
static var _defaults: Dictionary = {}


static func _capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for action in REBINDABLE:
		if InputMap.has_action(action):
			for ev in InputMap.action_get_events(action):
				if ev is InputEventKey:
					_defaults[action] = (ev as InputEventKey).duplicate()
					break


static func label(action: String) -> String:
	return LABELS.get(action, action)


## The action's current keyboard event (null if none bound).
static func primary_key_event(action: String) -> InputEventKey:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev
	return null


static func key_label(action: String) -> String:
	var ev := primary_key_event(action)
	if ev == null:
		return "(unset)"
	return ev.as_text().trim_suffix(" (Physical)")


## The action's first bound event, whatever its type (key or mouse), or null.
static func primary_event(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	var evs := InputMap.action_get_events(action)
	return evs[0] if evs.size() > 0 else null


## Whether the action can be rebound to a key here: it is in the rebindable set
## and is not bound to the mouse (mouse rebinding is deferred -- those rows are
## shown as fixed). An unbound action is still key-rebindable.
static func is_key_rebindable(action: String) -> bool:
	if not REBINDABLE.has(action) or not InputMap.has_action(action):
		return false
	var ev := primary_event(action)
	return ev == null or ev is InputEventKey


## Human-readable label for the action's current binding -- key text, or a fixed
## mouse label (so a mouse-bound action never reads "(unset)").
static func binding_label(action: String) -> String:
	var ev := primary_event(action)
	if ev is InputEventKey:
		return (ev as InputEventKey).as_text().trim_suffix(" (Physical)")
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Primary Mouse (fixed)"
			MOUSE_BUTTON_RIGHT:
				return "Secondary Mouse (fixed)"
			MOUSE_BUTTON_MIDDLE:
				return "Middle Mouse (fixed)"
			_:
				return "Mouse Button %d (fixed)" % (ev as InputEventMouseButton).button_index
	return "(unset)"


## Whether the action's current keyboard event differs from the project default.
static func is_changed(action: String) -> bool:
	_capture_defaults()
	var cur := primary_key_event(action)
	var base: InputEventKey = _defaults.get(action, null)
	if cur == null or base == null:
		return cur != base
	return cur.keycode != base.keycode or cur.physical_keycode != base.physical_keycode


## The rebindable action currently bound to `key_event`'s key, excluding
## `exclude_action`, or "" if none. Used to reject duplicate bindings so two
## actions can't share one key. Matches on keycode or physical_keycode.
static func action_using_key(key_event: InputEventKey, exclude_action: String) -> String:
	if key_event == null:
		return ""
	for action in REBINDABLE:
		if action == exclude_action or not InputMap.has_action(action):
			continue
		var ev := primary_key_event(action)
		if ev == null:
			continue
		# Guard keycode against 0: the project binds by physical_keycode, so every
		# action has keycode == 0 -- 0 == 0 would be a false match.
		if (key_event.keycode != 0 and ev.keycode == key_event.keycode) \
				or (key_event.physical_keycode != 0 \
				and ev.physical_keycode == key_event.physical_keycode):
			return action
	return ""


## Replace the action's keyboard binding (keeping any non-key events) and record
## the override in the profile. Does NOT persist -- the caller owns save_shell().
static func rebind(profile: Dictionary, action: String, key_event: InputEventKey) -> void:
	_capture_defaults()
	# Contract: only ever touch actions we declared rebindable.
	if not REBINDABLE.has(action) or not InputMap.has_action(action) or key_event == null:
		return
	_set_key_event(action, key_event)
	var store: Dictionary = profile.get("keybinds", {})
	store[action] = {
		"keycode": int(key_event.keycode),
		"physical": int(key_event.physical_keycode),
	}
	profile["keybinds"] = store


## Apply all stored overrides to the live InputMap. Safe to call at startup.
static func apply(profile: Dictionary) -> void:
	_capture_defaults()
	var store: Dictionary = profile.get("keybinds", {})
	for action in store:
		# Contract: ignore stored overrides for anything outside the rebindable set.
		if not REBINDABLE.has(action) or not InputMap.has_action(action):
			continue
		var d: Dictionary = store[action]
		var ev := InputEventKey.new()
		ev.keycode = int(d.get("keycode", 0))
		ev.physical_keycode = int(d.get("physical", 0))
		_set_key_event(action, ev)


## Restore all rebindable actions to their captured defaults and drop overrides.
static func reset(profile: Dictionary) -> void:
	_capture_defaults()
	profile.erase("keybinds")
	for action in REBINDABLE:
		if _defaults.has(action) and InputMap.has_action(action):
			_set_key_event(action, (_defaults[action] as InputEventKey).duplicate())


## Swap the single keyboard event on an action, preserving mouse/joypad events.
static func _set_key_event(action: String, key_event: InputEventKey) -> void:
	var kept: Array = []
	for ev in InputMap.action_get_events(action):
		if not (ev is InputEventKey):
			kept.append(ev)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, key_event)
	for ev in kept:
		InputMap.action_add_event(action, ev)
