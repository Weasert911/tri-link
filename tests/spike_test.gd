extends SceneTree

const ARENA := preload("res://scenes/prt_scene.tscn")
const RED := PlayerController.PlayerColor.RED

var _frames := 0
var _finished := false
var _checks := 0
var _failures := 0
var _arena: Node3D = null

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 3000 and not _finished:
		print("WATCHDOG: spike test hung")
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

## Instantiates a fresh arena and returns p1, p2 and the spike hazards.
func _spawn() -> Array:
	if _arena != null:
		_arena.queue_free()
		await _arena.tree_exited
	var arena: Node3D = ARENA.instantiate()
	_arena = arena
	root.add_child(arena)
	for _i in 3:
		await process_frame
	var p1: PlayerController = arena.get_node("Player")
	var p2: PlayerController = arena.get_node("Player2")
	var hazard_front: Area3D = arena.get_node("room/spikes/SpikeHazard")
	var hazard_back: Area3D = arena.get_node("room/spikes/SpikeHazard2")
	await _settle(10)
	return [p1, p2, hazard_front, hazard_back]

## One punch from p1 (both solid RED, p1 behind p2). Returns after the jab.
func _punch(p1: PlayerController, p2: PlayerController) -> void:
	p1.current_color = RED
	p2.current_color = RED
	await _settle(3)
	Input.action_press(&"light_attack")
	await _settle(3)
	Input.action_release(&"light_attack")
	await _settle(35)

func _initialize() -> void:
	await _hp_ko_checks()
	await _back_spike_checks()
	await _front_spike_checks()
	_finished = true
	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _hp_ko_checks() -> void:
	var result := await _spawn()
	var p1: PlayerController = result[0]
	var p2: PlayerController = result[1]
	_check("Death01 animation exists", p1.get_node("pack1").has_animation(&"Death01"))
	_check("player starts alive", p1.alive and p2.alive)
	_check("player starts movable", p1.can_move and p1.can_jump and p1.can_attack)

	p1.global_position = Vector3(p1.global_position.x, p1.global_position.y, -2.0)
	p2.global_position = Vector3(p2.global_position.x, p2.global_position.y, -1.5)
	p2.health = 10
	await _punch(p1, p2)
	_check("punch KO at zero health", not p2.alive and p2.health == 0)
	_check("KO disables movement", not p2.can_move and not p2.can_jump and not p2.can_attack)
	_check("KO plays Death01", p2.animation_state() == &"DEATH")

	# A dead player cannot attack and ignores further punches.
	var death_anim: StringName = p2.animation_state()
	Input.action_press(&"p2_light_attack")
	await _settle(3)
	Input.action_release(&"p2_light_attack")
	await _settle(10)
	_check("dead player cannot attack", p2.animation_state() == death_anim)
	await _punch(p1, p2)
	_check("dead player takes no more damage", p2.health == 0 and not p2.alive)

## Knockback pushes a player into the back spike wall. Plain wall contact must
## not kill; only the hazard area does.
func _back_spike_checks() -> void:
	var result := await _spawn()
	var p1: PlayerController = result[0]
	var p2: PlayerController = result[1]
	var hazard_back: Area3D = result[3]
	hazard_back.monitoring = false
	p1.global_position = Vector3(p1.global_position.x, p1.global_position.y, -3.3)
	p2.global_position = Vector3(p2.global_position.x, p2.global_position.y, -3.8)
	# Turn p1 to face the victim (back wall is -Z) without moving.
	p1.can_move = false
	Input.action_press(&"move_left")
	await _settle(5)
	Input.action_release(&"move_left")
	p1.can_move = true
	await _punch(p1, p2)
	_check("knockback pins player to back wall", p2.global_position.z < -3.8)
	_check("wall contact alone does not kill", p2.alive and p2.health == 90)

	var frozen_z := p2.global_position.z
	hazard_back.monitoring = true
	await _settle(10)
	_check("spike area KOs on contact", not p2.alive and p2.health == 0)
	await _settle(30)
	_check("KO'd player freezes in place", p2.global_position.z == frozen_z and absf(p2.velocity.z) < 0.001)

## Same loop against the front spike wall.
func _front_spike_checks() -> void:
	var result := await _spawn()
	var p1: PlayerController = result[0]
	var p2: PlayerController = result[1]
	var hazard_front: Area3D = result[2]
	hazard_front.monitoring = false
	p1.global_position = Vector3(p1.global_position.x, p1.global_position.y, -0.35)
	p2.global_position = Vector3(p2.global_position.x, p2.global_position.y, 0.0)
	await _punch(p1, p2)
	_check("knockback pins player to front wall", p2.global_position.z > 0.12)
	_check("front wall contact alone does not kill", p2.alive and p2.health == 90)

	hazard_front.monitoring = true
	await _settle(10)
	_check("front spike area KOs on contact", not p2.alive and p2.health == 0)
