extends Node

signal devices_changed
signal assignment_changed(player: int, device: int)

var _assignments := {1: -1, 2: -1}
var _connected: Array[int] = []

func _settings() -> Node:
	return get_node_or_null("/root/SettingsManager")

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_devices()

func _refresh_devices() -> void:
	_connected.assign(Input.get_connected_joypads())
	var used: Array[int] = []
	for player in [1, 2]:
		var saved: int = _settings().get_int(&"devices", StringName("player_%d" % player), -1)
		if saved in _connected and saved not in used:
			_assignments[player] = saved
			used.append(saved)
		else:
			_assignments[player] = -1
	for player in [1, 2]:
		if _assignments[player] >= 0:
			continue
		for device in _connected:
			if device not in used:
				_assignments[player] = device
				used.append(device)
				break
		_settings().set_value(&"devices", StringName("player_%d" % player), _assignments[player])
	devices_changed.emit()

func assign_device(player: int, device: int) -> bool:
	if player not in [1, 2] or (device >= 0 and device not in _connected):
		return false
	var other := 2 if player == 1 else 1
	if device >= 0 and _assignments[other] == device:
		_assignments[other] = -1
		_settings().set_value(&"devices", StringName("player_%d" % other), -1)
		assignment_changed.emit(other, -1)
	_assignments[player] = device
	_settings().set_value(&"devices", StringName("player_%d" % player), device)
	assignment_changed.emit(player, device)
	devices_changed.emit()
	return true

func device_for_player(player: int) -> int:
	return int(_assignments.get(player, -1))

func connected_devices() -> Array[int]:
	return _connected.duplicate()

func status_text() -> String:
	var count := _connected.size()
	return "NO CONTROLLERS" if count == 0 else "%d CONTROLLER%s CONNECTED" % [count, "" if count == 1 else "S"]

func _on_joy_connection_changed(_device: int, _connected_now: bool) -> void:
	_refresh_devices()

func set_connected_devices_for_test(devices: Array[int]) -> void:
	_connected = devices.duplicate()
	_assignments = {1: -1, 2: -1}
	var player := 1
	for device in _connected:
		if player > 2:
			break
		_assignments[player] = device
		player += 1
