extends SceneTree

const TREE_PATHS := [
	"res://assets/environment/foliage/trees/harvestable/harvestable_tree_01.glb",
	"res://assets/environment/foliage/trees/harvestable/harvestable_tree_02.glb",
	"res://assets/environment/foliage/trees/harvestable/harvestable_tree_03.glb",
	"res://assets/environment/foliage/trees/harvestable/harvestable_tree_04.glb",
	"res://assets/environment/foliage/trees/harvestable/harvestable_tree_05.glb",
	"res://assets/environment/foliage/trees/harvestable/harvestable_tree_06.glb",
]


func _init() -> void:
	var failures := PackedStringArray()
	for path in TREE_PATHS:
		var result := _inspect_tree(path)
		if not String(result.get("error", "")).is_empty():
			failures.append(String(result["error"]))
		else:
			print(
				"HARVESTABLE_TREE_ASSET path=", path,
				" meshes=", result["mesh_count"],
				" aabb=", result["aabb"]
			)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("HARVESTABLE_TREE_ASSETS_SMOKE_OK count=", TREE_PATHS.size())
	quit(0)


func _inspect_tree(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {"error": "No existe/importa el arbol: " + path}
	var scene := load(path) as PackedScene
	if scene == null:
		return {"error": "El arbol no importa como PackedScene: " + path}
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return {"error": "No se pudo instanciar el arbol: " + path}
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		instance.free()
		return {"error": "El arbol no contiene MeshInstance3D: " + path}

	var bounds := AABB()
	var has_bounds := false
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var relative_transform := _transform_relative_to(mesh_instance, instance)
		var mesh_bounds := relative_transform * mesh_instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	instance.free()
	if not has_bounds:
		return {"error": "El arbol no contiene geometria valida: " + path}
	return {
		"error": "",
		"mesh_count": meshes.size(),
		"aabb": bounds,
	}


func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
