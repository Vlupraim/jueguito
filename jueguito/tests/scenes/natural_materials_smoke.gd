extends Node

const WORLD := preload("res://scenes/terrain3d_walk_preview.tscn")
const EXPORTER := preload("res://scripts/tools/editor/terrain3d_sector_exporter.gd")
const OUTPUT := "res://../art/environment/material_audit_v1/"
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _run() -> void:
	GameManager.should_play_tutorial_intro = false
	var began := Time.get_ticks_msec()
	var world := WORLD.instantiate()
	add_child(world)
	var player: CharacterBody3D
	for _frame in range(120):
		await get_tree().process_frame
		player = world.get("player")
		if player != null and player.position.x > 250: break
	check(player != null, "No se creó el personaje")
	var terrain: Terrain3D = world.get("terrain")
	check(terrain.assets.get_texture_count() == 25, "Faltan slots o se perdieron IDs")
	check(EXPORTER.TEXTURE_SNOW == 24, "El exportador aún usa ceniza como nieve")
	for id in range(terrain.assets.get_texture_count()):
		var asset := terrain.assets.get_texture(id)
		var albedo := asset.albedo_texture.get_image()
		var normal := asset.normal_texture.get_image()
		check(asset.id == id, "Se movió el ID pintado %d" % id)
		check(albedo.get_size() == Vector2i(512, 512) and albedo.get_format() == Image.FORMAT_RGB8 and albedo.has_mipmaps(), "Albedo incompatible con array Terrain3D en slot %d" % id)
		check(normal.get_size() == Vector2i(256, 256) and normal.get_format() == Image.FORMAT_RGBA8 and normal.has_mipmaps(), "Normal/rugosidad incompatible en slot %d" % id)
		check(normal.get_pixel(0, 0).a > 0.8, "Rugosidad perdida en alpha de slot %d" % id)
	for mesh in player.get("character_instance").find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(surface)
			check(not bool(material.get("emission_enabled")), "La piel todavía emite luz")
			check(float(material.get("roughness")) >= 0.6, "La piel sigue demasiado pulida")
	var tree := load("res://assets/environment/foliage/trees/harvestable/harvestable_tree_05.glb").instantiate() as Node
	for mesh in tree.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			check(not bool(mesh.get_active_material(surface).get("emission_enabled")), "El árbol 05 todavía emite luz blanca")
	tree.free()
	var grass: Node3D = world.get("ground_grass")
	check(grass != null and int(grass.get("instance_count")) > 0, "No hay pasto en terrenos elegibles")
	check(int(grass.get("instance_count")) < int(grass.get("max_instances")), "La distribución alcanzó el límite y dejó parte del sector sin muestrear")
	check(grass.find_children("*", "CollisionObject3D", true, false).is_empty(), "El pasto decorativo agregó colisiones")
	var ocean: OceanWater = world.get("ocean_water")
	var positions: PackedVector3Array = grass.get("accepted_positions")
	for point in positions:
		check(not bool(ocean.get_water_info(point, point.y).get("in_water", false)), "Pasto bajo el agua")
		check(terrain.data.get_normal(point).y >= 0.85, "Pasto en una pared")
	print("NATURAL_MATERIALS world_ready_ms=", Time.get_ticks_msec() - began, " grass=", positions.size(), " batches=", grass.get_child_count())
	if failures.is_empty() and DisplayServer.get_name() != "headless":
		await _capture(world, player, terrain, positions)
	if failures.is_empty(): print("NATURAL_MATERIALS_SMOKE_OK terrain_arrays=true snow_id=true matte_skin=true grass_dry=true")
	else:
		for failure in failures: push_error(failure)
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture(world: Node, player: CharacterBody3D, terrain: Terrain3D, positions: PackedVector3Array) -> void:
	for _frame in range(30): await get_tree().physics_frame
	player.set_physics_process(false)
	player.call("set_gameplay_input_enabled", false)
	world.get("gameplay_hud").hide()
	var camera := Camera3D.new()
	camera.far = 1200
	camera.fov = 65
	world.add_child(camera)
	camera.current = true
	for entry in [["playa_piel_v1", player.position], ["pasto_interior_v1", _nearest(positions, Vector3(430, 25, 350))]]:
		var point: Vector3 = entry[1]
		point.y = terrain.data.get_height(point) + float(player.get("ground_clearance"))
		player.position = point
		camera.position = point + Vector3(1.8, 1.5, 3.2)
		camera.look_at(point + Vector3.UP * 0.3)
		for _frame in range(24): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + entry[0] + ".png"))
	print("NATURAL_MATERIALS_CAPTURES_OK")
	await _gallery(terrain.assets)

func _gallery(assets: Terrain3DAssets) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202934")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.45
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	viewport.add_child(sun)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18
	camera.position = Vector3(0, 12, 7)
	camera.look_at(Vector3(0, 0, 1.5))
	camera.current = true
	var examples := [[0,"TIERRA"],[1,"ARENA"],[2,"PASTO"],[3,"TIERRA HÚMEDA"],[4,"ROCA"],[8,"GRAVA"],[15,"CENIZA"],[16,"MUSGO"],[22,"EMPEDRADO"],[24,"NIEVE"]]
	for index in range(examples.size()):
		var asset := assets.get_texture(examples[index][0])
		var plane := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(2.7, 2.7)
		var material := StandardMaterial3D.new()
		material.albedo_texture = asset.albedo_texture
		material.albedo_color = asset.albedo_color
		material.normal_enabled = true
		material.normal_texture = asset.normal_texture
		material.normal_scale = asset.normal_depth
		material.roughness_texture = asset.normal_texture
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
		material.roughness = 1.0
		mesh.material = material
		plane.mesh = mesh
		plane.position = Vector3((index % 5 - 2) * 3.3, 0, (index / 5) * 3.7)
		viewport.add_child(plane)
		var label := Label3D.new()
		label.text = examples[index][1]
		label.font_size = 52
		label.pixel_size = 0.007
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = plane.position + Vector3(0, 0.15, 1.7)
		viewport.add_child(label)
	for _frame in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "materiales_bajo_luz_v1.png"))
	viewport.queue_free()

func _nearest(points: PackedVector3Array, target: Vector3) -> Vector3:
	var best := points[0]
	for point in points:
		if point.distance_squared_to(target) < best.distance_squared_to(target): best = point
	return best
