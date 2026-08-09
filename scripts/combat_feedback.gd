class_name CombatFeedback
extends Node

@export var camera_path: NodePath = ^"../Arena/Camera3D"
@export_range(0.0, 0.2) var light_hit_stop: float = 0.06
@export_range(0.0, 0.2) var heavy_hit_stop: float = 0.09
@export_range(0.0, 0.2) var light_shake: float = 0.018
@export_range(0.0, 0.2) var heavy_shake: float = 0.035
@export_range(0.0, 0.2) var critical_hit_stop: float = 0.14

var _camera: Camera3D
var _camera_origin := Transform3D.IDENTITY
var _camera_fov := 75.0
var _shake_time := 0.0
var _shake_strength := 0.0
var _rng := RandomNumberGenerator.new()
var _combo_counts: Dictionary = {}
var _combo_labels: Dictionary = {}
var _combo_timers: Dictionary = {}
var _critical_sequence := 0
var _zoom_time := 0.0
var _zoom_amount := 0.0

func _ready() -> void:
	_rng.randomize()
	_camera = get_node_or_null(camera_path)
	if _camera != null:
		_camera_origin = _camera.transform
		_camera_fov = _camera.fov
	for player in get_tree().get_nodes_in_group(&"players"):
		_connect_player(player)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if _camera != null:
		_camera.fov = _camera_fov
		_camera.transform = _camera_origin

func _connect_player(player: Node) -> void:
	if player is PlayerController and not player.hit_confirmed.is_connected(_on_hit_confirmed):
		player.hit_confirmed.connect(_on_hit_confirmed)
		player.wall_hit.connect(_on_wall_hit)
		player.spike_ko.connect(_on_spike_ko)
		player.phase_missed.connect(_on_phase_missed)
		player.color_changed.connect(_on_color_changed.bind(player))
		player.critical_hit.connect(_on_critical_hit)
		player.attack_active.connect(_on_attack_active)

func _process(delta: float) -> void:
	for victim in _combo_timers.keys():
		_combo_timers[victim] = maxf(float(_combo_timers[victim]) - delta, 0.0)
		if _combo_timers[victim] <= 0.0:
			_combo_counts.erase(victim)
			_combo_timers.erase(victim)
			var label: Label3D = _combo_labels.get(victim)
			if label != null and is_instance_valid(label):
				label.visible = false
	if _camera == null:
		return
	if _zoom_time > 0.0:
		_zoom_time = maxf(_zoom_time - delta, 0.0)
		_camera.fov = _camera_fov - _zoom_amount * (_zoom_time / 0.14)
	else:
		_camera.fov = _camera_fov
	if _shake_time > 0.0:
		_shake_time = maxf(_shake_time - delta, 0.0)
		var falloff := _shake_time / 0.12
		_camera.transform = _camera_origin
		_camera.position += Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * _shake_strength * falloff
	else:
		_camera.transform = _camera_origin

func _on_hit_confirmed(attacker: PlayerController, victim: PlayerController, position: Vector3, heavy: bool) -> void:
	var duration := heavy_hit_stop if heavy else light_hit_stop

	attacker.apply_hit_stop(duration)
	victim.apply_hit_stop(duration)
	_shake_strength = heavy_shake if heavy else light_shake
	_shake_time = 0.12
	_spawn_impact(position, heavy)
	_combo_counts[victim] = int(_combo_counts.get(victim, 0)) + 1
	_combo_timers[victim] = 0.9
	_show_combo(victim, _combo_counts[victim])

func _spawn_impact(position: Vector3, heavy: bool) -> void:
	var ring := MeshInstance3D.new()
	ring.name = &"HitImpact"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.035 if heavy else 0.025
	torus.outer_radius = 0.16 if heavy else 0.11
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.68, 0.18)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 4.0
	ring.material_override = material
	get_parent().add_child(ring)
	ring.global_position = position + Vector3.UP * 0.08
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * (2.0 if heavy else 1.5), 0.12)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.12)
	tween.chain().tween_callback(ring.queue_free)

func _on_wall_hit(position: Vector3, heavy: bool) -> void:
	_shake_strength = 0.055 if heavy else 0.04
	_shake_time = 0.16
	_spawn_impact(position, true)

func _on_spike_ko(position: Vector3) -> void:
	_shake_strength = 0.075
	_shake_time = 0.22
	_spawn_impact(position, true)

func _on_phase_missed(_attacker: PlayerController, _target: PlayerController, position: Vector3) -> void:
	_spawn_phase_effect(position)

func _on_critical_hit(attacker: PlayerController, victim: PlayerController, position: Vector3, _heavy: bool) -> void:
	attacker.apply_hit_stop(critical_hit_stop)
	victim.apply_hit_stop(critical_hit_stop)
	_shake_strength = 0.06
	_shake_time = 0.16
	_zoom_amount = 2.4
	_zoom_time = 0.14
	_spawn_impact(position, true)
	_show_combo(victim, int(_combo_counts.get(victim, 1)))
	_start_critical_slowdown()

func _on_attack_active(_attacker: PlayerController, position: Vector3, heavy: bool, critical: bool) -> void:
	var color := Color(1.0, 0.8, 0.25) if critical else Color(0.55, 0.82, 1.0)
	_spawn_trail(position, color, heavy)

func _show_combo(victim: PlayerController, count: int) -> void:
	var label: Label3D = _combo_labels.get(victim)
	if label == null or not is_instance_valid(label):
		label = Label3D.new()
		label.name = &"ComboCounter"
		label.font_size = 42
		label.modulate = Color(1.0, 0.84, 0.3)
		get_parent().add_child(label)
		_combo_labels[victim] = label
	label.global_position = victim.global_position + Vector3(0.0, 2.2, 0.0)
	label.text = "%d HIT\nCOMBO" % count
	label.visible = count > 1

func _spawn_trail(position: Vector3, color: Color, heavy: bool) -> void:
	var trail := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.08 if heavy else 0.045, 0.36 if heavy else 0.22)
	trail.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.5
	trail.material_override = material
	get_parent().add_child(trail)
	trail.global_position = position
	var tween := create_tween().set_parallel()
	tween.tween_property(trail, "scale", Vector3(1.0, 1.0, 1.8), 0.1)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.1)
	tween.chain().tween_callback(trail.queue_free)

func _start_critical_slowdown() -> void:
	_critical_sequence += 1
	var sequence := _critical_sequence
	Engine.time_scale = 0.35
	_restore_time_scale(sequence)

func _restore_time_scale(sequence: int) -> void:
	await get_tree().create_timer(0.1, true, false, true).timeout
	if sequence == _critical_sequence:
		Engine.time_scale = 1.0

func _on_color_changed(_color: PlayerController.PlayerColor, player: PlayerController) -> void:
	_spawn_switch_effect(player.global_position + Vector3.UP * 0.9, player.current_color)

func _spawn_phase_effect(position: Vector3) -> void:
	_spawn_colored_ring(position, Color(0.4, 0.8, 1.0), 0.08, 1.25)

func _spawn_switch_effect(position: Vector3, color_index: PlayerController.PlayerColor) -> void:
	var colors := [Color(1.0, 0.16, 0.16), Color(0.18, 1.0, 0.2), Color(0.22, 0.42, 1.0)]
	_spawn_colored_ring(position, colors[color_index], 0.12, 1.6)

func _spawn_colored_ring(position: Vector3, color: Color, duration: float, scale_target: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.02
	torus.outer_radius = 0.09
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	ring.material_override = material
	get_parent().add_child(ring)
	ring.global_position = position
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * scale_target, duration)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)
