extends Node

@export var pause_overlay_path: NodePath
@export var settings_panel_path: NodePath
@export var crosshair_path: NodePath
@export var crosshair_circle_path: NodePath
@export var skill_panel_path: NodePath
@export var inventory_panel_path: NodePath
@export var journal_panel_path: NodePath

var _is_paused: bool = false

@onready var _pause_overlay: CanvasItem = get_node_or_null(pause_overlay_path) as CanvasItem
@onready var _settings_panel: CanvasItem = get_node_or_null(settings_panel_path) as CanvasItem
@onready var _crosshair: CanvasItem = get_node_or_null(crosshair_path) as CanvasItem
@onready var _crosshair_circle: CanvasItem = get_node_or_null(crosshair_circle_path) as CanvasItem
@onready var _skill_panel: CanvasItem = get_node_or_null(skill_panel_path) as CanvasItem
@onready var _inventory_panel: CanvasItem = get_node_or_null(inventory_panel_path) as CanvasItem
@onready var _journal_panel: CanvasItem = get_node_or_null(journal_panel_path) as CanvasItem

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_ensure_action("pause", [KEY_ESCAPE])
	_set_paused(false)
	_add_menu_button()
	_add_quit_button()


func _add_menu_button() -> void:
	if not _pause_overlay:
		return
	var vp := get_viewport().get_visible_rect().size
	var bw := 200
	var bh := 40
	var btn := Button.new()
	btn.name = "MenuButton"
	btn.text = "返回主菜单"
	btn.layout_mode = 0
	btn.offset_left = (vp.x - bw) / 2.0
	btn.offset_top = vp.y * 2.0 / 3.0 - 54
	btn.offset_right = (vp.x + bw) / 2.0
	btn.offset_bottom = btn.offset_top + bh
	btn.pressed.connect(_on_return_menu)
	_pause_overlay.add_child(btn)


func _add_quit_button() -> void:
	if not _pause_overlay:
		return
	var vp := get_viewport().get_visible_rect().size
	var bw := 200
	var bh := 40
	var btn := Button.new()
	btn.name = "QuitButton"
	btn.text = "退出游戏"
	btn.layout_mode = 0
	btn.offset_left = (vp.x - bw) / 2.0
	btn.offset_top = vp.y * 2.0 / 3.0
	btn.offset_right = (vp.x + bw) / 2.0
	btn.offset_bottom = btn.offset_top + bh
	btn.pressed.connect(_on_quit)
	_pause_overlay.add_child(btn)


func _on_return_menu() -> void:
	SaveSystem.save()  # 返回菜单前自动存档
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_quit() -> void:
	SaveSystem.save()
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# 开场白期间 ESC：暂停并显示覆盖层
		var opening := get_node_or_null("../UI/OpeningDialog") as Control
		if opening and opening.visible:
			if _is_paused:
				get_tree().paused = false
				_is_paused = false
				_pause_overlay.visible = false
				if _settings_panel: _settings_panel.visible = false
				opening.mouse_filter = Control.MOUSE_FILTER_STOP
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				get_tree().paused = true
				_is_paused = true
				_pause_overlay.visible = true
				opening.mouse_filter = Control.MOUSE_FILTER_IGNORE
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			return
		# 对话期间 ESC：暂停游戏并显示暂停覆盖层
		var dlg: Control = get_node_or_null("../UI/DialogueBox") as Control
		var p2: Node = get_node_or_null("../Player2")
		var in_dialogue: bool = (dlg != null and dlg.visible) or (p2 != null and p2.has_method("_is_switch_open") and p2._is_switch_open())
		if in_dialogue:
			if _is_paused:
				get_tree().paused = false
				_is_paused = false
				_pause_overlay.visible = false
				if _settings_panel: _settings_panel.visible = false
				if dlg: _set_tree_mouse_filter(dlg, Control.MOUSE_FILTER_STOP)
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				get_tree().paused = true
				_is_paused = true
				_pause_overlay.visible = true
				if dlg: _set_tree_mouse_filter(dlg, Control.MOUSE_FILTER_IGNORE)
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			return
		if _skill_panel and _skill_panel.visible:
			_skill_panel.visible = false
			return
		if _inventory_panel and _inventory_panel.visible:
			_inventory_panel.visible = false
			return
		if _journal_panel and _journal_panel.visible:
			_journal_panel.visible = false
			return
		if _is_paused and _settings_panel and _settings_panel.visible:
			_settings_panel.visible = false
			_set_pause_overlay_visible(true)
			return
		_set_paused(not _is_paused)

func _set_paused(paused: bool) -> void:
	_is_paused = paused
	get_tree().paused = paused
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	if _pause_overlay:
		_set_pause_overlay_visible(paused)
	if _crosshair:
		_crosshair.visible = not paused
	if _crosshair_circle:
		_crosshair_circle.visible = false

func _set_pause_overlay_visible(visible: bool) -> void:
	if not _pause_overlay:
		return

	if _settings_panel and _settings_panel.visible:
		_pause_overlay.visible = false
	else:
		_pause_overlay.visible = visible

func _ensure_action(action_name: String, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if InputMap.action_get_events(action_name).size() > 0:
		return

	for key in keys:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = true
		InputMap.action_add_event(action_name, ev)


# 递归设置整棵子树的 mouse_filter
static func _set_tree_mouse_filter(root: Node, mode: Control.MouseFilter) -> void:
	if root is Control:
		(root as Control).mouse_filter = mode
	for child in root.get_children():
		_set_tree_mouse_filter(child, mode)
