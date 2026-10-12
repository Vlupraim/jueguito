extends Node

const DIRECTORY := "res://data/terrain3d_edits/sector_27_30"
const BACKUP := "res://data/terrain3d_edit_backups/coast_surface_v2_before"
const SIZE := 512
var terrain: Terrain3D

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP))
	for filename in DirAccess.open(DIRECTORY).get_files():
		if filename.ends_with(".res") and not FileAccess.file_exists(BACKUP+"/"+filename):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(DIRECTORY+"/"+filename),ProjectSettings.globalize_path(BACKUP+"/"+filename))
	terrain = Terrain3D.new()
	terrain.assets = load("res://assets/environment/terrain/jueguito_terrain_assets.tres")
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(256,150,256)
	camera.current = true
	add_child(terrain)
	terrain.set_camera(camera)
	terrain.data_directory = DIRECTORY
	await get_tree().process_frame
	var heights := PackedFloat32Array()
	heights.resize(SIZE*SIZE)
	var regions := {}
	for region: Terrain3DRegion in terrain.data.get_regions_active():
		if not (region.location.x in [0,1] and region.location.y in [0,1]): continue
		regions[region.location] = region
		var map := region.get_map(Terrain3DRegion.TYPE_HEIGHT)
		for z in range(256):
			for x in range(256): heights[(region.location.y*256+z)*SIZE+region.location.x*256+x] = map.get_pixel(x,z).r
	var noise := FastNoiseLite.new()
	noise.seed = 27302
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.018
	noise.fractal_octaves = 3
	var counts := {}
	for location: Vector2i in regions:
		var region: Terrain3DRegion = regions[location]
		var control := region.get_map(Terrain3DRegion.TYPE_CONTROL)
		var bytes := control.get_data()
		var color := region.get_map(Terrain3DRegion.TYPE_COLOR)
		if color.is_compressed(): color.decompress()
		color.convert(Image.FORMAT_RGBA8)
		for z in range(256):
			for x in range(256):
				var wx := location.x*256+x
				var wz := location.y*256+z
				var height := heights[wz*SIZE+wx]
				if height < 3.15: continue
				var dx := (_height(heights,wx+1,wz)-_height(heights,wx-1,wz))*0.5
				var dz := (_height(heights,wx,wz+1)-_height(heights,wx,wz-1))*0.5
				var slope := rad_to_deg(atan(sqrt(dx*dx+dz*dz)))
				var organic := noise.get_noise_2d(wx,wz)
				var grass := smoothstep(6.1+organic*1.1,11.8+organic*1.1,height)
				var exposed := smoothstep(22.0+organic*5.0,38.0+organic*5.0,slope)
				var soil := grass*(0.12+smoothstep(-0.22,0.32,organic)*0.18)
				var weights := [[1,(1.0-grass)*(1.0-exposed)],[2,(grass-soil)*(1.0-exposed)],[0,soil*(1.0-exposed)],[4,exposed]]
				weights.sort_custom(func(a: Array,b: Array)->bool:return a[1]>b[1])
				var primary: int = weights[0][0]
				var secondary: int = weights[1][0]
				var blend := int(255.0*weights[1][1]/maxf(weights[0][1]+weights[1][1],0.001))
				var offset := (z*256+x)*4
				var original := int(bytes.decode_u32(offset))
				var mask := (31<<27)|(31<<22)|(255<<14)
				bytes.encode_u32(offset,(original & ~mask)|(primary<<27)|(secondary<<22)|(blend<<14))
				# Retain authored wetness alpha; remove the obsolete dark green dye.
				var previous := color.get_pixel(x,z)
				var shade := 0.97+organic*0.035
				color.set_pixel(x,z,Color(shade,shade,shade*0.985,previous.a))
				counts[primary] = int(counts.get(primary,0))+1
		control.set_data(256,256,false,Image.FORMAT_RF,bytes)
		region.modified = true
		region.edited = true
	terrain.data.update_maps(Terrain3DRegion.TYPE_MAX,true,false)
	terrain.data.save_directory(DIRECTORY)
	print("COASTAL_SURFACE_PASS_OK primary_counts=",counts," heights_unchanged=true navigation_holes_unchanged=true backup=",BACKUP)
	get_tree().quit()

func _height(values: PackedFloat32Array,x: int,z: int) -> float:
	return values[clampi(z,0,SIZE-1)*SIZE+clampi(x,0,SIZE-1)]
