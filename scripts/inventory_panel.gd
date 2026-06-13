extends Panel

const SLOTS := 12
const SLOT_COLS := 4

var _slots: Array[Button] = []
var _selected: int = -1

@onready var _grid: GridContainer = $Grid
@onready var _preview: TextureRect = $Detail/Preview
@onready var _item_name: Label = $Detail/ItemName
@onready var _item_desc: Label = $Detail/ItemDesc
@onready var _detail_panel: Panel = $Detail


func _ready() -> void:
	visible = false
	_apply_bg_shader()
	_build_slots()


func _apply_bg_shader() -> void:
	var bg := get_node_or_null("BgTexture") as TextureRect
	if not bg:
		return
	var shader := load("res://shaders/white_to_alpha.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		bg.material = mat


var _prev_visible: bool = false

func _process(_delta: float) -> void:
	if visible != _prev_visible:
		_prev_visible = visible
		if visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_try_show_tutorial()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	if visible:
		_refresh()


func _build_slots() -> void:
	_grid.columns = SLOT_COLS  # 4 列
	for i in range(SLOTS):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.name = "Slot" + str(i)
		btn.text = ""
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8, 1))
		btn.add_theme_font_size_override("font_size", 16)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.12, 0.08, 0.85)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.6, 0.5, 0.3, 1)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.pressed.connect(_on_slot_clicked.bind(i))
		_grid.add_child(btn)
		_slots.append(btn)


func _refresh() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var items: Array = []
	if player and "inventory" in player:
		items = player.inventory
	for i in range(SLOTS):
		var btn := _slots[i]
		if i < items.size():
			btn.text = ""
			var tex: ImageTexture = _get_item_art(str(items[i]))
			if tex and tex.get_width() > 64:
				var img: Image = tex.get_image()
				img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
				tex = ImageTexture.create_from_image(img)
			btn.icon = tex
		else:
			btn.text = ""
			btn.icon = null


func _on_slot_clicked(index: int) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not "inventory" in player:
		return
	var items: Array = player.inventory
	if index >= items.size():
		_clear_detail()
		return
	_selected = index
	var item := str(items[index])
	_show_detail(item)


func _show_detail(item: String) -> void:
	if _detail_panel:
		_detail_panel.visible = true
	if _preview:
		_preview.texture = _get_item_art(item)
	if _item_name:
		_item_name.text = _get_item_name(item)
	if _item_desc:
		_item_desc.text = _get_item_desc(item)


func _clear_detail() -> void:
	_selected = -1
	if _detail_panel:
		_detail_panel.visible = false


func _get_item_art(item: String) -> ImageTexture:
	match item:
		"幸运币":
			var tex := load("res://硬币.png") as Texture2D
			if tex: return _resize_texture(tex)
		"笔记本":
			var tex := load("res://笔记本男.png") as Texture2D
			if tex: return _resize_texture(tex)
		"记事簿":
			var tex := load("res://笔记本女.png") as Texture2D
			if tex: return _resize_texture(tex)
		"鲁格P08":
			var tex := load("res://鲁格.png") as Texture2D
			if tex: return _resize_texture(tex)
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.18, 0.15, 1))
	match item:
		"钥匙":
			var gold := Color(0.9, 0.75, 0.15, 1)
			_fill_circle(img, Vector2(80, 38), 22, gold)
			_fill_circle(img, Vector2(80, 38), 14, Color(0.2, 0.18, 0.15, 1))
			img.fill_rect(Rect2i(74, 60, 12, 55), gold)
			img.fill_rect(Rect2i(86, 75, 16, 6), gold)
			img.fill_rect(Rect2i(86, 90, 12, 6), gold)
			img.fill_rect(Rect2i(86, 105, 8, 6), gold)
		_:
			var label_color := Color(0.5, 0.5, 0.5, 1)
			img.fill_rect(Rect2i(40, 52, 48, 24), label_color)
	return ImageTexture.create_from_image(img)


func _resize_texture(tex: Texture2D) -> ImageTexture:
	var img: Image = tex.get_image()
	img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)


func _get_item_name(item: String) -> String:
	match item:
		"幸运币": return "幸运币"
		"笔记本": return "笔记本"
		"记事簿": return "笔记本"
		"鲁格P08": return "鲁格P08"
		"钥匙": return "生锈的钥匙"
	return item


func _get_item_desc(item: String) -> String:
	match item:
		"幸运币": return "幸运币 —— 一枚旧版普鲁士泰勒银币，边缘磨得光滑。母亲塞进他行囊的——\"到了那边，别丢了魂。\""
		"笔记本": return "笔记本 —— 磨损的牛皮封笔记本，密密麻麻写满案件推演。柏林调令夹在扉页，墨迹渗入纸背。"
		"记事簿": return "笔记本 —— 法兰西宪兵标配记事簿，封面被烟灰烫出三个焦痕。第六年，空白页比写满的还多。"
		"鲁格P08": return "鲁格P08 —— 一把缴获的德制手枪，原主是第四名失踪士兵。她留着它——不是为了防身，是为了记住。"
		"钥匙": return "一把锈迹斑斑的铁钥匙，似乎能打开某扇老旧的门。"
	return ""


func _fill_circle(img: Image, center: Vector2, r: float, color: Color) -> void:
	var cx := int(center.x)
	var cy := int(center.y)
	var ri := int(r)
	for y in range(cy - ri, cy + ri + 1):
		for x in range(cx - ri, cx + ri + 1):
			if Vector2(x - center.x, y - center.y).length_squared() <= r * r:
				if x >= 0 and x < 128 and y >= 0 and y < 128:
					img.set_pixel(x, y, color)


func _try_show_tutorial() -> void:
	if SaveSystem.tutorial_inventory_shown:
		return
	SaveSystem.tutorial_inventory_shown = true
	SaveSystem.mark_dirty()
	_show_tutorial("背包 —— 存放你在探案过程中收集的证物、道具与个人物品。每件物品都可能成为对话的敲门砖。一块压碎的打火机、一罐可疑的油样、一封没寄出的信——你背包里装的从来不只是\"道具\"，它们是决定故事走向的钥匙。")


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
