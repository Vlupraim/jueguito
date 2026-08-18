@tool
extends RefCounted

const REGION_SIZE := 256
const SECTOR_SIZE := 512
const WATER_LEVEL := 2.0
const CENTRAL_REGIONS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

const STYLE_WET := 0
const STYLE_BEACH := 1
const STYLE_CLIFF := 2
const STYLE_ROCKY_GRASS := 3
const STYLE_GRASS := 4
const STYLE_TRAIL := 5
const STYLE_COUNT := 6


func process_terrain_data(terrain_data: Object, options: Dictionary = {}) -> Dictionary:
	if terrain_data == null or not terrain_data.has_method("get_regions_active"):
		return {"ok": false, "message": "No hay Terrain3DData cargado."}
	var region_map: Dictionary = {}
	for value in terrain_data.call("get_regions_active"):
		var region := value as Terrain3DRegion
		if region != null:
			region_map[region.location] = region
	for location in CENTRAL_REGIONS:
		if not region_map.has(location):
			return {"ok": false, "message": "Falta la region central " + str(location) + "."}

	var heights := PackedFloat32Array()
	heights.resize(SECTOR_SIZE * SECTOR_SIZE)
	var old_controls := PackedInt32Array()
	old_controls.resize(SECTOR_SIZE * SECTOR_SIZE)
	_load_source_maps(region_map, heights, old_controls)

	var styles := PackedByteArray()
	styles.resize(SECTOR_SIZE * SECTOR_SIZE)
	var counts := PackedInt32Array()
	counts.resize(STYLE_COUNT)
	var min_height := INF
	var max_height := -INF
	var max_slope := 0.0
	for z in range(SECTOR_SIZE):
		for x in range(SECTOR_SIZE):
			var index := z * SECTOR_SIZE + x
			var height := heights[index]
			var slope := _slope_at(heights, x, z)
			var old_base := (old_controls[index] >> 27) & 0x1F
			var style := _choose_style(old_base, height, slope, x, z, options)
			styles[index] = style
			counts[style] += 1
			min_height = minf(min_height, height)
			max_height = maxf(max_height, height)
			max_slope = maxf(max_slope, slope)

	var radius := clampi(int(options.get("edge_radius", 5)), 0, 12)
	var biome_id := clampi(int(options.get("biome_id", 1)), 0, 7)
	var profile := _biome_profile(biome_id)
	var used_texture_ids := _profile_texture_ids(profile)
	for texture_id in used_texture_ids:
		if texture_id < 0 or texture_id > 23:
			return {
				"ok": false,
				"message": "El perfil %s intenta usar el slot de textura %d; Terrain3D solo admite 0-23." % [_biome_name(biome_id), texture_id],
			}
	var preview := Image.create(SECTOR_SIZE, SECTOR_SIZE, false, Image.FORMAT_RGBA8)
	var painted_by_region: Dictionary = {}
	for location in CENTRAL_REGIONS:
		var bytes := PackedByteArray()
		bytes.resize(REGION_SIZE * REGION_SIZE * 4)
		for py in range(REGION_SIZE):
			for px in range(REGION_SIZE):
				var world_x: int = location.x * REGION_SIZE + px
				var world_z: int = location.y * REGION_SIZE + py
				var index := world_z * SECTOR_SIZE + world_x
				var slope := _slope_at(heights, world_x, world_z)
				var blend_info := _neighbor_style_blend(styles, world_x, world_z, radius)
				var packed := _paint_pixel(
					int(blend_info.primary), int(blend_info.secondary),
					float(blend_info.secondary_weight), heights[index], slope,
					world_x, world_z, profile
				)
				bytes.encode_u32((py * REGION_SIZE + px) * 4, packed)
				var primary_color := _style_color(int(blend_info.primary))
				var secondary_color := _style_color(int(blend_info.secondary))
				preview.set_pixel(world_x, world_z, primary_color.lerp(secondary_color, float(blend_info.secondary_weight)))
		painted_by_region[location] = bytes

	if bool(options.get("apply", false)):
		for location in CENTRAL_REGIONS:
			var region := region_map[location] as Terrain3DRegion
			var control := region.get_map(Terrain3DRegion.TYPE_CONTROL)
			if control == null:
				return {"ok": false, "message": "La region " + str(location) + " no tiene control map."}
			control.set_data(REGION_SIZE, REGION_SIZE, false, Image.FORMAT_RF, painted_by_region[location])
			region.modified = true
			region.edited = true
			if terrain_data.has_method("set_region_modified"):
				terrain_data.call("set_region_modified", location, true)
		terrain_data.call("update_maps", Terrain3DRegion.TYPE_CONTROL, true, false)

	return {
		"ok": true,
		"preview": preview,
		"pixels": SECTOR_SIZE * SECTOR_SIZE,
		"regions": 4,
		"counts": counts,
		"min_height": min_height,
		"max_height": max_height,
		"max_slope": max_slope,
		"edge_radius": radius,
		"biome_id": biome_id,
		"biome_name": _biome_name(biome_id),
		"surface_id": int(options.get("surface_id", 0)),
		"fallback_note": str(profile.get("fallback_note", "")),
		"used_texture_ids": used_texture_ids,
	}


func biome_profile_summary(biome_id: int) -> Dictionary:
	var safe_biome_id := clampi(biome_id, 0, 7)
	var profile := _biome_profile(safe_biome_id)
	return {
		"biome_id": safe_biome_id,
		"biome_name": _biome_name(safe_biome_id),
		"texture_ids": _profile_texture_ids(profile),
		"fallback_note": str(profile.get("fallback_note", "")),
	}


func _load_source_maps(region_map: Dictionary, heights: PackedFloat32Array, controls: PackedInt32Array) -> void:
	for location in CENTRAL_REGIONS:
		var region := region_map[location] as Terrain3DRegion
		var height_map := region.get_map(Terrain3DRegion.TYPE_HEIGHT)
		var control_map := region.get_map(Terrain3DRegion.TYPE_CONTROL)
		var control_bytes := control_map.get_data()
		for py in range(REGION_SIZE):
			for px in range(REGION_SIZE):
				var world_x: int = location.x * REGION_SIZE + px
				var world_z: int = location.y * REGION_SIZE + py
				var target_index := world_z * SECTOR_SIZE + world_x
				var local_index := py * REGION_SIZE + px
				heights[target_index] = height_map.get_pixel(px, py).r
				controls[target_index] = int(control_bytes.decode_u32(local_index * 4))


func _choose_style(old_base: int, height: float, slope: float, x: int, z: int, options: Dictionary) -> int:
	var is_sand := old_base in [1, 9, 10]
	var is_rock := old_base in [4, 14, 15, 19, 20, 21, 22]
	var is_grass := old_base in [2, 6, 17, 18, 23]
	var is_dirt := old_base in [0, 3, 8, 11, 12, 13]
	var water_level := float(options.get("water_level", WATER_LEVEL))
	var cliff_slope := float(options.get("cliff_slope", 27.0))
	var beach_height := float(options.get("beach_height", 4.6))
	var biome_id := clampi(int(options.get("biome_id", 1)), 0, 7)
	var surface_id := int(options.get("surface_id", 0))
	if surface_id == 2 or surface_id == 4:
		beach_height = minf(beach_height, 1.8)
	elif surface_id == 3:
		beach_height = maxf(beach_height, 5.2)
	if height <= water_level + 0.18:
		return STYLE_WET
	if slope >= cliff_slope:
		return STYLE_CLIFF
	var sand_ceiling := water_level + beach_height + _noise(float(x), float(z)) * 0.65
	if height <= sand_ceiling and slope < 18.0:
		return STYLE_BEACH
	if old_base == 16:
		return STYLE_ROCKY_GRASS
	# En estos biomas la tierra humeda/seca es la cubierta general, no un sendero.
	if biome_id == 2 and old_base in [0, 8, 9, 10, 11, 12, 13]:
		return STYLE_GRASS if slope < 15.0 else STYLE_ROCKY_GRASS
	if biome_id == 3 and old_base in [3, 6, 7, 16, 18, 23]:
		return STYLE_GRASS if slope < 15.0 else STYLE_ROCKY_GRASS
	if biome_id in [4, 5, 6, 7] and old_base in [0, 3, 5, 6, 7, 8, 15, 23]:
		return STYLE_GRASS if slope < 15.0 else STYLE_ROCKY_GRASS
	if is_rock:
		return STYLE_CLIFF if slope >= 12.0 else STYLE_ROCKY_GRASS
	if is_sand:
		return STYLE_BEACH if slope < 19.0 else STYLE_CLIFF
	if is_dirt:
		return STYLE_TRAIL if slope < 23.0 else STYLE_CLIFF
	if is_grass:
		return STYLE_GRASS if slope < 15.0 else STYLE_ROCKY_GRASS
	return STYLE_ROCKY_GRASS if slope > 11.0 + _noise(float(x), float(z)) * 2.5 else STYLE_GRASS


func _neighbor_style_blend(styles: PackedByteArray, x: int, z: int, radius: int) -> Dictionary:
	var center_style := int(styles[z * SECTOR_SIZE + x])
	if radius <= 0:
		return {"primary": center_style, "secondary": center_style, "secondary_weight": 0.0}
	var histogram := PackedInt32Array()
	histogram.resize(STYLE_COUNT)
	var step := maxi(1, radius / 2)
	for dz in range(-radius, radius + 1, step):
		for dx in range(-radius, radius + 1, step):
			if dx * dx + dz * dz > radius * radius:
				continue
			var sample_x := clampi(x + dx, 0, SECTOR_SIZE - 1)
			var sample_z := clampi(z + dz, 0, SECTOR_SIZE - 1)
			histogram[int(styles[sample_z * SECTOR_SIZE + sample_x])] += 1
	# Mantener la superficie central como primaria evita que una franja fina desaparezca.
	var primary := center_style
	var secondary := center_style
	var secondary_count := 0
	for style in range(STYLE_COUNT):
		if style != primary and histogram[style] > secondary_count:
			secondary = style
			secondary_count = histogram[style]
	var primary_count := histogram[primary]
	var total_pair := primary_count + secondary_count
	var weight := 0.0
	if secondary_count >= 2 and total_pair > 0:
		weight = clampf(float(secondary_count) / float(total_pair), 0.0, 0.48)
	return {"primary": primary, "secondary": secondary, "secondary_weight": weight}


func _paint_pixel(primary: int, secondary: int, secondary_weight: float, height: float, slope: float, x: int, z: int, profile: Dictionary) -> int:
	var noise := _noise(float(x), float(z))
	var angle := int(absf(floor(noise * 7.0))) & 0xF
	var base_id := _style_base_texture(primary, profile)
	var overlay_id := _style_detail_texture(primary, profile)
	var blend := _style_detail_blend(primary, slope, noise)
	if secondary != primary and secondary_weight > 0.06:
		overlay_id = _style_base_texture(secondary, profile)
		# Ruido de pincel: rompe el borde sin producir dientes de un solo pixel.
		var spray := noise * 0.055
		blend = int(round(clampf(secondary_weight + spray, 0.04, 0.48) * 255.0))
	var navigation := primary in [STYLE_BEACH, STYLE_GRASS, STYLE_TRAIL, STYLE_ROCKY_GRASS] and slope < 32.0 and height > WATER_LEVEL + 0.15
	return _pack_control(base_id, overlay_id, blend, navigation, angle)


func _style_base_texture(style: int, profile: Dictionary) -> int:
	var values: PackedInt32Array = profile.get("base", PackedInt32Array())
	return values[style] if style >= 0 and style < values.size() else 0


func _style_detail_texture(style: int, profile: Dictionary) -> int:
	var values: PackedInt32Array = profile.get("detail", PackedInt32Array())
	return values[style] if style >= 0 and style < values.size() else 0


func _profile_texture_ids(profile: Dictionary) -> PackedInt32Array:
	var unique: Dictionary = {}
	for texture_id in profile.get("base", PackedInt32Array()):
		unique[int(texture_id)] = true
	for texture_id in profile.get("detail", PackedInt32Array()):
		unique[int(texture_id)] = true
	var result := PackedInt32Array()
	for texture_id in unique.keys():
		result.append(int(texture_id))
	result.sort()
	return result


func _biome_profile(biome_id: int) -> Dictionary:
	match biome_id:
		2: # Desierto: arena rosada, caliza y tierras ocres.
			return {
				"base": PackedInt32Array([1, 9, 19, 11, 0, 13]),
				"detail": PackedInt32Array([21, 10, 14, 19, 11, 11]),
			}
		3: # Selva/humedo: tierra mojada, musgo y roca marron.
			return {
				"base": PackedInt32Array([21, 1, 16, 18, 6, 3]),
				"detail": PackedInt32Array([3, 21, 20, 16, 18, 8]),
			}
		4: # Polar sin la antigua nieve: tundra fria y pedregosa.
			return {
				"base": PackedInt32Array([1, 15, 14, 15, 8, 15]),
				"detail": PackedInt32Array([21, 8, 19, 14, 19, 8]),
				"fallback_note": "Polar usa tundra de grava/ceniza: no hay textura de nieve aprobada.",
			}
		5: # Montana: lajas, roca con musgo y pasto oscuro escaso.
			return {
				"base": PackedInt32Array([1, 8, 14, 16, 6, 8]),
				"detail": PackedInt32Array([21, 15, 20, 18, 23, 11]),
			}
		6: # Pantano.
			return {
				"base": PackedInt32Array([7, 3, 16, 18, 7, 3]),
				"detail": PackedInt32Array([21, 21, 20, 16, 3, 8]),
			}
		7: # Arcano/raro.
			return {
				"base": PackedInt32Array([5, 15, 14, 16, 6, 12]),
				"detail": PackedInt32Array([15, 5, 5, 5, 5, 5]),
			}
		_: # Sin bioma/templado: paleta vikinga actual.
			return {
				"base": PackedInt32Array([1, 1, 20, 16, 6, 0]),
				"detail": PackedInt32Array([21, 10, 14, 18, 23, 11]),
			}


func _biome_name(biome_id: int) -> String:
	match biome_id:
		1: return "Templado"
		2: return "Desierto"
		3: return "Selva / humedo"
		4: return "Polar / tundra"
		5: return "Montana"
		6: return "Pantano"
		7: return "Arcano / raro"
	return "Sin bioma"


func _style_detail_blend(style: int, slope: float, noise: float) -> int:
	match style:
		STYLE_WET: return int(clampf(24.0 + absf(noise) * 34.0, 18.0, 58.0))
		STYLE_BEACH: return int(clampf(28.0 + absf(noise) * 48.0 + slope * 1.25, 24.0, 104.0))
		STYLE_CLIFF: return int(clampf(75.0 + slope * 2.45 + noise * 18.0, 78.0, 220.0))
		STYLE_ROCKY_GRASS: return int(clampf(92.0 - slope * 1.2 + noise * 22.0, 48.0, 118.0))
		STYLE_GRASS: return int(clampf(38.0 + absf(noise) * 48.0, 32.0, 92.0))
		STYLE_TRAIL: return int(clampf(48.0 + absf(noise) * 62.0, 42.0, 118.0))
	return 0


func _slope_at(heights: PackedFloat32Array, x: int, z: int) -> float:
	var left := heights[z * SECTOR_SIZE + maxi(0, x - 1)]
	var right := heights[z * SECTOR_SIZE + mini(SECTOR_SIZE - 1, x + 1)]
	var down := heights[maxi(0, z - 1) * SECTOR_SIZE + x]
	var up := heights[mini(SECTOR_SIZE - 1, z + 1) * SECTOR_SIZE + x]
	return rad_to_deg(atan(Vector2((right - left) * 0.5, (up - down) * 0.5).length()))


func _noise(x: float, z: float) -> float:
	return sin(x * 0.061 + z * 0.017) * 0.55 + sin(x * 0.023 - z * 0.073) * 0.30 + sin((x + z) * 0.113) * 0.15


func _pack_control(base_id: int, overlay_id: int, blend: int, navigation: bool, angle: int) -> int:
	var packed := 0
	packed |= (base_id & 0x1F) << 27
	packed |= (overlay_id & 0x1F) << 22
	packed |= (blend & 0xFF) << 14
	packed |= (angle & 0xF) << 10
	packed |= (1 if navigation else 0) << 1
	return packed


func _style_color(style: int) -> Color:
	match style:
		STYLE_WET: return Color("ad986e")
		STYLE_BEACH: return Color("d8bd82")
		STYLE_CLIFF: return Color("65564c")
		STYLE_ROCKY_GRASS: return Color("586849")
		STYLE_GRASS: return Color("354a31")
		STYLE_TRAIL: return Color("916d4c")
	return Color.MAGENTA
