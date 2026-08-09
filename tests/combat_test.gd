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
var _phase_misses := 0

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
	_p1.phase_missed.connect(func(_attacker, _target, _position): _phase_misses += 1)
	_p1.global_position = Vector3(_p1.global_position.x, _p1.global_position.y, -2.0)
	_p2.global_position = Vector3(_p2.global_position.x, _p2.global_position.y, -1.5)
	await _settle(10)

func _initialize() -> void:
	await _setup()
	_check("punch animation exists", _p1.get_node("pack1").has_animation(&"Punch_Jab"))
	_check("hook animation exists", _p1.get_node("pack2").has_animation(&"Melee_Hook"))
	_check("cross animation exists", _p1.get_node("pack1").has_animation(&"Punch_Cross"))
	_check("hit reaction exists", _p2.get_node("pack2").has_animation(&"Hit_Knockback"))
	_check("initial health", _p2.health == 100)
	_check("combat debug hidden by default", not _p1.get_node("DebugHitbox").visible and not _p1.get_node("DebugHurtbox").visible)
	_p1.set_combat_debug(true)
	_check("debug hurtbox matches collision position", _p1.get_node("DebugHurtbox").position.is_equal_approx(_p1.get_node("Hurtbox/CollisionShape3D").position))
	_p1.set_combat_debug(false)
	_p1._facing = 1.0
	_p1.configure_hitbox_for_test(&"jab")
	var jab_position := _p1.attack_hitbox_position()
	var jab_size := _p1.attack_hitbox_size()
	_p1.configure_hitbox_for_test(&"hook")
	var hook_size := _p1.attack_hitbox_size()
	_p1.configure_hitbox_for_test(&"combo_hook")
	var combo_size := _p1.attack_hitbox_size()
	_check("attack hitboxes increase by role", jab_size.x < hook_size.x and hook_size.x < combo_size.x and jab_size.z < hook_size.z and hook_size.z < combo_size.z)
	_p1._facing = -1.0
	_p1.configure_hitbox_for_test(&"jab")
	_check("jab hitbox mirrors with facing", is_equal_approx(_p1.attack_hitbox_position().z, -jab_position.z))
	_p1._facing = 1.0
	var idle_position := _p1.animation_position()
	await _settle(8)
	_check("idle tree state plays", _p1.animation_state() == &"IDLE" and _p1.animation_position() > idle_position)
	_p1.request_color_for_test(BLUE)
	_check("color switch has commitment", _p1.current_color == RED and _p1.is_color_switching())
	_check("movement remains available during switch", _p1.can_move)
	_p1.advance_color_switch_for_test(_p1.color_switch_commitment)
	_check("color applies after commitment", _p1.current_color == BLUE and _p1.color_switch_cooldown_remaining() > 0.0)
	_p1._color_cooldown_timer = 0.0
	_p1.current_color = RED
	_p1._apply_color()

	# Same-color punch deals exactly one hit and pushes away from the attacker.
	_p1.current_color = RED
	_p2.current_color = RED
	var start_z := _p2.global_position.z
	Input.action_press(&"light_attack")
	await _settle(3)
	Input.action_release(&"light_attack")
	await _settle(35)
	_check("same color punch damages", _p2.health == 90)
	_check("same color punch knocks back", _p2.global_position.z > start_z)

	# Different colors are phased and cannot be hit by the punch area.
	_p1.current_color = RED
	_p2.current_color = BLUE
	await _settle(3)
	var phased_health := _p2.health
	Input.action_press(&"light_attack")
	await _settle(3)
	Input.action_release(&"light_attack")
	await _settle(35)
	_check("different color punch misses", _p2.health == phased_health)
	_p1._end_attack()
	_p1.current_color = RED
	_p2.current_color = BLUE
	_p1._start_attack(&"jab")
	_p1._resolve_attack_overlap(_p2, PlayerController.ATTACKS[&"jab"], _p2.global_position)
	_p1._resolve_attack_overlap(_p2, PlayerController.ATTACKS[&"jab"], _p2.global_position)
	_check("different color emits one phase miss", _phase_misses == 1)

	_p1._end_attack()
	_p1.current_color = RED
	_p1._start_attack(&"jab")
	_p1.current_color = BLUE
	_check("attack keeps startup color", _p1.attack_color() == RED)
	_p1._end_attack()

	# Hitstun locks movement, jumping and attacks for a short window, then
	# control returns.
	_p1.global_position.z = -2.0
	_p2.global_position.z = -1.5
	_p1.current_color = RED
	_p2.current_color = RED
	_p2.health = 100
	await _settle(3)
	_p2.take_hit(_p1, 10, 0.0)
	await _settle(2)
	var hitstun_pos := _p2.global_position
	Input.action_press(&"p2_move_right")
	Input.action_press(&"p2_jump")
	Input.action_press(&"p2_light_attack")
	await _settle(6)
	_check("hitstun blocks movement", _p2.global_position.distance_to(hitstun_pos) < 0.01)
	_check("hitstun blocks jump", absf(_p2.velocity.y) < 0.01)
	_check("hitstun blocks attack", _p2.animation_state() != &"JAB")
	Input.action_release(&"p2_move_right")
	Input.action_release(&"p2_jump")
	Input.action_release(&"p2_light_attack")
	await _settle(20)
	var idle_pos := _p2.global_position
	Input.action_press(&"p2_move_right")
	await _settle(10)
	Input.action_release(&"p2_move_right")
	_check("control returns after hitstun", _p2.global_position.z > idle_pos.z)

	# Hook: heavier attack driven through the same framework.
	_p1.global_position.z = -2.0
	_p2.global_position.z = -1.5
	_p1.current_color = RED
	_p2.current_color = RED
	_p2.health = 100
	var hook_start_z := _p2.global_position.z
	await _settle(3)
	Input.action_press(&"heavy_attack")
	await _settle(3)
	Input.action_release(&"heavy_attack")
	await _settle(35)
	_check("same color hook damages", _p2.health == 85)
	_check("same color hook knocks back", _p2.global_position.z > hook_start_z)

	# Phasing applies to the hook the same way: different colors miss.
	_p1.global_position.z = -2.0
	_p2.global_position.z = -1.5
	_p1.current_color = RED
	_p2.current_color = BLUE
	await _settle(3)
	var phased_health_2 := _p2.health
	Input.action_press(&"heavy_attack")
	await _settle(3)
	Input.action_release(&"heavy_attack")
	await _settle(35)
	_check("different color hook misses", _p2.health == phased_health_2)

	# One attack has one damage event, not repeated damage over its animation.
	_p1.global_position.z = -2.0
	_p2.global_position.z = -1.5
	_p2.current_color = RED
	_p2.health = 100
	await _settle(3)
	Input.action_press(&"light_attack")
	await _settle(3)
	Input.action_release(&"light_attack")
	await _settle(50)
	_check("one punch hits once", _p2.health == 90)

	# Combo state: jab -> jab -> combo hook, then resets when interrupted.
	_p1._end_attack()
	_p1._combo_step = 0
	_p1._start_light_attack()
	_check("combo hit 1 is jab", _p1.current_attack() == &"jab" and _p1.combo_step() == 1)
	_p1.queue_combo_for_test()
	var combo_2: StringName = _p1._queued_attack
	_p1._queued_attack = &""
	_p1._end_attack()
	_p1._combo_step += 1
	_p1._start_attack(combo_2)
	_check("combo hit 2 is cross", _p1.current_attack() == &"cross" and _p1.combo_step() == 2)
	_p1.queue_combo_for_test()
	var combo_3: StringName = _p1._queued_attack
	_p1._queued_attack = &""
	_p1._end_attack()
	_p1._combo_step += 1
	_p1._start_attack(combo_3)
	_check("combo hit 3 is hook", _p1.current_attack() == &"combo_hook" and PlayerController.ATTACKS[combo_3]["knockback"] == 8.0)
	_check("cross has distinct combat values", PlayerController.ATTACKS[&"cross"]["damage"] == 12 and PlayerController.ATTACKS[&"cross"]["knockback"] == 5.5)
	_p1._end_attack()
	_p1._start_attack(&"jab")
	_p1._queue_combo_attack(true)
	_check("jab heavy branch queues hook", _p1._queued_attack == &"hook")
	_p1.take_hit(_p2, 1, 0.0)
	_check("hit interrupts attack", _p1.current_attack() == &"" and _p1.combo_step() == 0)

	_p1._start_attack(&"jab")
	_p1._queue_combo_attack()
	_p1._accelerate_current_attack()
	_check("buffered input accelerates attack", is_equal_approx(_p1.animation_speed_scale(), _p1.buffered_attack_speed))
	_p1._end_attack()
	_check("attack speed resets after recovery", is_equal_approx(_p1.animation_speed_scale(), 1.0))

	_p1.current_color = RED
	_p2.current_color = RED
	_p2.health = 100
	_p1._start_attack(&"cross")
	_p1.set_attack_critical_for_test(true)
	_p1._resolve_attack_overlap(_p2, PlayerController.ATTACKS[&"cross"], _p2.global_position)
	_check("critical cross scales damage", _p2.health == 82)
	_check("critical uses head reaction", _p2.animation_state() == &"HIT_HEAD")

	_finished = true
	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
