extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SETTINGS_SCRIPT := preload("res://autoload/settings_manager.gd")
const INPUT_SCRIPT := preload("res://autoload/input_manager.gd")
const DEVICE_SCRIPT := preload("res://autoload/device_manager.gd")
const AUDIO_SCRIPT := preload("res://autoload/audio_manager.gd")

var _checks := 0
var _failures := 0
var _frames := 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1800:
		quit(2)
	return false

func _check(label: String, condition: bool) -> void:
	_checks += 1
	if not condition:
		_failures += 1
	print("%s | %s" % ["PASS" if condition else "FAIL", label])

func _initialize() -> void:
	for service in [[&"SettingsManager", SETTINGS_SCRIPT], [&"InputManager", INPUT_SCRIPT], [&"DeviceManager", DEVICE_SCRIPT], [&"AudioManager", AUDIO_SCRIPT]]:
		var node: Node = service[1].new()
		node.name = service[0]
		root.add_child(node)
	var game: Game = MAIN_SCENE.instantiate()
	root.add_child(game)
	for _i in 8:
		await process_frame
	_check("main scene enters menu showcase", game.state == Game.State.MENU and game.showcase.enabled)
	game._start_play()
	await process_frame
	game._pause_game()
	var before := game.match_controller.p1.global_position
	for _i in 8:
		await process_frame
	_check("pause is authoritative", paused and game.match_controller.p1.global_position.is_equal_approx(before))
	game._resume_game()
	_check("resume restores play", not paused and game.state == Game.State.PLAY)

	game.match_controller._set_state(MatchController.MatchState.MATCH_OVER)
	_check("showcase can auto-restart", game.showcase.restart_if_complete() and game.match_controller.state() == MatchController.MatchState.ROUND_START)

	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
