extends CharacterBody3D
class_name BasePlayer
## 玩家基类 —— Player1 / Player2 共享代码
## 仅包含 100% 相同的成员，有差异的方法保留在子类中

# ============================================================================
# 导出变量（供场景编辑器绑定 UI 节点路径）
# ============================================================================
@export var move_speed: float = 3.0
@export var turn_speed: float = 10.0
@export var crosshair_path: NodePath
@export var crosshair_circle_path: NodePath
@export var crosshair_redx_path: NodePath
@export var dialogue_box_path: NodePath
@export var choice_panel_path: NodePath
@export var dice_panel_path: NodePath
@export var skill_panel_path: NodePath
@export var inventory_panel_path: NodePath
@export var bubble_panel_path: NodePath
@export var journal_panel_path: NodePath

# ============================================================================
# 技能 & 数据
# ============================================================================
var _skill_xp: Dictionary = {
	"枯玫瑰": 0, "红色脉搏": 0, "莱茵河畔": 0, "帝国幽灵": 0,
	"普鲁士纪律": 0, "铁十字": 0, "灰烬喉": 0, "红衣逻辑": 0
}
var _skill_level: Dictionary = {
	"普鲁士纪律": 1, "莱茵河畔": 1, "帝国幽灵": 1, "红衣逻辑": 1,
	"灰烬喉": 1, "枯玫瑰": 1, "红色脉搏": 1, "铁十字": 1
}
const SKILL_XP_MAX := 100.0

var inventory: Array[String] = []
var journal: Array[String] = []

# ============================================================================
# 物理 & 移动状态
# ============================================================================
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _npc_frozen := false

# ============================================================================
# 点击移动
# ============================================================================
var _click_target: Vector3
var _has_click_target: bool = false
var _click_indicator: MeshInstance3D

# ============================================================================
# 交互
# ============================================================================
var _nearby_interactables: Array[Interactable] = []

# ============================================================================
# 墙壁透明
# ============================================================================
var _wall_meshes: Array[MeshInstance3D] = []

# ============================================================================
# 子类必须初始化的引用
# ============================================================================
var _camera: Camera3D  # 子类 @onready 赋值

# ============================================================================
# 影子
# ============================================================================
var _shadow_sprite: Sprite3D
const SHADOW_GROUND_Y := -0.49

# ============================================================================
# UI 节点引用（两个子类完全相同）
# ============================================================================
@onready var _crosshair: Control = get_node_or_null(crosshair_path) as Control
@onready var _crosshair_circle: Control = get_node_or_null(crosshair_circle_path) as Control
@onready var _crosshair_redx: Control = get_node_or_null(crosshair_redx_path) as Control
@onready var _dialogue_box: CanvasItem = get_node_or_null(dialogue_box_path) as CanvasItem
@onready var _choice_panel: CanvasItem = get_node_or_null(choice_panel_path) as CanvasItem
@onready var _dice_panel: CanvasItem = get_node_or_null(dice_panel_path) as CanvasItem
@onready var _skill_panel: CanvasItem = get_node_or_null(skill_panel_path) as CanvasItem
@onready var _inventory_panel: CanvasItem = get_node_or_null(inventory_panel_path) as CanvasItem
@onready var _bubble_panel: Panel = get_node_or_null(bubble_panel_path) as Panel
@onready var _journal_panel: CanvasItem = get_node_or_null(journal_panel_path) as CanvasItem


# ============================================================================
# 冻结模式
# ============================================================================
func _freeze_npc_mode() -> void:
	_npc_frozen = true
	velocity = Vector3.ZERO


func _snap_to_ground() -> void:
	var s := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.from = global_position + Vector3(0, 2, 0)
	q.to = global_position + Vector3(0, -5, 0)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var r := s.intersect_ray(q)
	if not r.is_empty():
		global_position.y = r["position"].y


# ============================================================================
# 输入工具
# ============================================================================
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


# ============================================================================
# 组检测工具
# ============================================================================
func _node_in_group(node: Node, group: String) -> bool:
	if node.is_in_group(group):
		return true
	var parent := node.get_parent()
	return parent != null and parent.is_in_group(group)


# ============================================================================
# 动画查找
# ============================================================================
func _find_ap_recursive(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child as AnimationPlayer
		var found := _find_ap_recursive(child)
		if found:
			return found
	return null


func _add_idle_animation(ap: AnimationPlayer) -> void:
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


# ============================================================================
# 模型上色
# ============================================================================
func _tint_model_recursive(node: Node, color: Color, roughness: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in range(mi.mesh.get_surface_count() if mi.mesh else 0):
			var existing: Material = mi.mesh.surface_get_material(s)
			var mat: StandardMaterial3D
			if existing is StandardMaterial3D:
				mat = existing.duplicate() as StandardMaterial3D
				mat.albedo_color = color
				mat.roughness = roughness
			else:
				mat = StandardMaterial3D.new()
				mat.albedo_color = color
				mat.roughness = roughness
			mi.set_surface_override_material(s, mat)
	for child in node.get_children():
		_tint_model_recursive(child, color, roughness)


# ============================================================================
# 墙壁透明
# ============================================================================
func _init_wall_transparency(walls: Node) -> void:
	# 防止两个玩家重复初始化同一组墙壁
	if walls.has_meta("_transparency_initialized"):
		return
	walls.set_meta("_transparency_initialized", true)
	_collect_wall_meshes(walls, _wall_meshes)
	for mi in _wall_meshes:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.72, 0.68, 0.58, 1)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for s in range(mi.mesh.get_surface_count() if mi.mesh else 0):
			mi.set_surface_override_material(s, mat)


func _collect_wall_meshes(node: Node, out_arr: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_arr.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_wall_meshes(child, out_arr)


func _aabb_contains(mi: MeshInstance3D, point: Vector3) -> bool:
	var aabb := mi.get_aabb()
	aabb.position += mi.global_position
	return aabb.has_point(point)


func _update_wall_transparency() -> void:
	# 全部重置为不透明
	for mi in _wall_meshes:
		var mat: StandardMaterial3D = mi.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color.a = 1.0

	if not _camera:
		return

	# 射线法：摄像机 → 玩家，穿过的墙变透明
	var cam_pos: Vector3 = _camera.global_position
	var player_pos: Vector3 = global_position
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.from = cam_pos
	query.to = player_pos
	query.collision_mask = 2

	var hit_meshes: Array[MeshInstance3D] = []
	var excluded_rids: Array[RID] = [self.get_rid()]
	for _iter in range(8):  # 最多 8 层
		query.exclude = excluded_rids
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			break
		var collider: Object = result.get("collider")
		if not collider:
			break
		var collider_node := collider as CollisionObject3D
		if collider_node:
			excluded_rids.append(collider_node.get_rid())
		else:
			excluded_rids.append(RID())
		var hit_pos: Vector3 = result.get("position", Vector3.ZERO)
		for mi in _wall_meshes:
			if mi in hit_meshes:
				continue
			if _aabb_contains(mi, hit_pos):
				hit_meshes.append(mi)
				break

	# 被射线穿过的墙 → 透明
	for mi in hit_meshes:
		var mat: StandardMaterial3D = mi.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color.a = 0.15


# ============================================================================
# 影子
# ============================================================================
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


# ============================================================================
# 点击指示器
# ============================================================================
func _create_click_indicator() -> void:
	if _click_indicator and is_instance_valid(_click_indicator):
		return
	await get_tree().process_frame
	var root := get_tree().current_scene
	if not root:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.1, 1.0, 0.3, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 1.0, 0.2, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var ring := TorusMesh.new()
	ring.inner_radius = 0.20
	ring.outer_radius = 0.28

	_click_indicator = MeshInstance3D.new()
	_click_indicator.mesh = ring
	_click_indicator.visible = false
	_click_indicator.set_surface_override_material(0, mat)
	root.add_child(_click_indicator)


func _clear_click_target() -> void:
	_has_click_target = false
	if _click_indicator:
		_click_indicator.visible = false


func _align_ring_to_normal(n: Vector3) -> void:
	var up: Vector3 = n.normalized()
	var right: Vector3 = Vector3(1, 0, 0)
	if abs(up.dot(right)) > 0.99:
		right = Vector3(0, 0, 1)
	right = (right - up * right.dot(up)).normalized()
	var fwd: Vector3 = up.cross(right).normalized()
	_click_indicator.global_basis = Basis(right, up, fwd)


# ============================================================================
# 交互注册
# ============================================================================
func register_interactable(item: Interactable) -> void:
	if not _nearby_interactables.has(item):
		_nearby_interactables.append(item)


func unregister_interactable(item: Interactable) -> void:
	item.set_prompt_visible(false)
	item.set_highlight_visible(false)
	_nearby_interactables.erase(item)


func _update_nearest_prompt() -> void:
	if _nearby_interactables.is_empty():
		return
	var nearest: Interactable
	var min_dist := INF
	var my_pos := global_position
	for item in _nearby_interactables:
		if not is_instance_valid(item):
			continue
		item.set_prompt_visible(false)
		item.set_highlight_visible(false)
		var d := my_pos.distance_squared_to(item.global_position)
		if d < min_dist:
			min_dist = d
			nearest = item
	if nearest:
		nearest.set_prompt_visible(true)
		nearest.set_highlight_visible(true)
		_update_prompt_text(nearest)


func _update_prompt_text(item: Interactable) -> void:
	if not item._prompt_label:
		return
	var key_name := "F"
	for ev in InputMap.action_get_events("interact"):
		if ev is InputEventKey:
			key_name = OS.get_keycode_string(ev.keycode)
			break
	var obj_name := "物品"
	if item.has_method("_start_dialogue") or "dialogue_text" in item:
		obj_name = item.get("npc_name") if "npc_name" in item else item.name
	elif "item_name" in item:
		obj_name = item.item_name
	item._prompt_label.text = "按 [%s] 或 右键 与 %s 交互" % [key_name, obj_name]


# ============================================================================
# 技能接口
# ============================================================================
func get_skill_xp(skill_name: String) -> float:
	return _skill_xp.get(skill_name, 0.0)


func get_skill_level(skill_name: String) -> int:
	return _skill_level.get(skill_name, 1)


func add_skill_xp(skill_name: String, amount: float) -> void:
	if not _skill_xp.has(skill_name):
		return
	_skill_xp[skill_name] += amount
	while _skill_xp[skill_name] >= SKILL_XP_MAX:
		_skill_xp[skill_name] -= SKILL_XP_MAX
		_skill_level[skill_name] += 1
	SaveSystem.mark_dirty()


# ============================================================================
# 背包 & 日志
# ============================================================================
func add_journal(text: String) -> void:
	if not journal.has(text):
		journal.append(text)
	SaveSystem.mark_dirty()


func add_item(item: String) -> void:
	inventory.append(item)
	SaveSystem.mark_dirty()
	print(_get_item_log_prefix(), " 获得: ", item)


## 子类覆盖以区分日志前缀
func _get_item_log_prefix() -> String:
	return "[背包]"


# ============================================================================
# UI 状态
# ============================================================================
func _is_any_ui_open() -> bool:
	if _dialogue_box and _dialogue_box.visible:
		return true
	if _choice_panel and _choice_panel.visible:
		return true
	if _dice_panel and _dice_panel.visible:
		return true
	if _skill_panel and _skill_panel.visible:
		return true
	if _inventory_panel and _inventory_panel.visible:
		return true
	if _journal_panel and _journal_panel.visible:
		return true
	return false
