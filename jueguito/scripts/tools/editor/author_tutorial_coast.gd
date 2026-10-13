extends Node

const WORLD := preload("res://scenes/terrain3d_walk_preview.tscn")
const MATTE := preload("res://scripts/world/environment/matte_geometry.gd")
const OUTPUT := "res://scenes/world/sectors/handmade/tutorial_coast_dressing.tscn"
const TREE_PLANS := [
	["pine_tall_01",270,240,6.0], ["acacia_01",286,258,4.5],
	["pine_tall_01",251,258,7.0], ["pine_tall_01",261,274,6.5],
	["pine_tall_01",277,281,7.3], ["pine_tall_01",287,279,5.4],
	["acacia_01",307,264,5.2], ["pine_tall_01",245,280,6.2],
	["pine_tall_01",310,277,6.8], ["acacia_01",350,262,4.8],
	["pine_tall_01",335,282,7.1], ["pine_tall_01",315,305,6.6],
	["pine_tall_01",251,305,7.5], ["pine_tall_01",365,270,5.8],
]
var terrain: Terrain3D
var ocean: OceanWater
var dressing: Node3D
var content_transform: Transform3D
var rng := RandomNumberGenerator.new()
var tree_points := PackedVector3Array()

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	GameManager.should_play_tutorial_intro = false
	var world := WORLD.instantiate()
	world.show_ground_grass = false
	add_child(world)
	for _frame in range(20): await get_tree().process_frame
	terrain = world.get("terrain")
	ocean = world.get("ocean_water")
	content_transform = (world.get("sector_content") as Node3D).global_transform
	dressing = Node3D.new()
	dressing.name = "CoastDressing"
	dressing.set_meta("art_version", 1)
	dressing.set_meta("sector", Vector2i(27, 30))
	rng.seed = 27301012
	var trees := _category("HarvestableTrees")
	for index in range(TREE_PLANS.size()):
		var plan: Array = TREE_PLANS[index]
		# Reserve the original IDs and random sequence; acacias belong to another
		# biome. Keeping their slots avoids moving/reidentifying the existing pines.
		if plan[0] != "pine_tall_01":
			rng.randf()
			continue
		var point := _ground(Vector2(plan[1], plan[2]))
		assert(_dry(point), "Invalid tree location")
		var tree := load("res://scenes/world/resources/trees/%s.tscn" % plan[0]).instantiate() as HarvestableTree
		tree.name = "CoastalTree_%02d" % (index + 1)
		tree.resource_id = "sector_27_30/coast_tree_%02d" % (index + 1)
		tree.foliage_material_override = load("res://resources/environment/coastal_%s_matte.tres" % ("pine" if plan[0] == "pine_tall_01" else "acacia"))
		tree.visual_height = plan[3]
		tree.visual_yaw_degrees = rng.randf() * 360
		tree.trunk_height = minf(tree.trunk_height, tree.visual_height * 0.60)
		trees.add_child(tree)
		tree.owner = dressing
		tree.position = content_transform.affine_inverse() * point
		tree_points.append(point)
	var stones := _category("CoastalStones")
	for cluster: Vector2 in [Vector2(241,199),Vector2(310,199),Vector2(342,216),Vector2(254,240),Vector2(328,245),Vector2(367,245)]:
		for index in range(4):
			var point := _ground(cluster + Vector2(rng.randf_range(-3,3),rng.randf_range(-2,2)))
			if not _dry(point): continue
			var rock := load("res://scenes/world/resources/coastal_rock.tscn").instantiate() as Node3D
			rock.name = "Stone_%02d" % stones.get_child_count()
			stones.add_child(rock)
			rock.owner = dressing
			rock.position = content_transform.affine_inverse() * (point - Vector3.UP * 0.08)
			var size := rng.randf_range(0.18,0.48) if index > 0 else rng.randf_range(0.70,1.0)
			rock.scale = Vector3(size, size * rng.randf_range(0.5,0.8), size)
			rock.rotation_degrees = Vector3(rng.randf_range(-10,10),rng.randf()*360,rng.randf_range(-8,8))
	var plants := _category("DuneGrass")
	var grass_material := StandardMaterial3D.new()
	grass_material.resource_name = "DuneGrass_MutedStraw"
	grass_material.albedo_color = Color("89916e")
	grass_material.roughness = 0.98
	grass_material.metallic_specular = 0.1
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for center: Vector2 in [Vector2(258,235),Vector2(271,241),Vector2(282,254),Vector2(250,251),Vector2(305,256),Vector2(345,249),Vector2(316,270)]:
		for index in range(12):
			var point := _ground(center + Vector2(rng.randf_range(-5,5),rng.randf_range(-4,4)))
			if not _dry(point) or point.y < 5.2: continue
			var plant := load("res://assets/environment/vegetation/quaternius_stylized_nature/Grass_Common_Short.gltf").instantiate() as Node3D
			plant.name = "DuneGrass_%03d" % plants.get_child_count()
			plant.set_script(MATTE)
			plant.set("surface_material", grass_material)
			plants.add_child(plant)
			plant.owner = dressing
			plant.position = content_transform.affine_inverse() * (point - Vector3.UP * 0.025)
			var size := rng.randf_range(0.8,1.2)
			plant.scale = Vector3(0.9,0.25,0.9) * size
			plant.rotation.y = rng.randf()*TAU
	var packed := PackedScene.new()
	assert(packed.pack(dressing) == OK)
	assert(ResourceSaver.save(packed, OUTPUT) == OK)
	_paint_root_soil()
	print("TUTORIAL_COAST_AUTHORED trees=",trees.get_child_count()," stones=",stones.get_child_count()," dune_grass=",plants.get_child_count())
	dressing.free()
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _category(label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	dressing.add_child(node)
	node.owner = dressing
	return node

func _ground(xz: Vector2) -> Vector3:
	return Vector3(xz.x,terrain.data.get_height(Vector3(xz.x,0,xz.y)),xz.y)

func _dry(point: Vector3) -> bool:
	return not is_nan(point.y) and point.y > ocean.water_level + 0.5 and not bool(ocean.get_water_info(point,point.y).get("in_water",false)) and terrain.data.get_normal(point).y > 0.85

func _paint_root_soil() -> void:
	var backup := "res://data/terrain3d_edit_backups/coast_dressing_v1_before"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup))
	var source := DirAccess.open("res://data/terrain3d_edits/sector_27_30")
	for file in source.get_files():
		if file.ends_with(".res") and not FileAccess.file_exists(backup + "/" + file):
			DirAccess.copy_absolute(ProjectSettings.globalize_path("res://data/terrain3d_edits/sector_27_30/" + file),ProjectSettings.globalize_path(backup + "/" + file))
	var maps := {}
	var regions := {}
	for region: Terrain3DRegion in terrain.data.get_regions_active():
		if region.location.x in [0,1] and region.location.y in [0,1]:
			maps[region.location] = region.get_map(Terrain3DRegion.TYPE_CONTROL).get_data()
			regions[region.location] = region
	var changed := {}
	for point in tree_points:
		for z in range(floori(point.z)-4,floori(point.z)+5):
			for x in range(floori(point.x)-4,floori(point.x)+5):
				var distance := Vector2(x-point.x,z-point.z).length()
				if distance > 1.8: continue
				var location := Vector2i(x/256,z/256)
				if not maps.has(location): continue
				var bytes: PackedByteArray = maps[location]
				var offset := ((z%256)*256+x%256)*4
				var old := int(bytes.decode_u32(offset))
				var base := (old >> 27) & 31
				if not base in [0,1,2,6,16,17,18,23]: continue
				var blend := int(45.0 * smoothstep(1.8,0.5,distance))
				# Only overlay/blend bits change; base, navigation and holes survive.
				var updated := (old & ~((31 << 22) | (255 << 14))) | (blend << 14)
				bytes.encode_u32(offset,updated)
				maps[location] = bytes
				changed[location] = true
	for location: Vector2i in changed:
		var region: Terrain3DRegion = regions[location]
		region.get_map(Terrain3DRegion.TYPE_CONTROL).set_data(256,256,false,Image.FORMAT_RF,maps[location])
		region.modified = true
		region.edited = true
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL,true,false)
	terrain.data.save_directory("res://data/terrain3d_edits/sector_27_30")
	print("TREE_ROOT_SOIL_PAINTED regions=", changed.size(), " radius=1.8m backup=", backup)
