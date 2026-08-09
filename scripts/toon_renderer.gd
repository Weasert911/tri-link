class_name ToonRenderer
extends Node
## Runtime toon rendering layer over the existing arena, applied entirely
## through MeshInstance3D surface overrides so no scene or material on disk
## is ever modified. World meshes get the 3-band world shader, player
## mannequins get stable identity-colored character materials plus expanded
## silhouette meshes, and a comic post treatment sits below the HUD layer.
## Everything is reverted by disable() / revert(), restoring the original
## StandardMaterial3D look.

const WORLD_SHADER := preload("res://shaders/toon_world.gdshader")
const CHARACTER_SHADER := preload("res://shaders/toon_character.gdshader")
const OUTLINE_SHADER := preload("res://shaders/toon_outline.gdshader")
const POST_SHADER := preload("res://shaders/toon_post.gdshader")
const FINISH_SHADER := preload("res://shaders/toon_finish.gdshader")

## RGB palette matching player_controller._color_materials, indexed by
## PlayerColor so the emission color always matches the gameplay color.
const COLOR_PALETTE := [
	Color(1.0, 0.16, 0.16),
	Color(0.18, 1.0, 0.2),
	Color(0.22, 0.42, 1.0),
]

## Node whose subtree contains every world and player mesh. Set from the
## scene; defaults to the Arena instance in match_scene.tscn.
@export var arena_root: NodePath = ^"../Arena"
@export var outline_enabled := true
@export_range(0.0, 0.05) var outline_width: float = 0.004
@export var post_enabled := false
@export var finish_enabled := true

var _applied := false
var _world_cache: Dictionary = {}
var _mesh_states: Array[Dictionary] = []
var _player_materials: Dictionary = {}
var _player_connections: Dictionary = {}
var _outline_meshes: Array[MeshInstance3D] = []
var _post_layer: CanvasLayer = null
var _finish_layer: CanvasLayer = null

func _ready() -> void:
	if not ProjectSettings.get_setting("toon_rendering/enabled", true):
		return
	apply()

## Applies the full toon treatment. Safe to call repeatedly; no-op once on.
func apply() -> void:
	if _applied:
		return
	var arena := get_node_or_null(arena_root)
	if arena == null:
		return
	for child in arena.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		# ColorIndicator and any other mesh with a runtime material override
		# (the RGB state disc) must keep its unshaded look.
		if mesh.material_override != null:
			continue
		_apply_surfaces(mesh, _is_character_mesh(mesh))
	if post_enabled:
		_build_post_layer()
	if finish_enabled:
		_build_finish_layer()
	_applied = true

## Reverts every surface override and removes the post layer, restoring the
## arena's original materials. Safe to call repeatedly; no-op when off.
func revert() -> void:
	if not _applied:
		return
	for state in _mesh_states:
		var mesh: MeshInstance3D = state["mesh"]
		var originals: Array = state["originals"]
		for i in originals.size():
			mesh.set_surface_override_material(i, originals[i])
	_mesh_states.clear()
	for player in _player_connections:
		var callback := _on_player_color_changed.bind(player)
		if is_instance_valid(player) and player.color_changed.is_connected(callback):
			player.color_changed.disconnect(callback)
	_player_materials.clear()
	_player_connections.clear()
	_world_cache.clear()
	for outline in _outline_meshes:
		if is_instance_valid(outline):
			outline.queue_free()
	_outline_meshes.clear()
	if _post_layer != null:
		_post_layer.queue_free()
		_post_layer = null
	if _finish_layer != null:
		_finish_layer.queue_free()
		_finish_layer = null
	_applied = false

func set_enabled(enabled: bool) -> void:
	if enabled:
		apply()
	else:
		revert()

func _on_player_color_changed(color_index: int, player: CharacterBody3D) -> void:
	if not _applied or not _player_materials.has(player):
		return
	var color: Color = COLOR_PALETTE[color_index]
	for mat in _player_materials[player]:
		mat.set_shader_parameter(&"player_color", color)

func _apply_surfaces(mesh: MeshInstance3D, is_character: bool) -> void:
	var count := mesh.mesh.get_surface_count()
	var originals: Array = []
	for i in count:
		var orig: Material = mesh.get_surface_override_material(i)
		if orig == null:
			orig = mesh.mesh.surface_get_material(i)
		originals.append(orig)
		if not is_character:
			mesh.set_surface_override_material(i, _build_world_material(orig))
			continue
		var player := _find_player(mesh)
		if player == null:
			continue
		mesh.set_surface_override_material(i, _build_character_material(orig, player, i))
	if outline_enabled:
		_add_outline(mesh)
	_mesh_states.append({"mesh": mesh, "originals": originals})

func _build_world_material(orig: Material) -> ShaderMaterial:
	var albedo := Color.WHITE
	var texture: Texture2D = null
	if orig is StandardMaterial3D:
		var std := orig as StandardMaterial3D
		albedo = std.albedo_color
		texture = std.albedo_texture
	var key := albedo.to_html() + "|" + (texture.resource_path if texture != null else "")
	if _world_cache.has(key):
		return _world_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = WORLD_SHADER
	mat.set_shader_parameter(&"albedo", albedo)
	if texture != null:
		mat.set_shader_parameter(&"albedo_texture", texture)
	_world_cache[key] = mat
	return mat

func _build_character_material(orig: Material, player: CharacterBody3D, surface: int) -> ShaderMaterial:
	var albedo := Color.WHITE
	var texture: Texture2D = null
	if orig is StandardMaterial3D:
		var std := orig as StandardMaterial3D
		albedo = std.albedo_color
		texture = std.albedo_texture
	var mat := ShaderMaterial.new()
	mat.shader = CHARACTER_SHADER
	mat.set_shader_parameter(&"albedo", albedo)
	mat.set_shader_parameter(&"player_color", COLOR_PALETTE[player.current_color])
	mat.set_shader_parameter(&"identity_accent_strength", 0.62 if surface == 1 else 0.08)
	mat.set_shader_parameter(&"rgb_emission_strength", 0.48 if surface == 1 else 0.04)
	if texture != null:
		mat.set_shader_parameter(&"albedo_texture", texture)
	var mats: Array = _player_materials.get(player, [])
	mats.append(mat)
	_player_materials[player] = mats
	if not _player_connections.has(player):
		var callback := _on_player_color_changed.bind(player)
		if not player.color_changed.is_connected(callback):
			player.color_changed.connect(callback)
		_player_connections[player] = true
	return mat

func _add_outline(mesh: MeshInstance3D) -> void:
	var outline := MeshInstance3D.new()
	outline.name = &"ToonOutline"
	outline.transform = mesh.transform
	outline.mesh = mesh.mesh
	outline.skin = mesh.skin
	outline.skeleton = mesh.skeleton
	outline.layers = mesh.layers
	outline.material_override = ShaderMaterial.new()
	outline.material_override.shader = OUTLINE_SHADER
	outline.material_override.set_shader_parameter(&"outline_width", outline_width)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.get_parent().add_child(outline)
	_outline_meshes.append(outline)

## True when the mesh belongs to a player: any ancestor up to the arena root
## is a CharacterBody3D (players are instanced inside the arena scene).
func _is_character_mesh(mesh: MeshInstance3D) -> bool:
	return _find_player(mesh) != null

func _find_player(mesh: MeshInstance3D) -> CharacterBody3D:
	var node: Node = mesh.get_parent()
	while node != null and node != get_node_or_null(arena_root):
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _build_post_layer() -> void:
	_post_layer = CanvasLayer.new()
	_post_layer.name = &"ToonPost"
	# Layer 0 keeps the post treatment below the HUD (MatchController adds
	# its HUD CanvasLayer at the default layer 1), so UI stays crisp.
	_post_layer.layer = 0
	add_child(_post_layer)
	var rect := ColorRect.new()
	rect.name = &"PostRect"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = POST_SHADER
	rect.material = mat
	_post_layer.add_child(rect)

func _build_finish_layer() -> void:
	_finish_layer = CanvasLayer.new()
	_finish_layer.name = &"ToonFinish"
	_finish_layer.layer = 0
	add_child(_finish_layer)
	var rect := ColorRect.new()
	rect.name = &"FinishRect"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = FINISH_SHADER
	mat.set_shader_parameter(&"brightness", 1.08)
	mat.set_shader_parameter(&"saturation", 1.12)
	mat.set_shader_parameter(&"contrast", 1.06)
	mat.set_shader_parameter(&"posterize_steps", 6)
	mat.set_shader_parameter(&"glow_strength", 0.18)
	mat.set_shader_parameter(&"glow_threshold", 0.68)
	rect.material = mat
	_finish_layer.add_child(rect)
