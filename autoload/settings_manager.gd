extends Node

signal settings_changed(section: StringName, key: StringName, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULTS := {
	&"gameplay": {
		&"screen_shake": true,
		&"hit_stop": true,
		&"combat_vfx": true,
		&"combo_counter": true,
		&"damage_numbers": true,
		&"color_effects": true,
		&"screen_flash": true,
		&"slow_motion": true,
	},
	&"video": {
		&"quality_preset": 1,
		&"resolution": Vector2i(1280, 720),
		&"window_mode": 0,
		&"vsync": true,
		&"fps_cap": 120,
	},
	&"audio": {
		&"master": 1.0,
		&"music": 0.8,
		&"sfx": 1.0,
		&"ui": 1.0,
	},
	&"devices": {
		&"player_1": -1,
		&"player_2": -1,
	},
}

var _config := ConfigFile.new()

func _ready() -> void:
	load_settings()

func load_settings() -> Error:
	_config = ConfigFile.new()
	var error := _config.load(SETTINGS_PATH)
	return OK if error == ERR_FILE_NOT_FOUND else error

func save_settings() -> Error:
	return _config.save(SETTINGS_PATH)

func get_value(section: StringName, key: StringName, fallback: Variant = null) -> Variant:
	var default_value: Variant = fallback
	if DEFAULTS.has(section):
		default_value = DEFAULTS[section].get(key, fallback)
	if not _config.has_section_key(section, key):
		return default_value
	return _config.get_value(section, key, default_value)

func set_value(section: StringName, key: StringName, value: Variant, save := true) -> void:
	if get_value(section, key) == value:
		return
	_config.set_value(section, key, value)
	if save:
		save_settings()
	settings_changed.emit(section, key, value)

func get_bool(section: StringName, key: StringName, fallback := false) -> bool:
	return bool(get_value(section, key, fallback))

func get_int(section: StringName, key: StringName, fallback := 0) -> int:
	return int(get_value(section, key, fallback))

func get_float(section: StringName, key: StringName, fallback := 0.0) -> float:
	return float(get_value(section, key, fallback))

func get_string(section: StringName, key: StringName, fallback := "") -> String:
	return str(get_value(section, key, fallback))

func reset_section(section: StringName) -> void:
	if not DEFAULTS.has(section):
		return
	_config.erase_section(section)
	for key in DEFAULTS[section]:
		settings_changed.emit(section, key, DEFAULTS[section][key])
	save_settings()

func reset_all() -> void:
	_config.clear()
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			settings_changed.emit(section, key, DEFAULTS[section][key])
	save_settings()
