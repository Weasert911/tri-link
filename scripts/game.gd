class_name Game
extends Node

enum State { MENU, PLAY, PAUSED, MATCH_OVER }

const MENU_SHADER := preload("res://shaders/menu_treatment.gdshader")
const CYAN := Color("52d6e8")
const ORANGE := Color("ff9d42")
const PANEL_COLOR := Color(0.025, 0.035, 0.055, 0.9)

var state := State.MENU
var match_root: Node3D
var match_controller: MatchController
var showcase: ShowcaseController
var _menu_layer: CanvasLayer
var _pause_layer: CanvasLayer
var _settings_layer: CanvasLayer
var _match_over_layer: CanvasLayer
var _controller_label: Label
var _match_over_label: Label
var _countdown_label: Label
var _countdown := 0.0
var _settings_return_state := State.MENU
var _capture_player := 0
var _capture_action: StringName = &""
var _capture_button: Button
var _conflict_label: Label
var _controls_box: VBoxContainer
var _ui_hidden := false
var _settings_was_visible := false
var _settings: Node
var _input_manager: Node
var _device_manager: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings = get_node("/root/SettingsManager")
	_input_manager = get_node("/root/InputManager")
	_device_manager = get_node("/root/DeviceManager")
	match_root = $Match
	match_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	match_controller = $Match/MatchController
	showcase = $ShowcaseController
	showcase.process_mode = Node.PROCESS_MODE_PAUSABLE
	while match_controller.p1 == null or match_controller.p2 == null:
		await get_tree().process_frame
	showcase.setup(match_root)
	match_controller.match_won.connect(_on_match_won)
	_device_manager.devices_changed.connect(_update_controller_status)
	_input_manager.binding_changed.connect(_refresh_control_buttons)
	_device_manager.devices_changed.connect(_refresh_device_options)
	_build_menu()
	_build_pause_menu()
	_build_settings()
	_build_match_over()
	_apply_video_settings()
	_settings.settings_changed.connect(_on_setting_changed)
	_enter_menu()

func _unhandled_input(event: InputEvent) -> void:
	if _capture_player > 0:
		_capture_binding(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_settings_was_visible = _settings_layer.visible if not _ui_hidden else _settings_was_visible
			_ui_hidden = not _ui_hidden
			_set_all_ui_visible(not _ui_hidden)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F2 and state == State.MENU:
			_menu_layer.visible = not _menu_layer.visible
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"ui_cancel"):
		match state:
			State.PLAY:
				_pause_game()
			State.PAUSED:
				_resume_game()
			State.MENU:
				if _settings_layer.visible:
					_close_settings()

func _process(delta: float) -> void:
	if state == State.MATCH_OVER:
		_countdown = maxf(_countdown - delta, 0.0)
		_countdown_label.text = "RETURNING TO MENU IN %d" % ceili(_countdown)
		if _countdown <= 0.0:
			_enter_menu()

func _enter_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	state = State.MENU
	_menu_layer.show()
	_pause_layer.hide()
	_settings_layer.hide()
	_match_over_layer.hide()
	match_controller.showcase_mode = true
	match_controller.set_hud_visible(false)
	showcase.set_enabled(true)
	if match_controller.state() == MatchController.MatchState.MATCH_OVER:
		match_controller.restart_match()

func _start_play() -> void:
	state = State.PLAY
	_menu_layer.hide()
	_settings_layer.hide()
	_match_over_layer.hide()
	showcase.set_enabled(false)
	match_controller.showcase_mode = false
	match_controller.set_hud_visible(true)
	match_controller.restart_match()

func _pause_game() -> void:
	if state != State.PLAY:
		return
	state = State.PAUSED
	Engine.time_scale = 1.0
	get_tree().paused = true
	_pause_layer.show()

func _resume_game() -> void:
	get_tree().paused = false
	state = State.PLAY
	_pause_layer.hide()

func _restart_round() -> void:
	get_tree().paused = false
	state = State.PLAY
	_pause_layer.hide()
	match_controller.restart_round()

func _restart_match() -> void:
	get_tree().paused = false
	state = State.PLAY
	_pause_layer.hide()
	match_controller.restart_match()

func _on_match_won(winner: PlayerController) -> void:
	if state == State.MENU:
		return
	state = State.MATCH_OVER
	showcase.set_enabled(false)
	_match_over_label.text = "P%d WINS!" % winner.player_index
	_countdown = 12.0
	_match_over_layer.show()

func _build_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = &"MenuUI"
	_menu_layer.layer = 100
	add_child(_menu_layer)
	var treatment := ColorRect.new()
	treatment.material = ShaderMaterial.new()
	(treatment.material as ShaderMaterial).shader = MENU_SHADER
	treatment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	treatment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(treatment)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_bottom", 40)
	_menu_layer.add_child(margin)
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(root)
	var title := Label.new()
	title.text = "TRILINK"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", CYAN)
	root.add_child(title)
	var rule := HSeparator.new()
	rule.custom_minimum_size = Vector2(360, 24)
	root.add_child(rule)
	root.add_child(_menu_button("PLAY", _start_play))
	root.add_child(_menu_button("SETTINGS", _open_settings.bind(State.MENU)))
	root.add_child(_menu_button("QUIT", get_tree().quit))
	_controller_label = Label.new()
	_controller_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_controller_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_controller_label.position = Vector2(-360, -52)
	_controller_label.size = Vector2(330, 28)
	_controller_label.add_theme_color_override("font_color", CYAN)
	_menu_layer.add_child(_controller_label)
	_update_controller_status()

func _build_pause_menu() -> void:
	_pause_layer = _overlay_layer(&"PauseUI", 110)
	var box := _center_panel(_pause_layer, Vector2(430, 500))
	box.add_child(_heading("PAUSED"))
	box.add_child(_menu_button("RESUME", _resume_game))
	box.add_child(_menu_button("RESTART ROUND", _restart_round))
	box.add_child(_menu_button("RESTART MATCH", _restart_match))
	box.add_child(_menu_button("SETTINGS", _open_settings.bind(State.PAUSED)))
	box.add_child(_menu_button("MAIN MENU", _enter_menu))
	_pause_layer.hide()

func _build_match_over() -> void:
	_match_over_layer = _overlay_layer(&"MatchOverUI", 115)
	var box := _center_panel(_match_over_layer, Vector2(500, 330))
	_match_over_label = _heading("P1 WINS!")
	box.add_child(_match_over_label)
	box.add_child(_menu_button("REMATCH", _start_play))
	box.add_child(_menu_button("MAIN MENU", _enter_menu))
	_countdown_label = Label.new()
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	box.add_child(_countdown_label)
	_match_over_layer.hide()

func _build_settings() -> void:
	_settings_layer = _overlay_layer(&"SettingsUI", 120)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-440, -310)
	panel.size = Vector2(880, 620)
	panel.add_theme_stylebox_override("panel", _panel_style())
	_settings_layer.add_child(panel)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	layout.add_child(_heading("SETTINGS"))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	_build_gameplay_tab(tabs)
	_build_video_tab(tabs)
	_build_audio_tab(tabs)
	_build_controls_tab(tabs)
	layout.add_child(_menu_button("BACK", _close_settings))
	_settings_layer.hide()

func _build_gameplay_tab(tabs: TabContainer) -> void:
	var box := _tab_box(tabs, "Gameplay")
	for item in [["Screen shake", &"screen_shake"], ["Hit-stop", &"hit_stop"], ["Combat VFX", &"combat_vfx"], ["Combo counter", &"combo_counter"], ["Damage numbers", &"damage_numbers"], ["Color effects", &"color_effects"], ["Screen flash", &"screen_flash"], ["Slow motion", &"slow_motion"]]:
		var toggle := CheckButton.new()
		toggle.text = item[0]
		toggle.button_pressed = _settings.get_bool(&"gameplay", item[1], true)
		var setting_key: StringName = item[1]
		toggle.toggled.connect(func(value: bool, key: StringName = setting_key): _settings.set_value(&"gameplay", key, value))
		box.add_child(toggle)

func _build_video_tab(tabs: TabContainer) -> void:
	var box := _tab_box(tabs, "Video")
	box.add_child(_option_row("Quality", ["Low", "Medium", "High"], _settings.get_int(&"video", &"quality_preset", 1), func(index: int): _settings.set_value(&"video", &"quality_preset", index)))
	box.add_child(_option_row("Resolution", ["1280 x 720", "1600 x 900", "1920 x 1080"], _resolution_index(), _set_resolution))
	box.add_child(_option_row("Window mode", ["Windowed", "Fullscreen", "Borderless"], _settings.get_int(&"video", &"window_mode", 0), func(index: int): _settings.set_value(&"video", &"window_mode", index)))
	var vsync := CheckButton.new()
	vsync.text = "VSync"
	vsync.button_pressed = _settings.get_bool(&"video", &"vsync", true)
	vsync.toggled.connect(func(value: bool): _settings.set_value(&"video", &"vsync", value))
	box.add_child(vsync)
	var fps := HSlider.new()
	fps.min_value = 30
	fps.max_value = 240
	fps.step = 30
	fps.value = _settings.get_int(&"video", &"fps_cap", 120)
	fps.value_changed.connect(func(value: float): _settings.set_value(&"video", &"fps_cap", int(value)))
	box.add_child(_labeled_control("FPS cap", fps))

func _build_audio_tab(tabs: TabContainer) -> void:
	var box := _tab_box(tabs, "Audio")
	for bus in [&"master", &"music", &"sfx", &"ui"]:
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = _settings.get_float(&"audio", bus, 1.0)
		var bus_key: StringName = bus
		slider.value_changed.connect(func(value: float, key: StringName = bus_key): _settings.set_value(&"audio", key, value))
		box.add_child(_labeled_control(String(bus).capitalize(), slider))

func _build_controls_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Controls"
	tabs.add_child(scroll)
	_controls_box = VBoxContainer.new()
	_controls_box.name = &"BindingRows"
	_controls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_controls_box)
	_conflict_label = Label.new()
	_conflict_label.add_theme_color_override("font_color", ORANGE)
	_controls_box.add_child(_conflict_label)
	for player in [1, 2]:
		var title := Label.new()
		title.name = "P%dDeviceLabel" % player
		title.text = "PLAYER %d  |  %s" % [player, _device_name(_device_manager.device_for_player(player))]
		title.add_theme_color_override("font_color", CYAN)
		_controls_box.add_child(title)
		var devices := OptionButton.new()
		devices.name = "P%dDevice" % player
		devices.item_selected.connect(_select_device.bind(player, devices))
		_controls_box.add_child(devices)
		for action_id in _input_manager.ACTION_IDS:
			var button := Button.new()
			button.name = "P%d_%s" % [player, action_id]
			button.text = "%s     %s" % [String(action_id).replace("_", " ").capitalize(), _input_manager.binding_text(player, action_id)]
			button.pressed.connect(_begin_capture.bind(player, action_id, button))
			_controls_box.add_child(button)
		_controls_box.add_child(_menu_button("RESET PLAYER %d" % player, _input_manager.reset_player.bind(player)))
	_refresh_device_options()

func _refresh_device_options() -> void:
	if _controls_box == null:
		return
	for player in [1, 2]:
		var option := _controls_box.get_node_or_null("P%dDevice" % player) as OptionButton
		var label := _controls_box.get_node_or_null("P%dDeviceLabel" % player) as Label
		if option == null:
			continue
		option.clear()
		option.add_item("Keyboard fallback")
		option.set_item_metadata(0, -1)
		for device in _device_manager.connected_devices():
			option.add_item(Input.get_joy_name(device))
			option.set_item_metadata(option.item_count - 1, device)
		var assigned: int = _device_manager.device_for_player(player)
		for index in option.item_count:
			if int(option.get_item_metadata(index)) == assigned:
				option.select(index)
				break
		if label != null:
			label.text = "PLAYER %d  |  %s" % [player, _device_name(assigned)]

func _select_device(index: int, player: int, option: OptionButton) -> void:
	_device_manager.assign_device(player, int(option.get_item_metadata(index)))

func _begin_capture(player: int, action_id: StringName, button: Button) -> void:
	_capture_player = player
	_capture_action = action_id
	_capture_button = button
	button.text = "PRESS A KEY OR CONTROLLER BUTTON..."
	_conflict_label.text = ""

func _capture_binding(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_finish_capture()
		return
	if event is not InputEventKey and event is not InputEventJoypadButton:
		return
	var conflict: StringName = _input_manager.find_conflict(_capture_player, _capture_action, event)
	if conflict != &"":
		_conflict_label.text = "CONFLICT: already bound to %s" % String(conflict).capitalize()
		_finish_capture()
		return
	if event is InputEventKey:
		_input_manager.rebind_key(_capture_player, _capture_action, event.physical_keycode)
	else:
		_input_manager.rebind_joy_button(_capture_player, _capture_action, event.button_index)
	_finish_capture()

func _finish_capture() -> void:
	_capture_player = 0
	_capture_action = &""
	_capture_button = null
	_refresh_control_buttons()

func _refresh_control_buttons(_player := 0, _action := &"") -> void:
	if _settings_layer == null:
		return
	for player in [1, 2]:
		for action_id in _input_manager.ACTION_IDS:
			var button := _controls_box.get_node_or_null("P%d_%s" % [player, action_id]) as Button
			if button != null:
				button.text = "%s     %s" % [String(action_id).replace("_", " ").capitalize(), _input_manager.binding_text(player, action_id)]

func _open_settings(return_state: State) -> void:
	_settings_return_state = return_state
	_settings_was_visible = true
	_menu_layer.hide()
	_pause_layer.hide()
	_settings_layer.show()
	_refresh_control_buttons()

func _close_settings() -> void:
	_settings_layer.hide()
	_settings_was_visible = false
	if _settings_return_state == State.PAUSED:
		_pause_layer.show()
	else:
		_menu_layer.show()

func _on_setting_changed(section: StringName, _key: StringName, _value: Variant) -> void:
	if section == &"video":
		_apply_video_settings()

func _apply_video_settings() -> void:
	var resolution: Vector2i = _settings.get_value(&"video", &"resolution", Vector2i(1280, 720))
	var mode: int = _settings.get_int(&"video", &"window_mode", 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if mode == 1 else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, mode == 2)
	if mode != 1:
		DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _settings.get_bool(&"video", &"vsync", true) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = _settings.get_int(&"video", &"fps_cap", 120)
	var scales := [0.67, 0.85, 1.0]
	var quality := clampi(_settings.get_int(&"video", &"quality_preset", 1), 0, 2)
	get_viewport().scaling_3d_scale = scales[quality]
	for node in get_tree().get_nodes_in_group(&"quality_lights"):
		if node is Light3D:
			node.shadow_enabled = quality > 0
	for node in match_root.find_children("*", "Light3D", true, false):
		(node as Light3D).shadow_enabled = quality > 0
	for node in match_root.find_children("*", "WorldEnvironment", true, false):
		var world := node as WorldEnvironment
		if world.environment != null:
			world.environment.glow_enabled = quality > 0

func _set_resolution(index: int) -> void:
	_settings.set_value(&"video", &"resolution", [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)][index])

func _resolution_index() -> int:
	var current: Vector2i = _settings.get_value(&"video", &"resolution", Vector2i(1280, 720))
	return maxi([Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)].find(current), 0)

func _update_controller_status() -> void:
	if _controller_label != null:
		_controller_label.text = "●  " + _device_manager.status_text()

func _set_all_ui_visible(value: bool) -> void:
	_menu_layer.visible = value and state == State.MENU and not _settings_was_visible
	_pause_layer.visible = value and state == State.PAUSED and not _settings_was_visible
	_settings_layer.visible = value and _settings_was_visible
	_match_over_layer.visible = value and state == State.MATCH_OVER
	match_controller.set_hud_visible(value and state == State.PLAY)

func _menu_button(text: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 52)
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(callable)
	return button

func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", CYAN)
	return label

func _overlay_layer(layer_name: StringName, layer_index: int) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.layer = layer_index
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	return layer

func _center_panel(layer: CanvasLayer, size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = &"CenterPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -size * 0.5
	panel.size = size
	panel.add_theme_stylebox_override("panel", _panel_style())
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	return box

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = Color(CYAN, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	return style

func _tab_box(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = tab_name
	box.add_theme_constant_override("separation", 8)
	tabs.add_child(box)
	return box

func _option_row(label_text: String, options: Array, selected: int, changed: Callable) -> HBoxContainer:
	var option := OptionButton.new()
	for text in options:
		option.add_item(text)
	option.selected = selected
	option.item_selected.connect(changed)
	return _labeled_control(label_text, option)

func _labeled_control(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 180
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _device_name(device: int) -> String:
	return "Keyboard" if device < 0 else Input.get_joy_name(device)
