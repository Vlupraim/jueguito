extends Node

const WORLD := preload("res://scenes/terrain3d_walk_preview.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	GameManager.should_play_tutorial_intro = false
	var world := WORLD.instantiate()
	add_child(world)
	var player: CharacterBody3D
	for _frame in range(180):
		await get_tree().process_frame
		player = world.get("player")
		if player != null and player.position.x > 250.0:
			break
	var environment := world.get_node("Ambiente").environment as Environment
	var ocean := world.get("ocean_water") as OceanWater
	if player == null or not ocean.horizon_surface.visible:
		_fail("No se completó el horizonte del sector costero")
		return
	# Visual geometry must not expand gameplay water detection or colliders.
	var arrays := ocean.horizon_surface.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		var point := Vector2(vertex.x, vertex.z)
		if ocean.sector_bounds.grow(-0.01).has_point(point):
			_fail("El decorado del horizonte invadió el interior del sector")
			return
	var far_point := Vector3(256, ocean.water_level, -1000)
	if bool(ocean.get_water_info(far_point, -4).get("in_water", false)):
		_fail("El decorado amplió el agua jugable fuera del sector")
		return
	var colliders_before := ocean.water_collision_shape_count
	var wind := world.get("weather_wind") as Resource
	var sky_material := environment.sky.sky_material as ShaderMaterial
	var initial_speed := float(wind.get("speed_meters_per_second"))
	wind.set("speed_meters_per_second", 0.0)
	var stopped_flow: Vector2 = sky_material.get_shader_parameter("wind_velocity")
	if stopped_flow.length() > 0.001:
		_fail("Detener el viento no detuvo el desplazamiento de las nubes")
		return
	wind.set("speed_meters_per_second", initial_speed)
	var moving_flow: Vector2 = sky_material.get_shader_parameter("wind_velocity")
	if absf(moving_flow.length() - initial_speed) > 0.001:
		_fail("El cielo no recibió la velocidad del recurso de viento")
		return
	world.call("set_fog_enabled", false)
	var material := ocean.water_surface.material_override as ShaderMaterial
	if environment.fog_enabled or bool(material.get_shader_parameter("sea_haze_enabled")):
		_fail("El control de niebla no desactivó la bruma marina")
		return
	world.call("set_fog_enabled", true)
	if not environment.fog_enabled or not bool(material.get_shader_parameter("sea_haze_enabled")) \
	or ocean.water_collision_shape_count != colliders_before:
		_fail("La atmósfera cambió la colisión o no se reactivó")
		return
	player.call("set_camera_locked", true)
	player.call("recenter_camera")
	for _frame in range(45):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await _capture("coastal_horizon_preview")
		player.get_node("CameraPivot/SpringArm3D").rotation_degrees.x = -2.0
		await _capture("coastal_low_horizon_preview")
		var before := get_viewport().get_texture().get_image()
		Engine.time_scale = 8.0
		for _frame in range(90):
			await get_tree().process_frame
		Engine.time_scale = 1.0
		await _capture("coastal_wind_motion_preview")
		var after := get_viewport().get_texture().get_image()
		var changed_pixels := 0
		for y in range(30, 240, 12):
			for x in range(120, 1200, 12):
				if before.get_pixel(x, y) != after.get_pixel(x, y):
					changed_pixels += 1
		if changed_pixels < 40:
			_fail("Las nubes no mostraron desplazamiento visual por viento")
			return
		print("CLOUD_MOTION_VISIBLE samples_changed=", changed_pixels)
	print("COASTAL_ATMOSPHERE_SMOKE_OK horizon_visual_only=true fog_toggle=true colliders=", colliders_before)
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)

func _capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/%s.png" % filename)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
