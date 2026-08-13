extends SceneTree

const SETTINGS_SCRIPT := preload("res://autoload/settings_manager.gd")
const INPUT_SCRIPT := preload("res://autoload/input_manager.gd")
const DEVICE_SCRIPT := preload("res://autoload/device_manager.gd")

var _checks := 0
var _failures := 0

func _check(label: String, condition: bool) -> void:
	_checks += 1
	if not condition:
		_failures += 1
	print("%s | %s" % ["PASS" if condition else "FAIL", label])

func _initialize() -> void:
	var settings := SETTINGS_SCRIPT.new()
	settings.name = &"SettingsManager"
	root.add_child(settings)
	var input_manager := INPUT_SCRIPT.new()
	input_manager.name = &"InputManager"
	root.add_child(input_manager)
	var device_manager := DEVICE_SCRIPT.new()
	device_manager.name = &"DeviceManager"
	root.add_child(device_manager)
	await process_frame
	var original_p1_device: int = settings.get_int(&"devices", &"player_1", -1)
	var original_p2_device: int = settings.get_int(&"devices", &"player_2", -1)
	var original_shake: bool = settings.get_bool(&"gameplay", &"screen_shake", true)
	settings.set_value(&"gameplay", &"screen_shake", not original_shake)
	settings.load_settings()
	_check("settings roundtrip", settings.get_bool(&"gameplay", &"screen_shake") == not original_shake)
	settings.set_value(&"gameplay", &"screen_shake", original_shake)

	var original_key: int = input_manager.key_for(1, &"jump")
	input_manager.rebind_key(1, &"jump", KEY_J)
	_check("rebind applies to InputMap", input_manager.key_for(1, &"jump") == KEY_J)
	var conflict_event := InputEventKey.new()
	conflict_event.physical_keycode = KEY_J
	_check("rebind conflict is reported", input_manager.find_conflict(1, &"light", conflict_event) == &"jump")
	input_manager.rebind_key(1, &"jump", original_key)

	device_manager.set_connected_devices_for_test([7, 3])
	_check("devices assign by connection order", device_manager.device_for_player(1) == 7 and device_manager.device_for_player(2) == 3)
	_check("device reassignment is exclusive", device_manager.assign_device(2, 7) and device_manager.device_for_player(1) == -1)
	settings.set_value(&"devices", &"player_1", original_p1_device)
	settings.set_value(&"devices", &"player_2", original_p2_device)
	device_manager._refresh_devices()

	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
