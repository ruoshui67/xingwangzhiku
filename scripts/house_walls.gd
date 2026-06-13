extends StaticBody3D

func _ready() -> void:
	# 墙壁贴图 - 创建新材质避免引用问题
	var wall_tex := load("res://墙壁.png") as Texture2D
	if wall_tex:
		var wall_mat := StandardMaterial3D.new()
		wall_mat.albedo_texture = wall_tex
		wall_mat.albedo_color = Color.WHITE
		wall_mat.uv1_scale = Vector3(4, 2, 1)
		for name in ["WallN", "WallW"]:
			var mesh_inst := get_node_or_null("Walls/" + name)
			if mesh_inst is MeshInstance3D:
				mesh_inst.material_override = wall_mat

	# 地板贴图
	var floor_tex := load("res://地板.png") as Texture2D
	if floor_tex:
		var floor := get_node_or_null("Floor")
		if floor is MeshInstance3D:
			var mat := floor.mesh.surface_get_material(0) as StandardMaterial3D
			if mat:
				mat.albedo_texture = floor_tex
				mat.albedo_color = Color.WHITE
				mat.uv1_scale = Vector3(8, 6, 1)

	# 窗户贴图
	var win_tex := load("res://assets/textures/window.png") as Texture2D
	if win_tex:
		var win_mat := StandardMaterial3D.new()
		win_mat.albedo_texture = win_tex
		win_mat.albedo_color = Color.WHITE
		win_mat.uv1_scale = Vector3(3, 2, 1)
		var win := get_node_or_null("Walls/WindowN1")
		if win is MeshInstance3D:
			win.material_override = win_mat
