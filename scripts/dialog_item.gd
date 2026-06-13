class_name DialogItem
extends Item

## 可对话物品 — 显示气泡 + 下方选项，不锁定移动
## 点击气泡外 / 角色移动 → 自动关闭

@export var bubble_panel_path: NodePath

var _bubble_visible: bool = false
var _last_player_pos: Vector3 = Vector3.ZERO

@onready var _bubble_wrapper: Control = get_node_or_null(bubble_panel_path)
@onready var _bubble_panel: Panel = _bubble_wrapper.get_node_or_null("BubblePanel") as Panel if _bubble_wrapper else null
@onready var _bubble_text: RichTextLabel = _bubble_panel.get_node_or_null("Text") as RichTextLabel if _bubble_panel else null
@onready var _bubble_opts: HBoxContainer = _bubble_wrapper.get_node_or_null("Options") as HBoxContainer if _bubble_wrapper else null


func _process(delta: float) -> void:
	super._process(delta)
	if _bubble_visible:
		_update_bubble_position()
		if _player and _player.global_position.distance_squared_to(_last_player_pos) > 1.0:
			_hide_bubble()
	if _player_in_range and _prompt_label and _prompt_label.visible and Input.is_action_just_pressed("interact"):
		if _bubble_visible:
			_hide_bubble()
		else:
			_show_bubble()


func _unhandled_input(event: InputEvent) -> void:
	if not _bubble_visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _is_mouse_inside_bubble():
			get_viewport().set_input_as_handled()
			_hide_bubble()


func _is_mouse_inside_bubble() -> bool:
	if not _bubble_wrapper or not _bubble_wrapper.visible:
		return false
	var mouse_pos := get_viewport().get_mouse_position()
	var rect := _bubble_wrapper.get_global_rect()
	return rect.has_point(mouse_pos)


func _show_bubble() -> void:
	_bubble_visible = true
	if _player:
		_last_player_pos = _player.global_position

	# 先设置文本
	if _bubble_text:
		_bubble_text.text = _get_bubble_text()
	_populate_choices()

	# 根据文本内容计算气泡大小
	if _bubble_panel and _bubble_text:
		_bubble_text.size = Vector2.ZERO
		await get_tree().process_frame
		var text_w: float = maxf(_bubble_text.get_content_width() + 24, 200.0)
		var text_h: float = maxf(_bubble_text.get_content_height() + 24, 40.0)
		_bubble_panel.position = Vector2.ZERO
		_bubble_panel.size = Vector2(text_w, text_h)
		_bubble_text.position = Vector2(12, 12)
		_bubble_text.size = Vector2(text_w - 24, text_h - 24)

	# 选项放在面板下方
	if _bubble_opts and _bubble_opts.get_child_count() > 0:
		_bubble_opts.position = Vector2(0, _bubble_panel.size.y + 6)
		_bubble_opts.size = Vector2(_bubble_panel.size.x, 0)
	else:
		_bubble_opts.size = Vector2.ZERO

	# 包装容器总大小
	if _bubble_wrapper:
		var opt_h: float = _bubble_opts.size.y + 6 if (_bubble_opts and _bubble_opts.get_child_count() > 0) else 0.0
		_bubble_wrapper.size = Vector2(_bubble_panel.size.x, _bubble_panel.size.y + opt_h)
		_bubble_wrapper.show()


func _hide_bubble() -> void:
	_bubble_visible = false
	if _bubble_wrapper:
		_bubble_wrapper.hide()


func _update_bubble_position() -> void:
	if not _bubble_wrapper or not _bubble_wrapper.visible:
		return
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var pos_3d := global_position + Vector3(0, 2, 0)
	if cam.is_position_behind(pos_3d):
		_bubble_wrapper.hide()
		return
	var screen_pos := cam.unproject_position(pos_3d)
	_bubble_wrapper.position = screen_pos - _bubble_wrapper.size * 0.5 - Vector2(0, _bubble_wrapper.size.y * 0.5 + 20)


# ---- 子类覆盖 ----

func _get_bubble_text() -> String:
	return "（空）"


func _get_bubble_choices() -> Array[Dictionary]:
	return []


func _populate_choices() -> void:
	if not _bubble_opts:
		return
	for c in _bubble_opts.get_children():
		c.queue_free()
	var choices := _get_bubble_choices()
	for ch in choices:
		var btn := Button.new()
		btn.text = ch["text"]
		btn.pressed.connect(ch["cb"])
		_bubble_opts.add_child(btn)
