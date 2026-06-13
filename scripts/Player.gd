extends BasePlayer

const DU = preload("res://scripts/shared/dialogue_utils.gd")

var _fixed_camera_rotation: Vector3 = Vector3.ZERO
var _camera_forward: Vector3 = Vector3(0.0, 0.0, -1.0)
var _camera_offset_world: Vector3 = Vector3.ZERO
var _camera_focus_distance: float = 10.0
var _house_node: Node3D
var _is_controlled := true
var _guide_mark: Sprite3D  # 莫罗结束后引导 Player2 与 Player1 对话的感叹号

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _player_shape: CollisionShape3D = $PlayerShape
@onready var _player_model: Node3D = $PlayerModel
@onready var _anim_player: AnimationPlayer = _find_animation_player()


func _ready() -> void:
	_camera = $CameraPivot/Camera3D  # 基类声明，子类赋值
	add_to_group("player")
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("move_forward", [KEY_W, KEY_UP])
	_ensure_action("move_back", [KEY_S, KEY_DOWN])
	_ensure_action("interact", [KEY_F])

	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	_fixed_camera_rotation = _camera_pivot.global_rotation
	_update_camera_basis_cache()
	if _camera_pivot:
		_camera_pivot.top_level = true

	_color_model(Color(0.7, 0.75, 0.8, 1.0), 0.6)
	_create_click_indicator()
	_create_shadow()
	_create_guide_mark()

	# 新游戏初始物品（仅首次初始化时添加）
	if inventory.is_empty():
		inventory.append("幸运币")
		inventory.append("笔记本")
		SaveSystem.mark_dirty()

	# 新游戏开场对话框（读档跳过）
	if not SaveSystem._pending_load and SaveSystem._opening_lines.size() > 0:
		_show_opening_dialog()

	# 设置不可行走区域 + 收集墙壁引用
	_house_node = get_node_or_null("../House") as Node3D
	var walls := get_node_or_null("../House/Walls")
	if walls:
		walls.add_to_group("non_walkable")
		_init_wall_transparency(walls)


func set_controlled(controlled: bool) -> void:
	_is_controlled = controlled
	if controlled:
		_npc_frozen = false
		add_to_group("player")
		for node in get_tree().get_nodes_in_group("interactable"):
			if node.has_method("set_controlled"):
				continue
			var item := node as Interactable
			if item:
				item._player = self
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
		set_physics_process(true)
		set_process(true)
		set_process_input(true)
	else:
		remove_from_group("player")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		set_process_input(false)


func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	_update_shadow()
	_update_guide_mark()
	_update_wall_transparency()
	_update_nearest_prompt()
	var pos: Vector2 = get_viewport().get_mouse_position()
	if _crosshair:
		_crosshair.position = pos - _crosshair.size * 0.5
	if _crosshair_circle:
		_crosshair_circle.position = pos - _crosshair_circle.size * 0.5
	if _crosshair_redx:
		_crosshair_redx.position = pos - _crosshair_redx.size * 0.5

	# UI面板打开时隐藏所有准星
	if (_journal_panel and _journal_panel.visible) or (_inventory_panel and _inventory_panel.visible) or (_skill_panel and _skill_panel.visible):
		if _crosshair: _crosshair.visible = false
		if _crosshair_circle: _crosshair_circle.visible = false
		if _crosshair_redx: _crosshair_redx.visible = false
		return

	var hit_info: Dictionary = _mouse_raycast_full(pos)
	var is_nonwalk: bool = hit_info.get("nonwalk", false)
	var is_interact: bool = hit_info.get("interact", false)

	if _crosshair:
		_crosshair.visible = not is_nonwalk and not is_interact
	if _crosshair_circle:
		_crosshair_circle.visible = is_interact and not is_nonwalk
	if _crosshair_redx:
		_crosshair_redx.visible = is_nonwalk


func _mouse_raycast_full(screen_pos: Vector2) -> Dictionary:
	var data := {"nonwalk": false, "interact": false}
	if not _camera:
		return data
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)

	var query := PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = origin + dir * 50.0
	var exclude_arr := [self]
	var p2 := get_node_or_null("../Player2")
	if p2:
		exclude_arr.append(p2)
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


func _mouse_hits_interactable(screen_pos: Vector2) -> bool:
	if not _camera:
		return false
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = origin + dir * 50.0
	query.exclude = [self]
	query.collide_with_areas = true
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var node := result.get("collider") as Node
	return node != null and _node_in_group(node, "interactable")


func _input(event: InputEvent) -> void:
	if _is_any_ui_open():
		return
	if _bubble_panel and _bubble_panel.visible:
		return
	if _is_opening_dialog_visible():
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
		var cam_basis := _camera_pivot.global_transform.basis
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


func _center_camera_on_player() -> void:
	if _camera_pivot:
		var camera_pos := global_position - _camera_forward * _camera_focus_distance
		_camera_pivot.global_position = camera_pos - _camera_offset_world
		_camera_pivot.global_rotation = _fixed_camera_rotation


func _update_camera_basis_cache() -> void:
	if not _camera_pivot or not _camera:
		return
	_camera_pivot.global_rotation = _fixed_camera_rotation
	var basis := _camera_pivot.global_transform.basis
	_camera_forward = (-basis.z).normalized()
	_camera_offset_world = basis * _camera.position
	_camera_focus_distance = _camera_offset_world.length()


func _find_animation_player() -> AnimationPlayer:
	if not _player_model:
		return null
	var ap := _find_ap_recursive(_player_model)
	if ap:
		_add_idle_animation(ap)
		print("[Anim] 可用动画: ", ap.get_animation_list())
	return ap


func _update_animation(dir_len: float) -> void:
	if not _anim_player:
		return
	if dir_len > 0.01:
		_play_anim_by_keys(["mixamo_com", "walking", "walk", "Walking", "Walk"])
	else:
		_play_anim_by_keys(["idle_lib/idle", "idle", "idle2"], 0.2)


func _play_anim(anim_name: String, blend: float = 0.15) -> void:
	if _anim_player and _anim_player.has_animation(anim_name):
		if _anim_player.current_animation != anim_name:
			_anim_player.play(anim_name, blend)


func _play_anim_by_keys(keys: Array[String], blend: float = 0.15) -> void:
	for k in keys:
		if _anim_player.has_animation(k):
			if _anim_player.current_animation != k:
				_anim_player.play(k, blend)
			return


func _color_model(color: Color, roughness: float = 0.88) -> void:
	if not _player_model:
		return
	_tint_model_recursive(_player_model, color, roughness)


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


# ---- 引导感叹号（莫罗结束后显示在 Player1 头顶）----

func _create_guide_mark() -> void:
	_guide_mark = Sprite3D.new()
	_guide_mark.name = "GuideMark"
	_guide_mark.texture = DU.make_exclamation_texture()
	_guide_mark.pixel_size = 0.01
	_guide_mark.position = Vector3(0, 3.8, 0)
	_guide_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_guide_mark.modulate = Color(1, 1, 0, 1)
	_guide_mark.visible = false
	add_child(_guide_mark)


func _update_guide_mark() -> void:
	if not _guide_mark:
		return
	# 莫罗 P2 对话结束后、与 Player1 对话前，且 Player1 为 NPC 模式时显示
	_guide_mark.visible = SaveSystem.moro_finale_pending and not _is_controlled


func _show_opening_dialog() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	SaveSystem._opening_triggered = true
	var ui := get_node_or_null("../UI")
	if not ui:
		return
	var dlg := ui.get_node_or_null("OpeningDialog")
	if dlg and dlg.has_method("start"):
		dlg.start(SaveSystem._opening_lines)


func _is_opening_dialog_visible() -> bool:
	var ui := get_node_or_null("../UI")
	if not ui:
		return false
	var dlg := ui.get_node_or_null("OpeningDialog")
	return dlg != null and dlg.visible
