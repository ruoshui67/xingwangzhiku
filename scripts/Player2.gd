class_name Player2
extends BasePlayer

const DU = preload("res://scripts/shared/dialogue_utils.gd")

## Player2 — 可互动NPC / 可操控角色双模式
## 未被控制时：作为Interactable，可被当前玩家F键交互
## 被控制时：完整玩家功能（移动、背包、技能），共用Player1相机，数据独立

@export var prompt_label_path: NodePath

const P1_NPC_SPAWN := Vector3(-5, 0.65, -0.5)
const P2_NPC_SPAWN := Vector3(-5, 0.85, -0.5)

# ---- 控制状态 ----
var _is_controlled: bool = false
var _other_player: Node  # 另一个玩家（Player1）

# ---- 交互相关（NPC模式）----
var _player_in_range := false
var _prompt_visible := false
var _switch_dialogue_open := false

@onready var _shared_camera_pivot: Node3D = get_node_or_null("../Player1/CameraPivot") as Node3D
@onready var _player_shape: CollisionShape3D = $Player2Shape
@onready var _player_model: Node3D = $NpcModel
@onready var _anim_player: AnimationPlayer = _find_animation_player()
@onready var _prompt_label: Label = get_node_or_null(prompt_label_path) as Label
@onready var _interact_area: Area3D = $InteractArea
var _guide_mark: Sprite3D  # 引导感叹号（迪特尔 P1 完成后显示在 Player2 头顶）


func _ready() -> void:
	# Player2 独立技能组
	_skill_xp = {
		"枯玫瑰": 0, "红色脉搏": 0, "莱茵河畔": 0, "帝国幽灵": 0,
		"共和国准则": 0, "三色旗": 0, "灰烬喉": 0, "三段论": 0
	}
	# Player2 初始物品（仅首次初始化时添加）
	if inventory.is_empty():
		inventory.append("记事簿")
		inventory.append("鲁格P08")
		SaveSystem.mark_dirty()
		print("[P2背包] 初始物品已添加: 记事簿, 鲁格P08")
	_camera = get_node_or_null("../Player1/CameraPivot/Camera3D") as Camera3D  # 基类声明，子类赋值
	add_to_group("interactable")
	_setup_highlight()

	# 初始为NPC模式（不被控制）
	set_controlled(false)

	# 绑定交互区域
	if _interact_area:
		_interact_area.body_entered.connect(_on_body_entered)
		_interact_area.body_exited.connect(_on_body_exited)
		_interact_area.monitoring = true
		_interact_area.monitorable = true

	# 加载动画
	_add_idle_animation(_anim_player)
	_add_walk_animation(_anim_player)
	if _anim_player and _anim_player.get_animation_list().size() > 0:
		_anim_player.play(_anim_player.get_animation_list()[0])

	_create_shadow()

	# 引导感叹号（迪特尔 P1 完成后显示，引导 Player1 过来对话）
	_create_guide_mark()

	# 墙壁透明初始化
	var walls := get_node_or_null("../House/Walls")
	if walls:
		walls.add_to_group("non_walkable")
		_init_wall_transparency(walls)


# ============================================================================
# 控制切换核心
# ============================================================================

func set_controlled(controlled: bool) -> void:
	_is_controlled = controlled
	if controlled:
		_npc_frozen = false
		add_to_group("player")
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
		if _shared_camera_pivot:
			_fixed_camera_rotation = _shared_camera_pivot.global_rotation
			_update_camera_basis_cache()
		set_physics_process(true)
		set_process(true)
		_create_click_indicator()
		print("[Player2] 已成为操控角色")
	else:
		remove_from_group("player")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if _click_indicator:
			_click_indicator.visible = false
		print("[Player2] 已变为NPC")


func switch_to_me() -> void:
	_other_player = get_tree().get_first_node_in_group("player")
	if _other_player and _other_player != self:
		if _other_player.has_method("set_controlled"):
			_other_player.set_controlled(false)
		_other_player.global_position = P1_NPC_SPAWN
		_other_player.velocity = Vector3.ZERO
		_other_player._freeze_npc_mode()
	await get_tree().physics_frame
	set_controlled(true)
	await get_tree().physics_frame
	_hide_switch_dialogue()


func switch_back() -> void:
	if not _other_player:
		for c in get_tree().current_scene.get_children():
			if c != self and c.has_method("set_controlled"):
				_other_player = c
				break
	if _other_player and _other_player.has_method("set_controlled"):
		set_controlled(false)
		await get_tree().physics_frame
		global_position = P2_NPC_SPAWN
		_freeze_npc_mode()
		await get_tree().physics_frame
		_other_player.set_controlled(true)
		await get_tree().physics_frame
		_hide_switch_dialogue()


# ============================================================================
# NPC模式 — 交互检测
# ============================================================================

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_update_shadow()
	_update_guide_mark()
	if _is_controlled:
		_update_wall_transparency()
		_update_interactables()
		# UI面板打开时隐藏所有准星
		if (_journal_panel and _journal_panel.visible) or (_inventory_panel and _inventory_panel.visible) or (_skill_panel and _skill_panel.visible):
			if _crosshair: _crosshair.visible = false
			if _crosshair_circle: _crosshair_circle.visible = false
			if _crosshair_redx: _crosshair_redx.visible = false
		else:
			var pos: Vector2 = get_viewport().get_mouse_position()
			if _crosshair:
				_crosshair.position = pos - _crosshair.size * 0.5
			if _crosshair_circle:
				_crosshair_circle.position = pos - _crosshair_circle.size * 0.5
			if _crosshair_redx:
				_crosshair_redx.position = pos - _crosshair_redx.size * 0.5
			var hit_info: Dictionary = _mouse_raycast_full(pos)
			var is_nonwalk: bool = hit_info.get("nonwalk", false)
			var is_interact: bool = hit_info.get("interact", false)
			if _crosshair:
				_crosshair.visible = not is_nonwalk and not is_interact
			if _crosshair_circle:
				_crosshair_circle.visible = is_interact and not is_nonwalk
			if _crosshair_redx:
				_crosshair_redx.visible = is_nonwalk
	else:
		pass


func _update_interactables() -> void:
	var all := get_tree().get_nodes_in_group("interactable")
	for node in all:
		if node == self:
			continue
		var item := node as Interactable
		if item:
			item._player = self

	for item in _nearby_interactables:
		if is_instance_valid(item):
			item.set_prompt_visible(false)
			item.set_highlight_visible(false)
	_nearby_interactables.clear()

	var my_pos := global_position

	for node in all:
		if node == self:
			continue
		var item := node as Interactable
		if not item:
			continue
		var d := my_pos.distance_to(item.global_position)
		if d <= 3.0:
			_nearby_interactables.append(item)

	var p1 := get_node_or_null("../Player1")
	var p1_is_nearby := false
	if p1 and p1 != self:
		var d_p1 := my_pos.distance_to(p1.global_position)
		if d_p1 <= 2.0:
			p1_is_nearby = true
			if _prompt_label:
				_prompt_label.visible = true
				_prompt_label.text = "按 [F] 切换到 Player1"
	if not p1_is_nearby and _nearby_interactables.is_empty():
		if _prompt_label:
			_prompt_label.visible = false

	if _nearby_interactables.is_empty() and not p1_is_nearby:
		return
	var nearest: Interactable = null
	var min_dist := INF
	for item in _nearby_interactables:
		if not is_instance_valid(item):
			continue
		var d := my_pos.distance_to(item.global_position)
		if d < min_dist:
			min_dist = d
			nearest = item
	if nearest:
		nearest.set_prompt_visible(true)
		nearest.set_highlight_visible(true)


# 显示"换回 Player1？"确认对话框
var _switch_back_open := false

func _show_switch_back_dialogue() -> void:
	# 莫罗结束后 → 终局独白
	if SaveSystem.moro_finale_pending:
		_show_finale_monologue()
		return
	_switch_back_open = true
	_share_clues()
	_show_switch_ui("Player2", "Player1", "player2", "player1")
	var dlg_label: RichTextLabel = get_node_or_null("../UI/DialogueBox/DialogueScroll/DialogueText") as RichTextLabel
	if dlg_label:
		var msg := "Player1: 线索已交换。要我继续吗？"
		await DU.typewrite(get_tree(), dlg_label, msg, "", 40.0)
		if _switch_back_open:
			dlg_label.text = msg + "\n[url=switch_yes]好的[/url]    [url=switch_no]再等一下[/url]"
			_connect_switch_meta()

# ============================================================
# 共享：展示切换 UI + 内联选项
# ============================================================

func _show_switch_ui(p_name: String, n_name: String, p_tex: String, n_tex: String) -> void:
	var dlg_box: CanvasItem = get_node_or_null("../UI/DialogueBox") as CanvasItem
	if dlg_box:
		dlg_box.visible = true
	var name_p: Label = get_node_or_null("../UI/DialogueBox/NamePlayer")
	var name_n: Label = get_node_or_null("../UI/DialogueBox/NameNpc")
	if name_p: name_p.text = p_name
	if name_n: name_n.text = n_name
	var pp: CanvasItem = get_node_or_null("../UI/PortraitPlayer")
	var np: CanvasItem = get_node_or_null("../UI/PortraitNpc")
	if pp:
		pp.visible = true
		if pp is TextureRect: pp.texture = load("res://assets/portraits/" + p_tex + ".png")
	if np:
		np.visible = true
		if np is TextureRect: np.texture = load("res://assets/portraits/" + n_tex + ".png")

func _connect_switch_meta() -> void:
	var dlg_label: RichTextLabel = get_node_or_null("../UI/DialogueBox/DialogueScroll/DialogueText") as RichTextLabel
	if dlg_label and not dlg_label.meta_clicked.is_connected(_on_switch_meta_clicked):
		dlg_label.meta_clicked.connect(_on_switch_meta_clicked)

func _disconnect_switch_meta() -> void:
	var dlg_label: RichTextLabel = get_node_or_null("../UI/DialogueBox/DialogueScroll/DialogueText") as RichTextLabel
	if dlg_label and dlg_label.meta_clicked.is_connected(_on_switch_meta_clicked):
		dlg_label.meta_clicked.disconnect(_on_switch_meta_clicked)

func _on_switch_meta_clicked(meta: String) -> void:
	if meta == "finale_end":
		_switch_back_open = false
		_play_epilogue()
		return
	if meta == "switch_yes":
		_hide_switch_dialogue()
		# 独白后切换：重新激活迪特尔
		var dieter := get_node_or_null("../迪特尔")
		if dieter:
			dieter.process_mode = Node.PROCESS_MODE_INHERIT
			dieter.visible = true
		if _switch_back_open:
			_switch_back_open = false
			switch_back()
		else:
			switch_to_me()
	elif meta == "switch_no":
		_hide_switch_dialogue()
		_switch_back_open = false


func _share_clues() -> void:
	var p1 := get_node_or_null("../Player1")
	if not p1 or not ("journal" in p1):
		return
	var p1j: Array = p1.journal
	var p2j: Array = journal
	for clue in p2j:
		if not (clue in p1j):
			p1j.append(clue)
	for clue in p1j:
		if not (clue in p2j):
			p2j.append(clue)


func _trigger_nearest_interactable() -> void:
	if _nearby_interactables.is_empty():
		return
	var my_pos := global_position
	var nearest: Interactable = null
	var min_dist := INF
	for item in _nearby_interactables:
		if not is_instance_valid(item):
			continue
		var d := my_pos.distance_to(item.global_position)
		if d < min_dist:
			min_dist = d
			nearest = item
	if not nearest:
		return
	if nearest.has_method("_start_dialogue") and not nearest.get("_dialogue_finished"):
		nearest._start_dialogue()
	elif nearest.has_method("_show_bubble"):
		nearest._show_bubble()
	elif nearest.has_method("interact"):
		nearest.interact()


func _input(event: InputEvent) -> void:
	if not _is_controlled:
		if event.is_action_pressed("interact") and not _switch_dialogue_open:
			var p1 := get_node_or_null("../Player1")
			if p1 and global_position.distance_to(p1.global_position) <= 2.0:
				_show_switch_dialogue()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		var p1 := get_node_or_null("../Player1")
		if p1 and p1 != self:
			var d_p1 := global_position.distance_to(p1.global_position)
			if d_p1 <= 2.0:
				_show_switch_back_dialogue()
				get_viewport().set_input_as_handled()
				return
		if not _nearby_interactables.is_empty():
			_trigger_nearest_interactable()
			get_viewport().set_input_as_handled()
			return
	if _is_any_ui_open():
		return
	if _bubble_panel and _bubble_panel.visible:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if not _camera:
		return
	var origin: Vector3 = _camera.project_ray_origin(event.position)
	var dir: Vector3 = _camera.project_ray_normal(event.position)
	var query := PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = origin + dir * 100.0
	query.collision_mask = 1
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var hit: Vector3 = result.get("position", Vector3.ZERO)
	var normal: Vector3 = result.get("normal", Vector3.UP)
	var ground_point := hit + normal * 0.08
	_click_target = ground_point
	_has_click_target = true
	if _click_indicator:
		_click_indicator.global_position = ground_point
		_align_ring_to_normal(normal)
		_click_indicator.visible = true


func _physics_process(delta: float) -> void:
	if _npc_frozen:
		return
	if not _is_controlled:
		if is_on_floor():
			velocity.y = 0.0
		else:
			velocity.y -= _gravity * delta
		move_and_slide()
		return
	if _is_any_ui_open():
		_update_animation(0.0)
		return
	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_back", "move_forward")
	)
	if input_vector.length() > 0.05:
		_clear_click_target()
	var dir: Vector3
	if _has_click_target:
		var to_target := _click_target - global_position
		to_target.y = 0.0
		if to_target.length() < 0.4:
			_clear_click_target()
		else:
			dir = to_target.normalized()
	else:
		var cam_basis := _shared_camera_pivot.global_transform.basis
		var forward := -cam_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := cam_basis.x
		right.y = 0.0
		right = right.normalized()
		dir = right * input_vector.x + forward * input_vector.y
		if dir.length() > 1.0:
			dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	if dir.length() > 0.01:
		var target_yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
	move_and_slide()
	_center_camera_on_player()
	_update_animation(dir.length())


# ============================================================================
# 交互区域回调（NPC模式）
# ============================================================================

func _on_body_entered(body: Node) -> void:
	if _is_controlled:
		return
	if body is CharacterBody3D:
		_set_npc_in_range(true)


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody3D:
		_set_npc_in_range(false)


func _set_npc_in_range(in_range: bool) -> void:
	if _player_in_range == in_range:
		return
	_player_in_range = in_range
	if in_range:
		set_prompt_visible(true)
		set_highlight_visible(true)
	else:
		set_prompt_visible(false)
		set_highlight_visible(false)
		if _switch_dialogue_open:
			_hide_switch_dialogue()


func set_prompt_visible(v: bool) -> void:
	_prompt_visible = v
	if _prompt_label:
		_prompt_label.visible = v and not _is_controlled


func set_highlight_visible(v: bool) -> void:
	_set_highlight(v)


# ============================================================================
# 相机 & 射线
# ============================================================================

func _center_camera_on_player() -> void:
	if _shared_camera_pivot:
		var camera_pos := global_position - _camera_forward * _camera_focus_distance
		_shared_camera_pivot.global_position = camera_pos - _camera_offset_world


func _update_camera_basis_cache() -> void:
	if not _shared_camera_pivot or not _camera:
		return
	var basis := _shared_camera_pivot.global_transform.basis
	_camera_forward = (-basis.z).normalized()
	_camera_offset_world = basis * _camera.position
	_camera_focus_distance = _camera_offset_world.length()


func _mouse_raycast_full(screen_pos: Vector2) -> Dictionary:
	var data := {"nonwalk": false, "interact": false}
	if not _camera:
		return data
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	var exclude_arr := [self]
	if _other_player and is_instance_valid(_other_player):
		exclude_arr.append(_other_player)
	var query := PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = origin + dir * 50.0
	query.exclude = exclude_arr
	query.collide_with_areas = true
	query.collision_mask = 1
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var node := result.get("collider") as Node
		if node and _node_in_group(node, "interactable"):
			data["interact"] = true
		return data
	query.collision_mask = 2
	var result2: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not result2.is_empty():
		var node2 := result2.get("collider") as Node
		if node2 and _node_in_group(node2, "non_walkable"):
			data["nonwalk"] = true
	return data


# ============================================================================
# 相机状态（子类特有，需存到基类变量）
# ============================================================================
var _fixed_camera_rotation: Vector3 = Vector3.ZERO
var _camera_forward: Vector3 = Vector3(0.0, 0.0, -1.0)
var _camera_offset_world: Vector3 = Vector3.ZERO
var _camera_focus_distance: float = 10.0


# ============================================================================
# 动画
# ============================================================================

func _find_animation_player() -> AnimationPlayer:
	if not _player_model:
		return null
	return _find_ap_recursive(_player_model)


func _add_walk_animation(ap: AnimationPlayer) -> void:
	var scene := load("res://assets/models/Walking_p2_walk.fbx") as PackedScene
	if not scene:
		return
	var tmp := scene.instantiate()
	var src_ap := _find_ap_recursive(tmp)
	if src_ap and src_ap.get_animation_list().size() > 0:
		var anim_name: StringName = StringName(src_ap.get_animation_list()[0])
		var anim: Animation = src_ap.get_animation(anim_name)
		var lib := AnimationLibrary.new()
		lib.add_animation(StringName("walk"), anim)
		ap.add_animation_library(StringName("walk_lib"), lib)
	tmp.queue_free()


func _update_animation(dir_len: float) -> void:
	if not _anim_player:
		return
	if dir_len > 0.01:
		_play_anim_by_keys(["walk_lib/walk", "mixamo_com|Layer0", "walking", "walk"])
	else:
		_play_anim_by_keys(["idle_lib/idle", "idle"], 0.2)


func _play_anim_by_keys(keys: Array[String], blend: float = 0.15) -> void:
	for k in keys:
		if _anim_player.has_animation(k):
			if _anim_player.current_animation != k:
				_anim_player.play(k, blend)
			return


# ============================================================================
# 高亮 & 颜色
# ============================================================================

var _meshes: Array[MeshInstance3D] = []
var _rim_material: ShaderMaterial
const RIM_CODE := "shader_type spatial;\nrender_mode blend_add, unshaded, cull_back;\nuniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);\nuniform float rim_width : hint_range(0.0, 1.0) = 0.04;\nuniform float rim_sharpness : hint_range(1.0, 30.0) = 30.0;\nvoid fragment() {\n\tfloat rim = 1.0 - abs(dot(NORMAL, VIEW));\n\trim = smoothstep(1.0 - rim_width, 1.0, rim);\n\trim *= rim_sharpness * 0.1;\n\trim = clamp(rim, 0.0, 1.0);\n\tALBEDO = rim_color.rgb * rim;\n\tEMISSION = rim_color.rgb * rim;\n\tALPHA = rim;\n}"


func _setup_highlight() -> void:
	_meshes.clear()
	_find_meshes(self, _meshes)
	if _meshes.is_empty():
		return
	if not _rim_material:
		var shader := Shader.new()
		shader.code = RIM_CODE
		_rim_material = ShaderMaterial.new()
		_rim_material.shader = shader


func _find_meshes(node: Node, out_meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes(child, out_meshes)


func _set_highlight(enabled: bool) -> void:
	if _meshes.is_empty() or not _rim_material:
		return
	for m in _meshes:
		if enabled:
			m.material_overlay = _rim_material
		else:
			m.material_overlay = null


func _color_model(color: Color, roughness: float = 0.88) -> void:
	if not _player_model:
		return
	_tint_model_recursive(_player_model, color, roughness)
	_setup_highlight()


# ============================================================================
# 切换确认对话（独立面板，不干扰骰子系统）
# ============================================================================

func _show_switch_dialogue() -> void:
	_switch_dialogue_open = true
	
	# 莫罗结束后 → 终局独白（Player1 走近 Player2 时触发）
	if SaveSystem.moro_finale_pending:
		_show_finale_monologue()
		return
	
	# 迪特尔 P1 结束后 → 独白 → 强制换人
	if SaveSystem.monologue_pending:
		SaveSystem.monologue_pending = false
		_show_monologue()
		return
	
	# 阶段1：迪特尔 P1 完成之前 → 仅告知规则，不换人
	if not SaveSystem.dieter_p1_done:
		_show_switch_ui("Player1", "Player2", "player1", "player2")
		var dlg_label: RichTextLabel = get_node_or_null("../UI/DialogueBox/DialogueScroll/DialogueText") as RichTextLabel
		if dlg_label:
			# 打字机效果
			var msg := "Player2: 规矩很简单，我在场你问。你是柏林来的——有些问题你可以问，我不能。"
			for j in range(msg.length() + 1):
				if not _switch_dialogue_open:
					return
				dlg_label.text = msg.substr(0, j)
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_just_pressed("interact"):
					dlg_label.text = msg
					while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
						await get_tree().process_frame
					break
				await get_tree().create_timer(0.03).timeout
			dlg_label.text += "\n\n[color=#888888]▼ 点击关闭 ▼[/color]"
		# 等待点击关闭
		while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
		while _switch_dialogue_open:
			await get_tree().process_frame
			if Input.is_action_just_pressed("interact") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				break
		if _switch_dialogue_open:
			_hide_switch_dialogue()
		return
	
	# 正常：交换线索 + 换人选项
	_share_clues()
	_show_switch_ui("Player1", "Player2", "player1", "player2")
	var dlg_label: RichTextLabel = get_node_or_null("../UI/DialogueBox/DialogueScroll/DialogueText") as RichTextLabel
	if dlg_label:
		var msg := "Player2: 线索已交换。要替你吗？"
		await DU.typewrite(get_tree(), dlg_label, msg, "", 40.0)
		if _switch_dialogue_open:
			dlg_label.text = msg + "\n[url=switch_yes]需要[/url]    [url=switch_no]不需要[/url]"
			_connect_switch_meta()


func _show_finale_monologue() -> void:
	_switch_back_open = true
	_switch_dialogue_open = true
	_show_switch_ui("Player2", "Player1", "player2", "player1")
	var dlg_label: RichTextLabel = get_node_or_null("../UI/DialogueBox/DialogueScroll/DialogueText") as RichTextLabel
	if not dlg_label:
		return
	dlg_label.text = ""
	var lines: Array[String] = [
		"弗莱站了一会儿。走到桌子的那一边——不是警察坐的这边。是证人们坐过的那一边。四个证人，一天之内。他拉出了那把椅子。椅腿刮过地面的声音比白天轻。",
		"然后他坐下了。坐在证人坐的位置上。",
		"他把手放在桌上——看着桌子对面空着的椅子。那是他自己刚才坐着的位置。",
		"[color=#888888]【内心独白 —— 自动触发】[/color]",
		"坐在证人席上看警察的位子——是空的。你今天看到的四个德国人——卡尔怕你，汉斯欣赏了你一部分，迪特尔信不过你，莫罗与你无关。你是柏林来的探员。你带着一本警察手册和一个别人替你订好的任务。",
		"但任务不是这个案子。任务是政治。柏林想让你在莱茵河左岸找到一点可以撬动的东西——法军腐败的证据，占领区内耗的证据——然后把它带回柏林变成外交筹码。",
		"你找到了。法军后勤上尉七年偷窃军用燃料、七条人命。你坐在证人席上——你已经有了那封信。这封信可以递给柏林，也可以递给杜瓦尔。",
		"信在杜瓦尔的抽屉里——你送给她的是副本。原件在你上衣内侧口袋里。",
		"你今晚就可以发电报。",
		"[color=#A08A8A]【红衣逻辑】 如果把证据交给柏林：德国获得外交筹码。法国占领军的合法性被动摇。六万裁军之后的法国人需要给国际社会一个交代。但代价是什么？代价是莫罗的案子变成政治工具——卡尔的证词被德国报纸断章取义，汉斯的技术鉴定被译成法文、英文、俄文。迪特尔会被审判——作为证人还是共犯取决于外交风向。莫罗的妻子会读到丈夫的名字被印在别人国家的头版上。杜邦——他倒是什么都不会知道了。[/color]",
		"[color=#8A7A65]【帝国幽灵】 你记得1891年科隆围城战结束时的那些报纸。第一版都印着巨大的标题——\"Deutschland Siegt\"、\"La France Triomphe\"。没有人写最后一版。最后一版都是小号字体，背面角落里贴着阵亡者的名字。你念了太多那些名字。你不想再念了。[/color]",
		"[color=#5A5A5A]【铁十字】 这不是德国和法国的事。不是。这是一个人为了救另一个人偷了一桶油——偷到最后自己不再是人。你从柏林出发的时候带的是命令。军人在柏林等你交上那封信。但你没有穿制服——他们说你不用穿。也许他们不想让穿制服的人做这件事。也许他们想让一个看起来不像军人的人把一份像政治的文件交给一个被当成政治的人。你。坐在这张凳子上——你不需要做选择。你需要不做选择。把信放在杜瓦尔桌上，然后——结束就是了。[/color]",
	]
	var accumulated := ""
	var speed := 50.0
	for i in range(lines.size()):
		if not _switch_dialogue_open:
			return
		if i > 0:
			accumulated += "\n\n"
		await DU.typewrite(get_tree(), dlg_label, lines[i], accumulated, speed)
		if not _switch_dialogue_open:
			return
		accumulated += lines[i]
		dlg_label.text = accumulated + "\n\n[color=#888888]▼ 点击继续 ▼[/color]"
		await DU.wait_for_click(get_tree())
	dlg_label.text = accumulated + "\n\n[url=finale_end]点击继续[/url]"
	_disconnect_switch_meta()
	_connect_switch_meta()


func _show_monologue() -> void:
	_switch_dialogue_open = true
	_show_switch_ui("Player1", "Player2", "player1", "player2")
	var dlg_label: RichTextLabel = get_node_or_null("../UI/DialogueBox/DialogueScroll/DialogueText") as RichTextLabel
	if not dlg_label:
		return
	dlg_label.text = ""
	var lines: Array[String] = [
		"杜瓦尔靠在墙上，左手夹着烟。烟已经烧尽了，几乎烧到她的指节——她没有弹掉。她一直站在这里。",
		"[color=#5A5A5A]【普鲁士纪律】 你该说什么。你不是在认输。你是在做警察应该做的事：把案件交给能破它的人。[/color]",
		"[color=#5A5A5A]【铁十字】 她是法国人。她是占领军的军官。你把一个德国年轻人交给一個法国女军官来审。你想想你要说这句话——说一個字的代价。[/color]",
		"你看着她。你什么也没说。只是退到门边，把椅子让出来。",
		"杜瓦尔看了你一眼。把烟头碾灭在墙角的砖缝里。然后走进来——坐到椅子上。",
	]
	var accumulated := ""
	var speed := 40.0  # 打字速度（字符/秒）
	for i in range(lines.size()):
		if not _switch_dialogue_open:
			return
		if i > 0:
			accumulated += "\n\n"
		# 打字机逐字显示（支持点击跳过）
		await DU.typewrite(get_tree(), dlg_label, lines[i], accumulated, speed)
		if not _switch_dialogue_open:
			return
		accumulated += lines[i]
		# 等待点击继续
		dlg_label.text = accumulated + "\n\n[color=#888888]▼ 点击继续 ▼[/color]"
		await DU.wait_for_click(get_tree())
	dlg_label.text = accumulated + "\n\n[url=switch_yes]点击继续[/url]"
	_connect_switch_meta()


func _play_epilogue() -> void:
	SaveSystem.moro_finale_pending = false
	# 先隐藏对话窗
	var dlg_box := get_node_or_null("../UI/DialogueBox") as CanvasItem
	if dlg_box:
		dlg_box.visible = false
	var ui := get_node_or_null("../UI")
	if not ui:
		return
	
	# 先黑屏淡入
	var fade := ColorRect.new()
	fade.name = "EpiFade"
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.z_index = 100
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.5)
	await tween.finished
	
	# 全屏黑底
	var bg := ColorRect.new()
	bg.name = "EpiBg"
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = 99
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	
	var epi_running := true
	
	var scroll := ScrollContainer.new()
	scroll.name = "EpilogueScroll"
	scroll.anchors_preset = -1
	scroll.anchor_left = 0.666
	scroll.anchor_top = 0.05
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 0.95
	scroll.offset_left = 36
	scroll.offset_top = 80
	scroll.offset_right = -36
	scroll.offset_bottom = -60
	scroll.follow_focus = true
	scroll.z_index = 100
	ui.add_child(scroll)
	
	var label := RichTextLabel.new()
	label.name = "EpilogueLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.bbcode_enabled = true
	label.add_theme_font_size_override("normal_font_size", 40)
	label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	label.scroll_following = true
	scroll.add_child(label)
	
	var lines: Array[String] = [
		"「你在想怎么传。是传到柏林还是传到总部。」（她不是问。她已经知道了。）「这案子——里面的每一个名字。弗莱探员。你无权传回柏林。你坐的不是柏林警察的椅子——你坐的是科隆证人的椅子。证人无罪、无国籍。证人只有真假。」",
		"她在桌子对面坐下来，坐在那个里面。",
		"「第一场——你的鞋匠。他看了你一眼就低下头去——他不相信你穿的是德国的制服。最后一场——他走的时候多看了你一眼。你不在证人席上。你在他对面的椅子上的时候，是你把这张椅子变成了证人席。」",
		"她把一张纸从口袋里抽出来——莫罗的供词副本，推到你面前。原件的副本，上面签了他的名字。",
		"「这个案子在你手里两个月。两个月你坐在柏林翻档案——但真正结了案的是你今天早上在这张桌子上对贝克尔先生说的第一句德语。是我在门外听到你审那个孩子审了四十分钟没有骂过一个脏字。是你把椅子让给我。」",
		"她坐直。一个宪兵中尉。深夜里唯一的制服。",
		"「柏林想要证据。证据在科隆。科隆在莱茵河左岸。河左岸是你五分钟前关掉灯走出这扇门的地方。所以你要把这封信带回柏林还是放在我办公室——我现在回答你：你不把我当敌人，所以你要来问我。那你不当我是敌人。这把椅子。证据在这座城里。」",
		"她把纸推到你面前。",
		"「你做选择。但别再说——柏林让你来的。来——是我自己来的。」",
	]
	var delays: Array[float] = [5.0, 2.0, 5.0, 3.0, 5.5, 2.0, 6.0, 2.0, 4.5]
	for i in range(lines.size()):
		if not epi_running:
			return
		label.text = lines[i]
		await get_tree().create_timer(delays[i]).timeout
	# 显示返回主菜单按钮（屏幕中心下方 1/3 处）
	var btn := Button.new()
	btn.name = "EpiReturnBtn"
	btn.text = "返回主菜单"
	btn.anchor_left = 0.5
	btn.anchor_top = 1.0 / 3.0
	btn.anchor_right = 0.5
	btn.anchor_bottom = 1.0 / 3.0
	btn.offset_left = -100
	btn.offset_top = 50
	btn.offset_right = 100
	btn.offset_bottom = 90
	btn.z_index = 101
	btn.add_theme_font_size_override("font_size", 24)
	ui.add_child(btn)
	btn.pressed.connect(func() -> void:
		get_tree().paused = false
		SaveSystem.reset_npc_phase()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)


func _is_switch_open() -> bool:
	return _switch_dialogue_open


func _hide_switch_dialogue() -> void:
	_switch_dialogue_open = false
	_disconnect_switch_meta()
	var dlg_box: CanvasItem = get_node_or_null("../UI/DialogueBox") as CanvasItem
	if dlg_box:
		dlg_box.visible = false
	var pp: CanvasItem = get_node_or_null("../UI/PortraitPlayer")
	var np: CanvasItem = get_node_or_null("../UI/PortraitNpc")
	if pp: pp.visible = false
	if np: np.visible = false


# ============================================================================
# 引导感叹号（迪特尔 P1 完成后显示，引导 Player1 与 Player2 对话）
# ============================================================================

func _create_guide_mark() -> void:
	_guide_mark = Sprite3D.new()
	_guide_mark.name = "GuideMark"
	_guide_mark.texture = DU.make_exclamation_texture()
	_guide_mark.pixel_size = 0.01
	_guide_mark.position = Vector3(0, 3.8, 0)  # 模型头顶上方
	_guide_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # 始终面向摄像机
	_guide_mark.modulate = Color(1, 1, 0, 1)  # 黄色
	_guide_mark.visible = false
	add_child(_guide_mark)


func _update_guide_mark() -> void:
	if not _guide_mark:
		return
	# 迪特尔 P1 完成后、独白未触发前，且 Player2 为 NPC 模式时显示
	_guide_mark.visible = SaveSystem.monologue_pending and not _is_controlled


# ============================================================================
# 背包日志前缀覆盖
# ============================================================================
func _get_item_log_prefix() -> String:
	return "[P2背包]"


# ============================================================================
# 脚下圆形影子
# ============================================================================

func _create_shadow() -> void:
	_shadow_sprite = Sprite3D.new()
	_shadow_sprite.name = "Shadow"
	_shadow_sprite.texture = _make_shadow_texture()
	_shadow_sprite.rotation_degrees = Vector3(-90, 0, 0)
	_shadow_sprite.modulate = Color(0, 0, 0, 0.7)
	_shadow_sprite.pixel_size = 0.008
	_shadow_sprite.position = Vector3(0, -1.05, 0)
	_shadow_sprite.scale = Vector3(3.0, 3.0, 1)
	add_child(_shadow_sprite)
