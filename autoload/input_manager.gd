extends Node

signal binding_changed(player: int, action_id: StringName)

const ACTION_IDS: Array[StringName] = [&"move_left", &"move_right", &"jump", &"light", &"heavy", &"roll", &"red", &"green", &"blue"]
const DEFAULT_KEYS := {
	1: {&"move_left": KEY_A, &"move_right": KEY_D, &"jump": KEY_SPACE, &"light": KEY_F, &"heavy": KEY_X, &"roll": KEY_END, &"red": KEY_1, &"green": KEY_2, &"blue": KEY_3},
	2: {&"move_left": KEY_LEFT, &"move_right": KEY_RIGHT, &"jump": KEY_ENTER, &"light": KEY_0, &"heavy": 4194439, &"roll": 4194434, &"red": KEY_7, &"green": KEY_8, &"blue": KEY_9},
}
const DEFAULT_BUTTONS := {
	&"jump": JOY_BUTTON_A,
	&"roll": JOY_BUTTON_B,
	&"light": JOY_BUTTON_X,
	&"heavy": JOY_BUTTON_Y,
	&"red": JOY_BUTTON_DPAD_LEFT,
	&"green": JOY_BUTTON_DPAD_UP,
	&"blue": JOY_BUTTON_DPAD_RIGHT,
}

var _joy_bindings: Dictionary = {1: {}, 2: {}}

func _settings() -> Node:
	return get_node_or_null("/root/SettingsManager")

func _ready() -> void:
	load_bindings()

func action_name(player: int, action_id: StringName) -> StringName:
	var names := {
		&"move_left": &"move_left", &"move_right": &"move_right", &"jump": &"jump",
		&"light": &"light_attack", &"heavy": &"heavy_attack", &"roll": &"roll",
		&"red": &"color_red", &"green": &"color_green", &"blue": &"color_blue",
	}
	var base: StringName = names.get(action_id, action_id)
	if player == 1:
		return base
	var p2_names := {&"red": &"p2_red", &"green": &"p2_green", &"blue": &"p2_blue"}
	return p2_names.get(action_id, StringName("p2_" + String(base)))

func joy_button(player: int, action_id: StringName) -> int:
	return int(_joy_bindings.get(player, {}).get(action_id, DEFAULT_BUTTONS.get(action_id, -1)))

func rebind_key(player: int, action_id: StringName, physical_keycode: int) -> void:
	_apply_key(player, action_id, physical_keycode)
	_settings().set_value(&"controls", _binding_key(player, action_id, &"key"), int(physical_keycode))
	binding_changed.emit(player, action_id)

func rebind_joy_button(player: int, action_id: StringName, button: int) -> void:
	_joy_bindings[player][action_id] = int(button)
	_settings().set_value(&"controls", _binding_key(player, action_id, &"joy"), int(button))
	binding_changed.emit(player, action_id)

func find_conflict(player: int, action_id: StringName, event: InputEvent) -> StringName:
	for other in ACTION_IDS:
		if other == action_id:
			continue
		if event is InputEventKey and key_for(player, other) == event.physical_keycode:
			return other
		if event is InputEventJoypadButton and joy_button(player, other) == event.button_index:
			return other
	return &""

func key_for(player: int, action_id: StringName) -> int:
	for event in InputMap.action_get_events(action_name(player, action_id)):
		if event is InputEventKey:
			return event.physical_keycode
	return KEY_NONE

func binding_text(player: int, action_id: StringName) -> String:
	var key := key_for(player, action_id)
	var button := joy_button(player, action_id)
	var key_text := OS.get_keycode_string(key) if key != KEY_NONE else "Unbound"
	return "%s / %s" % [key_text, _joy_button_text(button)]

func reset_player(player: int) -> void:
	for action_id in ACTION_IDS:
		rebind_key(player, action_id, DEFAULT_KEYS[player][action_id])
		if DEFAULT_BUTTONS.has(action_id):
			rebind_joy_button(player, action_id, DEFAULT_BUTTONS[action_id])

func load_bindings() -> void:
	for player in [1, 2]:
		_joy_bindings[player] = {}
		for action_id in ACTION_IDS:
			var default_key: int = DEFAULT_KEYS[player][action_id]
			var key: int = _settings().get_int(&"controls", _binding_key(player, action_id, &"key"), default_key)
			_apply_key(player, action_id, key)
			if DEFAULT_BUTTONS.has(action_id):
				var button: int = _settings().get_int(&"controls", _binding_key(player, action_id, &"joy"), DEFAULT_BUTTONS[action_id])
				_joy_bindings[player][action_id] = button

func _apply_key(player: int, action_id: StringName, physical_keycode: int) -> void:
	var action := action_name(player, action_id)
	_ensure_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key_event)

func _binding_key(player: int, action_id: StringName, kind: StringName) -> StringName:
	return StringName("p%d_%s_%s" % [player, action_id, kind])

func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

func _joy_button_text(button: int) -> String:
	var labels := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_DPAD_LEFT: "D-Pad Left", JOY_BUTTON_DPAD_UP: "D-Pad Up", JOY_BUTTON_DPAD_RIGHT: "D-Pad Right"}
	return labels.get(button, "Button %d" % button) if button >= 0 else "Unbound"
