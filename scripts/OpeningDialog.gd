extends Panel
## 开场叙事对话框 — 滚筒式，标题使用宋体，正文默认字体

@export var type_speed: float = 17.5

var _lines: Array[String] = []
var _headers: Array[String] = []   # 每段标题（可为空）
var _bodies: Array[String] = []    # 每段正文
var _current_para: int = 0
var _char_index: int = 0           # 累计字符索引
var _timer: float = 0.0
var _finished: bool = false
var _waiting: bool = false
var _cursor_timer: float = 0.0
var _click_cooldown: float = 0.0
var _mouse_clicked: bool = false
var _pause_timer: float = 0.0

var _header_font: Font = null
var _accumulated_chars: int = 0    # 已积累字符总数
var _paras_done: Array[int] = []   # 已完成的段落索引
var _portrait: TextureRect

@onready var _label: RichTextLabel = $Scroll/Label
@onready var _continue_hint: Label = $ContinueHint
@onready var _black_overlay: ColorRect = $BlackOverlay

## 技能颜色映射（与 Npc.gd 保持一致）
const _SKILL_COLOR_MAP := {
	"普鲁士纪律": "#5A5A5A", "莱茵河畔": "#7D9B8E", "帝国幽灵": "#8A7A65",
	"红衣逻辑": "#A08A8A", "灰烬喉": "#2C2218", "红色脉搏": "#8B1A1A",
	"铁十字": "#5A5A5A", "枯玫瑰": "#A08A8A",
}


func _ready() -> void:
	set_process(false)
	set_process_input(false)
	_label.add_theme_font_size_override("normal_font_size", 15)
	_label.add_theme_font_size_override("bold_font_size", 15)
	_continue_hint.add_theme_font_size_override("font_size", 15)
	_label.scroll_following = true
	_header_font = load("res://assets/fonts/simsun.ttc") as Font
	# 创建肖像（屏幕中上方 1/3 处）
	_create_portrait()
	hide()


func _create_portrait() -> void:
	_portrait = TextureRect.new()
	_portrait.name = "OpeningPortrait"
	_portrait.visible = false
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 定位：屏幕水平居中，上方 1/3（1280×720 → y=240）
	_portrait.anchor_left = 0.5
	_portrait.anchor_top = 0.0
	_portrait.anchor_right = 0.5
	_portrait.anchor_bottom = 0.0
	_portrait.offset_left = -200
	_portrait.offset_top = 60
	_portrait.offset_right = 200
	_portrait.offset_bottom = 460
	add_child(_portrait)


## 从标题中提取技能名称
func _extract_skill_name(header: String) -> String:
	if header == "":
		return ""
	var end := header.find("]")
	if end == -1:
		return ""
	var inner := header.substr(1, end - 1)
	var parts := inner.split("/", false)
	var skill_name := parts[-1].strip_edges() if parts.size() > 0 else ""
	var dot := skill_name.rfind(" · ")
	if dot != -1:
		skill_name = skill_name.substr(dot + 3)
	return skill_name.strip_edges()


## 技能图标路径映射（与 Npc.gd 一致，开场白只用男版）
const _SKILL_ICON_PATH := "res://assets/textures/skill_icons/%s"
const _SKILL_ICON_MAP := {
	"普鲁士纪律": "prussian_discipline.png",
	"莱茵河畔":   "rhine_riverbank_m.png",
	"帝国幽灵":   "empire_ghost_m.png",
	"红衣逻辑":   "red_logic_m.png",
	"灰烬喉":    "ash_throat_m.png",
	"枯玫瑰":    "withered_rose_m.png",
	"红色脉搏":   "red_pulse_m.png",
	"铁十字":    "iron_cross_m.png",
}


## 从标题中提取技能名称并着色
func _colorize_header(header: String) -> String:
	var skill_name := _extract_skill_name(header)
	if skill_name == "":
		return header
	var color: String = _SKILL_COLOR_MAP.get(skill_name, "")
	if color != "":
		return "[color=" + color + "]" + header + "[/color]"
	return header


func start(lines: Array[String]) -> void:
	_lines = lines
	_headers.clear()
	_bodies.clear()
	# 拆分每段为标题+正文
	for line in lines:
		var idx := line.find("]\n\n")
		if line.begins_with("[") and idx > 1:
			_headers.append(line.substr(0, idx + 1))
			_bodies.append(line.substr(idx + 1))
		else:
			_headers.append("")
			_bodies.append(line)

	_current_para = 0
	_char_index = 0
	_accumulated_chars = 0
	_paras_done.clear()
	_timer = 0.0
	_finished = false
	_waiting = false
	_cursor_timer = 0.0
	_click_cooldown = 0.0
	_mouse_clicked = false
	_pause_timer = 0.0
	_label.clear()
	_continue_hint.visible = false
	# 显示肖像
	if _portrait:
		_portrait.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show()
	set_process(true)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if get_tree().paused:
		return  # 暂停时由 PauseManager 处理
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_clicked = true


func _process(delta: float) -> void:
	if _lines.is_empty():
		return

	_click_cooldown = max(0.0, _click_cooldown - delta)
	var click := Input.is_action_just_pressed("interact") or (_mouse_clicked and _click_cooldown <= 0.0)
	_mouse_clicked = false

	# 全部打完 → 点击关闭
	if _finished:
		_cursor_timer += delta
		_continue_hint.visible = int(_cursor_timer * 2.0) % 2 == 0
		if click:
			_close()
		return

	# 段间等待 → 点击开始下一段
	if _waiting:
		_cursor_timer += delta
		_continue_hint.visible = int(_cursor_timer * 2.0) % 2 == 0
		if click:
			_waiting = false
			_continue_hint.visible = false
			_click_cooldown = 0.25
			_char_index = 0
			_timer = 0.0
		return

	# 打字中 → 单击补全当前段
	if click and _current_para < _lines.size():
		_skip_current_para()
		return

	# 打字机
	if _current_para < _lines.size():
		# 句号暂停
		if _pause_timer > 0.0:
			_pause_timer -= delta
		else:
			_timer += delta
		var total_len := _get_para_total_length(_current_para)
		while _pause_timer <= 0.0 and _timer >= 1.0 / type_speed and _char_index < total_len:
			_timer -= 1.0 / type_speed
			_char_index += 1
			# 刚打出的字符是。则暂停 0.5 秒
			if _get_char_at(_current_para, _char_index - 1) == "。" or _get_char_at(_current_para, _char_index - 1) == ".":
				_pause_timer = 0.5
				break

		_cursor_timer += delta
		var show_cursor := int(_cursor_timer * 3.0) % 2 == 0
		_render_with_cursor(show_cursor)
		_label.scroll_following = true

		if _char_index >= total_len:
			_finish_current_para()


func _get_para_total_length(pi: int) -> int:
	return _headers[pi].length() + _bodies[pi].length()


func _get_char_at(pi: int, idx: int) -> String:
	var full := _headers[pi] + _bodies[pi]
	if idx < 0 or idx >= full.length():
		return ""
	return full[idx]


func _render_with_cursor(show_cursor: bool) -> void:
	_label.clear()
	var remaining: int = _char_index
	var cursor: String = ""

	# 重新渲染所有已完成的段落
	for pi in _paras_done:
		_render_para_full(pi)
		_label.append_text("\n\n\n\n")

	# 渲染当前段落
	_render_para_partial(_current_para, remaining, cursor)


func _update_portrait(header: String) -> void:
	var skill_name := _extract_skill_name(header)
	if skill_name == "":
		_portrait.visible = false
		return
	var filename: String = _SKILL_ICON_MAP.get(skill_name, "")
	if filename == "":
		_portrait.visible = false
		return
	_portrait.texture = load(_SKILL_ICON_PATH % filename)
	_portrait.visible = true


func _render_para_full(pi: int) -> void:
	_update_portrait(_headers[pi])
	if _headers[pi] != "" and _header_font:
		_label.push_font(_header_font)
		_label.append_text(_colorize_header(_headers[pi]))
		_label.pop()
		_label.append_text("\n\n")
	_label.append_text(_bodies[pi])


func _render_para_partial(pi: int, remaining: int, cursor_str: String) -> void:
	_update_portrait(_headers[pi])
	var header_len: int = _headers[pi].length()

	if _headers[pi] != "" and _header_font:
		_label.push_font(_header_font)
		var colored: String = _colorize_header(_headers[pi])
		if remaining <= header_len:
			# 标题只显示了一部分（着色后不能用 substr，直接显示纯文本带光标）
			_label.append_text(_headers[pi].substr(0, remaining) + cursor_str)
			_label.pop()
			return
		_label.append_text(colored)
		_label.pop()
		_label.append_text("\n\n")
		remaining -= header_len

	var body: String = _bodies[pi]
	if remaining >= body.length():
		_label.append_text(body)
	else:
		_label.append_text(body.substr(0, remaining) + cursor_str)


func _skip_current_para() -> void:
	_finish_current_para()


func _finish_current_para() -> void:
	_paras_done.append(_current_para)
	_current_para += 1
	_char_index = 0
	# 重新渲染所有已完成段落
	_label.clear()
	for i in _paras_done.size():
		_render_para_full(_paras_done[i])
		if i < _paras_done.size() - 1:
			_label.append_text("\n\n\n\n")
	# "你推开门。" 段完成后淡出黑屏
	if _current_para == 12:
		_fade_out_black()
	if _current_para >= _lines.size():
		_finished = true
	else:
		_waiting = true
	_click_cooldown = 0.25


func _fade_out_black() -> void:
	var tween := create_tween()
	tween.tween_property(_black_overlay, "color:a", 0.0, 2.0)


func _close() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	if _portrait:
		_portrait.visible = false
	hide()
	set_process(false)
	set_process_input(false)
	queue_free()
