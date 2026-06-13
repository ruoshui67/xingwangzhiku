extends Panel

@export var clue_container_path: NodePath
@export var reason_btn_path: NodePath
@export var result_label_path: NodePath
@export var ai_endpoint: String = "https://api.deepseek.com/chat/completions"
@export var ai_model: String = "deepseek-chat"
@export var ai_api_key: String = ""

var _is_open: bool = false
var _selected_indices: Array[int] = []
var _clue_buttons: Array[Button] = []
var _clue_texts: Array[String] = []
var _ai_result_text: String = ""
# 线索组合表：两两配对 → 新线索
var _clue_combos: Array[Dictionary] = [
	{"a": "声音线索 —— 拖拽声 + 低声骂人（德语）", "b": "体态线索 —— 两个影子，一个步伐稳健似军人", "new": "□ 德方军人参与 —— 拖拽者为军人"},
	{"a": "气味线索 —— 可疑的油味", "b": "燃料鉴定 —— 军用混合油，指向军方内部盗窃", "new": "□ 军队燃料外流 —— 军方内部盗窃军用油"},
	{"a": "沃格桑仓库 —— 铁桶燃料储存地", "b": "燃料鉴定 —— 军用混合油，工业级军事级", "new": "□ 仓库与燃料匹配 —— 沃格桑仓库即失窃燃料存放点"},
	{"a": "杜邦被多次警告而非一次性清除", "b": "杜邦性格变化 —— 受过警告但相信自己能摆平", "new": "□ 杜邦的致命自信 —— 被警告多次却不逃跑"},
	{"a": "打火机鉴定 —— 故意撞击，非意外摔落", "b": "□ 金属撞击三下 —— 系船柱信号，\"已完成\"", "new": "□ 系船柱暗号 —— 金属撞击非意外，是信号"},
	{"a": "□ 迪特尔承认 —— 法军内部有人在偷运燃料", "b": "□ 勒布朗 —— \"穿法军制服送货的军官\"（个子不高）", "new": "□ 勒布朗确认 —— 偷运燃料的法军内部人员"},
	{"a": "□ 迪特尔为铁之心通风报信（四年）", "b": "□ 抵抗组织联系 —— 运河第三座桥的暗号", "new": "□ 铁之心网络 —— 运河暗号连接抵抗组织"},
	{"a": "□ 那晚迪特尔在桥边 —— 看到杜邦还活着但未施救", "b": "□ 莫罗与杜邦 —— 师徒关系、最后的背叛", "new": "□ 杜邦之死真相 —— 被师傅背叛，目击者未救"},
	{"a": "□ 莫罗的影子 —— 杜瓦尔开始意识到是自己人", "b": "□ 全部燃料交易链条 —— 勒布朗 + 沃格桑 + 铁之心", "new": "□ 莫罗的犯罪网络 —— 完整交易链条浮现"},
	{"a": "□ 莫罗全部认罪 —— 七年盗窃、七条人命", "b": "□ 妻子玛丽安娜 —— 肺病，巴黎，制度瘫痪下的个人悲剧", "new": "□ 莫罗动机 —— 为救妻子的制度牺牲品"},
	{"a": "杜邦查到了燃料来源并确认", "b": "□ 莫罗与杜邦 —— 师徒关系、最后的背叛", "new": "□ 杜邦死因 —— 查到了不该知道的"},
]
var _result_clue: String = ""  # 本次推理获得的新线索文字

@onready var _clue_container: VBoxContainer = get_node_or_null(clue_container_path) as VBoxContainer
@onready var _reason_btn: Button = get_node_or_null(reason_btn_path) as Button
@onready var _result_label: Label = get_node_or_null(result_label_path) as Label
@onready var _http: HTTPRequest = $HTTPRequest


func _ready() -> void:
	visible = false
	if _reason_btn:
		_reason_btn.pressed.connect(_on_reason)
	if _http:
		_http.request_completed.connect(_on_ai_response)
	# AI思考音效
	var ai_audio := AudioStreamPlayer.new()
	ai_audio.name = "AIThinkAudio"
	ai_audio.stream = load("res://assets/audio/ai_thinking.mp3") as AudioStream
	ai_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ai_audio)


var _prev_visible: bool = false

func _process(_delta: float) -> void:
	if visible != _prev_visible:
		_prev_visible = visible
		if visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_try_show_tutorial()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	if visible and _clue_container and _clue_container.get_child_count() == 0:
		_selected_indices.clear()
		_refresh()


func _refresh() -> void:
	if not _clue_container:
		return
	for c in _clue_container.get_children():
		c.queue_free()
	_clue_buttons.clear()
	_clue_texts.clear()
	if _reason_btn:
		_reason_btn.visible = false
	if _result_label:
		_result_label.text = ""

	var player := get_tree().get_first_node_in_group("player")
	var clues: Array = []
	if player and "journal" in player:
		clues = player.journal
	for c in clues:
		_clue_texts.append(str(c))

	if _clue_texts.is_empty():
		var empty := Label.new()
		empty.text = "暂无线索"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		empty.add_theme_font_size_override("font_size", 25)
		_clue_container.add_child(empty)
		return

	if _reason_btn:
		_reason_btn.visible = true

	for i in range(_clue_texts.size()):
		var btn := Button.new()
		btn.text = str(i + 1) + ". " + _clue_texts[i]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_clue_clicked.bind(i))
		_apply_btn_style(btn, i in _selected_indices)

		_clue_container.add_child(btn)
		_clue_buttons.append(btn)

	# 持久化 AI 推理结果
	if _ai_result_text != "":
		var sep := HSeparator.new()
		_clue_container.add_child(sep)
		var ai_label := Label.new()
		ai_label.text = "[推理] " + _ai_result_text
		ai_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ai_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1, 1))
		ai_label.add_theme_font_size_override("font_size", 25)
		_clue_container.add_child(ai_label)


func _apply_btn_style(btn: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var pressed := StyleBoxFlat.new()

	normal.bg_color = Color(0.05, 0.05, 0.05, 0.6)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 8

	hover.bg_color = Color(0.10, 0.12, 0.08, 0.7)
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.border_color = Color(0.4, 0.6, 0.3, 0.6)
	hover.set_corner_radius_all(6)
	hover.content_margin_left = 8

	pressed.bg_color = Color(0.15, 0.25, 0.10, 0.8)
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	pressed.border_color = Color(0.5, 0.8, 0.3, 1)
	pressed.set_corner_radius_all(6)
	pressed.content_margin_left = 8

	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	btn.add_theme_font_size_override("font_size", 28)

	if selected:
		btn.add_theme_stylebox_override("normal", pressed)
		btn.add_theme_stylebox_override("hover", pressed)
		btn.add_theme_stylebox_override("pressed", pressed)
	else:
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)


func _on_clue_clicked(index: int) -> void:
	if _selected_indices.has(index):
		_selected_indices.erase(index)
	else:
		if _selected_indices.size() >= 2:
			_selected_indices.pop_front()
		_selected_indices.append(index)
	_refresh()


func _on_reason() -> void:
	if _selected_indices.size() != 2:
		if _result_label:
			_result_label.text = "请先选择两条线索"
			_result_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3, 1))
		return

	var t1 := _clue_texts[_selected_indices[0]]
	var t2 := _clue_texts[_selected_indices[1]]

	# 查找匹配的组合（去除前导 "□ " 后再比较，兼容不一致的格式）
	_result_clue = ""
	var s1 := _strip_clue_prefix(t1)
	var s2 := _strip_clue_prefix(t2)
	for combo in _clue_combos:
		var ca := _strip_clue_prefix(combo["a"])
		var cb := _strip_clue_prefix(combo["b"])
		if (ca == s1 and cb == s2) or (ca == s2 and cb == s1):
			_result_clue = combo["new"]
			break

	# 有匹配组合 → 添加新线索
	if _result_clue != "":
		_add_new_clue(_result_clue)

	# 调用 AI
	if _http:
		_reason_btn.disabled = true
		# 播放 AI 思考音效
		var ai_audio: AudioStreamPlayer = get_node_or_null("AIThinkAudio")
		if ai_audio and not ai_audio.playing:
			ai_audio.play()
		if _result_label:
			_result_label.text = "推理中..."
			_result_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))

		var prompt: String
		if _result_clue != "":
			prompt = '玩家提供了两条线索："' + t1 + '"和"' + t2 + '"，推理后获得新线索："' + _result_clue + '"。请用50字以内解释这两条线索为什么能得出这条新线索。'
		else:
			prompt = '玩家提供了两条线索："' + t1 + '"和"' + t2 + '"。请先用一两句话分析两条线索的可能联系，然后转折说明为什么这两条线索之间无法直接产生新线索。50字以内。'

		var messages := [
			{"role": "system", "content": "你是一个推理助手，帮助玩家分析线索之间的关系。"},
			{"role": "user", "content": prompt}
		]
		var body_data := {
			"model": ai_model,
			"messages": messages
		}
		var body := JSON.stringify(body_data)
		var headers := ["Content-Type: application/json"]
		if ai_api_key != "":
			headers.append("Authorization: Bearer " + ai_api_key)
		var err := _http.request(ai_endpoint, headers, HTTPClient.METHOD_POST, body)
		if err != OK:
			_show_fallback(t1, t2)
	else:
		_show_fallback(t1, t2)


func _on_ai_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_reason_btn.disabled = false
	# 停止 AI 思考音效
	var ai_audio: AudioStreamPlayer = get_node_or_null("AIThinkAudio")
	if ai_audio:
		ai_audio.stop()
	if result != HTTPRequest.RESULT_SUCCESS:
		var t1 := _clue_texts[_selected_indices[0]]
		var t2 := _clue_texts[_selected_indices[1]]
		_show_fallback(t1, t2)
		return

	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json is Dictionary and json.has("choices"):
		var choices: Array = json["choices"]
		if choices.size() > 0:
			var choice: Dictionary = choices[0]
			var msg: Dictionary = choice.get("message", {})
			var text: String = msg.get("content", "").strip_edges()
			if text != "":
				_ai_result_text = text
			else:
				_ai_result_text = "AI 返回空内容"
		else:
			_ai_result_text = "AI 返回格式异常"
	else:
		_ai_result_text = "AI 返回格式异常"
	_refresh()


func _show_fallback(_t1: String, _t2: String) -> void:
	_reason_btn.disabled = false
	_ai_result_text = "这两条线索似乎没有什么联系"
	_refresh()


func _strip_clue_prefix(s: String) -> String:
	if s.begins_with("□ "):
		return s.substr(2)
	return s


func _add_new_clue(clue_text: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and "journal" in player and player.has_method("add_journal"):
		player.add_journal(clue_text)


func _try_show_tutorial() -> void:
	if SaveSystem.tutorial_journal_shown:
		return
	SaveSystem.tutorial_journal_shown = true
	SaveSystem.mark_dirty()
	_show_tutorial("日志 —— 记录所有任务进度、人物档案与已获线索。核心是内置 AI 助手：可以联系两条已知的线索，洞察背后的联系，标记尚未解开的疑点。当你面对拼图般的案件线索感到迷茫时——打开日志，让 AI 帮你把碎片拼成一张可以看清的地图。")


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
