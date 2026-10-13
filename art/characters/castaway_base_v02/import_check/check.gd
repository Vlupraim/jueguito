extends SceneTree

func _initialize() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path := ProjectSettings.globalize_path("res://../castaway_base_v02.glb")
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("GLB import failed: %s" % error)
		quit(1)
		return
	var scene := document.generate_scene(state)
	if scene == null:
		quit(2)
		return
	root.add_child(scene)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	assert(skeletons.size() == 1)
	assert(skeletons[0].get_bone_count() == 24)
	assert(meshes.size() == 2)
	assert(players.size() == 1)
	var animations: PackedStringArray = players[0].get_animation_list()
	assert(animations.size() >= 20)
	for mesh in meshes:
		assert(mesh.mesh != null)
		var material: Material = mesh.mesh.surface_get_material(0)
		assert(material is StandardMaterial3D)
		assert(material.albedo_texture != null)
	var report := {"engine": Engine.get_version_info().string, "bones": 24, "meshes": meshes.size(), "animations": Array(animations), "embedded_material_textures": true}
	var file := FileAccess.open("res://../godot_import_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("GODOT_IMPORT_OK ", JSON.stringify(report))
	quit(0)
