extends Panel

@export var inventory_panel_path: NodePath
@export var skill_panel_path: NodePath
@export var journal_panel_path: NodePath
@export var settings_panel_path: NodePath

var _panels: Array[CanvasItem] = []
var _buttons: Array[Button] = []

func _ready() -> void:
	_setup_buttons()
	_panels = [
		_get_panel(inventory_panel_path),
		_get_panel(skill_panel_path),
		_get_panel(journal_panel_path),
		_get_panel(settings_panel_path),
	]
	for btn in _buttons:
		btn.pressed.connect(_on_toolbar_btn.bind(btn))


func _setup_buttons() -> void:
	for child in get_children():
		if child is Button:
			_buttons.append(child as Button)


func _get_panel(path: NodePath) -> CanvasItem:
	return get_node_or_null(path) as CanvasItem


func _on_toolbar_btn(btn: Button) -> void:
	var idx := _buttons.find(btn)
	if idx < 0 or idx >= _panels.size():
		return
	var panel: CanvasItem = _panels[idx]
	if not panel:
		return
	var was_visible := panel.visible
	_close_all()
	if not was_visible:
		panel.visible = true
		_highlight_btn(idx)
		# 设置面板需要暂停
		if idx == 3:
			_pause_game(true)


func _close_all() -> void:
	_pause_game(false)
	for p in _panels:
		if p:
			p.visible = false
	for i in _buttons.size():
		_set_btn_active(i, false)


func _pause_game(paused: bool) -> void:
	get_tree().paused = paused
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)


func _highlight_btn(idx: int) -> void:
	for i in _buttons.size():
		_set_btn_active(i, i == idx)


func _set_btn_active(idx: int, active: bool) -> void:
	if idx < 0 or idx >= _buttons.size():
		return
	var btn := _buttons[idx]
	if active:
		btn.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 1))
	else:
		btn.remove_theme_color_override("font_color")
