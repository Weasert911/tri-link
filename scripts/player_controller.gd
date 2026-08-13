class_name PlayerController
extends CharacterBody3D
const ANIMATION_CONTROLLER_SCRIPT := preload("res://scripts/player_animation_controller.gd")
## In-place 2.5D player controller for the existing Trilink player scene.
## Locomotion drives the existing pack1 AnimationPlayer; pack2 is reserved
## for future combat animations.

enum LocomotionState {
	IDLE,
	MOVING,
	JUMPING,
	FALLING,
	LANDING,
}

enum AttackPhase {
	IDLE,
	STARTUP,
	ACTIVE,
	RECOVERY,
}

## The player's RGB state. Same color as the opponent means solid
## (player-vs-player collision active); different colors phase through.
enum PlayerColor {
	RED,
	GREEN,
	BLUE,
}

## Emitted when the player is KO'd (health reaches zero from any source).
## The match controller listens to this to end the round; the player itself
## does not know about rounds or matches.
signal died
signal color_changed(color: PlayerColor)
signal hit_confirmed(attacker: PlayerController, victim: PlayerController, position: Vector3, heavy: bool)
signal wall_hit(position: Vector3, heavy: bool, victim: PlayerController)
signal spike_ko(position: Vector3, victim: PlayerController)
signal phase_missed(attacker: PlayerController, target: PlayerController, position: Vector3)
signal critical_hit(attacker: PlayerController, victim: PlayerController, position: Vector3, heavy: bool)
signal attack_active(attacker: PlayerController, position: Vector3, heavy: bool, critical: bool)
signal combo_started(count: int)
signal combo_extended(count: int)
signal combo_finished
signal counter_hit(attacker: PlayerController, victim: PlayerController, position: Vector3)

const MAX_HEALTH := 100
const HITSTUN_DURATION := 0.25

## Attack definitions. Each attack supplies its own animation, timing,
## damage, knockback and reach; combat code just picks an attack id.
## Times are in seconds measured from the attack start:
##   startup   - before the hitbox activates
##   active    - hitbox active window
##   recovery  - after the active window, before control returns
##   player    - 1 = pack1 (locomotion/attacks), 2 = pack2 (combat)
## Optional per-attack fields (read with Dictionary.get()):
##   label, weight, reaction, launch, wall_bounce, can_cancel,
##   critical_window, critical_damage_mult, critical_knockback_mult,
##   trail_scale
const ATTACKS := {
	&"jab": {
		"animation": &"Punch_Jab",
		"player": 1,
		"startup": 0.20,
		"active": 0.18,
		"recovery": 0.49,
		"damage": 10,
		"knockback": 4.5,
		"range": 0.44,
		"hitbox_offset": Vector3(0.0, 0.925, 0.44),
		"hitbox_size": Vector3(1.9, 1.8, 0.38),
		"hitstun": HITSTUN_DURATION,
		"light_followup": &"cross",
		"heavy_followup": &"jab",
		"label": &"JAB",
		"weight": &"light",
		"reaction": &"chest",
		"launch": 0.0,
		"wall_bounce": false,
		"can_cancel": true,
		"cancel_start": 0.38,
		"cancel_end": 0.70,
		"can_critical": true,
		"special_impact": false,
		"critical_window": 0.22,
		"critical_damage_mult": 1.5,
		"critical_knockback_mult": 1.35,
		"trail_scale": 0.6,
	},
	&"cross": {
		"animation": &"Punch_Cross",
		"player": 1,
		"startup": 0.22,
		"active": 0.16,
		"recovery": 0.42,
		"damage": 12,
		"knockback": 5.5,
		"range": 0.48,
		"hitbox_offset": Vector3(0.0, 0.94, 0.48),
		"hitbox_size": Vector3(2.15, 1.9, 0.43),
		"hitstun": HITSTUN_DURATION,
		"light_followup": &"hook",
		"heavy_followup": &"overhand",
		"label": &"CROSS",
		"weight": &"light",
		"reaction": &"chest",
		"launch": 0.0,
		"wall_bounce": true,
		"can_cancel": true,
		"cancel_start": 0.38,
		"cancel_end": 0.66,
		"can_critical": true,
		"special_impact": false,
		"critical_window": 0.2,
		"critical_damage_mult": 1.5,
		"critical_knockback_mult": 1.35,
		"trail_scale": 0.9,
	},
	&"hook": {
		"animation": &"Melee_Hook",
		"player": 2,
		"startup": 0.20,
		"active": 0.12,
		"recovery": 0.15,
		"damage": 15,
		"knockback": 6.0,
		"range": 0.50,
		"hitbox_offset": Vector3(0.0, 0.95, 0.52),
		"hitbox_size": Vector3(2.35, 1.95, 0.46),
		"hitstun": HITSTUN_DURATION,
		"light_followup": &"",
		"heavy_followup": &"",
		"label": &"HOOK",
		"weight": &"heavy",
		"reaction": &"knockback",
		"launch": 0.0,
		"wall_bounce": true,
		"can_cancel": false,
		"cancel_start": 0.32,
		"cancel_end": 0.32,
		"can_critical": true,
		"special_impact": true,
		"critical_window": 0.18,
		"critical_damage_mult": 1.5,
		"critical_knockback_mult": 1.35,
		"trail_scale": 1.2,
	},
	&"combo_hook": {
		"animation": &"Melee_Hook",
		"player": 2,
		"startup": 0.24,
		"active": 0.14,
		"recovery": 0.25,
		"damage": 15,
		"knockback": 8.0,
		"range": 0.52,
		"hitbox_offset": Vector3(0.0, 0.98, 0.58),
		"hitbox_size": Vector3(2.8, 2.15, 0.56),
		"hitstun": HITSTUN_DURATION,
		"light_followup": &"",
		"heavy_followup": &"",
		"label": &"COMBO HOOK",
		"weight": &"heavy",
		"reaction": &"knockback",
		"launch": 0.0,
		"wall_bounce": true,
		"can_cancel": false,
		"cancel_start": 0.38,
		"cancel_end": 0.38,
		"can_critical": true,
		"special_impact": true,
		"critical_window": 0.18,
		"critical_damage_mult": 1.5,
		"critical_knockback_mult": 1.35,
		"trail_scale": 1.6,
	},
	&"overhand": {
		"animation": &"OverhandThrow",
		"player": 2,
		"startup": 0.26,
		"active": 0.14,
		"recovery": 0.5,
		"damage": 20,
		"knockback": 9.0,
		"range": 0.54,
		"hitbox_offset": Vector3(0.0, 1.05, 0.6),
		"hitbox_size": Vector3(2.9, 2.3, 0.6),
		"hitstun": HITSTUN_DURATION,
		"light_followup": &"",
		"heavy_followup": &"",
		"label": &"OVERHAND",
		"weight": &"heavy",
		"reaction": &"knockback",
		"launch": 0.0,
		"wall_bounce": true,
		"can_cancel": false,
		"cancel_start": 0.40,
		"cancel_end": 0.40,
		"can_critical": true,
		"special_impact": true,
		"critical_window": 0.2,
		"critical_damage_mult": 1.5,
		"critical_knockback_mult": 1.35,
		"trail_scale": 1.8,
	},
}

## Lane movement speed (units/second) at full run, tuned for a ~0.4-scale
## character (roughly 0.7 m tall).
@export var move_speed: float = 0.9
@export var backward_speed_multiplier: float = 0.55
@export var controller_deadzone: float = 0.18
@export var controller_device: int = -1
## Grounded acceleration.
@export var ground_acceleration: float = 12.0
## Grounded deceleration when no input is applied.
@export var ground_deceleration: float = 14.0
## Acceleration while airborne.
@export var air_acceleration: float = 8.0
## Deceleration while airborne.
@export var air_deceleration: float = 4.0
## Upward velocity applied on jump.
@export var jump_velocity: float = 3.2
## Downward acceleration while airborne.
@export var gravity: float = 12.0
## Ground speed below which the Walk animation plays.
@export var walk_speed_threshold: float = 0.5
## Ground speed below which the Jog animation plays (above it: Sprint).
@export var jog_speed_threshold: float = 0.9
@export var sprint_speed_threshold: float = 1.0
## Seconds after leaving the ground where a jump is still allowed.
@export var coyote_time: float = 0.10
## Seconds a jump press is remembered while airborne.
@export var jump_buffer_time: float = 0.10
## Fraction of upward velocity retained when jump is released early.
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
## Animation crossfade time for transitions.
@export var animation_blend_time: float = 0.12
@export_range(1.0, 4.0) var buffered_attack_speed: float = 2.0
@export_range(0.05, 0.4) var input_buffer_window: float = 0.15
@export_range(0.0, 1.5) var combo_refresh_time: float = 0.5
@export var wall_bounce_strength: float = 0.35
@export var wall_bounce_min_knockback: float = 5.5
@export_range(0.0, 0.5) var wall_bounce_hitstun: float = 0.12
@export_range(0.1, 1.0) var roll_duration: float = 0.55
@export_range(0.1, 2.0) var roll_speed: float = 1.15
@export_range(0.1, 1.0) var roll_diagonal_threshold: float = 0.45
## If true, the player's X position is locked to the 2.5D gameplay plane.
@export var constrain_to_plane: bool = true
## X coordinate of the 2.5D gameplay plane. A value of 0.0 locks the player
## to the X position it is placed at in the editor; set a different value to
## pin the plane to a fixed X instead.
@export var gameplay_plane_x: float = 0.0

## Direction the mannequin's face points, in the Armature's local space.
## Verified against the scene: the mannequin's face/toes point toward +Z,
## which is Godot's Vector3.BACK. Whatever direction the model faces in the
## editor is the canonical "front"; the opposite direction is the "back".
## If you rotate the model in the editor, this export follows automatically
## because the world front is derived from the Armature's actual transform.
@export var model_forward_local: Vector3 = Vector3.BACK
@export var visual_facing_inverted: bool = false
## Movement can be disabled later by combat/state systems.
@export var can_move: bool = true
## Jumping can be disabled later by combat/state systems.
@export var can_jump: bool = true
## Attacks can be disabled later by combat/state systems.
@export var can_attack: bool = true
## RGB switching can be disabled by the match controller between rounds.
@export var can_change_color: bool = true
## If false the player is KO'd: movement, jumping and attacks are disabled
## and the Death01 animation plays. Set by _die() on lethal damage.
@export var alive: bool = true
## Print locomotion state and animation transitions to the console.
@export var debug_log: bool = false
@export var combat_debug: bool = false
@export_range(0.0, 0.5) var color_switch_commitment: float = 0.18
@export_range(0.0, 1.0) var color_switch_cooldown: float = 0.25
## Player index. 1 uses the primary action set (move_left/move_right/jump),
## 2 uses the secondary set (p2_move_left/p2_move_right/p2_jump).
@export var player_index: int = 1
## Current RGB state. Determines solid/phase interaction with the opponent.
@export var current_color: PlayerColor = PlayerColor.RED
@export var health: int = MAX_HEALTH

@onready var _armature: Node3D = $Armature
@onready var _locomotion: AnimationPlayer = $pack1
@onready var _combat: AnimationPlayer = $pack2
@onready var _color_indicator: MeshInstance3D = $ColorIndicator
@onready var _attack_hitbox: Area3D = $AttackHitbox
@onready var _attack_shape: CollisionShape3D = $AttackHitbox/CollisionShape3D
@onready var _hurtbox_shape: CollisionShape3D = $Hurtbox/CollisionShape3D

var _current_state: LocomotionState = LocomotionState.IDLE
var _current_animation: StringName = &""
var _facing: float = 1.0
## Locomotion animations that play reversed while the character moves back.
const _LOCOMOTION_ANIMS: Array[StringName] = [&"Walk", &"Walk_Back", &"Jog_Fwd", &"Sprint"]
## Armature scale as authored in the editor. Only the horizontal axis is
## flipped for left/right facing; this base value is always restored.
var _base_armature_scale: Vector3 = Vector3.ONE
var _base_armature_rotation: Vector3 = Vector3.ZERO
## World X the player was placed at in the editor; the 2.5D plane locks to it
## unless gameplay_plane_x is explicitly overridden.
var _plane_x: float = 0.0
var _was_grounded: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _movement_input: float = 0.0
var _jump_started: bool = false
var _landing_animation_playing: bool = false
var _move_left_action: StringName = &"move_left"
var _move_right_action: StringName = &"move_right"
var _jump_action: StringName = &"jump"
var _red_action: StringName = &"color_red"
var _green_action: StringName = &"color_green"
var _blue_action: StringName = &"color_blue"
var _color_materials: Array[StandardMaterial3D] = []
var _pending_color: PlayerColor = PlayerColor.RED
var _color_switch_timer := 0.0
var _color_cooldown_timer := 0.0
var _attack_action: StringName = &"light_attack"
var _heavy_action: StringName = &"heavy_attack"
var _roll_action: StringName = &"roll"
var _current_attack: StringName = &""
var _attack_phase: AttackPhase = AttackPhase.IDLE
var _attack_elapsed := -1.0
var _attack_hit_targets: Dictionary = {}
var _attack_color: PlayerColor = PlayerColor.RED
var _attack_critical := false
var _attack_connected := false
var _critical_was_counter := false
var _combo_hits := 0
var _active_feedback_emitted := false
var _hitstun_timer := 0.0
var _hit_stop_timer := 0.0
var _combo_step := 0
var _combo_timer := 0.0
var _queued_attack: StringName = &""
var _input_buffer_timer := 0.0
var _buffer_heavy := false
var _attack_time_scale := 1.0
var _wall_hit_reported := false
var _last_knockback := 0.0
var _wall_bounce_allowed := false
var _debug_hitbox_mesh: MeshInstance3D
var _debug_hurtbox_mesh: MeshInstance3D
var _debug_label: Label3D
## True while the match controller holds the player frozen between rounds.
## Freezes movement facing, color switching and attack input without touching
## the can_* exports (which combat code also uses for temporary locks).
var _controls_locked := false
## World position the player spawns at; round resets return here.
var _spawn_position: Vector3 = Vector3.ZERO
var _animation_system: Node
var _joy_current: Dictionary = {}
var _joy_previous: Dictionary = {}
var _rolling := false
var _roll_timer := 0.0
var _roll_direction := 0.0
var _roll_backward := false
var _roll_input_held := false
var _test_joy_axis_x: float = 0.0
var _ai_input: Dictionary = {}
var _ai_previous: Dictionary = {}

func _ready() -> void:
	if player_index == 2:
		_move_left_action = &"p2_move_left"
		_move_right_action = &"p2_move_right"
		_jump_action = &"p2_jump"
		_red_action = &"p2_red"
		_green_action = &"p2_green"
		_blue_action = &"p2_blue"
		_attack_action = &"p2_light_attack"
		_heavy_action = &"p2_heavy_attack"
		_roll_action = &"p2_roll"
	add_to_group(&"players")
	_build_color_materials()
	_setup_combat_debug()
	_apply_color()
	_base_armature_scale = _armature.scale
	_base_armature_rotation = _armature.rotation
	_spawn_position = global_position
	_plane_x = global_position.x if is_zero_approx(gameplay_plane_x) else gameplay_plane_x
	_was_grounded = is_on_floor()
	_configure_animation_looping()
	_animation_system = ANIMATION_CONTROLLER_SCRIPT.new()
	_animation_system.name = &"AnimationController"
	add_child(_animation_system)
	_animation_system.setup(_locomotion, _combat)
	_apply_visual_facing()
	_play_animation(&"Idle")

func _build_color_materials() -> void:
	var colors: Array[Color] = [
		Color(1.0, 0.16, 0.16),
		Color(0.18, 1.0, 0.2),
		Color(0.22, 0.42, 1.0),
	]
	for c in colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 2.0
		_color_materials.append(mat)

func _apply_color() -> void:
	if _color_indicator != null and not _color_materials.is_empty():
		_color_indicator.material_override = _color_materials[current_color]
	_update_interaction()
	var opponent := _get_opponent()
	if opponent != null:
		opponent._update_interaction()

## Player-vs-player interaction rule: same color is solid, different colors
## phase through. Re-evaluated every physics frame (the opponent's color may
## have changed), so both bodies always agree. Environment collision is
## unaffected.
func _update_interaction() -> void:
	var solid: bool = _get_opponent() == null or _get_opponent().current_color == current_color
	collision_layer = 6 if solid else 2
	collision_mask = 5 if solid else 1

var _opponent: PlayerController = null

func _get_opponent() -> PlayerController:
	if _opponent == null or not is_instance_valid(_opponent):
		for node in get_tree().get_nodes_in_group(&"players"):
			if node != self:
				_opponent = node
				break
	return _opponent

func _physics_process(delta: float) -> void:
	_poll_controller_buttons()
	_commit_ai_input.call_deferred()
	if _animation_system != null:
		_animation_system.ensure_started()
	if _animation_system != null:
		_animation_system.advance(delta)
	if _hit_stop_timer > 0.0:
		_hit_stop_timer = maxf(_hit_stop_timer - delta, 0.0)
		if _hit_stop_timer <= 0.0:
			_animation_system.set_paused(false)
		return
	if not alive:
		_process_death(delta)
		return
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	if _combo_timer <= 0.0 and _current_attack == &"":
		_reset_combo()
	_process_color_input(delta)
	_process_attack(delta)
	_process_roll_input()
	_get_input()
	if _rolling:
		_process_roll(delta)
		_update_gravity(delta)
		_update_facing()
		_update_interaction()
		move_and_slide()
		_detect_wall_impact()
		_constrain_to_gameplay_plane()
		_was_grounded = is_on_floor()
		return
	if _hitstun_timer > 0.0:
		_hitstun_timer = maxf(_hitstun_timer - delta, 0.0)
		velocity.z = move_toward(velocity.z, 0.0, ground_deceleration * delta)
	else:
		_update_movement(delta)
	_update_gravity(delta)
	_handle_jump()
	_update_facing()
	_update_interaction()
	move_and_slide()
	_detect_wall_impact()
	if _current_attack == &"":
		_update_animation_state()
		_update_animation_speed()
	_constrain_to_gameplay_plane()
	_update_coyote_and_buffer_timers(delta)
	_was_grounded = is_on_floor()

func _commit_ai_input() -> void:
	_ai_previous = _ai_input.duplicate()

## KO'd players only fall and slide; input, attacks and animation state
## updates are disabled so the Death01 animation plays uninterrupted.
func _process_death(delta: float) -> void:
	_update_gravity(delta)
	velocity.x = 0.0
	move_and_slide()
	_constrain_to_gameplay_plane()
	_was_grounded = is_on_floor()

func _process_attack(delta: float) -> void:
	if _rolling:
		return
	if _current_attack == &"":
		if _hitstun_timer > 0.0:
			return
		if _action_just_pressed(&"light") and can_attack and not is_color_switching():
			_start_light_attack()
		elif _action_just_pressed(&"heavy") and can_attack and not is_color_switching():
			_reset_combo()
			_start_attack(&"hook")
		return
	_attack_elapsed += delta * _attack_time_scale
	var def: Dictionary = ATTACKS[_current_attack]
	var startup: float = def["startup"]
	var active_time: float = def["active"]
	var recovery: float = def["recovery"]
	var reach: float = def["range"]
	var active := _attack_elapsed >= startup and _attack_elapsed < startup + active_time
	if _attack_elapsed < startup:
		_attack_phase = AttackPhase.STARTUP
	elif active:
		_attack_phase = AttackPhase.ACTIVE
	else:
		_attack_phase = AttackPhase.RECOVERY
	var ideal_time := startup + active_time * 0.5
	var critical_window := float(def.get("critical_window", 0.22))
	_attack_critical = bool(def.get("can_critical", true)) and active and absf(_attack_elapsed - ideal_time) <= active_time * critical_window
	var hitbox_target := global_position + get_facing_direction() * reach
	_configure_attack_hitbox(def, hitbox_target)
	_attack_hitbox.monitoring = active
	_update_combat_debug(active, def)
	if active and not _active_feedback_emitted:
		_active_feedback_emitted = true
		attack_active.emit(self, hitbox_target, _current_attack != &"jab", _attack_critical)
	if active:
		for area in _attack_hitbox.get_overlapping_areas():
			var target := area.get_parent() as PlayerController
			if target != null and target != self:
				_resolve_attack_overlap(target, def, hitbox_target)
	var total_duration: float = startup + active_time + recovery
	var can_cancel := bool(def.get("can_cancel", true)) and _attack_connected
	var cancel_start := float(def.get("cancel_start", startup + active_time))
	var cancel_end := float(def.get("cancel_end", total_duration))
	var buffered_input := _action_just_pressed(&"light") or _action_just_pressed(&"heavy")
	if buffered_input and can_attack:
		_input_buffer_timer = input_buffer_window
		_buffer_heavy = _action_just_pressed(&"heavy")
		_accelerate_current_attack()
	_input_buffer_timer = maxf(_input_buffer_timer - delta, 0.0)
	if can_cancel and _attack_elapsed >= cancel_start and _attack_elapsed <= cancel_end and _input_buffer_timer > 0.0 and _queued_attack == &"":
		_input_buffer_timer = 0.0
		_queue_combo_attack(_buffer_heavy)
	if can_cancel and _queued_attack != &"" and _attack_elapsed >= cancel_start and _attack_elapsed <= cancel_end:
		var cancelled_follow_up := _queued_attack
		_queued_attack = &""
		_end_attack()
		_combo_step += 1
		_start_attack(cancelled_follow_up)
		return
	if _attack_elapsed >= total_duration:
		var follow_up := _queued_attack
		_queued_attack = &""
		_end_attack()
		if follow_up != &"":
			_combo_step += 1
			_start_attack(follow_up)
		else:
			_combo_timer = combo_refresh_time if _combo_step > 0 else 0.0
			_update_animation_state()

## Starts the named attack from the ATTACKS table. Attacks can be triggered
## from input or by combat systems (combos call this directly).
func _start_attack(attack_id: StringName) -> void:
	if not ATTACKS.has(attack_id) or _current_attack != &"":
		return
	_current_attack = attack_id
	_attack_color = current_color
	_attack_elapsed = 0.0
	_attack_phase = AttackPhase.STARTUP
	_attack_time_scale = 1.0
	_attack_hit_targets.clear()
	_attack_critical = false
	_attack_connected = false
	_critical_was_counter = false
	_active_feedback_emitted = false
	_attack_hitbox.monitoring = false
	_animation_system.set_speed_scale(1.0)
	var attack_state: StringName = &"JAB"
	if attack_id == &"cross":
		attack_state = &"CROSS"
	elif attack_id in [&"hook", &"combo_hook"]:
		attack_state = &"HOOK"
	elif attack_id == &"overhand":
		attack_state = &"OVERHAND"
	_animation_system.travel(attack_state, true)
	_current_animation = ATTACKS[attack_id]["animation"]

func _resolve_attack_overlap(target: PlayerController, definition: Dictionary, hit_position: Vector3) -> void:
	if _attack_hit_targets.has(target):
		return
	_attack_hit_targets[target] = true
	if target.current_color != _attack_color:
		phase_missed.emit(self, target, hit_position)
		_reset_combo()
		return
	var counter := target.is_recovery_vulnerable()
	_attack_critical = _attack_critical or (bool(definition.get("can_critical", true)) and counter)
	_critical_was_counter = counter
	var damage: int = definition["damage"]
	var knockback: float = definition["knockback"]
	var reaction: StringName = definition.get("reaction", &"chest")
	if _attack_critical:
		damage = roundi(damage * float(definition.get("critical_damage_mult", 1.5)))
		knockback *= float(definition.get("critical_knockback_mult", 1.35))
		reaction = &"head"
	target.take_hit(
		self,
		damage,
		knockback,
		reaction,
		float(definition.get("hitstun", HITSTUN_DURATION)),
		bool(definition.get("wall_bounce", false))
	)
	var launch := float(definition.get("launch", 0.0))
	if launch > 0.0 and target.alive:
		target.velocity.y = launch
	hit_confirmed.emit(self, target, hit_position, _current_attack != &"jab")
	_attack_connected = true
	if _attack_critical:
		critical_hit.emit(self, target, hit_position, _current_attack != &"jab")
	if _critical_was_counter:
		counter_hit.emit(self, target, hit_position)
	_combo_hits += 1
	if _combo_hits == 2:
		combo_started.emit(_combo_hits)
	elif _combo_hits > 2:
		combo_extended.emit(_combo_hits)
	_combo_timer = combo_refresh_time

func _configure_attack_hitbox(definition: Dictionary, target: Vector3) -> void:
	var hitbox_offset: Vector3 = definition["hitbox_offset"]
	_attack_shape.position = Vector3(hitbox_offset.x, hitbox_offset.y, to_local(target).z)
	(_attack_shape.shape as BoxShape3D).size = definition["hitbox_size"]

func configure_hitbox_for_test(attack_id: StringName) -> void:
	var definition: Dictionary = ATTACKS[attack_id]
	var target := global_position + get_facing_direction() * float(definition["range"])
	_configure_attack_hitbox(definition, target)

func attack_hitbox_position() -> Vector3:
	return _attack_shape.position

func attack_hitbox_size() -> Vector3:
	return (_attack_shape.shape as BoxShape3D).size

func _start_light_attack() -> void:
	var attack_id: StringName = &"jab"
	if _combo_step == 1:
		attack_id = &"cross"
	elif _combo_step >= 2:
		attack_id = &"combo_hook"
	_start_attack(attack_id)
	_combo_step += 1
	_combo_timer = 0.0

func _queue_combo_attack(heavy := false) -> void:
	if _current_attack == &"":
		return
	# The second jab is a finite alternate route, never a loop.
	if _current_attack == &"jab" and _combo_step >= 2:
		_queued_attack = &"combo_hook"
		return
	var key := "heavy_followup" if heavy else "light_followup"
	_queued_attack = ATTACKS[_current_attack].get(key, &"")

func _accelerate_current_attack() -> void:
	if _current_attack == &"" or _attack_time_scale > 1.0:
		return
	_attack_time_scale = buffered_attack_speed
	_animation_system.set_speed_scale(buffered_attack_speed)

func _end_attack() -> void:
	if _current_attack != &"":
		_animation_system.set_speed_scale(1.0)
	_current_attack = &""
	_attack_phase = AttackPhase.IDLE
	_attack_elapsed = -1.0
	_attack_time_scale = 1.0
	_attack_hitbox.monitoring = false
	_input_buffer_timer = 0.0
	_update_combat_debug(false, {})

func _reset_combo() -> void:
	var had_combo := _combo_hits > 0 or _combo_step > 0 or _queued_attack != &""
	_combo_hits = 0
	_combo_step = 0
	_combo_timer = 0.0
	_queued_attack = &""
	_input_buffer_timer = 0.0
	_buffer_heavy = false
	if had_combo:
		combo_finished.emit()

func _process_roll_input() -> void:
	if _rolling or _current_attack != &"" or _hitstun_timer > 0.0 or _controls_locked or not is_on_floor():
		return
	var horizontal := _axis(&"move_left", &"move_right")
	var device := _controller_device()
	var vertical := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y) if device >= 0 else 0.0
	var lower_diagonal := absf(vertical) >= roll_diagonal_threshold and absf(horizontal) >= roll_diagonal_threshold
	var keyboard_roll := _action_pressed(&"roll") and absf(horizontal) > 0.0
	var controller_roll := _action_just_pressed(&"roll") and absf(horizontal) >= controller_deadzone
	var roll_input := lower_diagonal or keyboard_roll or controller_roll
	if roll_input and not _roll_input_held:
		_start_roll(signf(horizontal))
	_roll_input_held = roll_input

func set_joy_axis_x_for_test(value: float) -> void:
	_test_joy_axis_x = value

func _start_roll(direction: float) -> void:
	if is_zero_approx(direction):
		return
	_rolling = true
	_roll_timer = roll_duration
	_roll_direction = direction
	_roll_backward = direction * _facing < 0.0
	_current_animation = &"Roll_Back" if _roll_backward else &"Roll"
	if _roll_backward:
		_animation_system.travel_reverse(&"ROLL_BACK")
		_animation_system.set_speed_scale(1.0)
	else:
		_animation_system.travel(&"ROLL", true)
		_animation_system.set_speed_scale(1.0)

func _process_roll(delta: float) -> void:
	_roll_timer = maxf(_roll_timer - delta, 0.0)
	var speed := roll_speed * (backward_speed_multiplier if _roll_backward else 1.0)
	velocity.z = _roll_direction * speed
	if _roll_timer <= 0.0:
		_end_roll()

func _end_roll() -> void:
	_rolling = false
	_roll_timer = 0.0
	_animation_system.set_speed_scale(1.0)
	_current_animation = &""
	_update_animation_state()

func is_rolling() -> bool:
	return _rolling

func start_roll_for_test(direction: float) -> void:
	_start_roll(direction)

func process_roll_input_for_test(horizontal: float, vertical: float) -> void:
	var lower_diagonal := absf(vertical) >= roll_diagonal_threshold and absf(horizontal) >= roll_diagonal_threshold
	if lower_diagonal:
		_start_roll(signf(horizontal))

func process_real_roll_input_for_test() -> void:
	_process_roll_input()

func process_roll_for_test(delta: float) -> void:
	_process_roll(delta)

func select_grounded_animation_for_test() -> void:
	_set_grounded_animation()

func apply_hit_stop(duration: float) -> void:
	_hit_stop_timer = maxf(_hit_stop_timer, duration)
	_animation_system.set_paused(true)

func is_in_hit_stop() -> bool:
	return _hit_stop_timer > 0.0

func current_attack() -> StringName:
	return _current_attack

func attack_phase() -> AttackPhase:
	return _attack_phase

func is_recovery_vulnerable() -> bool:
	return alive and _current_attack != &"" and _attack_phase == AttackPhase.RECOVERY

func combo_step() -> int:
	return _combo_step

func animation_speed_scale() -> float:
	return _animation_system._speed_scale if _animation_system != null else 1.0

func animation_state() -> StringName:
	return _animation_system.current_state if _animation_system != null else &""

func animation_position() -> float:
	return _animation_system.animation_position() if _animation_system != null else 0.0

func queue_combo_for_test() -> void:
	_queue_combo_attack()

func take_hit(attacker: PlayerController, damage: int, knockback: float, reaction: StringName = &"knockback", hitstun := HITSTUN_DURATION, can_wall_bounce := true) -> void:
	if not alive:
		return
	if _rolling:
		_end_roll()
	if _current_attack != &"":
		_end_attack()
		_reset_combo()
	health = max(health - damage, 0)
	if health <= 0:
		_die()
		return
	_reset_combo()
	_hitstun_timer = hitstun
	velocity.y = 0.0
	velocity.z = signf(global_position.z - attacker.global_position.z) * knockback
	_last_knockback = knockback
	_wall_bounce_allowed = can_wall_bounce
	_wall_hit_reported = false
	_current_animation = &""
	var reaction_state := &"HIT"
	var reaction_animation := &"Hit_Knockback"
	if reaction == &"chest":
		reaction_state = &"HIT_CHEST"
		reaction_animation = &"Hit_Chest"
	elif reaction == &"head":
		reaction_state = &"HIT_HEAD"
		reaction_animation = &"Hit_Head"
	_animation_system.travel(reaction_state, true)
	_current_animation = reaction_animation

## Lethal hazard damage (spikes). Any amount equal to or above the remaining
## health knocks the player out. Death comes only from this hazard area, never
## from plain wall contact.
func take_hazard_damage(amount: int) -> void:
	if not alive:
		return
	health = max(health - amount, 0)
	if health <= 0:
		_die()
		spike_ko.emit(global_position, self)

func _detect_wall_impact() -> void:
	if _wall_hit_reported or _hitstun_timer <= 0.0 or _last_knockback <= 0.0:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if absf(collision.get_normal().z) > 0.7:
			_wall_hit_reported = true
			var heavy := _last_knockback >= wall_bounce_min_knockback
			wall_hit.emit(collision.get_position(), heavy, self)
			if heavy and _wall_bounce_allowed and _last_knockback > 0.0:
				velocity.z = collision.get_normal().z * wall_bounce_strength * _last_knockback
				_hitstun_timer = maxf(_hitstun_timer, wall_bounce_hitstun)
			else:
				velocity.z = 0.0
			_last_knockback = 0.0
			_wall_bounce_allowed = false
			return

func _die() -> void:
	if _rolling:
		_end_roll()
	_end_attack()
	alive = false
	can_move = false
	can_jump = false
	can_attack = false
	velocity = Vector3.ZERO
	_attack_hitbox.monitoring = false
	_reset_combo()
	_play_animation(&"Death01")
	died.emit()

## Freezes the player in place for the match controller: input, movement
## facing, RGB switching, attacks, hitstun and velocity are all stopped.
## Does not touch health or alive - reset_round() restores those.
func lock_controls() -> void:
	_controls_locked = true
	can_move = false
	can_jump = false
	can_attack = false
	can_change_color = false
	if _rolling:
		_end_roll()
	_end_attack()
	_reset_combo()
	_rolling = false
	_roll_timer = 0.0
	_roll_input_held = false
	_hitstun_timer = 0.0
	_hit_stop_timer = 0.0
	_last_knockback = 0.0
	_wall_bounce_allowed = false
	_animation_system.set_paused(false)
	_animation_system.set_speed_scale(1.0)
	velocity = Vector3.ZERO

## Re-enables input after lock_controls(). Combat state (health, position,
## attack state) is left untouched; use reset_round() for a full reset.
func unlock_controls() -> void:
	_controls_locked = false
	can_move = true
	can_jump = true
	can_attack = true
	can_change_color = true

## Restores the player to its round-start state in place (no scene reload):
## health, life, controls, RGB state, attack state, hitstun, facing, velocity
## and position. Called by the match controller between rounds.
func reset_round() -> void:
	var color_was_changed := current_color != PlayerColor.RED
	health = MAX_HEALTH
	alive = true
	unlock_controls()
	current_color = PlayerColor.RED
	_apply_color()
	if color_was_changed:
		color_changed.emit(current_color)
	velocity = Vector3.ZERO
	_current_attack = &""
	_attack_phase = AttackPhase.IDLE
	_attack_elapsed = -1.0
	_attack_hitbox.monitoring = false
	_hitstun_timer = 0.0
	_reset_combo()
	_pending_color = current_color
	_color_switch_timer = 0.0
	_color_cooldown_timer = 0.0
	_last_knockback = 0.0
	_wall_bounce_allowed = false
	_wall_hit_reported = false
	_facing = 1.0
	_armature.scale = _base_armature_scale
	_armature.rotation = _base_armature_rotation
	_apply_visual_facing()
	_current_state = LocomotionState.IDLE
	_current_animation = &""
	_jump_buffer_timer = 0.0
	_landing_animation_playing = false
	_jump_started = false
	_animation_system.set_paused(false)
	_animation_system.set_speed_scale(1.0)
	global_position = _spawn_position
	_was_grounded = false
	_play_animation(&"Idle")

func _process_color_input(delta: float) -> void:
	if not can_change_color:
		return
	_color_cooldown_timer = maxf(_color_cooldown_timer - delta, 0.0)
	if _color_switch_timer > 0.0:
		_color_switch_timer = maxf(_color_switch_timer - delta, 0.0)
		if _color_switch_timer <= 0.0:
			current_color = _pending_color
			_apply_color()
			color_changed.emit(current_color)
			_color_cooldown_timer = color_switch_cooldown
		return
	if _color_cooldown_timer > 0.0:
		return
	var new_color: PlayerColor = current_color
	if _action_just_pressed(&"red"):
		new_color = PlayerColor.RED
	elif _action_just_pressed(&"green"):
		new_color = PlayerColor.GREEN
	elif _action_just_pressed(&"blue"):
		new_color = PlayerColor.BLUE
	if new_color != current_color:
		_pending_color = new_color
		_color_switch_timer = color_switch_commitment

func is_color_switching() -> bool:
	return _color_switch_timer > 0.0

func color_switch_cooldown_remaining() -> float:
	return _color_cooldown_timer

func request_color_for_test(color: PlayerColor) -> void:
	if color == current_color or is_color_switching() or _color_cooldown_timer > 0.0:
		return
	_pending_color = color
	_color_switch_timer = color_switch_commitment

func advance_color_switch_for_test(delta: float) -> void:
	_process_color_input(delta)

func attack_color() -> PlayerColor:
	return _attack_color

func set_attack_critical_for_test(value: bool) -> void:
	_attack_critical = value

func facing_sign() -> float:
	return _facing

func visual_faces_opponent_for_test() -> bool:
	var opponent := _get_opponent()
	if opponent == null:
		return false
	var toward := signf(opponent.global_position.z - global_position.z)
	var front := signf(get_world_front().z)
	return front == toward

func movement_input_value() -> float:
	return _movement_input

func facing_relative_movement() -> float:
	return _movement_input * _facing

func set_opponent_for_test(opponent: PlayerController) -> void:
	_opponent = opponent

func update_facing_for_test() -> void:
	_update_facing()

func _get_input() -> void:
	# 2.5D gameplay lane: Z is forward/back movement along the arena lane
	# (move_right = forward +Z, move_left = back -Z), X is locked depth.
	if _controls_locked:
		_movement_input = 0.0
		return
	_movement_input = _axis(&"move_left", &"move_right")

func resolve_movement_input(keyboard_input: float, analog_input: float) -> float:
	var controller_input := analog_input
	if absf(controller_input) < controller_deadzone:
		controller_input = 0.0
	else:
		controller_input = signf(controller_input) * inverse_lerp(controller_deadzone, 1.0, absf(controller_input))
	return clampf(controller_input if not is_zero_approx(controller_input) else keyboard_input, -1.0, 1.0)

func set_movement_input_for_test(value: float) -> void:
	_movement_input = clampf(value, -1.0, 1.0)

func update_animation_speed_for_test() -> void:
	_current_state = LocomotionState.MOVING
	_update_animation_speed()

func _update_movement(delta: float) -> void:
	if not can_move:
		return
	var forward_input := _movement_input * _facing
	var speed_limit := move_speed if forward_input >= 0.0 else move_speed * backward_speed_multiplier
	var target_velocity_z: float = _movement_input * speed_limit
	var current_z: float = velocity.z
	var new_z: float = current_z
	if _movement_input != 0.0:
		var acceleration: float = ground_acceleration if is_on_floor() else air_acceleration
		new_z = move_toward(current_z, target_velocity_z, acceleration * delta)
	else:
		var deceleration: float = ground_deceleration if is_on_floor() else air_deceleration
		new_z = move_toward(current_z, 0.0, deceleration * delta)
	velocity.z = new_z

func _update_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _handle_jump() -> void:
	if not can_jump or _hitstun_timer > 0.0:
		return
	if _action_just_pressed(&"jump"):
		_jump_buffer_timer = jump_buffer_time
	if _action_just_released(&"jump") and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0 and is_on_floor():
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_jump_started = true

func _update_facing() -> void:
	if _controls_locked:
		return
	var opponent := _get_opponent()
	var desired_facing := _facing
	if opponent != null and is_instance_valid(opponent) and absf(opponent.global_position.z - global_position.z) > 0.01:
		desired_facing = signf(opponent.global_position.z - global_position.z)
	elif _movement_input != 0.0:
		desired_facing = signf(_movement_input) * _facing
	if desired_facing == _facing:
		_apply_visual_facing()
		return
	_facing = desired_facing
	_apply_visual_facing()

func _apply_visual_facing() -> void:
	_armature.scale = _base_armature_scale
	var rotate_visual := (_facing < 0.0) != visual_facing_inverted
	_armature.rotation = _base_armature_rotation + Vector3(0.0, PI if rotate_visual else 0.0, 0.0)

## World-space direction the character's canonical front (face) points,
## derived from the Armature's current editor orientation only. The left/right
## gameplay mirror (horizontal scale flip) is removed from the basis, so this
## returns the authored front no matter which way the character is currently
## facing. Rotate the Player or Armature in the editor to redefine it.
func get_world_front() -> Vector3:
	var armature_basis: Basis = _armature.global_transform.basis
	return (armature_basis * model_forward_local).normalized()

## World-space direction behind the character (exact opposite of the front).
func get_world_back() -> Vector3:
	return -get_world_front()

## The character's current gameplay combat direction along the arena's
## back/front lane: +Z when facing forward, -Z when facing back. Independent
## of the canonical get_world_front(); use this for attacks, hitboxes,
## knockback, combos, dashes and projectiles.
func get_facing_direction() -> Vector3:
	return Vector3(0, 0, 1.0) if _facing > 0.0 else Vector3(0, 0, -1.0)

func _update_animation_state() -> void:
	var grounded: bool = is_on_floor()

	if _jump_started:
		_jump_started = false
		_set_state(LocomotionState.JUMPING)
		_play_animation(&"Jump_Start")
		return

	if not grounded:
		if _current_animation == &"Jump_Start":
			_play_animation(&"Jump")
		if velocity.y > 0.0:
			_set_state(LocomotionState.JUMPING)
		else:
			_set_state(LocomotionState.FALLING)
		_play_animation(&"Jump")
		return

	if not _was_grounded:
		if absf(velocity.z) >= 0.1 or absf(_movement_input) > 0.05:
			_landing_animation_playing = false
			_set_grounded_animation()
		else:
			_landing_animation_playing = true
			_set_state(LocomotionState.LANDING)
			_play_animation(&"Jump_Land")
		return

	if _landing_animation_playing:
		if _animation_system.is_playing() and _animation_system.animation_position() >= _animation_system.animation_length() - 0.05:
			_landing_animation_playing = false
		else:
			return

	_set_grounded_animation()

func _setup_combat_debug() -> void:
	_debug_hitbox_mesh = MeshInstance3D.new()
	_debug_hitbox_mesh.name = &"DebugHitbox"
	var hit_mesh := BoxMesh.new()
	hit_mesh.size = Vector3.ONE
	_debug_hitbox_mesh.mesh = hit_mesh
	_debug_hitbox_mesh.material_override = _debug_material(Color(1.0, 0.08, 0.08, 0.28))
	add_child(_debug_hitbox_mesh)
	_debug_hurtbox_mesh = MeshInstance3D.new()
	_debug_hurtbox_mesh.name = &"DebugHurtbox"
	var hurt_mesh := CapsuleMesh.new()
	hurt_mesh.radius = 0.45
	hurt_mesh.height = 1.85
	_debug_hurtbox_mesh.mesh = hurt_mesh
	_debug_hurtbox_mesh.material_override = _debug_material(Color(0.08, 0.3, 1.0, 0.18))
	add_child(_debug_hurtbox_mesh)
	_debug_hitbox_mesh.visible = combat_debug
	_debug_hurtbox_mesh.visible = combat_debug
	_debug_label = Label3D.new()
	_debug_label.name = &"CombatDebugLabel"
	_debug_label.position = Vector3(0.0, 2.5, 0.0)
	_debug_label.font_size = 32
	_debug_label.modulate = Color.WHITE
	add_child(_debug_label)
	_debug_label.visible = combat_debug
	_debug_hurtbox_mesh.position = _hurtbox_shape.position
	_debug_hurtbox_mesh.rotation = _hurtbox_shape.rotation
	_debug_hurtbox_mesh.scale = Vector3.ONE
	_update_combat_debug(false, {})

func set_combat_debug(enabled: bool) -> void:
	combat_debug = enabled
	_update_combat_debug(false, {})

func _debug_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

func _update_combat_debug(active: bool, definition: Dictionary) -> void:
	if not combat_debug:
		_debug_hitbox_mesh.visible = false
		_debug_hurtbox_mesh.visible = false
		_debug_label.visible = false
		return
	_debug_hurtbox_mesh.visible = true
	_debug_hitbox_mesh.visible = active
	_debug_label.visible = true
	_debug_hitbox_mesh.position = _attack_shape.position
	_debug_hitbox_mesh.scale = (_attack_shape.shape as BoxShape3D).size
	_debug_label.text = "%s\n%s %.2f" % [_current_attack, "ACTIVE" if active else "RECOVERY", _attack_elapsed]
	if definition.is_empty():
		return
	_attack_hitbox.name = "JabHitbox" if _current_attack == &"jab" else "HookHitbox"

func _set_grounded_animation() -> void:
	var speed: float = absf(velocity.z)
	if speed < 0.1:
		_set_state(LocomotionState.IDLE)
		_play_animation(&"Idle")
	else:
		_set_state(LocomotionState.MOVING)
		if speed < walk_speed_threshold:
			var backward := velocity.z * _facing < 0.0
			if backward:
				if _current_animation != &"Walk_Back":
					_current_animation = &"Walk_Back"
					_animation_system.travel_reverse(&"WALK_BACK")
				_animation_system.set_speed_scale(clampf(speed / maxf(move_speed, 0.001), 0.15, 1.0))
			else:
				_play_animation(&"Walk")
		elif speed < jog_speed_threshold:
			_play_animation(&"Jog_Fwd")
		else:
			_play_animation(&"Sprint")

func _action_pressed(action_id: StringName) -> bool:
	var action := _managed_action_name(action_id)
	var button := _managed_joy_button(action_id)
	return Input.is_action_pressed(action) or bool(_joy_current.get(button, false)) or bool(_ai_input.get(action_id, false))

func _action_just_pressed(action_id: StringName) -> bool:
	var action := _managed_action_name(action_id)
	var button := _managed_joy_button(action_id)
	var joy_pressed: bool = button >= 0 and bool(_joy_current.get(button, false)) and not bool(_joy_previous.get(button, false))
	var ai_pressed := bool(_ai_input.get(action_id, false)) and not bool(_ai_previous.get(action_id, false))
	return Input.is_action_just_pressed(action) or joy_pressed or ai_pressed

func _action_just_released(action_id: StringName) -> bool:
	var action := _managed_action_name(action_id)
	var button := _managed_joy_button(action_id)
	var joy_released: bool = button >= 0 and not bool(_joy_current.get(button, false)) and bool(_joy_previous.get(button, false))
	var ai_released := not bool(_ai_input.get(action_id, false)) and bool(_ai_previous.get(action_id, false))
	return Input.is_action_just_released(action) or joy_released or ai_released

func _axis(negative: StringName, positive: StringName) -> float:
	var keyboard := Input.get_axis(_managed_action_name(negative), _managed_action_name(positive))
	var device := _controller_device()
	var analog := _test_joy_axis_x if not is_zero_approx(_test_joy_axis_x) else (Input.get_joy_axis(device, JOY_AXIS_LEFT_X) if device >= 0 else 0.0)
	var ai_axis := float(_ai_input.get(&"move_axis", 0.0))
	return resolve_movement_input(keyboard, ai_axis if not is_zero_approx(ai_axis) else analog)

func set_ai_input(state: Dictionary) -> void:
	_ai_input = state.duplicate()

func clear_ai_input() -> void:
	_ai_input.clear()
	_ai_previous.clear()

func _controller_device() -> int:
	var manager := get_node_or_null("/root/DeviceManager")
	return manager.device_for_player(player_index) if manager != null else controller_device

func _poll_controller_buttons() -> void:
	_joy_previous = _joy_current.duplicate()
	_joy_current.clear()
	var device := _controller_device()
	if device < 0:
		return
	for action_id in [&"jump", &"roll", &"light", &"heavy", &"red", &"green", &"blue"]:
		var button := _managed_joy_button(action_id)
		if button >= 0:
			_joy_current[button] = Input.is_joy_button_pressed(device, button)

func _managed_action_name(action_id: StringName) -> StringName:
	var manager := get_node_or_null("/root/InputManager")
	if manager != null:
		return manager.action_name(player_index, action_id)
	var actions := {
		&"move_left": _move_left_action, &"move_right": _move_right_action, &"jump": _jump_action,
		&"light": _attack_action, &"heavy": _heavy_action, &"roll": _roll_action,
		&"red": _red_action, &"green": _green_action, &"blue": _blue_action,
	}
	return actions.get(action_id, action_id)

func _managed_joy_button(action_id: StringName) -> int:
	var manager := get_node_or_null("/root/InputManager")
	if manager != null:
		return manager.joy_button(player_index, action_id)
	var buttons := {&"jump": JOY_BUTTON_A, &"roll": JOY_BUTTON_B, &"light": JOY_BUTTON_X, &"heavy": JOY_BUTTON_Y, &"red": JOY_BUTTON_DPAD_LEFT, &"green": JOY_BUTTON_DPAD_UP, &"blue": JOY_BUTTON_DPAD_RIGHT}
	return int(buttons.get(action_id, -1))

## Locomotion animations play forward while moving front and reversed while
## moving back, and their playback rate follows the character's ground speed.
func _update_animation_speed() -> void:
	if _current_state != LocomotionState.MOVING:
		return
	var speed_ratio: float = clampf(absf(velocity.z) / maxf(move_speed, 0.001), 0.15, 1.0)
	_animation_system.set_speed_scale(speed_ratio)

func _play_animation(animation_name: StringName) -> void:
	if _current_animation == animation_name:
		return
	_current_animation = animation_name
	var state := _animation_state_for(animation_name)
	_animation_system.travel(state, animation_name in [&"Death01", &"Jump_Start", &"Jump_Land"])
	if animation_name not in _LOCOMOTION_ANIMS:
		_animation_system.set_speed_scale(1.0)
	if debug_log:
		print("PlayerController: animation -> ", animation_name)

func _animation_state_for(animation_name: StringName) -> StringName:
	match animation_name:
		&"Idle": return &"IDLE"
		&"Walk": return &"WALK"
		&"Walk_Back": return &"WALK_BACK"
		&"Jog_Fwd": return &"JOG"
		&"Sprint": return &"SPRINT"
		&"Jump_Start": return &"JUMP_START"
		&"Jump": return &"JUMP"
		&"Jump_Land": return &"LAND"
		&"Punch_Jab": return &"JAB"
		&"Punch_Cross": return &"CROSS"
		&"Melee_Hook": return &"HOOK"
		&"Hit_Knockback": return &"HIT"
		&"Hit_Chest": return &"HIT_CHEST"
		&"Hit_Head": return &"HIT_HEAD"
		&"Death01": return &"DEATH"
	return &"IDLE"

func _set_state(state: LocomotionState) -> void:
	if _current_state != state:
		_current_state = state
		if debug_log:
			print("PlayerController: state -> ", LocomotionState.keys()[state])

func _constrain_to_gameplay_plane() -> void:
	if constrain_to_plane:
		global_position.x = _plane_x

func _update_coyote_and_buffer_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

func _configure_animation_looping() -> void:
	# In-memory loop mode for the locomotion set only. The scene files and
	# animation assets on disk are not modified.
	_set_loop_mode(&"Idle", Animation.LOOP_LINEAR)
	_set_loop_mode(&"Walk", Animation.LOOP_LINEAR)
	_set_loop_mode(&"Jog_Fwd", Animation.LOOP_LINEAR)
	_set_loop_mode(&"Sprint", Animation.LOOP_LINEAR)
	_set_loop_mode(&"Jump", Animation.LOOP_LINEAR)
	_set_loop_mode(&"Jump_Start", Animation.LOOP_NONE)
	_set_loop_mode(&"Jump_Land", Animation.LOOP_NONE)

func _set_loop_mode(animation_name: StringName, loop_mode: Animation.LoopMode) -> void:
	if not _locomotion.has_animation(animation_name):
		push_warning("PlayerController: animation not found in pack1: %s" % animation_name)
		return
	_locomotion.get_animation(animation_name).loop_mode = loop_mode
