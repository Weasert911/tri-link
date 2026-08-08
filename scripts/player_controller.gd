class_name PlayerController
extends CharacterBody3D
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

## The player's RGB state. Same color as the opponent means solid
## (player-vs-player collision active); different colors phase through.
enum PlayerColor {
	RED,
	GREEN,
	BLUE,
}

const MAX_HEALTH := 100
const PUNCH_DAMAGE := 10
const PUNCH_DURATION := 0.87
const PUNCH_ACTIVE_START := 0.20
const PUNCH_ACTIVE_END := 0.38
const PUNCH_KNOCKBACK := 4.5

## Lane movement speed (units/second) at full run, tuned for a ~0.4-scale
## character (roughly 0.7 m tall).
@export var move_speed: float = 1.2
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
## Seconds after leaving the ground where a jump is still allowed.
@export var coyote_time: float = 0.10
## Seconds a jump press is remembered while airborne.
@export var jump_buffer_time: float = 0.10
## Fraction of upward velocity retained when jump is released early.
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
## Animation crossfade time for transitions.
@export var animation_blend_time: float = 0.12
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
## Movement can be disabled later by combat/state systems.
@export var can_move: bool = true
## Jumping can be disabled later by combat/state systems.
@export var can_jump: bool = true
## Print locomotion state and animation transitions to the console.
@export var debug_log: bool = false
## Player index. 1 uses the primary action set (move_left/move_right/jump),
## 2 uses the secondary set (p2_move_left/p2_move_right/p2_jump).
@export var player_index: int = 1
## Current RGB state. Determines solid/phase interaction with the opponent.
@export var current_color: PlayerColor = PlayerColor.RED
@export var health: int = MAX_HEALTH

@onready var _armature: Node3D = $Armature
@onready var _locomotion: AnimationPlayer = $pack1
@onready var _color_indicator: MeshInstance3D = $ColorIndicator
@onready var _attack_hitbox: Area3D = $AttackHitbox
@onready var _attack_shape: CollisionShape3D = $AttackHitbox/CollisionShape3D

var _current_state: LocomotionState = LocomotionState.IDLE
var _current_animation: StringName = &""
var _facing: float = 1.0
## Locomotion animations that play reversed while the character moves back.
const _LOCOMOTION_ANIMS: Array[StringName] = [&"Walk", &"Jog_Fwd", &"Sprint"]
## Armature scale as authored in the editor. Only the horizontal axis is
## flipped for left/right facing; this base value is always restored.
var _base_armature_scale: Vector3 = Vector3.ONE
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
var _attack_action: StringName = &"attack"
var _attack_elapsed := -1.0
var _attack_hit_targets: Dictionary = {}
var _hitstun_timer := 0.0

func _ready() -> void:
	if player_index == 2:
		_move_left_action = &"p2_move_left"
		_move_right_action = &"p2_move_right"
		_jump_action = &"p2_jump"
		_red_action = &"p2_red"
		_green_action = &"p2_green"
		_blue_action = &"p2_blue"
		_attack_action = &"p2_attack"
	add_to_group(&"players")
	_build_color_materials()
	_apply_color()
	_base_armature_scale = _armature.scale
	_plane_x = global_position.x if is_zero_approx(gameplay_plane_x) else gameplay_plane_x
	_was_grounded = is_on_floor()
	_configure_animation_looping()
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
	_process_color_input()
	_process_attack(delta)
	_get_input()
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
	if _attack_elapsed < 0.0:
		_update_animation_state()
		_update_animation_speed()
	_constrain_to_gameplay_plane()
	_update_coyote_and_buffer_timers(delta)
	_was_grounded = is_on_floor()

func _process_attack(delta: float) -> void:
	if _attack_elapsed < 0.0:
		if Input.is_action_just_pressed(_attack_action) and _hitstun_timer <= 0.0:
			_attack_elapsed = 0.0
			_attack_hit_targets.clear()
			_attack_hitbox.monitoring = false
			_locomotion.play(&"Punch_Jab", animation_blend_time)
		return
	_attack_elapsed += delta
	var active := _attack_elapsed >= PUNCH_ACTIVE_START and _attack_elapsed < PUNCH_ACTIVE_END
	var hitbox_target := global_position + get_facing_direction() * 0.44
	_attack_shape.position.z = to_local(hitbox_target).z
	_attack_hitbox.monitoring = active
	if active:
		for body in _attack_hitbox.get_overlapping_bodies():
			if body is PlayerController and body != self and not _attack_hit_targets.has(body):
				_attack_hit_targets[body] = true
				body.take_punch(self)
	if _attack_elapsed >= PUNCH_DURATION:
		_attack_elapsed = -1.0
		_attack_hitbox.monitoring = false

func take_punch(attacker: PlayerController) -> void:
	if health <= 0:
		return
	health = max(health - PUNCH_DAMAGE, 0)
	_hitstun_timer = 0.25
	velocity.y = 0.0
	velocity.z = signf(global_position.z - attacker.global_position.z) * PUNCH_KNOCKBACK
	_current_animation = &""
	$pack2.play(&"Hit_Knockback", animation_blend_time)

func _process_color_input() -> void:
	var new_color: PlayerColor = current_color
	if Input.is_action_just_pressed(_red_action):
		new_color = PlayerColor.RED
	elif Input.is_action_just_pressed(_green_action):
		new_color = PlayerColor.GREEN
	elif Input.is_action_just_pressed(_blue_action):
		new_color = PlayerColor.BLUE
	if new_color != current_color:
		current_color = new_color
		_apply_color()

func _get_input() -> void:
	# 2.5D gameplay lane: Z is forward/back movement along the arena lane
	# (move_right = forward +Z, move_left = back -Z), X is locked depth.
	_movement_input = Input.get_axis(_move_left_action, _move_right_action)

func _update_movement(delta: float) -> void:
	if not can_move:
		return
	var target_velocity_z: float = _movement_input * move_speed
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
	if not can_jump:
		return
	if Input.is_action_just_pressed(_jump_action):
		_jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_released(_jump_action) and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0 and is_on_floor():
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_jump_started = true

func _update_facing() -> void:
	if _movement_input == 0.0:
		return
	var desired_facing: float = signf(_movement_input)
	if desired_facing == _facing:
		return
	_facing = desired_facing
	# Visual mirror only: preserve the Armature's editor rotation and scale,
	# flipping only the horizontal axis. The physics body never rotates.
	_armature.scale.x = _base_armature_scale.x * _facing

## World-space direction the character's canonical front (face) points,
## derived from the Armature's current editor orientation only. The left/right
## gameplay mirror (horizontal scale flip) is removed from the basis, so this
## returns the authored front no matter which way the character is currently
## facing. Rotate the Player or Armature in the editor to redefine it.
func get_world_front() -> Vector3:
	var basis: Basis = _armature.global_transform.basis
	basis.x = basis.x * _facing
	return (basis * model_forward_local).normalized()

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
		# Jump_Start plays on takeoff; move to the airborne loop once it
		# finishes or once the rise is over.
		if _current_animation == &"Jump_Start":
			var jump_start_finished: bool = not _locomotion.is_playing()
			jump_start_finished = jump_start_finished or _locomotion.current_animation_position >= _locomotion.current_animation_length - 0.05
			if not jump_start_finished and velocity.y > 0.0:
				return
			_play_animation(&"Jump")
		if velocity.y > 0.0:
			_set_state(LocomotionState.JUMPING)
		else:
			_set_state(LocomotionState.FALLING)
		_play_animation(&"Jump")
		return

	if not _was_grounded:
		_landing_animation_playing = true
		_set_state(LocomotionState.LANDING)
		_play_animation(&"Jump_Land")
		return

	if _landing_animation_playing:
		if _locomotion.is_playing() and _locomotion.current_animation_position >= _locomotion.current_animation_length - 0.05:
			_landing_animation_playing = false
		else:
			return

	_set_grounded_animation()

func _set_grounded_animation() -> void:
	var speed: float = absf(velocity.z)
	if speed < 0.1:
		_set_state(LocomotionState.IDLE)
		_play_animation(&"Idle")
	else:
		_set_state(LocomotionState.MOVING)
		if speed < walk_speed_threshold:
			_play_animation(&"Walk")
		elif speed < jog_speed_threshold:
			_play_animation(&"Jog_Fwd")
		else:
			_play_animation(&"Sprint")

## Locomotion animations play forward while moving front and reversed while
## moving back, and their playback rate follows the character's ground speed.
func _update_animation_speed() -> void:
	if _current_state != LocomotionState.MOVING:
		return
	var speed_ratio: float = clampf(absf(velocity.z) / maxf(move_speed, 0.001), 0.15, 1.0)
	_locomotion.speed_scale = _facing * speed_ratio

func _play_animation(animation_name: StringName) -> void:
	if _current_animation == animation_name:
		return
	_current_animation = animation_name
	_locomotion.play(animation_name, animation_blend_time)
	if animation_name not in _LOCOMOTION_ANIMS:
		_locomotion.speed_scale = 1.0
	if debug_log:
		print("PlayerController: animation -> ", animation_name)

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
