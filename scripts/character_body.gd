@tool
extends Node3D
class_name CharacterBody

## 为角色构建简单人形骨骼 + BoneAttachment3D + 基础几何体网格。
## 作为 Player 或 NPC 的子节点使用。
## 骨骼包含：躯干(臀部/脊柱/胸部/颈部/头部)、四肢(上臂/前臂/手、大腿/小腿/脚)。

# ============================================================================
# 身体比例参数
# ============================================================================
@export_category("Body Proportions")

@export var body_height: float = 1.65
## 头部大小
@export var head_size: Vector3 = Vector3(0.22, 0.26, 0.22)
## 躯干宽度（胸部）
@export var torso_width: float = 0.48
## 躯干厚度
@export var torso_depth: float = 0.30

@export var upper_arm_radius: float = 0.075
@export var upper_arm_length: float = 0.26
@export var lower_arm_radius: float = 0.065
@export var lower_arm_length: float = 0.26
@export var hand_size: Vector3 = Vector3(0.10, 0.10, 0.10)

@export var upper_leg_radius: float = 0.10
@export var upper_leg_length: float = 0.34
@export var lower_leg_radius: float = 0.085
@export var lower_leg_length: float = 0.34
@export var foot_size: Vector3 = Vector3(0.14, 0.07, 0.26)

# ============================================================================
# 外观参数
# ============================================================================
@export_category("Appearance")
@export var body_color: Color = Color(0.2, 0.6, 0.9, 1.0)
@export var body_roughness: float = 0.7

# ----------------------------------------------------------------------------
# 编辑器"重建"按钮 - 在 Inspector 中勾选即可触发重建
# ----------------------------------------------------------------------------
@export_category("Editor")
@export var rebuild: bool = false:
	set(val):
		if val:
			_build_all()
			rebuild = false

# ============================================================================
# 公有成员
# ============================================================================
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var _mesh_parts: Array[MeshInstance3D] = []
var _base_materials: Array[StandardMaterial3D] = []
var _highlight_material: StandardMaterial3D
var _highlighted: bool = false

# ============================================================================
# 内部数据结构 - 骨骼定义
# ============================================================================
class BoneDef:
	var name: String
	var parent_idx: int
	var rest: Transform3D
	var mesh_type: String          # "box", "capsule", ""
	var mesh_size: Vector3         # box: size, capsule: Vector3(radius, mid_height, 0)
	var mesh_offset: Vector3       # mesh local offset for visual alignment

	func _init(p_name: String, p_parent: int, p_rest: Transform3D,
			p_mesh_type: String = "", p_mesh_size: Vector3 = Vector3.ZERO,
			p_mesh_offset: Vector3 = Vector3.ZERO) -> void:
		name = p_name
		parent_idx = p_parent
		rest = p_rest
		mesh_type = p_mesh_type
		mesh_size = p_mesh_size
		mesh_offset = p_mesh_offset

# ============================================================================
# 生命周期
# ============================================================================
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_all()

# ============================================================================
# 构建流程
# ============================================================================
func _build_all() -> void:
	_clear_children()
	_create_skeleton()
	_create_animation_player()
	_create_body_parts()
	_update_highlight_material()

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_mesh_parts.clear()
	_base_materials.clear()
	_highlight_material = null
	_highlighted = false

# ============================================================================
# 骨骼创建
# ============================================================================
func _create_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)

	var bones := _get_bone_definitions()
	for i: int in range(bones.size()):
		var bd: BoneDef = bones[i]
		skeleton.add_bone(bd.name)
		if i > 0:
			skeleton.set_bone_parent(i, bd.parent_idx)
		skeleton.set_bone_rest(i, bd.rest)

func _create_animation_player() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)

# ============================================================================
# 身体部件创建
# ============================================================================
func _create_body_parts() -> void:
	for bd: BoneDef in _get_bone_definitions():
		if bd.mesh_type.is_empty():
			continue

		var attachment := BoneAttachment3D.new()
		attachment.name = "Attach_" + bd.name
		attachment.bone_name = bd.name
		skeleton.add_child(attachment)

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh_" + bd.name

		var mat := StandardMaterial3D.new()
		mat.albedo_color = body_color
		mat.roughness = body_roughness

		match bd.mesh_type:
			"box":
				var box := BoxMesh.new()
				box.size = bd.mesh_size
				mesh_instance.mesh = box
			"capsule":
				var cap := CapsuleMesh.new()
				cap.radius = bd.mesh_size.x
				cap.mid_height = bd.mesh_size.y
				mesh_instance.mesh = cap

		mesh_instance.position = bd.mesh_offset
		mesh_instance.set_surface_override_material(0, mat)

		attachment.add_child(mesh_instance)
		_mesh_parts.append(mesh_instance)
		_base_materials.append(mat)

# ============================================================================
# 骨骼数据定义
# ============================================================================
func _get_bone_definitions() -> Array[BoneDef]:
	var b: Array[BoneDef] = []

	var t := func(pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Transform3D:
		return Transform3D(Basis.from_euler(rot), pos)

	# --- Index 0: Hips（臀部 - 骨骼根）---
	b.append(BoneDef.new("Hips", -1, t(Vector3.ZERO),
		"box", Vector3(torso_width * 0.85, 0.18, torso_depth),
		Vector3(0, 0.09, 0)))

	# --- Index 1: Spine（脊柱下部）---
	b.append(BoneDef.new("Spine", 0, t(Vector3(0, 0.18, 0)),
		"box", Vector3(torso_width * 0.82, 0.22, torso_depth * 0.92),
		Vector3(0, 0.11, 0)))

	# --- Index 2: Chest（胸部 / 肩膀高度）---
	b.append(BoneDef.new("Chest", 1, t(Vector3(0, 0.22, 0)),
		"box", Vector3(torso_width, 0.24, torso_depth),
		Vector3(0, 0.12, 0)))

	# --- Index 3: Neck（颈部）---
	# 无网格，仅结构骨骼
	b.append(BoneDef.new("Neck", 2, t(Vector3(0, 0.12, 0))))

	# --- Index 4: Head（头部）---
	b.append(BoneDef.new("Head", 3, t(Vector3(0, 0.06, 0)),
		"box", head_size,
		Vector3(0, head_size.y * 0.5, 0)))

	# --- Arms ---
	# 左臂
	b.append(BoneDef.new("LeftUpperArm", 2, t(Vector3(-torso_width * 0.5 - 0.03, 0.04, 0)),
		"capsule", Vector3(upper_arm_radius, upper_arm_length, 0),
		Vector3(0, -upper_arm_length * 0.5, 0)))
	b.append(BoneDef.new("LeftLowerArm", 5, t(Vector3(0, -upper_arm_length, 0)),
		"capsule", Vector3(lower_arm_radius, lower_arm_length, 0),
		Vector3(0, -lower_arm_length * 0.5, 0)))
	b.append(BoneDef.new("LeftHand", 6, t(Vector3(0, -lower_arm_length, 0)),
		"box", hand_size,
		Vector3(0, -hand_size.y * 0.5, 0)))

	# 右臂
	b.append(BoneDef.new("RightUpperArm", 2, t(Vector3(torso_width * 0.5 + 0.03, 0.04, 0)),
		"capsule", Vector3(upper_arm_radius, upper_arm_length, 0),
		Vector3(0, -upper_arm_length * 0.5, 0)))
	b.append(BoneDef.new("RightLowerArm", 8, t(Vector3(0, -upper_arm_length, 0)),
		"capsule", Vector3(lower_arm_radius, lower_arm_length, 0),
		Vector3(0, -lower_arm_length * 0.5, 0)))
	b.append(BoneDef.new("RightHand", 9, t(Vector3(0, -lower_arm_length, 0)),
		"box", hand_size,
		Vector3(0, -hand_size.y * 0.5, 0)))

	# --- Legs ---
	# 左腿
	b.append(BoneDef.new("LeftUpperLeg", 0, t(Vector3(-0.11, -0.1, 0)),
		"capsule", Vector3(upper_leg_radius, upper_leg_length, 0),
		Vector3(0, -upper_leg_length * 0.5, 0)))
	b.append(BoneDef.new("LeftLowerLeg", 11, t(Vector3(0, -upper_leg_length, 0)),
		"capsule", Vector3(lower_leg_radius, lower_leg_length, 0),
		Vector3(0, -lower_leg_length * 0.5, 0)))
	b.append(BoneDef.new("LeftFoot", 12, t(Vector3(0, -lower_leg_length, 0)),
		"box", foot_size,
		Vector3(0, 0, foot_size.z * 0.5)))

	# 右腿
	b.append(BoneDef.new("RightUpperLeg", 0, t(Vector3(0.11, -0.1, 0)),
		"capsule", Vector3(upper_leg_radius, upper_leg_length, 0),
		Vector3(0, -upper_leg_length * 0.5, 0)))
	b.append(BoneDef.new("RightLowerLeg", 14, t(Vector3(0, -upper_leg_length, 0)),
		"capsule", Vector3(lower_leg_radius, lower_leg_length, 0),
		Vector3(0, -lower_leg_length * 0.5, 0)))
	b.append(BoneDef.new("RightFoot", 15, t(Vector3(0, -lower_leg_length, 0)),
		"box", foot_size,
		Vector3(0, 0, foot_size.z * 0.5)))

	return b

# ============================================================================
# 公有接口
# ============================================================================

## 设置身体主颜色
func set_body_color(color: Color) -> void:
	body_color = color
	for i: int in range(_mesh_parts.size()):
		if i < _base_materials.size():
			_base_materials[i].albedo_color = color
	_update_highlight_material()

## 获取所有网格实例（用于高亮等操作）
func get_all_meshes() -> Array[MeshInstance3D]:
	return _mesh_parts

## 设置高亮开/关
func set_highlight(enabled: bool, highlight_color: Color = Color(1.0, 1.0, 0.4, 1.0)) -> void:
	if enabled == _highlighted:
		return
	_highlighted = enabled

	if not _highlight_material:
		return

	for mesh: MeshInstance3D in _mesh_parts:
		if enabled:
			mesh.set_surface_override_material(0, _highlight_material)
		else:
			mesh.set_surface_override_material(0, null)

func _update_highlight_material() -> void:
	if _base_materials.is_empty():
		return
	var mat := _base_materials[0].duplicate() as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.4, 1.0)
	_highlight_material = mat

## 播放动画
func play_animation(anim_name: String, blend_time: float = 0.2) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name, blend_time)

## 停止动画
func stop_animation() -> void:
	if animation_player:
		animation_player.stop()
