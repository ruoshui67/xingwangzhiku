extends Control
## 主菜单 —— 新游戏 / 继续游戏 / 设置 / 退出游戏
##
## 背景图片：Background 为纯黑 ColorRect，BgImage 为可替换图片（默认隐藏）。
## 替换背景：在编辑器中给 BgImage 赋值 texture 并设为 visible=true 即可。

@export var game_scene_path: String = "res://scenes/Main.tscn"

@onready var _settings_panel: Panel = $SettingsPanel
@onready var _volume_slider: HSlider = $SettingsPanel/VolumeSlider
@onready var _volume_value: Label = $SettingsPanel/VolumeValue
@onready var _resolution_option: OptionButton = $SettingsPanel/ResolutionOption
@onready var _display_option: OptionButton = $SettingsPanel/DisplayOption
@onready var _btn_continue: Button = $MenuButtons/BtnContinue


func _ready() -> void:
	# 默认全屏
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 存档检测：无存档时继续游戏按钮变暗不可用
	if SaveSystem.has_save():
		_btn_continue.disabled = false
		_btn_continue.modulate = Color(1, 1, 1, 1)
	else:
		_btn_continue.disabled = true
		_btn_continue.modulate = Color(0.35, 0.35, 0.35, 1)

	# 初始化音量滑块
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	var linear := db_to_linear(db)
	_volume_slider.value = linear
	_volume_value.text = "%d%%" % int(linear * 100)

	# 同步当前分辨率
	var vp := get_viewport()
	var screen_size := vp.get_visible_rect().size
	for i in range(_resolution_option.item_count):
		var txt := _resolution_option.get_item_text(i)
		var parts := txt.split("x")
		if parts.size() == 2 and int(parts[0]) == int(screen_size.x) and int(parts[1]) == int(screen_size.y):
			_resolution_option.selected = i
			break

	# 同步显示模式（默认全屏）
	_display_option.selected = 1  # 全屏

	# 按钮信号
	$MenuButtons/BtnNewGame.pressed.connect(_on_new_game)
	$MenuButtons/BtnContinue.pressed.connect(_on_continue)
	$MenuButtons/BtnSettings.pressed.connect(_on_settings)
	$MenuButtons/BtnQuit.pressed.connect(_on_quit)
	$SettingsPanel/SettingsBackBtn.pressed.connect(_on_settings_back)

	# 设置面板中的交互
	_volume_slider.value_changed.connect(_on_volume_changed)
	_resolution_option.get_popup().id_pressed.connect(_on_resolution_changed)
	_display_option.get_popup().id_pressed.connect(_on_display_changed)

	# 暂停按键在菜单中直接退出
	_ensure_action("pause", [KEY_ESCAPE])


func _input(event: InputEvent) -> void:
	# 设置面板打开时，ESC 关闭设置面板
	if _settings_panel.visible and event.is_action_pressed("pause"):
		_on_settings_back()
		get_viewport().set_input_as_handled()


# ── 按钮回调 ──

func _play_start_sound() -> void:
	var audio := get_node_or_null("StartAudio")
	if not audio:
		audio = AudioStreamPlayer.new()
		audio.name = "StartAudio"
		audio.stream = load("res://assets/audio/start_game.mp3") as AudioStream
		add_child(audio)
	audio.play()


func _on_new_game() -> void:
	_play_start_sound()
	await get_tree().create_timer(0.3).timeout
	SaveSystem.delete_save()           # 新游戏清除旧存档
	SaveSystem.reset_npc_phase()
	SaveSystem._pending_load = false
	get_tree().change_scene_to_file(game_scene_path)


func _on_continue() -> void:
	if not SaveSystem.has_save():
		return
	_play_start_sound()
	await get_tree().create_timer(0.3).timeout
	SaveSystem._pending_load = true    # 通知 SaveSystem 场景加载后恢复存档
	get_tree().change_scene_to_file(game_scene_path)


func _on_settings() -> void:
	_settings_panel.visible = true


func _on_settings_back() -> void:
	_settings_panel.visible = false


func _on_quit() -> void:
	get_tree().quit()


# ── 设置回调 ──

func _on_volume_changed(value: float) -> void:
	var db := linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	_volume_value.text = "%d%%" % int(value * 100)


func _on_resolution_changed(idx: int) -> void:
	var txt := _resolution_option.get_item_text(idx)
	var parts := txt.split("x")
	if parts.size() != 2:
		return
	var w := int(parts[0])
	var h := int(parts[1])
	get_viewport().content_scale_size = Vector2i(w, h)
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(Vector2i(w, h))


func _on_display_changed(idx: int) -> void:
	if idx == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ── 工具 ──

func _ensure_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k
		InputMap.action_add_event(action, ev)
