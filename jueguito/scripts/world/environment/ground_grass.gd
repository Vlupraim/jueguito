extends Node3D

## Cosmetic grass batches. Never writes Terrain3D paint/instances to disk.
const GRASS_SCENE := preload("res://assets/environment/vegetation/quaternius_stylized_nature/Grass_Wispy_Short.gltf")
const GRASS_IDS := [2, 6, 16, 17, 18, 23]
@export var spacing := 2.8
@export var chunk_size := 32.0
@export var visible_distance := 65.0
@export var max_instances := 14000
var instance_count := 0
var accepted_positions := PackedVector3Array()

func configure(terrain: Terrain3D, ocean: OceanWater, sector: Vector2i) -> void:
	for child in get_children(): child.queue_free()
	instance_count = 0
	accepted_positions.clear()
	var source := GRASS_SCENE.instantiate()
	var source_mesh := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := source_mesh.mesh.duplicate() as ArrayMesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("738365")
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.metallic_specular = 0.18
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for surface in range(mesh.get_surface_count()): mesh.surface_set_material(surface, material)
	var height_scale := 0.28 / maxf(source_mesh.get_aabb().size.y, 0.01)
	source.free()
	var bounds := ocean.sector_bounds
	var batches := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:grass_v1" % [sector.x, sector.y])
	var steps := Vector2i(bounds.size / spacing)
	for z in range(steps.y):
		for x in range(steps.x):
			if instance_count >= max_instances: break
			var point := Vector3(bounds.position.x + (x + rng.randf()) * spacing, 0, bounds.position.y + (z + rng.randf()) * spacing)
			var textures := terrain.data.get_texture_id(point)
			var texture_id := int(textures.x if textures.z < 0.5 else textures.y)
			if not texture_id in GRASS_IDS: continue
			# Patchy cover leaves soil readable rather than forming a green carpet.
			if rng.randf() > 0.45: continue
			var height := terrain.data.get_height(point)
			if is_nan(height) or height < ocean.water_level + 0.25: continue
			point.y = height
			if bool(ocean.get_water_info(point, height).get("in_water", false)): continue
			var normal := terrain.data.get_normal(point)
			if normal.y < 0.85: continue
			var cell := Vector2i(floori(point.x / chunk_size), floori(point.z / chunk_size))
			var origin := Vector3(cell.x * chunk_size, 0, cell.y * chunk_size)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(2.1, 1.0, 2.1) * height_scale * rng.randf_range(0.7, 1.25))
			if not batches.has(cell): batches[cell] = []
			batches[cell].append(Transform3D(basis, point - origin - Vector3(0, 0.02, 0)))
			accepted_positions.append(point)
			instance_count += 1
	for cell: Vector2i in batches:
		var transforms: Array = batches[cell]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index])
			var shade := rng.randf_range(0.82, 1.05)
			multimesh.set_instance_color(index, Color(shade, shade, shade * 0.95, 1))
		var batch := MultiMeshInstance3D.new()
		batch.name = "Grass_%d_%d" % [cell.x, cell.y]
		batch.position = Vector3(cell.x * chunk_size, 0, cell.y * chunk_size)
		batch.multimesh = multimesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = visible_distance
		batch.visibility_range_end_margin = 12.0
		batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(batch)
