extends SceneTree

const MATCH_SCENE := preload("res://scenes/match_scene.tscn")

var _checks := 0
var _failures := 0
var _frames := 0
var _finished := false

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 3000 and not _finished:
		print("WATCHDOG: game feel test hung")
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

func _initialize() -> void:
	var scene := MATCH_SCENE.instantiate()
	root.add_child(scene)
	await _settle(4)
	var feedback: CombatFeedback = scene.get_node("CombatFeedback")
	var match_controller: MatchController = scene.get_node("MatchController")
	var p1: PlayerController = scene.get_node("Arena/Player")
	var p2: PlayerController = scene.get_node("Arena/Player2")

	_check("screen flash layer exists", feedback.get_node_or_null("CombatScreenEffects/ImpactFlash") != null)
	feedback._flash(0.5, 0.01, 0.04, Color.WHITE)
	_check("screen flash activates", feedback.is_flash_active())
	await _settle(8)
	_check("screen flash cleans up", not feedback.is_flash_active())

	feedback._slow_motion(0.4, 0.04)
	_check("slow motion is separate and active", feedback.is_slow_motion_active())
	await create_timer(0.08, true, false, true).timeout
	_check("slow motion restores global time", not feedback.is_slow_motion_active())

	feedback._spawn_shower(Vector3.ZERO, Vector3.UP, Color.WHITE, 1.0, 8)
	_check("impact shower uses bounded pool", feedback._shards.size() == CombatFeedback.SHARD_POOL_SIZE)
	await _settle(24)
	var visible_shards := 0
	for shard in feedback._shards:
		if shard.visible:
			visible_shards += 1
	_check("impact shower cleans pooled shards", visible_shards == 0)
	feedback._show_style("CRITICAL!", p2.global_position, Color.WHITE)
	_check("style overlay pool creates cleanly", feedback._style_labels.size() == CombatFeedback.STYLE_LABEL_COUNT and feedback._style_labels[0].visible)

	feedback._on_hit_confirmed(p1, p2, p2.global_position, false)
	feedback.reset_presentation()
	_check("presentation reset restores camera", feedback.camera_is_at_rest())
	_check("presentation reset restores time and flash", not feedback.is_slow_motion_active() and not feedback.is_flash_active())

	_check("arcade HUD has both health bars", match_controller.get_node_or_null("HUD/P1HealthBar") != null and match_controller.get_node_or_null("HUD/P2HealthBar") != null)
	_check("arcade HUD has round pips", match_controller.get_node_or_null("HUD/P1Pips") != null and match_controller.get_node_or_null("HUD/P2Pips") != null)

	_finished = true
	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
