extends Interactable

const DU = preload("res://scripts/shared/dialogue_utils.gd")

@export var dialogue_box_path: NodePath
@export var dialogue_label_path: NodePath
@export var dialogue_text: String = "村民：你好，旅行者。"
@export var dialogue_lines: Array[String] = [
	"村民：你好，旅行者。",
	"玩家：这里是哪里？",
	"村民：这里是雾丘镇，北边是旧矿坑。",
	"玩家：我在找一把失落的钥匙。",
	"村民：去找守门人，他在桥头。"
]
@export var speaker_sequence: Array[String] = ["npc", "player", "npc", "player", "npc"]
@export var type_speed: float = 28.0
@export var player_portrait_path: NodePath
@export var npc_portrait_path: NodePath
@export var npc_portrait_texture: Texture2D  # 每个 NPC 可绑定独立头像，为空时显示纯黑
@export var default_speaker: String = "npc"
@export var choice_panel_path: NodePath
@export var dice_panel_path: NodePath
@export var npc_name: String = "测试NPC"
@export var post_complete_text: String = ""
@export var ground_offset: float = 0.0  # 模型离地偏移（模型原点不在脚底时使用）

# ---- Player2 独立对话数据 ----
@export_group("Player2 Dialogue")
@export var p2_dialogue_lines: Array[String] = []
@export var p2_speaker_sequence: Array[String] = ["npc"]
@export var p2_choice_lines: Array[String] = []
@export var p2_choice_responses: Array[String] = []
@export var p2_choice_dice_idxs: Array[int] = []
@export var p2_choice_response_fail: String = ""
@export var p2_follow_up_lines: Array[String] = []
@export var p2_follow_up_speakers: Array[String] = []
@export var p2_follow_up_choice_lines: Array[String] = []
@export var p2_follow_up_choice_responses: Array[String] = []
@export var p2_follow_up_choice_dice_idxs: Array[int] = []
@export var p2_follow_up_choice_response_fail: String = ""
@export var p2_follow_up2_lines: Array[String] = []
@export var p2_follow_up2_speakers: Array[String] = []
@export var p2_follow_up2_choice_lines: Array[String] = []
@export var p2_follow_up2_choice_responses: Array[String] = []
@export var p2_follow_up2_choice_dice_idxs: Array[int] = []
@export var p2_follow_up2_choice_response_fail: String = ""
@export var p2_follow_up3_lines: Array[String] = []
@export var p2_follow_up3_speakers: Array[String] = []
@export var p2_follow_up3_choice_lines: Array[String] = []
@export var p2_follow_up3_choice_responses: Array[String] = []
@export var p2_follow_up3_choice_dice_idxs: Array[int] = []
@export var p2_follow_up3_choice_response_fail: String = ""
@export var p2_follow_up4_lines: Array[String] = []
@export var p2_follow_up4_speakers: Array[String] = []
@export var p2_follow_up4_choice_lines: Array[String] = []
@export var p2_follow_up4_choice_responses: Array[String] = []
@export var p2_follow_up4_choice_dice_idxs: Array[int] = []
@export var p2_follow_up4_choice_response_fail: String = ""
@export var p2_scene_end_text: String = ""
@export var p2_post_complete_text: String = ""

var _dialogue_index: int = 0
var _current_full_text: String = ""
var _type_index: int = 0
var _type_timer: float = 0.0
var _is_typing: bool = false
var _dialogue_finished: bool = false
var _dice_phase: bool = false
var _dice_required: int = 6
var _mouse_was_pressed: bool = false
var _history_text: String = ""
var _p1_dialogue_ever_completed: bool = false
var _p2_dialogue_ever_completed: bool = false
var _is_post_dialogue: bool = false
var _using_p2: bool = false
var _p1_backup: Dictionary = {}
# 类型化备份（Dictionary 存取丢失 Array 泛型，Godot 4.6 报错）
var _b_d_lines: Array[String] = []
var _b_d_speakers: Array[String] = []
var _b_c_lines: Array[String] = []
var _b_c_responses: Array[String] = []
var _b_c_dice: Array[int] = []
var _b_c_fail: String = ""
var _b_f1_lines: Array[String] = []
var _b_f1_speakers: Array[String] = []
var _b_f1_c_lines: Array[String] = []
var _b_f1_c_responses: Array[String] = []
var _b_f1_c_dice: Array[int] = []
var _b_f1_c_fail: String = ""
var _b_f2_lines: Array[String] = []
var _b_f2_speakers: Array[String] = []
var _b_f2_c_lines: Array[String] = []
var _b_f2_c_responses: Array[String] = []
var _b_f2_c_dice: Array[int] = []
var _b_f2_c_fail: String = ""
var _b_f3_lines: Array[String] = []
var _b_f3_speakers: Array[String] = []
var _b_f3_c_lines: Array[String] = []
var _b_f3_c_responses: Array[String] = []
var _b_f3_c_dice: Array[int] = []
var _b_f3_c_fail: String = ""
var _b_f4_lines: Array[String] = []
var _b_f4_speakers: Array[String] = []
var _b_f4_c_lines: Array[String] = []
var _b_f4_c_responses: Array[String] = []
var _b_f4_c_dice: Array[int] = []
var _b_f4_c_fail: String = ""
var _b_c_journal: Array[String] = []
var _b_f1_journal: Array[String] = []
var _b_f2_journal: Array[String] = []
var _b_f3_journal: Array[String] = []
var _b_f4_journal: Array[String] = []
var _b_scene_end: String = ""
var _b_post: String = ""

@onready var _dialogue_box: CanvasItem = get_node_or_null(dialogue_box_path)
@onready var _dialogue_label: RichTextLabel = get_node_or_null(dialogue_label_path) as RichTextLabel
@onready var _player_portrait: CanvasItem = get_node_or_null(player_portrait_path) as CanvasItem
@onready var _npc_portrait: CanvasItem = get_node_or_null(npc_portrait_path) as CanvasItem
@onready var _choice_panel: Panel = get_node_or_null(choice_panel_path)
@onready var _dice_panel: Panel = get_node_or_null(dice_panel_path)


func _ready() -> void:
	super._ready()
	_setup_highlight()
	_setup_npc_animation()
	# 选择音效
	var choice_audio := AudioStreamPlayer.new()
	choice_audio.name = "ChoiceAudio"
	choice_audio.stream = load("res://assets/audio/choice_select.mp3") as AudioStream
	choice_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(choice_audio)
	if _dialogue_box:
		_dialogue_box.visible = false
	if _dialogue_label:
		_dialogue_label.text = _get_line_text(0)
		if not _dialogue_box:
			_dialogue_label.visible = false
		if not _dialogue_label.meta_clicked.is_connected(_on_choice_meta_clicked):
			_dialogue_label.meta_clicked.connect(_on_choice_meta_clicked)
	_set_portrait_visibility(false)
	_set_speaker(default_speaker)
	_connect_choice_buttons()
	_create_shadow()
	_create_guide_mark()
	# 初始在屋外的 NPC 禁用且隐藏
	if npc_name in ["汉斯", "迪特尔", "莫罗"]:
		process_mode = Node.PROCESS_MODE_DISABLED
		visible = false


var _npc_gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var velocity := Vector3.ZERO  # 手动声明，StaticBody3D 没有内置 velocity


func _physics_process(delta: float) -> void:
	# 射线向下检测地面
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.from = global_position + Vector3(0, 0.5, 0)
	query.to = global_position + Vector3(0, -10, 0)
	query.exclude = [self.get_rid()]
	var result := space.intersect_ray(query)
	if not result.is_empty():
		velocity.y = 0.0
		global_position.y = result["position"].y + ground_offset
	else:
		velocity.y -= _npc_gravity * delta
		global_position += velocity * delta


func _on_player_exit() -> void:
	_set_dialogue_visible(false)
	_hide_panels()


func _process(delta: float) -> void:
	super._process(delta)
	_update_shadow()
	_update_guide_mark()
	_follow_up_click_guard = max(0.0, _follow_up_click_guard - delta)
	if not _player_in_range:
		return
	_update_typing(delta)

	# 左键仅用于跳过打字机动画
	var mouse_down: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var just_clicked := mouse_down and not _mouse_was_pressed
	_mouse_was_pressed = mouse_down

	if just_clicked:
		if _choice_panel and _choice_panel.visible:
			return
		if _dice_panel and _dice_panel.visible:
			return
		if not _is_dialogue_visible():
			return
		if _follow_up_click_guard > 0.0:
			return
		if _dialogue_finished:
			if _choices_displayed:
				return
			_is_post_dialogue = false
			# 迪特尔 P1：不转场，标记等 P1 去找 P2 触发独白，禁用 NPC 防止再次对话
			if npc_name == "迪特尔" and not SaveSystem.dieter_p1_done:
				SaveSystem.dieter_p1_done = true
				SaveSystem.monologue_pending = true
				_set_dialogue_visible(false)
				process_mode = Node.PROCESS_MODE_DISABLED
				return
			# 莫罗：仅 Player2 交互时标记终局独白并黑屏转场移出
			if npc_name == "莫罗" and _using_p2:
				SaveSystem.moro_finale_pending = true
				_set_dialogue_visible(false)
				_start_scene_transition()
				return
			if npc_name in ["卡尔", "汉斯", "迪特尔"]:
				_start_scene_transition()
			else:
				_set_dialogue_visible(false)
			return
		if _is_typing:
			_finish_typing()
			if _is_post_dialogue:
				_dialogue_finished = true
			if _awaiting_follow_up:
				_follow_up_click_guard = 0.15
		elif _scene_ending:
			_show_exit_button()
		elif _auto_advance_timer > 0.0:
			# 鼠标点击跳过等待，立即前进
			_auto_advance_timer = 0.0
			if _awaiting_follow_up:
				_awaiting_follow_up = false
				_start_follow_up()
			else:
				_advance_dialogue()

	# 自动前进：打字完成后等待 0.5 秒自动播下一句
	if not _is_typing and _is_dialogue_visible() and not _dialogue_finished and not _scene_ending:
		_auto_advance_timer += delta
		if _auto_advance_timer >= 0.5:
			_auto_advance_timer = 0.0
			if _awaiting_follow_up:
				_awaiting_follow_up = false
				_start_follow_up()
			else:
				_advance_dialogue()
	else:
		_auto_advance_timer = 0.0

	# F 键开始对话（仅高亮中的最近对象响应）
	if Input.is_action_just_pressed("interact"):
		if not _is_dialogue_visible() and not _dialogue_finished and _prompt_label and _prompt_label.visible:
			_start_dialogue()


# ---- 对话 ----

func _is_dialogue_visible() -> bool:
	if _dialogue_box:
		return _dialogue_box.visible
	if _dialogue_label:
		return _dialogue_label.visible
	return false


func _set_dialogue_visible(visible: bool) -> void:
	if _dialogue_box:
		_dialogue_box.visible = visible
	elif _dialogue_label:
		_dialogue_label.visible = visible
	_set_portrait_visibility(visible)
	if visible:
		_apply_portrait_textures()
		_apply_dialogue_line(_dialogue_index)
	else:
		if _active_speaker == npc_name:
			_active_speaker = ""
		var scene2 := get_tree().current_scene
		if scene2:
			var icon2: TextureRect = scene2.get_node_or_null("UI/SkillIcon") as TextureRect
			if icon2: icon2.visible = false
		_dialogue_index = 0
		_is_typing = false
		_dialogue_finished = false
		_awaiting_follow_up = false
		_history_text = ""
		_choices_displayed = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)


static var _active_speaker: String = ""

func _start_dialogue() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_using_p2 = _is_player2_interacting() and p2_dialogue_lines.size() > 0
	_active_speaker = npc_name  # 标记当前活跃发言者
	
	if _using_p2:
		_swap_to_p2()
	else:
		_restore_p1()
	
	if _get_dialogue_ever_completed() and post_complete_text != "":
		_show_post_dialogue()
		return
	_dialogue_index = 0
	_round_index = 0
	_dialogue_finished = false
	_history_text = ""
	_dice_required = 6  # 重置骰子难度
	_active_journal_clues.clear()
	_active_journal_clues.append_array(choice_journal_clues)
	# 对话开始时自动获得该 NPC 所有线索（确保玩家不会因选项遗漏）
	_grant_all_clues()
	_set_dialogue_box_visible(true)
	_set_portrait_visibility(true)
	_apply_portrait_textures()
	_update_name_labels()
	_apply_dialogue_line(_dialogue_index)


# 对话开始时自动授予所有线索（所有轮次的 choice_journal_clues 汇总）
func _grant_all_clues() -> void:
	var all_clues: Array[String] = []
	if _using_p2:
		all_clues.append_array(p2_choice_journal_clues)
		all_clues.append_array(p2_follow_up_choice_journal_clues)
		all_clues.append_array(p2_follow_up2_choice_journal_clues)
		all_clues.append_array(p2_follow_up3_choice_journal_clues)
		all_clues.append_array(p2_follow_up4_choice_journal_clues)
	else:
		all_clues.append_array(choice_journal_clues)
		all_clues.append_array(follow_up_choice_journal_clues)
		all_clues.append_array(follow_up2_choice_journal_clues)
		all_clues.append_array(follow_up3_choice_journal_clues)
		all_clues.append_array(follow_up4_choice_journal_clues)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_journal"):
		for clue in all_clues:
			if clue != "":
				player.add_journal(clue)
		SaveSystem.mark_dirty()


# 读档恢复对话（不重新开始，直接显示已保存的进度）
func _resume_dialogue() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_active_speaker = npc_name  # 恢复活跃发言者标记
	_set_dialogue_box_visible(true)
	_set_portrait_visibility(true)
	_apply_portrait_textures()  # 恢复双方肖像（含玩家侧）
	_update_name_labels()
	# 恢复对话文本显示（_history_text 已在存档中保存完整内容，直接显示）
	if _dialogue_label:
		if _dialogue_finished and _choices_displayed:
			# 选项显示中：_history_text 已包含选项，直接渲染
			_dialogue_label.text = _history_text
		elif _dialogue_finished:
			_dialogue_label.text = _history_text
		elif _is_typing and _type_index > 0:
			_dialogue_label.text = _history_text + _current_full_text.substr(0, _type_index)
		else:
			_dialogue_label.text = _history_text + _current_full_text
		_dialogue_label.visible_characters = -1


func _is_player2_interacting() -> bool:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	var closest := players[0]
	var min_dist := global_position.distance_squared_to(closest.global_position)
	for p in players:
		var d := global_position.distance_squared_to(p.global_position)
		if d < min_dist:
			closest = p
			min_dist = d
	return closest is Node and closest.name.to_lower().begins_with("player2")


func _swap_to_p2() -> void:
	if p2_dialogue_lines.is_empty():
		return
	if _p1_backup.is_empty():
		_b_d_lines = dialogue_lines.duplicate()
		_b_d_speakers = speaker_sequence.duplicate()
		_b_c_lines = choice_lines.duplicate()
		_b_c_responses = choice_responses.duplicate()
		_b_c_dice = choice_dice_idxs.duplicate()
		_b_c_fail = choice_response_fail
		_b_f1_lines = follow_up_lines.duplicate()
		_b_f1_speakers = follow_up_speakers.duplicate()
		_b_f1_c_lines = follow_up_choice_lines.duplicate()
		_b_f1_c_responses = follow_up_choice_responses.duplicate()
		_b_f1_c_dice = follow_up_choice_dice_idxs.duplicate()
		_b_f1_c_fail = follow_up_choice_response_fail
		_b_f2_lines = follow_up2_lines.duplicate()
		_b_f2_speakers = follow_up2_speakers.duplicate()
		_b_f2_c_lines = follow_up2_choice_lines.duplicate()
		_b_f2_c_responses = follow_up2_choice_responses.duplicate()
		_b_f2_c_dice = follow_up2_choice_dice_idxs.duplicate()
		_b_f2_c_fail = follow_up2_choice_response_fail
		_b_f3_lines = follow_up3_lines.duplicate()
		_b_f3_speakers = follow_up3_speakers.duplicate()
		_b_f3_c_lines = follow_up3_choice_lines.duplicate()
		_b_f3_c_responses = follow_up3_choice_responses.duplicate()
		_b_f3_c_dice = follow_up3_choice_dice_idxs.duplicate()
		_b_f3_c_fail = follow_up3_choice_response_fail
		_b_f4_lines = follow_up4_lines.duplicate()
		_b_f4_speakers = follow_up4_speakers.duplicate()
		_b_f4_c_lines = follow_up4_choice_lines.duplicate()
		_b_f4_c_responses = follow_up4_choice_responses.duplicate()
		_b_f4_c_dice = follow_up4_choice_dice_idxs.duplicate()
		_b_f4_c_fail = follow_up4_choice_response_fail
		_b_c_journal = choice_journal_clues.duplicate()
		_b_f1_journal = follow_up_choice_journal_clues.duplicate()
		_b_f2_journal = follow_up2_choice_journal_clues.duplicate()
		_b_f3_journal = follow_up3_choice_journal_clues.duplicate()
		_b_f4_journal = follow_up4_choice_journal_clues.duplicate()
		_b_scene_end = scene_end_text
		_b_post = post_complete_text
	dialogue_lines = p2_dialogue_lines
	speaker_sequence = p2_speaker_sequence
	choice_lines = p2_choice_lines
	choice_responses = p2_choice_responses
	choice_dice_idxs = p2_choice_dice_idxs
	choice_response_fail = p2_choice_response_fail
	choice_dice_idx = -1
	follow_up_lines = p2_follow_up_lines
	follow_up_speakers = p2_follow_up_speakers
	follow_up_choice_lines = p2_follow_up_choice_lines
	follow_up_choice_responses = p2_follow_up_choice_responses
	follow_up_choice_dice_idxs = p2_follow_up_choice_dice_idxs
	follow_up_choice_response_fail = p2_follow_up_choice_response_fail
	follow_up2_lines = p2_follow_up2_lines
	follow_up2_speakers = p2_follow_up2_speakers
	follow_up2_choice_lines = p2_follow_up2_choice_lines
	follow_up2_choice_responses = p2_follow_up2_choice_responses
	follow_up2_choice_dice_idxs = p2_follow_up2_choice_dice_idxs
	follow_up2_choice_response_fail = p2_follow_up2_choice_response_fail
	follow_up3_lines = p2_follow_up3_lines
	follow_up3_speakers = p2_follow_up3_speakers
	follow_up3_choice_lines = p2_follow_up3_choice_lines
	follow_up3_choice_responses = p2_follow_up3_choice_responses
	follow_up3_choice_dice_idxs = p2_follow_up3_choice_dice_idxs
	follow_up3_choice_response_fail = p2_follow_up3_choice_response_fail
	follow_up4_lines = p2_follow_up4_lines
	follow_up4_speakers = p2_follow_up4_speakers
	follow_up4_choice_lines = p2_follow_up4_choice_lines
	follow_up4_choice_responses = p2_follow_up4_choice_responses
	follow_up4_choice_dice_idxs = p2_follow_up4_choice_dice_idxs
	follow_up4_choice_response_fail = p2_follow_up4_choice_response_fail
	choice_journal_clues = p2_choice_journal_clues
	follow_up_choice_journal_clues = p2_follow_up_choice_journal_clues
	follow_up2_choice_journal_clues = p2_follow_up2_choice_journal_clues
	follow_up3_choice_journal_clues = p2_follow_up3_choice_journal_clues
	follow_up4_choice_journal_clues = p2_follow_up4_choice_journal_clues
	scene_end_text = p2_scene_end_text
	post_complete_text = p2_post_complete_text


func _restore_p1() -> void:
	if _b_d_lines.is_empty() and _b_c_lines.is_empty():
		return
	dialogue_lines = _b_d_lines
	speaker_sequence = _b_d_speakers
	choice_lines = _b_c_lines
	choice_responses = _b_c_responses
	choice_dice_idxs = _b_c_dice
	choice_response_fail = _b_c_fail
	follow_up_lines = _b_f1_lines
	follow_up_speakers = _b_f1_speakers
	follow_up_choice_lines = _b_f1_c_lines
	follow_up_choice_responses = _b_f1_c_responses
	follow_up_choice_dice_idxs = _b_f1_c_dice
	follow_up_choice_response_fail = _b_f1_c_fail
	follow_up2_lines = _b_f2_lines
	follow_up2_speakers = _b_f2_speakers
	follow_up2_choice_lines = _b_f2_c_lines
	follow_up2_choice_responses = _b_f2_c_responses
	follow_up2_choice_dice_idxs = _b_f2_c_dice
	follow_up2_choice_response_fail = _b_f2_c_fail
	follow_up3_lines = _b_f3_lines
	follow_up3_speakers = _b_f3_speakers
	follow_up3_choice_lines = _b_f3_c_lines
	follow_up3_choice_responses = _b_f3_c_responses
	follow_up3_choice_dice_idxs = _b_f3_c_dice
	follow_up3_choice_response_fail = _b_f3_c_fail
	follow_up4_lines = _b_f4_lines
	follow_up4_speakers = _b_f4_speakers
	follow_up4_choice_lines = _b_f4_c_lines
	follow_up4_choice_responses = _b_f4_c_responses
	follow_up4_choice_dice_idxs = _b_f4_c_dice
	follow_up4_choice_response_fail = _b_f4_c_fail
	choice_journal_clues = _b_c_journal
	follow_up_choice_journal_clues = _b_f1_journal
	follow_up2_choice_journal_clues = _b_f2_journal
	follow_up3_choice_journal_clues = _b_f3_journal
	follow_up4_choice_journal_clues = _b_f4_journal
	scene_end_text = _b_scene_end
	post_complete_text = _b_post


func _get_dialogue_ever_completed() -> bool:
	return _p2_dialogue_ever_completed if _using_p2 else _p1_dialogue_ever_completed


func _set_dialogue_ever_completed(val: bool) -> void:
	if _using_p2:
		_p2_dialogue_ever_completed = val
	else:
		_p1_dialogue_ever_completed = val


func _show_post_dialogue() -> void:
	_is_post_dialogue = true
	_dialogue_finished = false
	_current_full_text = post_complete_text
	_history_text = ""
	_type_index = 0
	_type_timer = 0.0
	_is_typing = true
	_set_dialogue_box_visible(true)
	_set_portrait_visibility(false)
	if _dialogue_label:
		_dialogue_label.text = ""
		_dialogue_label.visible_characters = -1
	_set_speaker("npc")


# 设置名字标签：左侧=当前控制角色名, 右侧=NPC的npc_name
func _update_name_labels() -> void:
	# 左侧名字 = 当前玩家名
	var name_player: Label = get_node_or_null("../UI/DialogueBox/NamePlayer")
	if name_player:
		var active := get_tree().get_first_node_in_group("player")
		if active and active.name == "Player1":
			name_player.text = "弗莱"
		elif active and active.name == "Player2":
			name_player.text = "杜瓦尔"
		else:
			name_player.text = "弗莱"
	# 右侧名字 = npc_name
	var name_npc: Label = get_node_or_null("../UI/DialogueBox/NameNpc")
	if name_npc:
		name_npc.text = npc_name


func _advance_dialogue() -> void:
	_dialogue_index += 1
	SaveSystem.mark_dirty()
	if _dialogue_index >= _get_line_count():
		_on_dialogue_complete()
		return
	_apply_dialogue_line(_dialogue_index)


func _on_dialogue_complete() -> void:
	_dialogue_finished = true
	_set_dialogue_ever_completed(true)
	var scene3 := get_tree().current_scene
	if scene3:
		var icon3: TextureRect = scene3.get_node_or_null("UI/SkillIcon") as TextureRect
		if icon3: icon3.visible = false
	# 将最后一句对话加入历史记录
	_history_text += _apply_skill_color(_current_full_text) + "\n\n"
	_current_full_text = ""
	if choice_lines.size() > 0:
		_show_choice_panel()
	else:
		_history_text += "\n\n>>> 点击结束对话 <<<"
		if _dialogue_label:
			_dialogue_label.text = _history_text


func _get_line_count() -> int:
	return dialogue_lines.size() if dialogue_lines.size() > 0 else 1


func _get_line_text(index: int) -> String:
	if dialogue_lines.size() == 0:
		return dialogue_text
	return dialogue_lines[clamp(index, 0, dialogue_lines.size() - 1)]


func _get_speaker(index: int) -> String:
	if speaker_sequence.size() == 0:
		return default_speaker
	return speaker_sequence[clamp(index, 0, speaker_sequence.size() - 1)]


func _apply_dialogue_line(index: int) -> void:
	var line: String = _get_line_text(index)
	var speaker: String = _get_speaker(index)
	# 上一句已完成，追加到历史（带技能颜色）
	if _current_full_text != "":
		_history_text += _apply_skill_color(_current_full_text) + "\n\n"
	_start_typing(line)
	_set_speaker(speaker)


# ---- 打字机 ----

# 技能图标映射：技能名 → 资源路径（男版 . 女版）
const _SKILL_ICON_PATH := "res://assets/textures/skill_icons/%s"
const _SKILL_ICON_MAP := {
	"普鲁士纪律": "prussian_discipline.png",
	"莱茵河畔":   "rhine_riverbank_%s.png",
	"帝国幽灵":   "empire_ghost_%s.png",
	"红衣逻辑":   "red_logic_%s.png",
	"灰烬喉":    "ash_throat_%s.png",
	"枯玫瑰":    "withered_rose_%s.png",
	"红色脉搏":   "red_pulse_%s.png",
	"铁十字":    "iron_cross_%s.png",
	"共和国准则":  "republic_principle.png",
	"三段论":    "syllogism.png",
	"三色旗":    "tricolor.png",
}

func _apply_skill_color(text: String) -> String:
	var start := text.find("【")
	var end := text.find("】")
	if start == 0 and end != -1:
		var tag := text.substr(start + 1, end - start - 1)
		var color: String = DU.SKILL_COLOR_MAP.get(tag, "")
		if color != "":
			return "[color=" + color + "]" + text + "[/color]"
	return text

func _get_display_text() -> String:
	return _history_text + _apply_skill_color(_current_full_text)


# 打字过程中的着色文本（不截断 BBCode 标签）
func _get_typing_text() -> String:
	var typed := _current_full_text.substr(0, _type_index)
	var color: String = ""
	var start := _current_full_text.find("【")
	var end := _current_full_text.find("】")
	if start == 0 and end != -1:
		var tag := _current_full_text.substr(start + 1, end - start - 1)
		color = DU.SKILL_COLOR_MAP.get(tag, "")
	if color != "":
		return _history_text + "[color=" + color + "]" + typed + "[/color]"
	return _history_text + typed


func _update_skill_icon(text: String) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var icon: TextureRect = scene.get_node_or_null("UI/SkillIcon") as TextureRect
	if not icon:
		return
	var tag := _extract_skill_tag(text)
	if tag == "":
		icon.visible = false
		return
	# 查找图标文件名
	var filename: String = _SKILL_ICON_MAP.get(tag, "")
	if filename == "":
		icon.visible = false
		return
	# 含 %s 需按性别替换（m=男, f=女）
	if "%s" in filename:
		filename = filename % ("f" if _using_p2 else "m")
	icon.texture = load(_SKILL_ICON_PATH % filename)
	icon.visible = true


func _start_typing(text: String) -> void:
	_current_full_text = text
	_type_index = 0
	_type_timer = 0.0
	_is_typing = true
	# 技能图标：检测当前文本中的技能标签并显示对应图标
	_update_skill_icon(text)
	if not _dialogue_label:
		_is_typing = false


func _update_typing(delta: float) -> void:
	if not _is_typing:
		return
	if type_speed <= 0.0:
		_finish_typing()
		return
	_type_timer += delta
	var step := 1.0 / type_speed
	while _type_timer >= step and _type_index < _current_full_text.length():
		_type_timer -= step
		_type_index += 1
	if _dialogue_label:
		_dialogue_label.text = _get_typing_text()
		_dialogue_label.visible_characters = -1
	if _type_index >= _current_full_text.length():
		_is_typing = false
		if _dialogue_label:
			_dialogue_label.text = _get_display_text()


func _finish_typing() -> void:
	_is_typing = false
	_type_timer = 0.0
	_type_index = _current_full_text.length()
	if _dialogue_label:
		_dialogue_label.text = _get_display_text()




# ---- 头像 ----

func _set_portrait_visibility(visible: bool) -> void:
	if _player_portrait:
		_player_portrait.visible = visible
	if _npc_portrait:
		_npc_portrait.visible = visible


func _apply_portrait_textures() -> void:
	# NPC 侧：使用该 NPC 绑定的图片，未设置则纯黑
	if _npc_portrait and _npc_portrait is TextureRect:
		_npc_portrait.texture = npc_portrait_texture if npc_portrait_texture else _make_solid_color_texture(Color(0, 0, 0, 1))

	# 玩家侧：根据当前活跃玩家选择头像
	if _player_portrait and _player_portrait is TextureRect:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.name.to_lower().begins_with("player2"):
			_player_portrait.texture = load("res://assets/portraits/player2.png")
		else:
			_player_portrait.texture = load("res://assets/portraits/player1.png")


## 生成纯色 128×512 纹理（NPC 默认肖像用）
func _make_solid_color_texture(color: Color) -> ImageTexture:
	var img := Image.create(128, 512, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _set_speaker(_speaker: String) -> void:
	if _player_portrait:
		_player_portrait.modulate = Color(1, 1, 1, 1)
	if _npc_portrait:
		_npc_portrait.modulate = Color(1, 1, 1, 1)


# ---- 选项 & 骰子 ----
@export var choice_lines: Array[String] = []     # 选项按钮文字
@export var choice_responses: Array[String] = []  # 各选项对应 NPC 回应
@export var choice_journal_clues: Array[String] = []  # 各选项获得的日志线索
@export var choice_dice_idx: int = -1              # 需要骰子的选项索引（-1=无）
@export var choice_dice_idxs: Array[int] = []      # 多个骰子选项（优先于此）
@export var choice_response_fail: String = ""      # 骰子失败时的回应
@export var follow_up_lines: Array[String] = []    # 选项后的统一后续对话
@export var follow_up_speakers: Array[String] = [] # 后续对话的说话者
@export var follow_up_choice_lines: Array[String] = []     # 第二轮选项
@export var follow_up_choice_responses: Array[String] = []  # 第二轮回应
@export var follow_up_choice_journal_clues: Array[String] = []
@export var follow_up_choice_dice_idx: int = -1
@export var follow_up_choice_dice_idxs: Array[int] = []
@export var follow_up_choice_response_fail: String = ""
@export var follow_up2_lines: Array[String] = []
@export var follow_up2_speakers: Array[String] = []
@export var follow_up2_choice_lines: Array[String] = []
@export var follow_up2_choice_responses: Array[String] = []
@export var follow_up2_choice_journal_clues: Array[String] = []
@export var follow_up2_choice_dice_idxs: Array[int] = []
@export var p2_choice_journal_clues: Array[String] = []
@export var p2_follow_up_choice_journal_clues: Array[String] = []
@export var p2_follow_up2_choice_journal_clues: Array[String] = []
@export var p2_follow_up3_choice_journal_clues: Array[String] = []
@export var p2_follow_up4_choice_journal_clues: Array[String] = []
@export var follow_up2_choice_response_fail: String = ""
@export var follow_up3_lines: Array[String] = []
@export var follow_up3_speakers: Array[String] = []
@export var follow_up3_choice_lines: Array[String] = []
@export var follow_up3_choice_responses: Array[String] = []
@export var follow_up3_choice_journal_clues: Array[String] = []
@export var follow_up3_choice_dice_idxs: Array[int] = []
@export var follow_up3_choice_response_fail: String = ""
@export var follow_up4_lines: Array[String] = []
@export var follow_up4_speakers: Array[String] = []
@export var follow_up4_choice_lines: Array[String] = []
@export var follow_up4_choice_responses: Array[String] = []
@export var follow_up4_choice_journal_clues: Array[String] = []
@export var follow_up4_choice_dice_idxs: Array[int] = []
@export var follow_up4_choice_response_fail: String = ""
@export var scene_end_text: String = ""

var _choice_selected: int = -1
var _awaiting_follow_up: bool = false
var _follow_up_click_guard: float = 0.0
var _round_index: int = 0
var _scene_ending: bool = false
var _active_journal_clues: Array[String] = []
var _auto_advance_timer: float = 0.0  # 打字完成后自动前进计时器
var _choices_displayed: bool = false  # 选项内联显示中
var _history_before_choices: String = ""  # 显示选项前的历史，做完选择后恢复
var _guide_mark: Sprite3D  # 初次对话引导感叹号

func _connect_choice_buttons() -> void:
	if not _choice_panel:
		return
	for i in 5:
		var btn: Button = _choice_panel.get_node_or_null("ChoiceOption" + str(i + 1)) as Button
		if btn:
			btn.pressed.connect(_on_choice_pressed.bind(i))
	var exit_btn: Button = _choice_panel.get_node_or_null("ChoiceExit") as Button
	if exit_btn:
		exit_btn.pressed.connect(_on_choice_exit)


func _show_choice_panel() -> void:
	# 在对话框内显示选项，不弹出独立窗口
	_choices_displayed = true
	_history_before_choices = _history_text  # 保存选择前的历史
	_set_dialogue_box_visible(true)
	var choice_text := "\n请选择：\n"
	for i in choice_lines.size():
		choice_text += "[color=#FFD700][url=" + str(i) + "]" + str(i + 1) + ". " + choice_lines[i] + "[/url][/color]\n"
	_history_text += choice_text
	if _dialogue_label:
		_dialogue_label.text = _history_text


func _on_choice_meta_clicked(meta: String) -> void:
	if not _choices_displayed:
		return
	_choices_displayed = false
	var idx := int(meta)
	if idx >= 0 and idx < choice_lines.size():
		_on_choice_pressed(idx)


func _play_choice_sound() -> void:
	var audio: AudioStreamPlayer = get_node_or_null("ChoiceAudio")
	if audio:
		audio.play()


func _on_choice_pressed(idx: int) -> void:
	_play_choice_sound()
	_choice_selected = idx
	_choice_panel.visible = false
	if idx in choice_dice_idxs or idx == choice_dice_idx:
		choice_dice_idx = idx  # 临时记录
		_dice_required = _get_dice_difficulty(choice_lines[idx])
		_roll_dice()
		return
	_apply_choice_response(idx)


func _apply_choice_response(idx: int, dice_bonus: bool = false) -> void:
	_awaiting_follow_up = true
	_history_text = _history_before_choices  # 删去选项文字
	_set_dialogue_box_visible(true)
	# 记录玩家选择的选项到对话历史
	if idx < choice_lines.size() and choice_lines[idx] != "":
		_history_text += "\n\n[我] " + _apply_skill_color(choice_lines[idx]) + "\n"
	# 技能经验值：选择即 +5，判定成功再加 +5
	_award_skill_xp(idx, 5)
	if dice_bonus:
		_award_skill_xp(idx, 5)
	if idx < choice_responses.size() and choice_responses[idx] != "":
		var resp := choice_responses[idx]
		_current_full_text = resp
		_history_text += "\n\n"
		_type_index = 0
		_type_timer = 0.0
		_is_typing = true
		_dialogue_finished = false
		if _dialogue_label:
			_dialogue_label.visible_characters = -1
		_set_portrait_visibility(true)
		_set_speaker("npc")
	else:
		_start_follow_up()


func _play_sfx(name: String) -> void:
	var path := "res://assets/audio/" + name
	var audio := get_node_or_null("SFX_" + name)
	if not audio:
		audio = AudioStreamPlayer.new()
		audio.name = "SFX_" + name
		audio.stream = load(path) as AudioStream
		audio.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(audio)
	audio.play()


func _on_dice_success() -> void:
	_play_sfx("dice_success.mp3")
	_apply_choice_response(choice_dice_idx, true)


func _on_dice_fail() -> void:
	_play_sfx("dice_fail.mp3")
	_awaiting_follow_up = true
	if choice_response_fail != "":
		_set_dialogue_box_visible(true)
		_current_full_text = choice_response_fail
		_history_text += "\n\n"
		_type_index = 0
		_type_timer = 0.0
		_is_typing = true
		_dialogue_finished = false
		if _dialogue_label:
			_dialogue_label.visible_characters = -1
		_set_portrait_visibility(true)
		_set_speaker("npc")
	else:
		_start_follow_up()


func _start_typewriter_from_text(text: String) -> void:
	_is_typing = true
	_dialogue_finished = false
	_type_index = 0
	_type_timer = 0.0
	_history_text = ""
	if _dialogue_label:
		_dialogue_label.text = ""
		_dialogue_label.visible_characters = -1
	_set_portrait_visibility(true)
	_set_speaker("npc")


func _finish_choice_or_follow() -> void:
	if follow_up_lines.size() > 0:
		_start_follow_up()
	else:
		_dialogue_index = 0
		_set_dialogue_visible(false)


func _start_follow_up() -> void:
	_awaiting_follow_up = false
	_dialogue_index = 0
	_round_index += 1
	# 按轮次切换数据
	var lines: Array[String] = []
	var speakers: Array[String] = []
	var clines: Array[String] = []
	var cresps: Array[String] = []
	var journal_arr: Array[String] = []
	var cdice: Array[int] = []
	var cfail: String = ""
	match _round_index:
		0:
			journal_arr.assign(choice_journal_clues)
		1:
			lines.assign(follow_up_lines)
			speakers.assign(follow_up_speakers)
			clines.assign(follow_up_choice_lines)
			cresps.assign(follow_up_choice_responses)
			journal_arr.assign(follow_up_choice_journal_clues)
			cdice.assign(follow_up_choice_dice_idxs)
			cfail = follow_up_choice_response_fail
		2:
			lines.assign(follow_up2_lines)
			speakers.assign(follow_up2_speakers)
			clines.assign(follow_up2_choice_lines)
			cresps.assign(follow_up2_choice_responses)
			journal_arr.assign(follow_up2_choice_journal_clues)
			cdice.assign(follow_up2_choice_dice_idxs)
			cfail = follow_up2_choice_response_fail
		3:
			lines.assign(follow_up3_lines)
			speakers.assign(follow_up3_speakers)
			clines.assign(follow_up3_choice_lines)
			cresps.assign(follow_up3_choice_responses)
			journal_arr.assign(follow_up3_choice_journal_clues)
			cdice.assign(follow_up3_choice_dice_idxs)
			cfail = follow_up3_choice_response_fail
		4:
			lines.assign(follow_up4_lines)
			speakers.assign(follow_up4_speakers)
			clines.assign(follow_up4_choice_lines)
			cresps.assign(follow_up4_choice_responses)
			journal_arr.assign(follow_up4_choice_journal_clues)
			cdice.assign(follow_up4_choice_dice_idxs)
			cfail = follow_up4_choice_response_fail
	# 更新数据
	dialogue_lines = lines
	speaker_sequence = speakers
	choice_lines = clines
	choice_responses = cresps
	_active_journal_clues.clear()
	_active_journal_clues.append_array(journal_arr)
	choice_dice_idxs = cdice
	choice_response_fail = cfail
	_is_typing = false
	_dialogue_finished = false
	if _current_full_text != "":
		_history_text += _apply_skill_color(_current_full_text) + "\n"
	_current_full_text = ""
	_type_index = 0
	_type_timer = 0.0
	_history_text += "\n"
	if dialogue_lines.size() > 0:
		_dialogue_box.visible = true
		_set_portrait_visibility(true)
		_set_speaker(speaker_sequence[0] if speaker_sequence.size() > 0 else "npc")
		_apply_dialogue_line(0)
	elif scene_end_text != "" and _round_index > 0:
		# 显示场景结束文字 + 退出按钮
		_set_dialogue_box_visible(true)
		_dialogue_finished = false
		_current_full_text = scene_end_text
		_history_text += "\n\n"
		_type_index = 0
		_type_timer = 0.0
		_is_typing = true
		if _dialogue_label:
			_dialogue_label.visible_characters = -1
		_awaiting_follow_up = false
		_scene_ending = true


func _hide_panels() -> void:
	if _choice_panel:
		_choice_panel.visible = false
	if _dice_panel:
		_dice_panel.visible = false


func _show_exit_button() -> void:
	_scene_ending = false
	_history_text += "\n\n>>> 点击结束对话 <<<"
	_dialogue_finished = true
	if _dialogue_label:
		_dialogue_label.text = _history_text


func _award_skill_xp(idx: int, amount: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("add_skill_xp"):
		return
	if idx < 0 or idx >= choice_lines.size():
		return
	var tag := _extract_skill_tag(choice_lines[idx])
	if tag != "":
		player.add_skill_xp(tag, amount)


func _extract_skill_tag(text: String) -> String:
	var start := text.find("【")
	var end := text.find("】")
	if start != -1 and end != -1 and end > start:
		var tag := text.substr(start + 1, end - start - 1)
		var dash := tag.find(" - ")
		if dash != -1:
			tag = tag.substr(0, dash)
		return tag
	return ""


func _get_dice_difficulty(text: String) -> int:
	if "极难" in text: return 10
	if "困难" in text: return 8
	return 6  # 简易/普通/无标注


func _on_choice_exit() -> void:
	_set_dialogue_ever_completed(true)
	_hide_panels()
	_set_dialogue_visible(false)


func _roll_dice() -> void:
	if not _dice_panel:
		return
	_dice_panel.visible = true

	var dice1_tex: TextureRect = _dice_panel.get_node_or_null("Dice1") as TextureRect
	var dice2_tex: TextureRect = _dice_panel.get_node_or_null("Dice2") as TextureRect
	var dice3_tex: TextureRect = _dice_panel.get_node_or_null("Dice3") as TextureRect
	var roll_label: Label = _dice_panel.get_node_or_null("DiceRollLabel") as Label
	var verdict_label: Label = _dice_panel.get_node_or_null("DiceVerdictLabel") as Label
	var continue_btn: Button = _dice_panel.get_node_or_null("DiceContinueButton") as Button
	# 前两颗骰子显示，技能骰先隐藏
	if dice1_tex: dice1_tex.visible = true
	if dice2_tex: dice2_tex.visible = true
	if dice3_tex: dice3_tex.visible = false
	if roll_label: roll_label.visible = true
	if verdict_label: verdict_label.visible = true
	if continue_btn: continue_btn.visible = true

	var d1: int = randi() % 6 + 1
	var d2: int = randi() % 6 + 1
	var d3: int = _get_skill_one_level()

	if roll_label:
		roll_label.text = "投掷中..."
	if verdict_label:
		verdict_label.text = ""
	if continue_btn:
		continue_btn.visible = false

	# 阶段1：前两颗骰子动画
	for _i in range(8):
		if dice1_tex:
			dice1_tex.texture = _make_dice_face(randi() % 6 + 1)
		if dice2_tex:
			dice2_tex.texture = _make_dice_face(randi() % 6 + 1)
		await get_tree().create_timer(0.07).timeout

	if dice1_tex:
		dice1_tex.texture = _make_dice_face(d1)
	if dice2_tex:
		dice2_tex.texture = _make_dice_face(d2)

	# 阶段2：技能骰淡入出现
	if dice3_tex:
		dice3_tex.texture = _make_dice_face(d3)
		dice3_tex.modulate = Color(1, 1, 1, 0)
		dice3_tex.visible = true
		var tween := create_tween()
		tween.tween_property(dice3_tex, "modulate", Color(1, 1, 1, 1), 0.5)

	var total: int = d1 + d2 + d3
	var success: bool = total >= _dice_required

	if roll_label:
		roll_label.text = "D6 合计: " + str(total) + " (含技能+%d)  (需要 ≥ %d)" % [d3, _dice_required]
	if verdict_label:
		if success:
			verdict_label.text = "判定成功！"
			verdict_label.set("theme_override_colors/font_color", Color(0.3, 1.0, 0.3, 1.0))
		else:
			verdict_label.text = "判定失败！"
			verdict_label.set("theme_override_colors/font_color", Color(1.0, 0.3, 0.3, 1.0))
	if continue_btn:
		continue_btn.visible = true

	if continue_btn and continue_btn.pressed.is_connected(_on_dice_continue.bind(success)):
		continue_btn.pressed.disconnect(_on_dice_continue)
	if continue_btn:
		continue_btn.pressed.connect(_on_dice_continue.bind(success), CONNECT_ONE_SHOT)


func _get_skill_one_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_skill_level"):
		return min(player.get_skill_level("技能一"), 6)
	return 1


# ---- 骰子图片生成 ----

const _DICE_SIZE := 128
const _DOT_R := 16.0
const _MARGIN := 28.0

func _make_dice_face(value: int) -> ImageTexture:
	var img := Image.create(_DICE_SIZE, _DICE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	var cx := float(_DICE_SIZE) / 2.0
	var cy := float(_DICE_SIZE) / 2.0
	var o1 := _MARGIN
	var o2 := float(_DICE_SIZE) - _MARGIN

	var dots: Array[Vector2] = []
	match value:
		1: dots = [Vector2(cx, cy)]
		2: dots = [Vector2(o2, o1), Vector2(o1, o2)]
		3: dots = [Vector2(o2, o1), Vector2(cx, cy), Vector2(o1, o2)]
		4: dots = [Vector2(o1, o1), Vector2(o2, o1), Vector2(o1, o2), Vector2(o2, o2)]
		5: dots = [Vector2(o1, o1), Vector2(o2, o1), Vector2(cx, cy), Vector2(o1, o2), Vector2(o2, o2)]
		6: dots = [Vector2(o1, o1), Vector2(o2, o1), Vector2(o1, cy), Vector2(o2, cy), Vector2(o1, o2), Vector2(o2, o2)]

	for d in dots:
		_fill_circle(img, d, _DOT_R, Color(0.15, 0.15, 0.15, 1.0))

	return ImageTexture.create_from_image(img)


func _fill_circle(img: Image, center: Vector2, r: float, color: Color) -> void:
	var cx := int(center.x)
	var cy := int(center.y)
	var ri := int(r)
	for y in range(cy - ri, cy + ri + 1):
		for x in range(cx - ri, cx + ri + 1):
			if Vector2(x - center.x, y - center.y).length_squared() <= r * r:
				if x >= 0 and x < _DICE_SIZE and y >= 0 and y < _DICE_SIZE:
					img.set_pixel(x, y, color)


func _on_dice_continue(_success: bool) -> void:
	if _dice_panel:
		_dice_panel.visible = false
	if _success:
		_on_dice_success()
	else:
		_on_dice_fail()
	_dialogue_index = 0


func _set_dialogue_box_visible(visible: bool) -> void:
	if _dialogue_box:
		_dialogue_box.visible = visible
	elif _dialogue_label:
		_dialogue_label.visible = visible


# ---- 动画 ----

var _npc_anim_player: AnimationPlayer


func _setup_npc_animation() -> void:
	var model := get_node_or_null("NpcModel") as Node3D
	if not model:
		return
	_npc_anim_player = _find_ap_recursive(model)
	if not _npc_anim_player:
		return
	print("[NPC Anim] 可用动画: ", _npc_anim_player.get_animation_list())
	# 加载站立动画 (Standing Idle / Standing Idle (1))
	_add_npc_idle_animation(_npc_anim_player)
	# 默认播放站立动画
	if _npc_anim_player.has_animation("idle_lib/idle"):
		_npc_anim_player.play("idle_lib/idle")
	elif _npc_anim_player.get_animation_list().size() > 0:
		_npc_anim_player.play(_npc_anim_player.get_animation_list()[0])


func _add_npc_idle_animation(ap: AnimationPlayer) -> void:
	var idle_scene := load("res://assets/models/StandingIdle.fbx") as PackedScene
	if not idle_scene:
		return
	var tmp := idle_scene.instantiate()
	var idle_ap := _find_ap_recursive(tmp)
	if idle_ap and idle_ap.get_animation_list().size() > 0:
		var anim_name: StringName = StringName(idle_ap.get_animation_list()[0])
		var anim: Animation = idle_ap.get_animation(anim_name)
		var lib := AnimationLibrary.new()
		lib.add_animation(StringName("idle"), anim)
		ap.add_animation_library(StringName("idle_lib"), lib)
	tmp.queue_free()


func _find_ap_recursive(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child as AnimationPlayer
		var found := _find_ap_recursive(child)
		if found:
			return found
	return null


# ---- 脚下圆形影子 ----
var _shadow_sprite: Sprite3D
const SHADOW_GROUND_Y := -0.49

func _create_shadow() -> void:
	_shadow_sprite = Sprite3D.new()
	_shadow_sprite.name = "Shadow"
	_shadow_sprite.texture = _make_shadow_texture()
	_shadow_sprite.rotation_degrees = Vector3(-90, 0, 0)
	_shadow_sprite.modulate = Color(0, 0, 0, 0.7)
	_shadow_sprite.pixel_size = 0.008
	_shadow_sprite.position = Vector3(0, 0.015, 0)
	_shadow_sprite.scale = Vector3(3.0, 3.0, 1)
	add_child(_shadow_sprite)


# ============================================================
# 场景转场：NPC 逐个登场
# ============================================================

const TRANSITION_DURATION := 1.0
const NPC_OUTSIDE := Vector3(-20, 1.05, -15)
const KARL_POSITION := Vector3(1.31, 1.05, 7.82)

var _next_npc_map := {
	"卡尔": "汉斯",
	"汉斯": "迪特尔",
	"迪特尔": "莫罗"
}

func _fade_to_monologue() -> void:
	await get_tree().create_timer(0.5).timeout
	var p2 := get_node_or_null("../Player2")
	if p2 and p2.has_method("_show_monologue"):
		p2._show_monologue()


func _start_scene_transition() -> void:
	SaveSystem.npc_done_count += 1
	_do_fade_out()


func _do_fade_out() -> void:
	var overlay := _get_or_create_transition_overlay()
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, TRANSITION_DURATION)
	tween.tween_callback(_on_faded_out)


func _on_faded_out() -> void:
	# 把当前 NPC 移出屋子并隐藏（暂不禁用，tween 需要存活）
	global_position = NPC_OUTSIDE
	visible = false
	
	# 下一个 NPC：移到卡尔位并显示
	var next_name: String = _next_npc_map.get(npc_name, "")
	if next_name != "":
		var scene := get_tree().current_scene
		var next_npc := scene.get_node_or_null(next_name)
		if next_npc:
			next_npc.global_position = KARL_POSITION
			next_npc.visible = true
			next_npc.process_mode = Node.PROCESS_MODE_INHERIT
	
	_do_fade_in()


func _do_fade_in() -> void:
	var overlay := _get_or_create_transition_overlay()
	_set_dialogue_visible(false)
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 0.0, TRANSITION_DURATION)
	tween.tween_callback(_on_transition_done)


func _on_transition_done() -> void:
	var overlay := _get_or_create_transition_overlay()
	overlay.hide()
	# 彻底禁用已移出的 NPC
	process_mode = Node.PROCESS_MODE_DISABLED


func _get_or_create_transition_overlay() -> ColorRect:
	var name := "TransitionOverlay"
	var ui := get_node_or_null("../UI")
	if not ui:
		return null
	var overlay := ui.get_node_or_null(name)
	if overlay:
		overlay.show()
		return overlay
	overlay = ColorRect.new()
	overlay.name = name
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)
	overlay.show()
	return overlay


func _make_shadow_texture() -> ImageTexture:
	const S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(S) / 2.0
	var r := float(S) / 2.0 - 4.0
	for y in range(S):
		for x in range(S):
			var dist := Vector2(x - cx, y - cx).length()
			if dist <= r:
				var a := 1.0 - dist / r
				a = a * a
				img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)


func _update_shadow() -> void:
	if not _shadow_sprite:
		return
	var s := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.from = global_position + Vector3(0, 3, 0)
	q.to = global_position + Vector3(0, -10, 0)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var r := s.intersect_ray(q)
	if not r.is_empty():
		_shadow_sprite.global_position = Vector3(global_position.x, r["position"].y + 0.01, global_position.z)


# ---- 引导感叹号（初次对话前显示）----

func _create_guide_mark() -> void:
	_guide_mark = Sprite3D.new()
	_guide_mark.name = "GuideMark"
	_guide_mark.texture = DU.make_exclamation_texture()
	_guide_mark.pixel_size = 0.01
	_guide_mark.position = Vector3(0, 3.8, 0)  # 模型头顶上方
	_guide_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_guide_mark.modulate = Color(1, 1, 0, 1)
	_guide_mark.visible = false
	add_child(_guide_mark)


func _update_guide_mark() -> void:
	if not _guide_mark:
		return
	# NPC 可见、活跃、且从未完成过任何对话时显示
	var active := process_mode != Node.PROCESS_MODE_DISABLED
	_guide_mark.visible = visible and active and not _p1_dialogue_ever_completed and not _p2_dialogue_ever_completed
