extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")

var player: Node3D
var camera: Camera3D


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("HAND_EQUIPMENT_VISUAL_CAPTURE_SKIPPED_HEADLESS")
		get_tree().quit(0)
		return
	GameManager.player_inventory = {
		"Espada vikinga": 1,
		"Escudo vikingo": 1,
		"Arco vikingo": 1,
	}
	player = PLAYER_SCENE.instantiate() as Node3D
	player.set("use_generator_ground_snap", false)
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_setup_stage()
	await _capture_combo("two_hand_sword", ["Espada vikinga"])
	await _capture_combo("shield", ["Escudo vikingo"])
	await _capture_combo("two_hand_bow", ["Arco vikingo"])
	print("HAND_EQUIPMENT_VISUAL_CAPTURE_OK")
	get_tree().quit(0)


func _setup_stage() -> void:
	camera = Camera3D.new()
	camera.fov = 34.0
	add_child(camera)
	camera.make_current()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	light.light_energy = 1.6
	light.shadow_enabled = true
	add_child(light)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.09, 0.11, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.72)
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	add_child(world_environment)


func _capture_combo(file_stem: String, items: Array[String]) -> void:
	GameManager.clear_equipment()
	for item_name in items:
		GameManager.toggle_item_equipped(item_name)
	for _index in range(3):
		await get_tree().process_frame
	var bounds := _calculate_global_bounds(player)
	print("CAPTURE ", file_stem, " bounds=", bounds)
	for mesh_node in player.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if "ItemAttachment" in String(mesh_instance.get_path()):
			print(
				"ITEM_MESH ", mesh_instance.get_path(),
				" global=", mesh_instance.global_transform,
				" aabb=", mesh_instance.get_aabb()
			)
	var target := bounds.get_center()
	camera.global_position = target + Vector3(3.2, 1.4, 4.2)
	camera.look_at(target, Vector3.UP)
	for _index in range(3):
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var error := get_viewport().get_texture().get_image().save_png(
		"res://tests/output/%s.png" % file_stem
	)
	if error != OK:
		push_error("No se pudo guardar " + file_stem)


func _calculate_global_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var mesh_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	return bounds
