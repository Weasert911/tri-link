class_name CombatFeedback
extends Node

enum ImpactTier { LIGHT, HEAVY, CRITICAL, WALL, SPIKE }

@export var camera_path: NodePath = ^"../Arena/Camera3D"
@export_range(0.0, 0.2) var light_hit_stop: float = 0.06
@export_range(0.0, 0.2) var heavy_hit_stop: float = 0.09
@export_range(0.0, 0.2) var light_shake: float = 0.018
@export_range(0.0, 0.2) var heavy_shake: float = 0.035
@export_range(0.0, 0.2) var critical_hit_stop: float = 0.14
@export_range(0.0, 0.2) var wall_hit_stop: float = 0.06
@export_range(0.0, 0.2) var spike_hit_stop: float = 0.1
@export var flash_enabled := true
@export_range(0.0, 1.0) var critical_slow_scale: float = 0.35
@export_range(0.0, 0.5) var critical_slow_duration: float = 0.1
@export_range(0.0, 1.0) var spike_slow_scale: float = 0.4
@export_range(0.0, 0.5) var spike_slow_duration: float = 0.25
@export_range(0.0, 1.0) var wall_slow_scale: float = 0.7
@export_range(0.0, 0.5) var wall_slow_duration: float = 0.08

const SHARD_POOL_SIZE := 24
const STYLE_LABEL_COUNT := 2
const DAMAGE_LABEL_COUNT := 8
const FLASH_SHADER := preload("res://shaders/transitional_flash.gdshader")
const PLAYER_COLORS := [Color(1.0, 0.16, 0.16), Color(0.18, 1.0, 0.2), Color(0.22, 0.42, 1.0)]

var _camera: Camera3D
var _camera_origin := Transform3D.IDENTITY
var _camera_fov := 75.0
var _shake_time := 0.0
var _shake_strength := 0.0
var _shake_axis := Vector3.RIGHT
var _rng := RandomNumberGenerator.new()
var _combo_counts: Dictionary = {}
var _combo_labels: Dictionary = {}
var _combo_timers: Dictionary = {}
var _combo_fade_tweens: Dictionary = {}
var _critical_sequence := 0
var _zoom_time := 0.0
var _zoom_amount := 0.0
var _shards: Array[MeshInstance3D] = []
var _shard_idx := 0
var _flash_layer: CanvasLayer = null
var _flash_rect: ColorRect = null
var _flash_mat: ShaderMaterial = null
var _flash_time := 0.0
var _flash_duration := 0.0
var _flash_peak := 0.0
var _flash_chromatic := 0.0
var _flash_distortion := 0.0
var _flash_ripple := 0.0
var _flash_color := Color.WHITE
var _style_labels: Array[Label3D] = []
var _style_idx := 0
var _style_tweens: Dictionary = {}
var _match_controller: MatchController = null
var _damage_labels: Array[Label3D] = []
var _damage_idx := 0
var _damage_tweens: Dictionary = {}
var _shake_enabled := true
var _hit_stop_enabled := true
var _vfx_enabled := true
var _combo_enabled := true
var _damage_enabled := true
var _slow_motion_enabled := true
var _color_effects_enabled := true

func _ready() -> void:
	_rng.randomize()
	_camera = get_node_or_null(camera_path)
	if _camera != null:
		_camera_origin = _camera.transform
		_camera_fov = _camera.fov
	_build_flash_layer()
	_apply_settings()
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.settings_changed.connect(_on_setting_changed)
	for player in get_tree().get_nodes_in_group(&"players"):
		_connect_player(player)
	var match_node := get_parent().get_node_or_null("MatchController")
	if match_node is MatchController:
		_match_controller = match_node
		_match_controller.match_won.connect(_on_match_won)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if _camera != null:
		_camera.fov = _camera_fov
		_camera.transform = _camera_origin
	if _flash_layer != null:
		_flash_layer.queue_free()
		_flash_layer = null

func _connect_player(player: Node) -> void:
	if player is PlayerController and not player.hit_confirmed.is_connected(_on_hit_confirmed):
		player.hit_confirmed.connect(_on_hit_confirmed)
		player.wall_hit.connect(_on_wall_hit)
		player.spike_ko.connect(_on_spike_ko)
		player.phase_missed.connect(_on_phase_missed)
		player.color_changed.connect(_on_color_changed.bind(player))
		player.critical_hit.connect(_on_critical_hit)
		player.counter_hit.connect(_on_counter_hit)
		player.attack_active.connect(_on_attack_active)
		player.combo_finished.connect(_on_combo_finished.bind(player))
		player.died.connect(_on_player_died.bind(player))

func _build_flash_layer() -> void:
	_flash_layer = CanvasLayer.new()
	_flash_layer.name = &"CombatScreenEffects"
	_flash_layer.layer = 50
	add_child(_flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.name = &"ImpactFlash"
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_flash_rect)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SHADER
	_flash_rect.material = _flash_mat
	_flash_rect.visible = false

func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_update_combo_overlays(real_delta)
	_update_camera(real_delta)
	if _flash_time > 0.0:
		_flash_time = maxf(_flash_time - real_delta, 0.0)
		_update_flash(_flash_time / maxf(_flash_duration, 0.001))
		if _flash_time <= 0.0:
			_clear_flash()

func _update_combo_overlays(delta: float) -> void:
	for victim in _combo_timers.keys():
		if not is_instance_valid(victim):
			_combo_timers.erase(victim)
			_combo_counts.erase(victim)
			continue
		_combo_timers[victim] = maxf(float(_combo_timers[victim]) - delta, 0.0)
		var label: Label3D = _combo_labels.get(victim)
		if label != null and is_instance_valid(label):
			label.global_position = victim.global_position + Vector3(0.0, 2.2, 0.0)
		if _combo_timers[victim] <= 0.0:
			_finish_combo_overlay(victim)

func _update_camera(delta: float) -> void:
	if _camera == null:
		return
	_camera.transform = _camera_origin
	if _zoom_time > 0.0:
		_zoom_time = maxf(_zoom_time - delta, 0.0)
		_camera.fov = _camera_fov - _zoom_amount * smoothstep(0.0, 0.16, _zoom_time)
	else:
		_camera.fov = move_toward(_camera.fov, _camera_fov, 20.0 * delta)
	if _shake_time <= 0.0:
		return
	_shake_time = maxf(_shake_time - delta, 0.0)
	var falloff := smoothstep(0.0, 0.22, _shake_time)
	var tangent := Vector3(_shake_axis.z, _shake_axis.y, _shake_axis.x).normalized()
	var impulse := _shake_axis * _rng.randf_range(-1.0, 1.0) + tangent * _rng.randf_range(-0.55, 0.55)
	_camera.position += impulse * _shake_strength * falloff

func _ensure_pool() -> void:
	if not _shards.is_empty():
		return
	for i in SHARD_POOL_SIZE:
		var shard := MeshInstance3D.new()
		shard.name = &"ImpactShard"
		var box := BoxMesh.new()
		box.size = Vector3(0.035, 0.035, 0.035)
		shard.mesh = box
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		shard.material_override = material
		get_parent().add_child(shard)
		shard.visible = false
		_shards.append(shard)

func _ensure_style_labels() -> void:
	if not _style_labels.is_empty():
		return
	for i in STYLE_LABEL_COUNT:
		var label := Label3D.new()
		label.name = &"StyleLabel"
		label.font_size = 40
		label.modulate = Color.WHITE
		get_parent().add_child(label)
		label.visible = false
		_style_labels.append(label)

func _ensure_damage_labels() -> void:
	if not _damage_labels.is_empty():
		return
	for i in DAMAGE_LABEL_COUNT:
		var label := Label3D.new()
		label.name = &"DamageNumber"
		label.font_size = 36
		label.outline_size = 8
		label.no_depth_test = true
		get_parent().add_child(label)
		label.hide()
		_damage_labels.append(label)

func _show_damage(value: int, position: Vector3, heavy: bool) -> void:
	if not _damage_enabled:
		return
	_ensure_damage_labels()
	var label := _damage_labels[_damage_idx]
	_damage_idx = (_damage_idx + 1) % _damage_labels.size()
	var old: Tween = _damage_tweens.get(label)
	if old != null and is_instance_valid(old):
		old.kill()
	label.text = str(value)
	label.modulate = Color(1.0, 0.62, 0.2) if heavy else Color.WHITE
	label.global_position = position + Vector3(0.0, 1.25, 0.0)
	label.scale = Vector3.ONE * (1.25 if heavy else 1.0)
	label.show()
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "global_position", label.global_position + Vector3(0.0, 0.65, 0.0), 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.2)
	tween.chain().tween_callback(label.hide)
	_damage_tweens[label] = tween

func _spawn_shard(position: Vector3, direction: Vector3, color: Color, speed: float) -> void:
	_ensure_pool()
	var shard := _shards[_shard_idx]
	_shard_idx = (_shard_idx + 1) % _shards.size()
	shard.visible = true
	shard.global_position = position
	shard.scale = Vector3.ONE
	var mat := shard.material_override as StandardMaterial3D
	mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
	mat.emission = color
	var offset := Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.3, 0.7), _rng.randf_range(-0.35, 0.35)).normalized()
	var dir := (direction + offset * 0.7).normalized()
	var travel: float = speed * _rng.randf_range(0.55, 1.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(shard, "global_position", shard.global_position + dir * travel, 0.22)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tween.tween_property(shard, "scale", Vector3.ONE * 0.35, 0.22)
	tween.chain().tween_callback(shard.hide)

func _spawn_shower(position: Vector3, direction: Vector3, color: Color, speed: float, count: int) -> void:
	_ensure_pool()
	for i in range(count):
		var shard := _shards[_shard_idx]
		_shard_idx = (_shard_idx + 1) % _shards.size()
		shard.visible = true
		shard.global_position = position
		shard.scale = Vector3.ONE
		var mat := shard.material_override as StandardMaterial3D
		mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
		mat.emission = color
		var offset := Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.3, 0.7), _rng.randf_range(-0.35, 0.35)).normalized()
		var dir := (direction + offset * 0.7).normalized()
		var travel: float = speed * _rng.randf_range(0.55, 1.0)
		var tween := create_tween().set_parallel()
		tween.tween_property(shard, "global_position", shard.global_position + dir * travel, 0.22)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.22)
		tween.tween_property(shard, "scale", Vector3.ONE * 0.35, 0.22)
		tween.chain().tween_callback(shard.hide)

func _spawn_impact(position: Vector3, tier: ImpactTier) -> void:
	var heavy := tier in [ImpactTier.HEAVY, ImpactTier.CRITICAL, ImpactTier.WALL, ImpactTier.SPIKE]
	var ring := MeshInstance3D.new()
	ring.name = &"HitImpact"
	var torus := TorusMesh.new()
	match tier:
		ImpactTier.LIGHT:
			torus.inner_radius = 0.025
			torus.outer_radius = 0.11
		ImpactTier.HEAVY:
			torus.inner_radius = 0.035
			torus.outer_radius = 0.16
		ImpactTier.CRITICAL:
			torus.inner_radius = 0.05
			torus.outer_radius = 0.22
		ImpactTier.WALL:
			torus.inner_radius = 0.03
			torus.outer_radius = 0.15
		ImpactTier.SPIKE:
			torus.inner_radius = 0.045
			torus.outer_radius = 0.20
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	var color := Color.WHITE
	match tier:
		ImpactTier.LIGHT:
			color = Color(1.0, 0.68, 0.18)
		ImpactTier.HEAVY:
			color = Color(1.0, 0.45, 0.15)
		ImpactTier.CRITICAL:
			color = Color(1.0, 0.9, 0.4)
		ImpactTier.WALL:
			color = Color(0.55, 0.85, 1.0)
		ImpactTier.SPIKE:
			color = Color(1.0, 0.2, 0.25)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0
	ring.material_override = material
	get_parent().add_child(ring)
	ring.global_position = position + Vector3.UP * 0.08
	var target_scale := Vector3.ONE * (2.0 if heavy else 1.5)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(ring, "scale", target_scale, 0.12)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.12)
	tween.chain().tween_callback(ring.queue_free)

func _spawn_switch_effect(position: Vector3, color_index: PlayerController.PlayerColor) -> void:
	_spawn_colored_ring(position, PLAYER_COLORS[color_index], 0.12, 1.6)

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
	var material_emission_energy_multiplier := 3.0
	material.emission_energy_multiplier = material_emission_energy_multiplier
	ring.material_override = material
	get_parent().add_child(ring)
	ring.global_position = position
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * scale_target, duration)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)

func _spawn_trail(position: Vector3, color: Color, heavy: bool, scale: float, facing: float) -> void:
	var trail := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var size_y := (0.08 if heavy else 0.045) * scale
	var size_z := (0.36 if heavy else 0.22) * scale
	mesh.size = Vector3(0.025, size_y, size_z)
	trail.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	var emission_energy_multiplier := 3.5
	if heavy:
		emission_energy_multiplier = 4.5
	material.emission_energy_multiplier = emission_energy_multiplier
	trail.material_override = material
	get_parent().add_child(trail)
	trail.global_position = position
	trail.rotation_degrees.x = 18.0 if heavy else 0.0
	trail.rotation_degrees.y = 12.0 * facing if heavy else 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(trail, "scale", Vector3(1.0, 1.8, 1.0), 0.1)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.1)
	tween.chain().tween_callback(trail.queue_free)

func _show_combo(victim: PlayerController, count: int) -> void:
	var label: Label3D = _combo_labels.get(victim)
	if label == null or not is_instance_valid(label):
		label = Label3D.new()
		label.name = &"ComboCounter"
		label.font_size = 42
		label.modulate = Color(1.0, 0.84, 0.3)
		get_parent().add_child(label)
		_combo_labels[victim] = label
	var fade_tween: Tween = _combo_fade_tweens.get(victim)
	if fade_tween != null and is_instance_valid(fade_tween):
		fade_tween.kill()
	label.modulate = Color(1.0, 0.84, 0.3, 1.0)
	label.global_position = victim.global_position + Vector3(0.0, 2.2, 0.0)
	label.text = "%d HIT" % count
	label.visible = count > 1
	if count > 1:
		label.scale = Vector3.ONE * 1.3
		var bounce := create_tween()
		bounce.tween_property(label, "scale", Vector3.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_combo_fade_tweens[victim] = bounce

func _show_style(text: String, position: Vector3, color: Color, peak_scale := 1.6) -> void:
	_ensure_style_labels()
	var label := _style_labels[_style_idx]
	_style_idx = (_style_idx + 1) % _style_labels.size()
	var existing_tween: Tween = _style_tweens.get(label)
	if existing_tween != null and is_instance_valid(existing_tween):
		existing_tween.kill()
	label.show()
	label.text = text
	label.modulate = color
	label.global_position = position + Vector3(0.0, 1.9, 0.0)
	label.scale = Vector3.ONE * 0.3
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * peak_scale, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.35)
	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(label.hide)
	_style_tweens[label] = tween

func _slow_motion(scale: float, duration: float) -> void:
	if not _slow_motion_enabled:
		return
	_critical_sequence += 1
	var sequence := _critical_sequence
	Engine.time_scale = scale
	_restore_time_scale(sequence, duration)

func reset_presentation() -> void:
	_critical_sequence += 1
	Engine.time_scale = 1.0
	_shake_time = 0.0
	_shake_strength = 0.0
	_zoom_time = 0.0
	_zoom_amount = 0.0
	_clear_flash()
	if _camera != null:
		_camera.transform = _camera_origin
		_camera.fov = _camera_fov
	for victim in _combo_counts.keys():
		_finish_combo_overlay(victim)

func is_slow_motion_active() -> bool:
	return not is_equal_approx(Engine.time_scale, 1.0)

func is_flash_active() -> bool:
	return _flash_time > 0.0 and _flash_rect != null and _flash_rect.visible

func camera_is_at_rest() -> bool:
	return _camera == null or (_camera.transform.is_equal_approx(_camera_origin) and is_equal_approx(_camera.fov, _camera_fov))

func _restore_time_scale(sequence: int, duration: float) -> void:
	await get_tree().create_timer(duration, false, false, true).timeout
	if sequence == _critical_sequence:
		Engine.time_scale = 1.0

func _flash(peak: float, chromatic: float, duration: float, color: Color, distortion := 0.0, ripple := 0.0) -> void:
	if not flash_enabled or _flash_rect == null:
		return
	_flash_peak = maxf(_flash_peak, peak)
	_flash_chromatic = maxf(_flash_chromatic, chromatic)
	_flash_distortion = maxf(_flash_distortion, distortion)
	_flash_ripple = maxf(_flash_ripple, ripple)
	_flash_duration = maxf(_flash_duration, duration)
	_flash_time = _flash_duration
	_flash_color = color
	_flash_rect.visible = true
	_update_flash(1.0)

func _update_flash(t: float) -> void:
	if _flash_time <= 0.0:
		_flash_rect.visible = false
		return
	var eased := t * t * (3.0 - 2.0 * t)
	_flash_mat.set_shader_parameter(&"intensity", _flash_peak * eased)
	_flash_mat.set_shader_parameter(&"chromatic", _flash_chromatic * eased)
	_flash_mat.set_shader_parameter(&"distortion", _flash_distortion * eased)
	_flash_mat.set_shader_parameter(&"ripple", _flash_ripple * eased)
	_flash_mat.set_shader_parameter(&"flash_color", _flash_color)

func _clear_flash() -> void:
	_flash_time = 0.0
	_flash_duration = 0.0
	_flash_peak = 0.0
	_flash_chromatic = 0.0
	_flash_distortion = 0.0
	_flash_ripple = 0.0
	if _flash_mat != null:
		_flash_mat.set_shader_parameter(&"intensity", 0.0)
		_flash_mat.set_shader_parameter(&"chromatic", 0.0)
		_flash_mat.set_shader_parameter(&"distortion", 0.0)
		_flash_mat.set_shader_parameter(&"ripple", 0.0)
	if _flash_rect != null:
		_flash_rect.visible = false

func _on_hit_confirmed(attacker: PlayerController, victim: PlayerController, position: Vector3, heavy: bool) -> void:
	var duration := heavy_hit_stop if heavy else light_hit_stop
	if _hit_stop_enabled:
		attacker.apply_hit_stop(duration)
		victim.apply_hit_stop(duration)
	_shake_strength = (heavy_shake if heavy else light_shake) if _shake_enabled else 0.0
	_shake_time = 0.12
	_shake_axis = Vector3.RIGHT
	if _vfx_enabled:
		_spawn_impact(position, ImpactTier.HEAVY if heavy else ImpactTier.LIGHT)
	if heavy and _vfx_enabled:
		_spawn_shower(position, Vector3.UP, Color(1.0, 0.7, 0.3), 2.2, 2)
		_flash(0.3, 0.003, 0.07, Color(1.0, 0.85, 0.6))
	_combo_counts[victim] = int(_combo_counts.get(victim, 0)) + 1
	_combo_timers[victim] = 0.9
	if _combo_enabled:
		_show_combo(victim, _combo_counts[victim])
	var attack_id := attacker.current_attack()
	if PlayerController.ATTACKS.has(attack_id):
		var damage := int(PlayerController.ATTACKS[attack_id]["damage"])
		if attacker._attack_critical:
			damage = roundi(damage * float(PlayerController.ATTACKS[attack_id].get("critical_damage_mult", 1.5)))
		_show_damage(damage, position, heavy)

func _apply_settings() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	_shake_enabled = settings.get_bool(&"gameplay", &"screen_shake", true)
	_hit_stop_enabled = settings.get_bool(&"gameplay", &"hit_stop", true)
	_vfx_enabled = settings.get_bool(&"gameplay", &"combat_vfx", true)
	_combo_enabled = settings.get_bool(&"gameplay", &"combo_counter", true)
	_damage_enabled = settings.get_bool(&"gameplay", &"damage_numbers", true)
	_color_effects_enabled = settings.get_bool(&"gameplay", &"color_effects", true)
	flash_enabled = settings.get_bool(&"gameplay", &"screen_flash", true)
	_slow_motion_enabled = settings.get_bool(&"gameplay", &"slow_motion", true)

func _on_setting_changed(section: StringName, _key: StringName, _value: Variant) -> void:
	if section == &"gameplay":
		_apply_settings()

func _on_critical_hit(attacker: PlayerController, victim: PlayerController, position: Vector3, _heavy: bool) -> void:
	attacker.apply_hit_stop(critical_hit_stop)
	victim.apply_hit_stop(critical_hit_stop)
	_shake_strength = 0.07
	_shake_time = 0.18
	_shake_axis = attacker.get_facing_direction()
	_zoom_amount = 2.4
	_zoom_time = 0.16
	_spawn_impact(position, ImpactTier.CRITICAL)
	_spawn_shower(position, attacker.get_facing_direction(), Color(1.0, 0.9, 0.35), 3.3, 12)
	_flash(0.68, 0.012, 0.12, Color(1.0, 0.95, 0.72), 0.025, 0.012)
	_show_style("CRITICAL!", position, Color(1.0, 0.9, 0.35), 1.9)
	_slow_motion(critical_slow_scale, critical_slow_duration)

func _on_counter_hit(_attacker: PlayerController, victim: PlayerController, position: Vector3) -> void:
	_show_style("COUNTER", position, Color(1.0, 0.55, 0.2), 1.5)
	_combo_timers[victim] = maxf(float(_combo_timers.get(victim, 0.0)), 0.9)

func _on_wall_hit(position: Vector3, heavy: bool, victim: PlayerController) -> void:
	_shake_strength = 0.055 if heavy else 0.04
	_shake_time = 0.16
	var axis := signf(position.z - victim.global_position.z)
	_shake_axis = Vector3(0.0, 0.0, 1.0 if axis == 0.0 else axis)
	if is_instance_valid(victim):
		victim.apply_hit_stop(wall_hit_stop)
	_spawn_impact(position, ImpactTier.HEAVY if heavy else ImpactTier.WALL)
	_spawn_shower(position, _shake_axis, Color(0.55, 0.85, 1.0), 2.6, 6 if heavy else 3)
	_flash(0.4, 0.005, 0.08, Color(0.7, 0.85, 1.0), 0.015, 0.008)
	_show_style("WALL HIT", position, Color(0.5, 0.8, 1.0))
	if heavy:
		_slow_motion(wall_slow_scale, wall_slow_duration)

func _on_spike_ko(position: Vector3, victim: PlayerController) -> void:
	_shake_strength = 0.075
	_shake_time = 0.22
	_shake_axis = Vector3.RIGHT
	_spawn_impact(position, ImpactTier.SPIKE)
	_spawn_shower(position, Vector3.UP, Color(1.0, 0.25, 0.3), 3.4, 10)
	_flash(0.7, 0.012, 0.14, Color(1.0, 0.9, 0.9), 0.03, 0.01)
	_show_style("SPIKE KO", position, Color(1.0, 0.3, 0.35))
	if is_instance_valid(victim):
		victim.apply_hit_stop(spike_hit_stop)
	_slow_motion(spike_slow_scale, spike_slow_duration)

func _on_phase_missed(_attacker: PlayerController, _target: PlayerController, position: Vector3) -> void:
	_spawn_colored_ring(position, Color(0.35, 0.82, 1.0), 0.08, 1.25)
	_show_style("PHASE", position, Color(0.4, 0.75, 1.0), 1.25)

func _on_color_changed(_color: PlayerController.PlayerColor, player: PlayerController) -> void:
	if not _color_effects_enabled:
		return
	var position := player.global_position + Vector3.UP * 0.9
	_spawn_switch_effect(position, player.current_color)
	_spawn_shower(position, Vector3.UP, PLAYER_COLORS[player.current_color], 1.6, 4)

func _on_attack_active(attacker: PlayerController, position: Vector3, heavy: bool, critical: bool) -> void:
	var color := Color(1.0, 0.8, 0.25) if critical else Color(0.55, 0.82, 1.0)
	var scale := 1.0
	if attacker.current_attack() != &"":
		scale = float(PlayerController.ATTACKS[attacker.current_attack()].get("trail_scale", 1.0))
	if critical:
		scale += 0.5
	_spawn_trail(position, color, heavy, scale, attacker.facing_sign())

func _on_combo_finished(_player: PlayerController) -> void:
	for victim in _combo_counts.keys():
		_finish_combo_overlay(victim)

func _finish_combo_overlay(victim: PlayerController) -> void:
	_combo_counts.erase(victim)
	_combo_timers.erase(victim)
	var label: Label3D = _combo_labels.get(victim)
	var old_tween: Tween = _combo_fade_tweens.get(victim)
	if old_tween != null and is_instance_valid(old_tween):
		old_tween.kill()
	if label != null and is_instance_valid(label):
		var fade := create_tween()
		fade.tween_property(label, "modulate:a", 0.0, 0.18)
		fade.tween_callback(label.hide)
		_combo_fade_tweens[victim] = fade

func _on_player_died(_player: PlayerController) -> void:
	_shake_strength = 0.055
	_shake_time = 0.18
	_show_style("K.O.", _player.global_position, Color(1.0, 0.9, 0.4))
	_flash(0.45, 0.006, 0.1, Color(1.0, 1.0, 0.95))

func _on_match_won(winner: PlayerController) -> void:
	_shake_strength = 0.07
	_shake_time = 0.22
	_zoom_amount = 1.8
	_zoom_time = 0.16
	_show_style("P%d WINS!" % winner.player_index, winner.global_position, Color(1.0, 0.9, 0.3), 2.0)
	_flash(0.6, 0.009, 0.12, Color(1.0, 0.95, 0.85))
	_slow_motion(0.5, 0.2)
