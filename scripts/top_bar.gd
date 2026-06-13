extends Panel

@export var journal_panel_path: NodePath
@export var inventory_panel_path: NodePath
@export var skill_panel_path: NodePath

@onready var _journal_panel: CanvasItem = get_node_or_null(journal_panel_path)
@onready var _inventory_panel: CanvasItem = get_node_or_null(inventory_panel_path)
@onready var _skill_panel: CanvasItem = get_node_or_null(skill_panel_path)

@onready var _btn_journal: Button = get_node_or_null("Bar/HBox/BtnJournal") as Button
@onready var _btn_inventory: Button = get_node_or_null("Bar/HBox/BtnInventory") as Button
@onready var _btn_skill: Button = get_node_or_null("Bar/HBox/BtnSkill") as Button

var _panels: Array[CanvasItem] = []
var _buttons: Array[Button] = []
var _audio: AudioStreamPlayer

enum PanelID { INVENTORY, SKILL, JOURNAL }


func _ready() -> void:
	_panels = [_inventory_panel, _skill_panel, _journal_panel]
	_buttons = [_btn_inventory, _btn_skill, _btn_journal]
	_audio = AudioStreamPlayer.new()
	_audio.name = "UIOpenSound"
	_audio.stream = load("res://assets/audio/ui_open.mp3") as AudioStream
	_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_audio)
	for i in _buttons.size():
		if _buttons[i]:
			_buttons[i].pressed.connect(_toggle_panel.bind(i))
	_register_actions()


func _register_actions() -> void:
	_ensure_action("inventory", [KEY_B])
	_ensure_action("skill_panel", [KEY_TAB])
	_ensure_action("journal", [KEY_J])


func _is_dialogue_active() -> bool:
	var dlg := get_node_or_null("../DialogueBox") as CanvasItem
	if dlg and dlg.visible:
		return true
	var p2 := get_node_or_null("../Player2")
	if p2 and p2.has_method("_is_switch_open") and p2._is_switch_open():
		return true
	return false


func _process(_delta: float) -> void:
	if _is_dialogue_active():
		for btn in _buttons:
			if btn and btn.focus_mode != Control.FOCUS_NONE:
				btn.focus_mode = Control.FOCUS_NONE
	else:
		for btn in _buttons:
			if btn and btn.focus_mode == Control.FOCUS_NONE:
				btn.focus_mode = Control.FOCUS_ALL


func _input(event: InputEvent) -> void:
	if _is_dialogue_active():
		return
	if event.is_action_pressed("inventory"):
		_toggle_panel(PanelID.INVENTORY)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_panel"):
		_toggle_panel(PanelID.SKILL)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		_toggle_panel(PanelID.JOURNAL)
		get_viewport().set_input_as_handled()


func _toggle_panel(idx: int) -> void:
	if _is_dialogue_active():
		return
	var panel: CanvasItem = _panels[idx]
	if not panel:
		return
	var was_visible: bool = panel.visible
	# 关闭所有
	close_all()
	if not was_visible:
		panel.visible = true
		if _audio:
			_audio.play()


func close_all() -> void:
	for p in _panels:
		if p:
			p.visible = false


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
