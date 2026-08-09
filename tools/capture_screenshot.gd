extends SceneTree

## Dev tool: launches the match scene, waits for the fight, sets P2 to BLUE
## (so both RGB states are visible), applies the toon rendering, captures a
## screenshot, then also verifies revert/restore before quitting.
## Run WITHOUT --headless so a real rendering device exists:
##   Godot_v4.7-beta1_win64_console.exe --path . --script tools/capture_screenshot.gd

const MATCH_SCENE := preload("res://scenes/match_scene.tscn")
const OUTPUT_PATH := "res://tools/toon_preview.png"

var _frames := 0
var _match: MatchController
var _p2: PlayerController
var _toon: ToonRenderer

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1800:
		print("WATCHDOG: screenshot tool hung")
		quit(2)
	return false

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: Node3D = MATCH_SCENE.instantiate()
	root.add_child(scene)
	for _i in 5:
		await process_frame
	_match = scene.get_node("MatchController")
	_toon = scene.get_node("ToonRenderer")
	_p2 = _match.p2
	var finish_material: ShaderMaterial = _toon.get_node("ToonFinish/FinishRect").material
	print("FINISH POSTERIZE STEPS: ", finish_material.get_shader_parameter(&"posterize_steps"))
	print("FINISH GLOW STRENGTH: ", finish_material.get_shader_parameter(&"glow_strength"))

	for _i in 300:
		if _match.state() == MatchController.MatchState.FIGHTING:
			break
		await physics_frame

	_p2.current_color = PlayerController.PlayerColor.BLUE
	_p2._apply_color()
	_p2.color_changed.emit(_p2.current_color)

	for _i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	print("SCREENSHOT SAVED: ", ProjectSettings.globalize_path(OUTPUT_PATH))
	print("RGB BLUE UNIFORM: ", _toon._player_materials[_p2][0].get_shader_parameter(&"player_color"))

	_p2.current_color = PlayerController.PlayerColor.GREEN
	_p2._apply_color()
	_p2.color_changed.emit(_p2.current_color)
	for _i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/toon_green_preview.png")
	print("RGB GREEN UNIFORM: ", _toon._player_materials[_p2][0].get_shader_parameter(&"player_color"))

	_p2.current_color = PlayerController.PlayerColor.RED
	_p2._apply_color()
	_p2.color_changed.emit(_p2.current_color)
	for _i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/toon_red_preview.png")
	print("RGB RED UNIFORM: ", _toon._player_materials[_p2][0].get_shader_parameter(&"player_color"))

	_p2.current_color = PlayerController.PlayerColor.BLUE
	_p2._apply_color()
	_p2.color_changed.emit(_p2.current_color)
	for _i in 5:
		await process_frame

	_toon.revert()
	for _i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var reverted := root.get_texture().get_image()
	reverted.save_png("res://tools/toon_reverted_preview.png")
	print("REVERTED SAVED: ", ProjectSettings.globalize_path("res://tools/toon_reverted_preview.png"))

	_toon.apply()
	for _i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var reapplied := root.get_texture().get_image()
	reapplied.save_png("res://tools/toon_reapplied_preview.png")
	print("REAPPLIED SAVED: ", ProjectSettings.globalize_path("res://tools/toon_reapplied_preview.png"))

	quit(0)
