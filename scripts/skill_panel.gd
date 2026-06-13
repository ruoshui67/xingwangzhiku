extends Panel

@export var open_action: String = "skill_panel"
const COLS := 4
const BTN_SIZE := 55
const RING_WIDTH := 4
const RING_RADIUS := (BTN_SIZE + RING_WIDTH) / 2.0

var _is_open: bool = false
var _skill_buttons: Array[Button] = []
var _skill_rings: Array[Control] = []
var _skill_names: Array[String] = []

@onready var _grid: GridContainer = $Grid
@onready var _detail_name: Label = $Detail/DetailName
@onready var _detail_desc: Label = $Detail/DetailDesc
@onready var _detail_xp: Label = $Detail/DetailXP
@onready var _detail_panel: Panel = $Detail
@onready var _detail_circle: ColorRect = $Detail/DetailCircle


class SkillRing extends Control:
	var _xp_fraction: float = 0.0
	func set_xp(f: float) -> void:
		_xp_fraction = clamp(f, 0.0, 1.0)
		queue_redraw()
	func _draw() -> void:
		var c := size / 2.0
		var r := RING_RADIUS - RING_WIDTH / 2.0
		draw_arc(c, r, 0, TAU, 64, Color(0.15, 0.12, 0.10, 0.8), RING_WIDTH, true)
		if _xp_fraction > 0:
			draw_arc(c, r, -PI / 2, -PI / 2 + TAU * _xp_fraction, 32,
				Color(0.3, 0.8, 0.4, 1), RING_WIDTH, true)


var _prev_visible: bool = false

func _ready() -> void:
	visible = false
	_build_skills()


func _process(_delta: float) -> void:
	if visible != _prev_visible:
		_prev_visible = visible
		if visible:
			_apply_active_bg()
			_build_skills()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_try_show_tutorial()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	if visible:
		_refresh()


func _apply_active_bg() -> void:
	var bg := get_node_or_null("BgTexture") as TextureRect
	if not bg:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and player.name.to_lower().begins_with("player2"):
		bg.texture = load("res://assets/textures/skill_bg_female.png")
	else:
		bg.texture = load("res://assets/textures/skill_bg_male.png")


func _build_skills() -> void:
	# 清除旧内容
	for c in _grid.get_children():
		c.queue_free()
	_skill_buttons.clear()
	_skill_rings.clear()
	
	var player := get_tree().get_first_node_in_group("player")
	if player and "_skill_xp" in player:
		_skill_names.clear()
		var raw: Variant = player._skill_xp
		if raw is Dictionary:
			for k in raw.keys():
				_skill_names.append(str(k))
	else:
		_skill_names = [
			"技能一", "技能二", "技能三", "技能四",
			"技能五", "技能六", "技能七", "技能八"
		]
	var cell_w := BTN_SIZE + RING_WIDTH * 2 + 16
	var cell_h := BTN_SIZE + RING_WIDTH * 2 + 28
	_grid.columns = 9  # 4 技能 + 1 间隔 + 4 技能
	_grid.add_theme_constant_override("h_separation", 34)
	_grid.add_theme_constant_override("v_separation", 0)
	for i in range(9):
		# 中间位置放空间隔
		if i == 4:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(cell_w + 20, cell_h)
			_grid.add_child(spacer)
			continue

		var skill_idx := i if i < 4 else i - 1
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(cell_w, cell_h)

		var ring := SkillRing.new()
		ring.set_anchors_preset(Control.PRESET_CENTER_TOP)
		ring.position = Vector2(-(BTN_SIZE + RING_WIDTH * 2) / 2.0, RING_WIDTH)
		ring.size = Vector2(BTN_SIZE + RING_WIDTH * 2, BTN_SIZE + RING_WIDTH * 2)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(ring)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
		btn.name = "SkillBtn" + str(skill_idx)
		btn.text = "1"
		btn.add_theme_font_size_override("font_size", 24)
		btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1))
		btn.pressed.connect(_on_skill_clicked.bind(skill_idx))
		var circle := StyleBoxFlat.new()
		circle.bg_color = Color(0.12, 0.10, 0.08, 0.9)
		circle.border_width_left = 3
		circle.border_width_right = 3
		circle.border_width_top = 3
		circle.border_width_bottom = 3
		circle.border_color = Color(0.7, 0.6, 0.3, 1)
		circle.corner_radius_top_left = BTN_SIZE / 2
		circle.corner_radius_top_right = BTN_SIZE / 2
		circle.corner_radius_bottom_left = BTN_SIZE / 2
		circle.corner_radius_bottom_right = BTN_SIZE / 2
		btn.add_theme_stylebox_override("normal", circle)
		var hover_style := circle.duplicate()
		hover_style.border_color = Color(1, 0.85, 0.4, 1)
		btn.add_theme_stylebox_override("hover", hover_style)
		# 按钮居中叠在环上
		btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
		btn.position = Vector2(-BTN_SIZE / 2.0, RING_WIDTH * 2)
		cell.add_child(btn)

		var label := Label.new()
		label.text = _skill_names[skill_idx]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.55, 1))
		label.add_theme_font_size_override("font_size", 12)
		label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		label.position = Vector2(-40, BTN_SIZE + RING_WIDTH * 2 + 2)
		label.size = Vector2(80, 20)
		cell.add_child(label)

		_grid.add_child(cell)
		_skill_buttons.append(btn)
		_skill_rings.append(ring)


func _refresh() -> void:
	for i in range(_skill_names.size()):
		var lv := _get_skill_level(_skill_names[i])
		if i < _skill_buttons.size():
			_skill_buttons[i].text = str(lv)
		if i < _skill_rings.size():
			var xp := _get_skill_xp(_skill_names[i])
			_skill_rings[i].set_xp(xp / 100.0)


func _on_skill_clicked(index: int) -> void:
	if index >= _skill_names.size():
		return
	var name := _skill_names[index]
	var lv := _get_skill_level(name)
	var xp := _get_skill_xp(name)
	if _detail_name:
		_detail_name.text = name
	if _detail_desc:
		_detail_desc.text = _get_desc(name)
	if _detail_xp:
		_detail_xp.text = "等级 Lv." + str(lv) + "  经验 " + str(int(xp)) + " / 100"
	if _detail_panel:
		_detail_panel.visible = true
	if _detail_circle and _detail_circle.get_child_count() > 0:
		(_detail_circle.get_child(0) as Label).text = str(lv)


# ---- 数据读取 ----

func _get_skill_xp(skill_name: String) -> float:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_skill_xp"):
		return player.get_skill_xp(skill_name)
	return 0.0


func _get_skill_level(skill_name: String) -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_skill_level"):
		return player.get_skill_level(skill_name)
	return 1


func _get_desc(name: String) -> String:
	var is_p2 := _is_player2()
	if is_p2:
		return _P2_DESC.get(name, "")
	return _P1_DESC.get(name, "")


const _P1_DESC := {
	"普鲁士纪律": "恪守规则与秩序，在混乱中保持冷静，识破谎言与破绽。",
	"帝国幽灵":   "唤起德意志旧帝国的记忆，察觉历史投下的长长阴影。",
	"莱茵河畔":   "倾听莱茵兰百姓的悲欢，拉近与德国市民之间的距离。",
	"红色脉搏":   "感知革命暗流的涌动，捕捉反抗者压抑的呼吸与心跳。",
	"灰烬喉":    "用恐惧撬开沉默的嘴。暴力是最直接有效的审讯方式。",
	"铁十字":    "以德意志民族意志对抗压迫，在逆境中挺直脊梁不低头。",
	"红衣逻辑":   "用法典与逻辑梳理线索，从纷乱碎片中拼凑出真相。",
	"枯玫瑰":    "察觉废墟下的伤感与残存之美，读懂人心中最脆弱的部分。",
}

const _P2_DESC := {
	"共和国准则": "恪守法兰西纪律与荣誉，在占领区守住正义的最后底线。",
	"帝国幽灵":   "审视拿破仑的帝国遗梦，看清征服者荣光背后的代价与荒芜。",
	"莱茵河畔":   "倾听莱茵兰百姓的悲欢，跨越占领者与被占领者之间的鸿沟。",
	"红色脉搏":   "感知革命暗流的涌动，捕捉反抗者压抑的呼吸与心跳。",
	"灰烬喉":    "用恐惧撬开沉默的嘴。暴力是最直接有效的审讯方式。",
	"三色旗":    "以法兰西的信念坚定己心，在怀疑与动摇中守住信仰。",
	"三段论":    "用严密逻辑推演剖析案情，抽丝剥茧一步步还原事件真相。",
	"枯玫瑰":    "察觉废墟下的伤感与残存之美，读懂人心中最脆弱的部分。",
}


func _is_player2() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and player.name.to_lower().begins_with("player2")


func _try_show_tutorial() -> void:
	if SaveSystem.tutorial_skill_shown:
		return
	SaveSystem.tutorial_skill_shown = true
	SaveSystem.mark_dirty()
	_show_tutorial("技能 —— 展示弗莱与杜瓦尔各八项核心技能的等级与效果说明。每次通过技能判定——不管成功还是失败——都会自动积累经验。技能升级后，新的对话选项和叙事分支会悄然打开：更高的\"莱茵河畔\"让你听到更多德国市民的心声，更高的\"红衣逻辑\"让你拼出更完整的案情地图。")


func _show_tutorial(text: String) -> void:
	var overlay := ColorRect.new()
	overlay.name = "TutorialOverlay"
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_tutorial_click.bind(overlay))
	add_child(overlay)
	
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", 28)
	label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	label.text = "[center]" + text + "[/center]\n\n[center][color=#888888]单击鼠标左键关闭[/color][/center]"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 50
	label.offset_top = 30
	label.offset_right = -50
	label.offset_bottom = -30
	label.z_index = 201
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(label)


func _on_tutorial_click(event: InputEvent, overlay: ColorRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		overlay.queue_free()


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
