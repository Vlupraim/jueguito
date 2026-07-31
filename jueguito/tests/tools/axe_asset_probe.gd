extends SceneTree


func _init() -> void:
	var axe_scene := load(
		"res://assets/items/equipment/tools/axes/lumberjack_axe/lumberjack_axe.glb"
	) as PackedScene
	if axe_scene == null:
		push_error("AXE_ASSET_PROBE: no se pudo cargar el GLB")
		quit(1)
		return
	var axe := axe_scene.instantiate() as Node3D
	root.add_child(axe)
	var bounds := _calculate_bounds(axe)
	print("AXE_BOUNDS position=", bounds.position, " size=", bounds.size)
	for mesh_node in axe.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		print("AXE_MESH path=", axe.get_path_to(mesh_instance), " aabb=", mesh_instance.get_aabb())

	var character_scene := load(
		"res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb"
	) as PackedScene
	var character := character_scene.instantiate() as Node3D
	root.add_child(character)
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_error("AXE_ASSET_PROBE: el personaje no tiene Skeleton3D")
		quit(1)
		return
	var skeleton := skeletons[0] as Skeleton3D
	var names: Array[String] = []
	for index in range(skeleton.get_bone_count()):
		names.append(skeleton.get_bone_name(index))
	print("STRONGMAN_BONES ", ", ".join(names))
	quit()


func _calculate_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var relative := model.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds := relative * mesh_instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	return bounds
