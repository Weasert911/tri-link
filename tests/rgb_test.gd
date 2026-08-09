extends SceneTree

## RGB interaction acceptance test.

const ARENA := preload("res://scenes/prt_scene.tscn")
const RED := PlayerController.PlayerColor.RED
const GREEN := PlayerController.PlayerColor.GREEN
const BLUE := PlayerController.PlayerColor.BLUE
const SOLID_GAP := 0.32

var _frames := 0
var _finished := false
var _p1: PlayerController
var _p2: PlayerController
var _checks := 0
var _failures := 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 9000 and not _finished:
		print("WATCHDOG: test hung")
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

func _press(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _settle(frames)
	Input.action_release(action)
	await _settle(30)

func _masks() -> Vector2i:
	return Vector2i(_p1.collision_mask, _p2.collision_mask)

func _reset_positions() -> void:
	_p1.global_position = Vector3(_p1.global_position.x, _p1.global_position.y, -3.42)
	_p2.global_position = Vector3(_p2.global_position.x, _p2.global_position.y, -0.35)
	await _settle(5)

func _initialize() -> void:
	var arena: Node3D = ARENA.instantiate()
	root.add_child(arena)
	for _i in 3:
		await process_frame
	_p1 = arena.get_node("Player")
	_p2 = arena.get_node("Player2")
	_p1.set_opponent_for_test(_p2)
	_p2.set_opponent_for_test(_p1)
	await _settle(130)
	_check("P1 faces opponent on right", _p1.facing_sign() == 1.0)
	_check("P2 faces opponent on left", _p2.facing_sign() == -1.0)
	_check("P1 mesh faces opponent", _p1.visual_faces_opponent_for_test())
	_check("P2 mesh faces opponent", _p2.visual_faces_opponent_for_test())
	_p1.global_position.z = -0.2
	_p2.global_position.z = -3.4
	_p1.update_facing_for_test()
	_p2.update_facing_for_test()
	_check("P1 faces opponent after phasing", _p1.facing_sign() == -1.0)
	_check("P2 faces opponent after phasing", _p2.facing_sign() == 1.0)
	_check("P1 mesh follows after phasing", _p1.visual_faces_opponent_for_test())
	_check("P2 mesh follows after phasing", _p2.visual_faces_opponent_for_test())
	_check("controller devices assigned per player", _p1.controller_device == 0 and _p2.controller_device == 1)
	_check("controller deadzone removes drift", is_zero_approx(_p1.resolve_movement_input(0.0, _p1.controller_deadzone * 0.5)))
	var half_stick := _p1.resolve_movement_input(0.0, 0.6)
	_check("analog magnitude remains proportional", half_stick > 0.0 and half_stick < 1.0)
	_check("keyboard shares movement abstraction", is_equal_approx(_p1.resolve_movement_input(-1.0, 0.0), -1.0))
	_p1.set_movement_input_for_test(1.0)
	_p1.velocity.z = _p1.move_speed * 0.5
	_p1.update_facing_for_test()
	_p1.update_animation_speed_for_test()
	_check("backward input keeps opponent facing", _p1.facing_sign() == -1.0)
	_check("backward locomotion keeps tree advancing", _p1.animation_speed_scale() > 0.0)
	_p1._facing = 1.0
	_p1.set_movement_input_for_test(-1.0)
	_p1.velocity.z = 0.0
	_p1._update_movement(1.0)
	_check("backward movement is walk-speed capped", absf(_p1.velocity.z) <= _p1.move_speed * _p1.backward_speed_multiplier + 0.001)
	_p1._facing = 1.0
	_p1.set_movement_input_for_test(1.0)
	_p1.velocity.z = _p1.move_speed * 0.5
	_p1.select_grounded_animation_for_test()
	_check("forward walk uses forward state", _p1.animation_state() == &"WALK")
	_p1.set_movement_input_for_test(-1.0)
	_p1.velocity.z = -_p1.move_speed * 0.5
	_p1.select_grounded_animation_for_test()
	_check("backward walk uses reverse state", _p1.animation_state() == &"WALK_BACK" and _p1.animation_speed_scale() > 0.0)
	_p1.start_roll_for_test(1.0)
	_check("forward roll starts", _p1.is_rolling() and _p1.animation_state() == &"ROLL")
	var forward_roll_start := _p1.global_position.z
	for _i in 12:
		_p1.process_roll_for_test(_p1.roll_duration / 12.0)
		_p1.global_position.z += _p1.velocity.z * (_p1.roll_duration / 12.0)
	_check("forward roll moves fixed distance", _p1.global_position.z > forward_roll_start and not _p1.is_rolling())
	_check("roll exits cleanly", not _p1.is_rolling())
	_p1.start_roll_for_test(-1.0)
	_check("backward roll reverses", _p1.is_rolling() and _p1.animation_state() == &"ROLL_BACK" and _p1.animation_speed_scale() > 0.0)
	var backward_roll_start := _p1.global_position.z
	for _i in 12:
		_p1.process_roll_for_test(_p1.roll_duration / 12.0)
		_p1.global_position.z += _p1.velocity.z * (_p1.roll_duration / 12.0)
	_check("backward roll moves fixed distance", _p1.global_position.z < backward_roll_start and not _p1.is_rolling())
	_p1.process_roll_input_for_test(-0.8, 0.8)
	_check("left lower diagonal rolls", _p1.is_rolling())
	_p1.process_roll_for_test(_p1.roll_duration)
	_p1.process_roll_input_for_test(0.8, -0.8)
	_check("right lower diagonal rolls", _p1.is_rolling())
	_p1.process_roll_for_test(_p1.roll_duration)

	_p1._joy_previous[JOY_BUTTON_B] = false
	_p1._joy_current[JOY_BUTTON_B] = true
	_p1.set_joy_axis_x_for_test(-0.8)
	_p1.process_real_roll_input_for_test()
	_check("controller B plus left movement rolls", _p1.is_rolling() and _p1.animation_state() == &"ROLL_BACK")
	_p1.set_joy_axis_x_for_test(0.0)
	_p1._joy_current[JOY_BUTTON_B] = false
	_p1._joy_previous[JOY_BUTTON_B] = true
	_p1.process_roll_for_test(_p1.roll_duration)
	_p1.process_real_roll_input_for_test()
	_check("controller B release does not re-roll", not _p1.is_rolling())

	_p1.global_position.z = -3.42
	_p2.global_position.z = -0.35

	_check("default colors RED/RED", _p1.current_color == RED and _p2.current_color == RED)
	_check("solid at spawn", _masks() == Vector2i(5, 5))
	_check("indicator nodes exist", _p1.get_node("ColorIndicator") != null and _p2.get_node("ColorIndicator") != null)
	_check("indicator red at spawn", _p1.get_node("ColorIndicator").material_override.albedo_color.r > 0.9)

	await _press(&"color_green", 3)
	_check("P1 switches on 1-3", _p1.current_color == GREEN)
	_check("P2 unaffected by P1 color keys", _p2.current_color == RED)
	await _press(&"color_red", 3)
	await _press(&"p2_blue", 3)
	_check("P2 switches on 7-9", _p2.current_color == BLUE)
	_check("P1 unaffected by P2 color keys", _p1.current_color == RED)
	_check("different colors phase", _masks() == Vector2i(1, 1))

	# Same colors stop at the scaled capsule diameter.
	await _press(&"color_red", 3)
	await _press(&"p2_red", 3)
	_check("RED/RED solid", _masks() == Vector2i(5, 5))
	Input.action_press("move_right")
	Input.action_press("p2_move_left")
	await _settle(190)
	Input.action_release("move_right")
	Input.action_release("p2_move_left")
	await _settle(30)
	var gap := _p2.global_position.z - _p1.global_position.z
	_check("same color: no pass-through", _p1.global_position.z < _p2.global_position.z)
	_check("same color: solid gap preserved", gap > SOLID_GAP - 0.08 and gap < SOLID_GAP + 0.08)
	_check("same color: both grounded", _p1.is_on_floor() and _p2.is_on_floor())

	# Different colors pass through and reach opposite ends.
	await _reset_positions()
	await _press(&"p2_blue", 3)
	var z0 := _p1.global_position.z
	var p2z0 := _p2.global_position.z
	_check("RED/BLUE setup", _p1.current_color == RED and _p2.current_color == BLUE and _masks() == Vector2i(1, 1))
	Input.action_press("move_right")
	Input.action_press("p2_move_left")
	await _settle(300)
	Input.action_release("move_right")
	Input.action_release("p2_move_left")
	await _settle(30)
	_check("different colors: positions crossed", _p1.global_position.z > p2z0 - 0.1 and _p2.global_position.z < z0 + 0.1)
	_check("different colors: no block", _p1.global_position.z - _p2.global_position.z > 0.3)

	# Reset and make them solid while approaching from opposite ends.
	await _reset_positions()
	_check("T3 reset positions", _p1.global_position.z < _p2.global_position.z)
	Input.action_press("move_right")
	Input.action_press("p2_move_left")
	await _settle(65)
	Input.action_press("color_blue")
	await _settle(3)
	Input.action_release("color_blue")
	await _settle(60)
	_check("switching to matching color restores masks", _masks() == Vector2i(5, 5))
	await _settle(120)
	Input.action_release("move_right")
	Input.action_release("p2_move_left")
	await _settle(30)
	gap = _p2.global_position.z - _p1.global_position.z
	_check("mid-run switch: no pass-through", _p1.global_position.z < _p2.global_position.z)
	_check("mid-run switch: separated", gap > SOLID_GAP - 0.08 and gap < SOLID_GAP + 0.08)

	# Same-color BLUE collision remains solid after the mid-run switch.
	Input.action_press("move_right")
	Input.action_press("p2_move_left")
	await _settle(190)
	Input.action_release("move_right")
	Input.action_release("p2_move_left")
	await _settle(30)
	gap = _p2.global_position.z - _p1.global_position.z
	_check("BLUE/BLUE solid", _masks() == Vector2i(5, 5))
	_check("BLUE/BLUE gap preserved", gap > SOLID_GAP - 0.08 and gap < SOLID_GAP + 0.08)

	# Rapid switching keeps positions, colors, masks, and movement valid.
	Input.action_press("move_left")
	for i in 90:
		if i % 10 == 0:
			await _press(&"p2_green", 1)
			await _press(&"color_green", 1)
			await _press(&"p2_blue", 1)
			await _press(&"color_red", 1)
		await physics_frame
	Input.action_release("move_left")
	await _settle(60)
	_check("rapid switching: finite positions", is_finite(_p1.global_position.z) and is_finite(_p2.global_position.z))
	_check("rapid switching: players standing", _p1.is_on_floor() and _p2.is_on_floor())
	_check("rapid switching: valid colors", _p1.current_color in [RED, GREEN, BLUE] and _p2.current_color in [RED, GREEN, BLUE])
	var expected_mask := 5 if _p1.current_color == _p2.current_color else 1
	_check("rapid switching: symmetric masks", _masks() == Vector2i(expected_mask, expected_mask))
	_check("rapid switching: movement remains available", _p1.global_position.z < -2.0)

	_finished = true
	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
