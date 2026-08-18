extends Node3D

const OUTPUT_PATH := "res://docs/design/concepts/tutorial/coast_art_paint_actual_v1.png"


func _ready() -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 570.0
	camera.position = Vector3(256.0, 620.0, 256.0)
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera.far = 1200.0
	camera.current = true
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	add_child(light)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("86a9b2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4ccc4")
	environment.ambient_light_energy = 0.72
	world_environment.environment = environment
	add_child(world_environment)

	var terrain := Terrain3D.new()
	add_child(terrain)
	terrain.data_directory = "res://data/terrain3d_edits/sector_27_30"
	terrain.assets = load("res://assets/environment/terrain/jueguito_terrain_assets.tres")
	terrain.material = load("res://assets/environment/terrain/jueguito_terrain_material.tres")
	terrain.material.show_checkered = false
	terrain.set_camera(camera)

	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(620.0, 620.0)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.05, 0.38, 0.54, 0.70)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.3
	water_mesh.material = water_material
	water.mesh = water_mesh
	water.position = Vector3(256.0, 2.0, 256.0)
	add_child(water)

	var content := load("res://scenes/world/sectors/handmade/sector_27_30.tscn") as PackedScene
	if content != null:
		add_child(content.instantiate())

	for _frame in range(12):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null:
		printerr("COAST_VISUAL_CAPTURE_ERROR viewport sin imagen")
		get_tree().quit(2)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("COAST_VISUAL_CAPTURE_OK " + OUTPUT_PATH if error == OK else "COAST_VISUAL_CAPTURE_ERROR " + error_string(error))
	get_tree().quit(0 if error == OK else 1)
