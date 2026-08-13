class_name MatchController
extends Node
## Best-of-three match loop: WAITING -> ROUND_START -> FIGHTING -> ROUND_OVER
## -> ROUND_RESET -> FIGHTING -> ... -> MATCH_OVER.
##
## The match controller owns rounds, winners and the reset between rounds.
## Players only report "I died" (via the died signal); they have no knowledge
## of rounds or matches. This separation is what keeps the same controller
## portable to LAN play later.

enum MatchState {
	WAITING,
	ROUND_START,
	FIGHTING,
	ROUND_OVER,
	ROUND_RESET,
	MATCH_OVER,
}

## Rounds a player must win to take the match (best of N, default best of 3).
@export var rounds_to_win: int = 2
## Seconds spent in WAITING before the first round starts.
@export var wait_duration: float = 0.8
## Seconds the ROUND_START banner ("FIGHT!") stays on screen.
@export var round_start_duration: float = 1.2
## Seconds the ROUND_OVER result banner stays on screen.
@export var round_over_duration: float = 1.8
@export var showcase_mode := false
@export var showcase_restart_delay := 2.5

## Emitted whenever the match state changes.
signal state_changed(state: MatchState)
## Emitted when a round ends with a winner.
signal round_won(winner: PlayerController)
## Emitted when the match is won.
signal match_won(winner: PlayerController)

var p1: PlayerController
var p2: PlayerController
var _p1_bar: ProgressBar
var _p2_bar: ProgressBar
var _p1_pips: Label
var _p2_pips: Label

var _state: MatchState = MatchState.WAITING
var _p1_rounds: int = 0
var _p2_rounds: int = 0
var _round_number: int = 1
var _last_round_winner: PlayerController = null
var _label: Label = null
var _flow_revision := 0

func _ready() -> void:
	await _find_players()
	if p1 == null or p2 == null:
		push_error("MatchController: could not find both players")
		return
	p1.died.connect(_on_player_died.bind(p1))
	p2.died.connect(_on_player_died.bind(p2))
	_build_hud()
	_update_hud()
	_set_state(MatchState.WAITING)
	_update_hud()
	p1.lock_controls()
	p2.lock_controls()
	var revision := _flow_revision
	await get_tree().create_timer(wait_duration, false).timeout
	if _state == MatchState.WAITING and revision == _flow_revision:
		_start_round()

## Players add themselves to the "players" group in _ready; find them by
## player_index once they are all inside the tree.
func _find_players() -> void:
	for _i in 20:
		for node in get_tree().get_nodes_in_group(&"players"):
			if node is PlayerController:
				if node.player_index == 1:
					p1 = node
				elif node.player_index == 2:
					p2 = node
		if p1 != null and p2 != null:
			return
		await get_tree().process_frame

func _set_state(new_state: MatchState) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(_state)
	_update_hud()

func _start_round() -> void:
	_set_state(MatchState.ROUND_START)
	var revision := _flow_revision
	await get_tree().create_timer(round_start_duration, false).timeout
	if _state != MatchState.ROUND_START or revision != _flow_revision:
		return
	p1.unlock_controls()
	p2.unlock_controls()
	_set_state(MatchState.FIGHTING)

## The loser is reported by the died signal; the other player wins the round.
## If both players die in the same instant, the round is a draw.
func _on_player_died(_loser: PlayerController) -> void:
	if _state != MatchState.FIGHTING:
		return
	var revision := _flow_revision
	# One physics frame lets a simultaneous KO register as a draw.
	await get_tree().physics_frame
	if revision != _flow_revision or _state != MatchState.FIGHTING:
		return
	p1.lock_controls()
	p2.lock_controls()
	_last_round_winner = null
	if p1.alive and not p2.alive:
		_last_round_winner = p1
	elif p2.alive and not p1.alive:
		_last_round_winner = p2
	if _last_round_winner != null:
		if _last_round_winner == p1:
			_p1_rounds += 1
		else:
			_p2_rounds += 1
		round_won.emit(_last_round_winner)
	_set_state(MatchState.ROUND_OVER)
	await get_tree().create_timer(round_over_duration, false).timeout
	if _state != MatchState.ROUND_OVER or revision != _flow_revision:
		return
	if _p1_rounds >= rounds_to_win or _p2_rounds >= rounds_to_win:
		var winner: PlayerController = p1 if _p1_rounds > _p2_rounds else p2
		_set_state(MatchState.MATCH_OVER)
		match_won.emit(winner)
		if showcase_mode:
			await get_tree().create_timer(showcase_restart_delay, false).timeout
			if _state == MatchState.MATCH_OVER and revision == _flow_revision:
				restart_match()
	else:
		_reset_round()

## Restores both players in place (no scene reload) and starts the next round.
func _reset_round() -> void:
	_set_state(MatchState.ROUND_RESET)
	var feedback := get_parent().get_node_or_null("CombatFeedback") as CombatFeedback
	if feedback != null:
		feedback.reset_presentation()
	p1.reset_round()
	p2.reset_round()
	_round_number += 1
	_start_round()

func restart_round() -> void:
	if p1 == null or p2 == null:
		return
	_flow_revision += 1
	_last_round_winner = null
	_reset_round()

func restart_match() -> void:
	if p1 == null or p2 == null:
		return
	_flow_revision += 1
	_p1_rounds = 0
	_p2_rounds = 0
	_round_number = 0
	_last_round_winner = null
	_reset_round()

func set_hud_visible(visible: bool) -> void:
	var hud := get_node_or_null("HUD")
	if hud != null:
		hud.visible = visible

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	_label = Label.new()
	_label.name = "MatchLabel"
	_label.add_theme_font_size_override("font_size", 40)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 24
	_label.offset_bottom = 112
	layer.add_child(_label)

	_p1_bar = _make_health_bar(&"P1HealthBar", true)
	_p1_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_p1_bar.position = Vector2(16, 8)
	layer.add_child(_p1_bar)
	_p1_pips = _make_pips(&"P1Pips", true)
	_p1_pips.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_p1_pips.position = Vector2(16, 22)
	layer.add_child(_p1_pips)

	_p2_bar = _make_health_bar(&"P2HealthBar", false)
	_p2_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_p2_bar.position = Vector2(-316, 8)
	_p2_bar.size = Vector2(300, 14)
	layer.add_child(_p2_bar)
	_p2_pips = _make_pips(&"P2Pips", false)
	_p2_pips.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_p2_pips.position = Vector2(-316, 22)
	_p2_pips.size = Vector2(300, 24)
	_p2_pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_p2_pips)

func _make_health_bar(bar_name: StringName, is_p1: bool) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = bar_name
	bar.min_value = 0.0
	bar.max_value = float(PlayerController.MAX_HEALTH)
	bar.value = float(PlayerController.MAX_HEALTH)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(300, 14)
	bar.size = Vector2(300, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.26, 0.26) if is_p1 else Color(0.26, 0.8, 1.0)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	bar.add_theme_stylebox_override("background", bg)
	return bar

func _make_pips(pip_name: StringName, is_p1: bool) -> Label:
	var pips := Label.new()
	pips.name = pip_name
	pips.add_theme_font_size_override("font_size", 16)
	pips.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if is_p1 else Color(0.6, 0.9, 1.0))
	return pips

func _process(_delta: float) -> void:
	if p1 == null or p2 == null:
		return
	if _p1_bar != null:
		_p1_bar.value = float(p1.health)
		_p2_bar.value = float(p2.health)
	if _p1_pips != null:
		var max_rounds := rounds_to_win - 1
		_p1_pips.text = "●".repeat(clampi(_p1_rounds, 0, max_rounds)) + "○".repeat(maxi(max_rounds - _p1_rounds, 0))
		_p2_pips.text = "●".repeat(clampi(_p2_rounds, 0, max_rounds)) + "○".repeat(maxi(max_rounds - _p2_rounds, 0))

func _update_hud() -> void:
	if _label == null:
		return
	var text := ""
	match _state:
		MatchState.WAITING:
			text = "READY"
		MatchState.ROUND_START:
			text = "ROUND %d\nFIGHT!" % _round_number
		MatchState.FIGHTING:
			text = "ROUND %d" % _round_number
		MatchState.ROUND_OVER:
			if _last_round_winner == null:
				text = "DRAW"
			else:
				text = "P%d WINS ROUND\nROUND %d" % [_last_round_winner.player_index, _round_number]
		MatchState.ROUND_RESET:
			text = "ROUND %d" % (_round_number + 1)
		MatchState.MATCH_OVER:
			var winner: PlayerController = p1 if _p1_rounds > _p2_rounds else p2
			text = "P%d WINS MATCH" % winner.player_index
	_label.text = "P1  %d    P2  %d\n%s" % [_p1_rounds, _p2_rounds, text]

## Test/debug accessors.
func state() -> MatchState:
	return _state

func p1_rounds() -> int:
	return _p1_rounds

func p2_rounds() -> int:
	return _p2_rounds

func round_number() -> int:
	return _round_number

func hud_text() -> String:
	return _label.text if _label != null else ""
