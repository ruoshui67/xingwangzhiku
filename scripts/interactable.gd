class_name Interactable
extends StaticBody3D

@export var highlight_emission_color: Color = Color(1.0, 1.0, 0.4, 1.0)
@export var interact_radius: float = 3.0
@export var prompt_label_path: NodePath

var _player_in_range := false
var _player: Node3D
var _meshes: Array[MeshInstance3D] = []


@onready var _prompt_label: Label = get_node_or_null(prompt_label_path) as Label
@onready var _interact_area: Area3D = $InteractArea


func _ready() -> void:
	add_to_group("interactable")
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_ensure_action("interact", [KEY_F])
	_ensure_action_mouse("interact", MOUSE_BUTTON_RIGHT)
	if _prompt_label:
		_prompt_label.visible = false
	if _interact_area:
		_interact_area.monitoring = true
		_interact_area.monitorable = true
		_interact_area.collision_layer = 1
		_interact_area.collision_mask = 1
		_interact_area.body_entered.connect(_on_body_entered)
		_interact_area.body_exited.connect(_on_body_exited)
	_setup_highlight()


func _process(_delta: float) -> void:
	_update_range_from_distance()


func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody3D):
		return
	_set_player_in_range(true)


func _on_body_exited(body: Node) -> void:
	if not (body is CharacterBody3D):
		return
	_set_player_in_range(false)


func _update_range_from_distance() -> void:
	if not _player:
		return
	var d := _player.global_position - global_position
	d.y = 0.0
	_set_player_in_range(d.length() <= interact_radius)


func _set_player_in_range(in_range: bool) -> void:
	if _player_in_range == in_range:
		return
	_player_in_range = in_range
	if in_range:
		_on_player_enter()
		if _player and _player.has_method("register_interactable"):
			_player.register_interactable(self)
	else:
		_on_player_exit()
		if _player and _player.has_method("unregister_interactable"):
			_player.unregister_interactable(self)


func set_prompt_visible(v: bool) -> void:
	if _prompt_label:
		_prompt_label.visible = v


func set_highlight_visible(v: bool) -> void:
	_set_highlight(v)


func _on_player_enter() -> void:
	pass


func _on_player_exit() -> void:
	pass


# ---- 高亮 ----

var _rim_material: ShaderMaterial
const RIM_SHADER_CODE := "shader_type spatial;\nrender_mode blend_add, unshaded, cull_back;\nuniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);\nuniform float rim_width : hint_range(0.0, 1.0) = 0.04;\nuniform float rim_sharpness : hint_range(1.0, 30.0) = 30.0;\nvoid fragment() {\n\tfloat rim = 1.0 - abs(dot(NORMAL, VIEW));\n\trim = smoothstep(1.0 - rim_width, 1.0, rim);\n\trim *= rim_sharpness * 0.1;\n\trim = clamp(rim, 0.0, 1.0);\n\tALBEDO = rim_color.rgb * rim;\n\tEMISSION = rim_color.rgb * rim;\n\tALPHA = rim;\n}"

func _setup_highlight() -> void:
	_meshes.clear()
	_find_meshes(self, _meshes)
	if _meshes.is_empty():
		return
	if not _rim_material:
		var shader := Shader.new()
		shader.code = RIM_SHADER_CODE
		_rim_material = ShaderMaterial.new()
		_rim_material.shader = shader
		_rim_material.set_shader_parameter("rim_color", highlight_emission_color)


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
			# 边缘光叠加在原材质上
			m.material_overlay = _rim_material
		else:
			m.material_overlay = null


# ---- 颜色 ----

func _color_model(color: Color, roughness: float) -> void:
	_tint_model_recursive(self, color, roughness)
	_setup_highlight()


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


# ---- 输入助手 ----

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


func _ensure_action_mouse(action_name: String, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventMouseButton and ev.button_index == button_index:
			return
	var mev := InputEventMouseButton.new()
	mev.button_index = button_index
	mev.pressed = true
	InputMap.action_add_event(action_name, mev)
