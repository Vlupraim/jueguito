extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")
const AXE_NAME := "Hacha de leñador"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameManager.player_inventory = {AXE_NAME: 1}
	if not GameManager.equip_tool(AXE_NAME):
		_fail("GameManager rechazo el equipamiento del hacha")
		return

	var player := PLAYER_SCENE.instantiate()
	player.set("use_generator_ground_snap", false)
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for _frame in range(5):
		await get_tree().process_frame

	var attachment := player.find_child("PrimaryItemAttachment", true, false) as BoneAttachment3D
	var equipped_tool := player.find_child("EquippedPrimaryItem", true, false) as Node3D
	if attachment == null or equipped_tool == null:
		_fail("El hacha no se monto en un BoneAttachment3D")
		return
	if attachment.bone_name != "RightHand":
		_fail("El hacha se monto en un hueso inesperado: " + attachment.bone_name)
		return
	if DisplayServer.get_name() == "headless":
		print("AXE_EQUIPMENT_SMOKE_OK bone=", attachment.bone_name)
		get_tree().quit(0)
		return

	var character_bounds := _calculate_global_bounds(player)
	print("AXE_EQUIPMENT_BOUNDS ", character_bounds)
	print("AXE_ATTACHMENT_GLOBAL ", attachment.global_position)
	var target := character_bounds.get_center()
	var camera := Camera3D.new()
	camera.fov = 34.0
	add_child(camera)
	camera.global_position = target + Vector3(3.2, 1.4, 4.2)
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	print("AXE_CAMERA target=", target, " position=", camera.global_position)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	light.light_energy = 1.6
	light.shadow_enabled = true
	add_child(light)
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.09, 0.11, 0.15)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.55, 0.6, 0.72)
	environment_resource.ambient_light_energy = 0.7
	environment.environment = environment_resource
	add_child(environment)
	for _frame in range(4):
		await RenderingServer.frame_post_draw

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://tests/output")
	)
	var error := get_viewport().get_texture().get_image().save_png(
		"res://tests/output/axe_equipped_preview.png"
	)
	if error != OK:
		_fail("No se pudo guardar la captura de equipamiento")
		return
	print("AXE_EQUIPMENT_SMOKE_OK bone=", attachment.bone_name)
	get_tree().quit(0)


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


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
