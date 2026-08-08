extends SceneTree

const ARENA := preload("res://scenes/prt_scene.tscn")
const RED := PlayerController.PlayerColor.RED
const BLUE := PlayerController.PlayerColor.BLUE

var _frames := 0
var _finished := false
var _p1: PlayerController
var _p2: PlayerController
var _checks := 0
var _failures := 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 3000 and not _finished:
		print("WATCHDOG: combat test hung")
		quit(2)
	return false

func _check(label: String, condition: bool) -> void:
	_checks += 1
	if not condition:
		_failures += 1
	print("%s | %s" % ["PASS" if condition else "FAIL", label])

func _settle(frames: int) -> void:
	for _i in frames:
		await physics_frame

func _setup() -> void:
	var arena: Node3D = ARENA.instantiate()
	root.add_child(arena)
	for _i in 3:
		await process_frame
	_p1 = arena.get_node("Player")
	_p2 = arena.get_node("Player2")
	_p1.global_position = Vector3(_p1.global_position.x, _p1.global_position.y, -2.0)
	_p2.global_position = Vector3(_p2.global_position.x, _p2.global_position.y, -1.5)
	await _settle(10)

func _initialize() -> void:
	await _setup()
	_check("punch animation exists", _p1.get_node("pack1").has_animation(&"Punch_Jab"))
	_check("hit reaction exists", _p2.get_node("pack2").has_animation(&"Hit_Knockback"))
	_check("initial health", _p2.health == 100)

	# Same-color punch deals exactly one hit and pushes away from the attacker.
	_p1.current_color = RED
	_p2.current_color = RED
	var start_z := _p2.global_position.z
	Input.action_press(&"attack")
	await _settle(3)
	Input.action_release(&"attack")
	await _settle(35)
	_check("same color punch damages", _p2.health == 90)
	_check("same color punch knocks back", _p2.global_position.z > start_z)

	# Different colors are phased and cannot be hit by the punch area.
	_p1.current_color = RED
	_p2.current_color = BLUE
	await _settle(3)
	var phased_health := _p2.health
	Input.action_press(&"attack")
	await _settle(3)
	Input.action_release(&"attack")
	await _settle(35)
	_check("different color punch misses", _p2.health == phased_health)

	# One attack has one damage event, not repeated damage over its animation.
	_p1.global_position.z = -2.0
	_p2.global_position.z = -1.5
	_p2.current_color = RED
	await _settle(3)
	Input.action_press(&"attack")
	await _settle(3)
	Input.action_release(&"attack")
	await _settle(50)
	_check("one punch hits once", _p2.health == 80)

	_finished = true
	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
