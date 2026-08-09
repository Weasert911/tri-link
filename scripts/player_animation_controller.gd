class_name PlayerAnimationController
extends Node

const STATES := {
	&"IDLE": &"Idle",
	&"WALK": &"Walk",
	&"JOG": &"Jog_Fwd",
	&"SPRINT": &"Sprint",
	&"WALK_BACK": &"Walk",
	&"ROLL": &"Roll",
	&"ROLL_BACK": &"Roll",
	&"JUMP_START": &"Jump_Start",
	&"JUMP": &"Jump",
	&"LAND": &"Jump_Land",
	&"JAB": &"Punch_Jab",
	&"CROSS": &"Punch_Cross",
	&"HOOK": &"Melee_Hook",
	&"HIT": &"Hit_Knockback",
	&"HIT_CHEST": &"Hit_Chest",
	&"HIT_HEAD": &"Hit_Head",
	&"DEATH": &"Death01",
}

var source: AnimationPlayer
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var current_state: StringName = &""
var _speed_scale := 1.0

func setup(pack1: AnimationPlayer, pack2: AnimationPlayer) -> void:
	source = AnimationPlayer.new()
	source.name = &"AnimationSource"
	source.root_node = NodePath("../..")
	add_child(source)
	var library := AnimationLibrary.new()
	for clip_name in STATES.values():
		var origin := pack1 if pack1.has_animation(clip_name) else pack2
		if origin.has_animation(clip_name) and not library.has_animation(clip_name):
			library.add_animation(clip_name, origin.get_animation(clip_name))
	source.add_animation_library(&"", library)

	var machine := AnimationNodeStateMachine.new()
	for state_name in STATES:
		var animation := AnimationNodeAnimation.new()
		animation.animation = STATES[state_name]
		if state_name in [&"WALK_BACK", &"ROLL_BACK"]:
			animation.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
		machine.add_node(state_name, animation)
	for from_state in STATES:
		for to_state in STATES:
			if from_state == to_state:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = _transition_time(from_state, to_state)
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			transition.reset = true
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED
			machine.add_transition(from_state, to_state, transition)

	tree = AnimationTree.new()
	tree.name = &"AnimationTree"
	tree.tree_root = machine
	add_child(tree)
	tree.anim_player = NodePath("../AnimationSource")
	tree.process_callback = AnimationTree.ANIMATION_PROCESS_MANUAL
	tree.active = false
	call_deferred("_start_initial_state")

func _start_initial_state() -> void:
	tree.active = true
	playback = tree.get(&"parameters/playback")
	current_state = &""
	travel(&"IDLE", true)

func travel(state: StringName, force := false) -> void:
	if playback == null and tree != null:
		playback = tree.get(&"parameters/playback")
	if playback == null or (state == current_state and not force):
		return
	current_state = state
	if force:
		playback.start(state, true)
	else:
		playback.travel(state)

func travel_reverse(state: StringName) -> void:
	travel(state, true)

func set_speed_scale(value: float) -> void:
	_speed_scale = clampf(value, -4.0, 4.0)

func ensure_started() -> void:
	if tree != null and playback != null and playback.get_current_node() == &"":
		playback.start(current_state if current_state != &"" else &"IDLE", true)

func advance(delta: float) -> void:
	if tree != null and tree.active:
		tree.advance(delta * _speed_scale)

func set_paused(paused: bool) -> void:
	if tree != null:
		tree.active = not paused

func has_state(state: StringName) -> bool:
	return STATES.has(state)

func is_playing() -> bool:
	return playback != null and playback.get_current_node() != &""

func animation_position() -> float:
	return playback.get_current_play_position() if playback != null else 0.0

func animation_length() -> float:
	return playback.get_current_length() if playback != null else 0.0

func animation_name() -> StringName:
	return playback.get_current_node() if playback != null else &""

func _transition_time(from_state: StringName, to_state: StringName) -> float:
	if to_state in [&"JAB", &"CROSS", &"HOOK", &"HIT", &"HIT_CHEST", &"HIT_HEAD", &"DEATH", &"ROLL", &"ROLL_BACK"]:
		return 0.01
	if from_state in [&"JAB", &"CROSS", &"HOOK", &"HIT", &"HIT_CHEST", &"HIT_HEAD", &"DEATH", &"ROLL", &"ROLL_BACK"]:
		return 0.04
	if to_state in [&"JUMP_START", &"JUMP", &"LAND"]:
		return 0.05
	return 0.12
