extends SceneTree

const MATCH_SCENE := preload("res://scenes/match_scene.tscn")
const RED := PlayerController.PlayerColor.RED

var _frames := 0
var _finished := false
var _checks := 0
var _failures := 0
var _match: MatchController
var _p1: PlayerController
var _p2: PlayerController
var _p1_spawn_z: float
var _p2_spawn_z: float

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 3000 and not _finished:
		print("WATCHDOG: match test hung")
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

func _wait_for_state(target: MatchController.MatchState, label: String) -> void:
	for _i in 300:
		if _match.state() == target:
			_check(label, true)
			return
		await physics_frame
	_check(label, false)

func _initialize() -> void:
	var scene: Node3D = MATCH_SCENE.instantiate()
	root.add_child(scene)
	for _i in 3:
		await process_frame
	_match = scene.get_node("MatchController")
	_check("match controller found players", _match.p1 != null and _match.p2 != null)
	_p1 = _match.p1
	_p2 = _match.p2

	# Fast timers so the whole best-of-3 runs quickly in the test.
	_match.wait_duration = 0.05
	_match.round_start_duration = 0.05
	_match.round_over_duration = 0.05

	await _wait_for_state(MatchController.MatchState.WAITING, "match starts in WAITING")
	_p1_spawn_z = _p1.global_position.z
	_p2_spawn_z = _p2.global_position.z
	_check("players locked in WAITING", not _p1.can_move and not _p2.can_attack)

	await _wait_for_state(MatchController.MatchState.FIGHTING, "round 1 starts FIGHTING")
	_check("players unlocked in FIGHTING", _p1.can_move and _p2.can_attack and _p2.can_change_color)
	_check("round 1 shows in HUD", _match.hud_text().contains("ROUND 1"))
	_check("round 1 starts at full health", _p1.health == 100 and _p2.health == 100)

	# Player 2 dies -> Player 1 wins round 1, both freeze, then round 2 resets.
	var p2_id := _p2.get_instance_id()
	_p2.take_hit(_p1, 100, 0.0)
	await _wait_for_state(MatchController.MatchState.ROUND_OVER, "death triggers ROUND_OVER")
	_check("round 1 winner is P1", _match.p1_rounds() == 1 and _match.p2_rounds() == 0)
	_check("round 1 loser is dead", not _p2.alive and _p2.health == 0)
	_check("both players frozen in ROUND_OVER", not _p1.can_move and not _p1.can_attack and not _p2.can_move)
	_check("round result in HUD", _match.hud_text().contains("P1 WINS ROUND"))

	await _wait_for_state(MatchController.MatchState.FIGHTING, "round 2 starts FIGHTING")
	_check("reset restores health and life", _p2.alive and _p2.health == 100)
	_check("reset restores RGB state", _p1.current_color == RED and _p2.current_color == RED)
	_check("reset restores controls", _p2.can_move and _p2.can_attack and _p2.can_change_color)
	_check("reset returns players to spawn", absf(_p1.global_position.z - _p1_spawn_z) < 0.01 and absf(_p2.global_position.z - _p2_spawn_z) < 0.01)
	_check("reset reuses the same player nodes", _p2.get_instance_id() == p2_id)
	_check("score survives the reset", _match.p1_rounds() == 1 and _match.p2_rounds() == 0)
	_check("round 2 shows in HUD", _match.hud_text().contains("ROUND 2"))

	# Player 1 dies -> Player 2 wins round 2, match is not over yet (1-1).
	_p1.take_hit(_p2, 100, 0.0)
	await _wait_for_state(MatchController.MatchState.ROUND_OVER, "round 2 death triggers ROUND_OVER")
	_check("round 2 winner is P2", _match.p2_rounds() == 1)
	await _wait_for_state(MatchController.MatchState.FIGHTING, "round 3 starts FIGHTING")
	_check("round 3 shows in HUD", _match.hud_text().contains("ROUND 3"))

	# Player 1 dies again -> P2 takes the match at 2-1.
	_p1.take_hit(_p2, 100, 0.0)
	await _wait_for_state(MatchController.MatchState.ROUND_OVER, "round 3 death triggers ROUND_OVER")
	await _wait_for_state(MatchController.MatchState.MATCH_OVER, "best of 3 ends the match")
	_check("final score is 1-2", _match.p1_rounds() == 1 and _match.p2_rounds() == 2)
	_check("match winner is P2", _match.hud_text().contains("P2 WINS MATCH"))
	_check("match over freezes both players", not _p1.can_move and not _p2.can_attack and not _p2.can_change_color)

	_finished = true
	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
