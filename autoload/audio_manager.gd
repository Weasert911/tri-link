extends Node

const BUS_NAMES := [&"Master", &"Music", &"SFX", &"UI"]

func _ready() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	apply_settings()
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.settings_changed.connect(_on_setting_changed)

func apply_settings() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	for bus_name in BUS_NAMES:
		var index := AudioServer.get_bus_index(bus_name)
		var key := StringName(String(bus_name).to_lower())
		var linear: float = settings.get_float(&"audio", key, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, is_zero_approx(linear))

func _on_setting_changed(section: StringName, _key: StringName, _value: Variant) -> void:
	if section == &"audio":
		apply_settings()
