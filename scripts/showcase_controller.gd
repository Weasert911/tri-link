class_name ShowcaseController
extends Node

@export var enabled := true
@export var decision_interval := 0.22

var p1: PlayerController
var p2: PlayerController
var match_controller: MatchController
var _decision_time := 0.0
var _beat := 0

func setup(match_root: Node) -> void:
	process_physics_priority = -10
	match_controller = match_root.get_node("MatchController") as MatchController
	p1 = match_controller.p1
	p2 = match_controller.p2

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		if p1 != null:
			p1.clear_ai_input()
		if p2 != null:
			p2.clear_ai_input()

func _physics_process(delta: float) -> void:
	if not enabled or p1 == null or p2 == null or match_controller.state() != MatchController.MatchState.FIGHTING:
		return
	_decision_time -= delta
	if _decision_time > 0.0:
		return
	_decision_time = decision_interval
	_beat += 1
	_drive(p1, p2, true)
	_drive(p2, p1, false)

func _drive(actor: PlayerController, target: PlayerController, aggressive: bool) -> void:
	var distance := absf(target.global_position.z - actor.global_position.z)
	var toward := signf(target.global_position.z - actor.global_position.z)
	var state := {&"move_axis": toward if distance > 0.48 else 0.0}
	var cadence := 3 if aggressive else 5
	if distance < 0.72 and _beat % cadence == 0:
		state[&"light"] = true
	if distance < 0.68 and _beat % (cadence * 3) == 0:
		state[&"heavy"] = true
	if not aggressive and distance < 0.52 and _beat % 7 == 0:
		state[&"roll"] = true
		state[&"move_axis"] = -toward
	if _beat % (11 if aggressive else 8) == 0:
		state[[&"red", &"green", &"blue"][_beat % 3]] = true
	actor.set_ai_input(state)

func restart_if_complete() -> bool:
	if match_controller != null and match_controller.state() == MatchController.MatchState.MATCH_OVER:
		match_controller.restart_match()
		return true
	return false
