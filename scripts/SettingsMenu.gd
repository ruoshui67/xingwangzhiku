extends Control

@export var panel_path: NodePath
@export var open_button_path: NodePath
@export var close_button_path: NodePath
@export var pause_overlay_path: NodePath
@export var volume_slider_path: NodePath
@export var volume_value_label_path: NodePath
@export var resolution_option_path: NodePath
@export var display_mode_option_path: NodePath
@export var apply_button_path: NodePath
@export var confirm_dialog_path: NodePath

var _panel: Control
var _open_button: Button
var _close_button: Button
var _volume_slider: HSlider
var _volume_value_label: Label
var _resolution_option: OptionButton
var _display_mode_option: OptionButton
var _apply_button: Button
var _confirm_dialog: ConfirmationDialog
var _pause_overlay: CanvasItem
var _resolutions: Array[Vector2i] = []
var _dirty: bool = false
var _snapshot_volume: float = 1.0
var _snapshot_resolution: Vector2i = Vector2i(0, 0)
var _snapshot_display_mode: int = DisplayServer.WINDOW_MODE_WINDOWED

# ---- 按键绑定子面板 ----
var _bind_panel: Control
var _bind_dirty: bool = false
var _bind_actions: Array[Dictionary] = [
	{name="move_forward", label="前进"},
	{name="move_back", label="后退"},
	{name="move_left", label="左移"},
	{name="move_right", label="右移"},
	{name="interact", label="交互"},
	{name="inventory", label="背包"},
	{name="skill_panel", label="技能"},
	{name="journal", label="日志"},
	{name="pause", label="暂停"},
]
var _bind_buttons: Array[Button] = []
var _bind_listening_action: String = ""
var _snapshot_bindings: Dictionary = {}
var _bind_save_btn: Button

const BTN_HEIGHT := 36
const BTN_WIDTH := 240


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = get_node_or_null(panel_path) as Control
	_open_button = get_node_or_null(open_button_path) as Button
	_close_button = get_node_or_null(close_button_path) as Button
	_volume_slider = get_node_or_null(volume_slider_path) as HSlider
	_volume_value_label = get_node_or_null(volume_value_label_path) as Label
	_resolution_option = get_node_or_null(resolution_option_path) as OptionButton
	_display_mode_option = get_node_or_null(display_mode_option_path) as OptionButton
	_apply_button = get_node_or_null(apply_button_path) as Button
	_confirm_dialog = get_node_or_null(confirm_dialog_path) as ConfirmationDialog
	_pause_overlay = get_node_or_null(pause_overlay_path) as CanvasItem

	if _panel:
		_panel.visible = false

	if _open_button:
		_open_button.pressed.connect(_on_open_pressed)
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)
	if _volume_slider:
		_volume_slider.value_changed.connect(_on_volume_changed)
	if _resolution_option:
		_resolution_option.item_selected.connect(_on_resolution_selected)
	if _display_mode_option:
		_display_mode_option.item_selected.connect(_on_display_mode_selected)
	if _apply_button:
		_apply_button.pressed.connect(_on_apply_pressed)
	if _confirm_dialog:
		_confirm_dialog.confirmed.connect(_on_confirm_apply)
		_confirm_dialog.custom_action.connect(_on_confirm_discard)
		_confirm_dialog.add_button("不保存", true, "discard")

	_build_bind_panel()
	_build_bind_entry_btn()

	_sync_volume()
	_sync_resolution()
	_sync_display_mode()


func _build_bind_entry_btn() -> void:
	if not _panel:
		return
	var btn := Button.new()
	btn.name = "KeyBindBtn"
	btn.text = "按键绑定"
	btn.custom_minimum_size = Vector2(200, 40)
	btn.layout_mode = 0
	btn.offset_left = 20
	btn.offset_top = 204
	btn.offset_right = 500
	btn.offset_bottom = 240
	_panel.add_child(btn)
	btn.pressed.connect(_on_keybind_entry)


func _on_keybind_entry() -> void:
	if _panel:
		_panel.visible = false
	_bind_panel.visible = true


# ========================================================================
# 按键绑定子面板
# ========================================================================
func _build_bind_panel() -> void:
	_bind_panel = Control.new()
	_bind_panel.name = "BindPanel"
	_bind_panel.visible = false
	_bind_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_panel.add_theme_stylebox_override("panel", _make_bg_style())
	add_child(_bind_panel)

	var title := Label.new()
	title.text = "按键绑定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-120, 30)
	title.size = Vector2(240, 36)
	_bind_panel.add_child(title)

	var list := VBoxContainer.new()
	list.name = "BindList"
	list.set_anchors_preset(Control.PRESET_CENTER_TOP)
	list.position = Vector2(-BTN_WIDTH / 2, 80)
	list.size = Vector2(BTN_WIDTH, _bind_actions.size() * (BTN_HEIGHT + 6))
	list.add_theme_constant_override("separation", 6)
	_bind_panel.add_child(list)

	for act in _bind_actions:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(BTN_WIDTH, BTN_HEIGHT)
		btn.text = act["label"] + ": " + _get_action_key_name(act["name"])
		btn.pressed.connect(_on_bind_btn_pressed.bind(act["name"]))
		list.add_child(btn)
		_bind_buttons.append(btn)

	# 保存按钮
	_bind_save_btn = Button.new()
	_bind_save_btn.text = "保存"
	_bind_save_btn.custom_minimum_size = Vector2(120, BTN_HEIGHT)
	_bind_save_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bind_save_btn.position = Vector2(-60, -50)
	_bind_panel.add_child(_bind_save_btn)
	_bind_save_btn.pressed.connect(_on_bind_save)

	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(120, BTN_HEIGHT)
	back_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back_btn.position = Vector2(-60, -90)
	_bind_panel.add_child(back_btn)
	back_btn.pressed.connect(_on_bind_back)

	# 首次快照
	for act in _bind_actions:
		_snapshot_bindings[act["name"]] = _copy_action_events(act["name"])

func _make_bg_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	s.set_corner_radius_all(8)
	return s


func _on_bind_btn_pressed(action_name: String) -> void:
	_bind_listening_action = action_name
	for i in range(_bind_actions.size()):
		if _bind_actions[i]["name"] == action_name:
			_bind_buttons[i].text = _bind_actions[i]["label"] + "：按下按键…"


func _on_bind_save() -> void:
	_bind_dirty = false
	for act in _bind_actions:
		_snapshot_bindings[act["name"]] = _copy_action_events(act["name"])
	print("[Settings] 按键绑定已保存")


func _on_bind_back() -> void:
	if _bind_dirty:
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = "按键绑定尚未保存，是否保存？"
		dlg.confirmed.connect(_on_bind_save)
		dlg.confirmed.connect(func(): _show_settings())
		dlg.canceled.connect(func(): _revert_bindings(); _show_settings())
		dlg.add_button("不保存", true, "discard")
		dlg.custom_action.connect(func(action: String):
			if action == "discard": _revert_bindings(); _show_settings(); dlg.queue_free()
		)
		dlg.close_requested.connect(func(): _show_settings(); dlg.queue_free())
		add_child(dlg)
		dlg.popup_centered()
		return
	_show_settings()


func _show_settings() -> void:
	_bind_panel.visible = false
	if _panel:
		_panel.visible = true


func _refresh_bind_labels() -> void:
	for i in range(_bind_actions.size()):
		var act := _bind_actions[i]
		_bind_buttons[i].text = act["label"] + ": " + _get_action_key_name(act["name"])


func _get_action_key_name(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "未绑定"
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for ev in events:
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).keycode)
	return "未绑定"


func _bind_key(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for ev in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, ev)
	var kev := InputEventKey.new()
	kev.keycode = keycode
	kev.physical_keycode = keycode
	kev.pressed = true
	InputMap.action_add_event(action_name, kev)
	_bind_dirty = true


func _copy_action_events(action_name: String) -> Array[InputEvent]:
	if not InputMap.has_action(action_name):
		return []
	var result: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action_name):
		result.append(ev.duplicate())
	return result


func _revert_bindings() -> void:
	for action_name in _snapshot_bindings.keys():
		if InputMap.has_action(action_name):
			for ev in InputMap.action_get_events(action_name):
				InputMap.action_erase_event(action_name, ev)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for ev: InputEvent in _snapshot_bindings[action_name]:
			InputMap.action_add_event(action_name, ev)
	_bind_dirty = false
	_refresh_bind_labels()


# ========================================================================
# 主设置面板
# ========================================================================
func _input(event: InputEvent) -> void:
	# 绑定面板打开时：拦截所有输入，阻止角色移动
	if _bind_panel and _bind_panel.visible:
		if _bind_listening_action != "" and event is InputEventKey and event.pressed:
			var kev := event as InputEventKey
			if kev.keycode == KEY_ESCAPE:
				_bind_listening_action = ""
				_refresh_bind_labels()
			else:
				_bind_key(_bind_listening_action, kev.keycode)
				_bind_listening_action = ""
				_refresh_bind_labels()
		elif event.is_action_pressed("pause"):
			_on_bind_back()  # ESC 关闭绑定面板，不打开暂停
		get_viewport().set_input_as_handled()
		return

	if _panel and _panel.visible and event.is_action_pressed("pause"):
		_request_close()
		get_viewport().set_input_as_handled()


func _on_open_pressed() -> void:
	if _panel:
		_panel.visible = true
	if _pause_overlay:
		_pause_overlay.visible = false
	_sync_volume()
	_sync_resolution()
	_sync_display_mode()
	_snapshot_settings()
	_set_dirty(false)


func _on_close_pressed() -> void:
	_request_close()


func _on_volume_changed(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	_update_volume_label(value)
	_set_dirty(true)


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= _resolutions.size():
		return
	var size: Vector2i = _resolutions[index]
	DisplayServer.window_set_size(size)
	_set_dirty(true)


func _on_display_mode_selected(index: int) -> void:
	if index == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	elif index == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_set_dirty(true)


func _request_close() -> void:
	if _dirty and _confirm_dialog:
		_confirm_dialog.popup_centered()
		return
	_close_panel()


func _close_panel() -> void:
	if _panel:
		_panel.visible = false
	if _pause_overlay and get_tree().paused:
		_pause_overlay.visible = true


func _on_apply_pressed() -> void:
	_snapshot_settings()
	_set_dirty(false)


func _on_confirm_apply() -> void:
	_snapshot_settings()
	_set_dirty(false)
	_close_panel()


func _on_confirm_discard(action: String) -> void:
	if action != "discard":
		return
	_revert_to_snapshot()
	_set_dirty(false)
	_close_panel()


func _snapshot_settings() -> void:
	_snapshot_volume = _get_current_volume()
	_snapshot_resolution = DisplayServer.window_get_size()
	_snapshot_display_mode = DisplayServer.window_get_mode()


func _revert_to_snapshot() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(_snapshot_volume))
	DisplayServer.window_set_mode(_snapshot_display_mode)
	DisplayServer.window_set_size(_snapshot_resolution)
	_sync_volume()
	_sync_resolution()
	_sync_display_mode()


func _sync_volume() -> void:
	if not _volume_slider:
		return
	var bus_index: int = AudioServer.get_bus_index("Master")
	var db_value: float = AudioServer.get_bus_volume_db(bus_index)
	_volume_slider.value = db_to_linear(db_value)
	_update_volume_label(db_to_linear(db_value))


func _sync_resolution() -> void:
	if not _resolution_option:
		return
	_resolution_option.clear()
	_resolutions.clear()
	var candidates: Array[Vector2i] = [
		Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)
	]
	var current: Vector2i = DisplayServer.window_get_size()
	_add_resolution(current)
	for size in candidates:
		_add_resolution(size)
	var selected := 0
	for i in range(_resolutions.size()):
		if _resolutions[i] == current:
			selected = i; break
	_resolution_option.select(selected)


func _sync_display_mode() -> void:
	if not _display_mode_option:
		return
	_display_mode_option.clear()
	_display_mode_option.add_item("窗口化")
	_display_mode_option.add_item("全屏")
	var mode := DisplayServer.window_get_mode()
	_display_mode_option.select(1 if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else 0)


func _get_current_volume() -> float:
	var bus_index: int = AudioServer.get_bus_index("Master")
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index))


func _set_dirty(value: bool) -> void:
	_dirty = value
	if _apply_button:
		_apply_button.disabled = not _dirty


func _add_resolution(size: Vector2i) -> void:
	if _has_resolution(size):
		return
	_resolutions.append(size)
	_resolution_option.add_item(str(size.x) + "x" + str(size.y))


func _has_resolution(size: Vector2i) -> bool:
	for item in _resolutions:
		if item == size:
			return true
	return false


func _update_volume_label(value: float) -> void:
	if _volume_value_label:
		_volume_value_label.text = str(int(round(value * 100.0))) + "%"
