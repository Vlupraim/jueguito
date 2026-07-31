extends Node

# MapDataManager
# Manager de datos y topologia de mapas con identidad cartografica unica

signal current_sector_changed(sector_coord: Vector2i, sector_info: Dictionary)
signal ping_placed(ping_info: Dictionary)

enum HazardLevel {
	SANCTUARY,          # Santuario: Zona segura sin PvP
	DISCORD_FRONTIER,   # Frontera de Discordia: PvP no letal
	BLOOD_TERRITORY,    # Territorio Sangriento: PvP letal + contador de rivales
	UNTAMED_ABYSS       # Dominio Indomito: PvP libre sin ley / Tier alto
}

# Configuracion global de escala
var world_columns: int = 67
var world_rows: int = 38
var sector_size_meters: float = 5000.0

# Base de datos de sectores cargada desde JSON
var sectors_data: Dictionary = {}

# Posicion y sector actual del jugador en tiempo real
var current_player_sector: Vector2i = Vector2i(33, 19) # Sector central por defecto
var current_player_world_pos: Vector3 = Vector3.ZERO
var active_pings: Array[Dictionary] = []

# Paleta cartografica para niveles de dominio y peligro
const COLOR_SANCTUARY := Color(0.24, 0.60, 0.45)       # Verde esmeralda pergamino
const COLOR_FRONTIER := Color(0.85, 0.68, 0.22)        # Ambar antiguo
const COLOR_BLOOD := Color(0.82, 0.30, 0.24)           # Carmesi profundo
const COLOR_UNTAMED := Color(0.35, 0.22, 0.40)         # Violeta oscuro indomito

# Nombres de bioma tradicionales
const BIOME_NAMES := {
	"Bosque Ancestral": Color(0.25, 0.52, 0.32),
	"Estepa Dorada": Color(0.78, 0.64, 0.35),
	"Pantano Brumoso": Color(0.32, 0.45, 0.36),
	"Cumbres de Piedra": Color(0.50, 0.55, 0.62),
	"Tierras Altas": Color(0.42, 0.54, 0.40),
	"Desierto Olvidado": Color(0.85, 0.72, 0.42)
}


func _ready() -> void:
	_load_sectors_database()


func _load_sectors_database() -> void:
	var json_path := "res://data/map_design_sectors_5km.json"
	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		if file != null:
			var json_string := file.get_as_text()
			file.close()
			var json := JSON.new()
			var parse_result := json.parse(json_string)
			if parse_result == OK and json.data is Dictionary:
				var root: Dictionary = json.data as Dictionary
				if root.has("scale") and root["scale"] is Dictionary:
					var scale_dict: Dictionary = root["scale"] as Dictionary
					world_columns = int(scale_dict.get("columns", 67))
					world_rows = int(scale_dict.get("rows", 38))
					sector_size_meters = float(scale_dict.get("sector_side_km", 5.0)) * 1000.0
				
				if root.has("sectors") and root["sectors"] is Dictionary:
					var raw_sectors: Dictionary = root["sectors"] as Dictionary
					for key in raw_sectors.keys():
						var s_data: Dictionary = raw_sectors[key] as Dictionary
						var coord_arr: Array = s_data.get("coord", [0, 0]) as Array
						var coord := Vector2i(int(coord_arr[0]), int(coord_arr[1]))
						sectors_data[coord] = _enrich_sector_info(coord, s_data)
					print("[MapDataManager] Cargados %d sectores desde JSON." % sectors_data.size())
					return

	print("[MapDataManager] JSON no encontrado o invalido. Generando atlas por defecto.")
	_generate_fallback_atlas()


func _enrich_sector_info(coord: Vector2i, raw: Dictionary) -> Dictionary:
	var info := raw.duplicate(true)
	info["coord_v2i"] = coord
	
	# Rango de Dominio (Grado I a VIII)
	var dist_from_center := float(abs(coord.x - world_columns / 2) + abs(coord.y - world_rows / 2))
	var max_dist := float(maxi(world_columns / 2 + world_rows / 2, 1))
	var norm_dist := clampf(dist_from_center / max_dist, 0.0, 1.0)
	
	var grade_num := clampi(int(1.0 + (1.0 - norm_dist) * 7.0), 1, 8)
	info["grade_num"] = grade_num
	info["grade_roman"] = _to_roman_numeral(grade_num)
	
	# Nomenclatura original de Territorio y Peligro
	if grade_num <= 3:
		info["hazard"] = HazardLevel.SANCTUARY
		info["hazard_name"] = "Santuario Real (Protegido)"
		info["hazard_color"] = COLOR_SANCTUARY
	elif grade_num <= 5:
		info["hazard"] = HazardLevel.DISCORD_FRONTIER
		info["hazard_name"] = "Frontera de Discordia (Disputa)"
		info["hazard_color"] = COLOR_FRONTIER
	elif grade_num <= 7:
		info["hazard"] = HazardLevel.BLOOD_TERRITORY
		info["hazard_name"] = "Tierras Sangrientas (Peligro)"
		info["hazard_color"] = COLOR_BLOOD
	else:
		info["hazard"] = HazardLevel.UNTAMED_ABYSS
		info["hazard_name"] = "Dominio Indómito (Sin Ley)"
		info["hazard_color"] = COLOR_UNTAMED

	var raw_biome: String = str(raw.get("biome", "Sin bioma"))
	if raw_biome == "Sin bioma" or raw_biome.is_empty():
		raw_biome = _determine_biome_by_coord(coord)
	info["biome_display"] = raw_biome
	
	if not info.has("name") or str(info["name"]).is_empty():
		info["name"] = "%s · Dominio [%d, %d]" % [raw_biome, coord.x, coord.y]

	info["portals"] = _generate_sector_portals(coord)
	info["resources"] = _generate_sector_resources(raw_biome, grade_num)
	info["hostile_count"] = randi_range(0, 7) if int(info.get("hazard", 0)) >= HazardLevel.BLOOD_TERRITORY else 0
	
	return info


func _to_roman_numeral(num: int) -> String:
	var roman_map := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
	if num >= 1 and num <= 8:
		return roman_map[num - 1]
	return str(num)


func _determine_biome_by_coord(coord: Vector2i) -> String:
	var keys := BIOME_NAMES.keys()
	if keys.is_empty():
		return "Bosque Ancestral"
	var idx := posmod(coord.x * 31 + coord.y * 17, keys.size())
	return str(keys[idx])


func _generate_sector_portals(coord: Vector2i) -> Array[Dictionary]:
	var portals: Array[Dictionary] = []
	var offsets := {
		"Norte": Vector2i(0, -1),
		"Sur": Vector2i(0, 1),
		"Este": Vector2i(1, 0),
		"Oeste": Vector2i(-1, 0)
	}
	var edge_positions := {
		"Norte": Vector2(0.5, 0.08),
		"Sur": Vector2(0.5, 0.92),
		"Este": Vector2(0.92, 0.5),
		"Oeste": Vector2(0.08, 0.5)
	}
	
	for dir_name in offsets.keys():
		var target_coord: Vector2i = coord + offsets[dir_name]
		if target_coord.x >= 0 and target_coord.x < world_columns and target_coord.y >= 0 and target_coord.y < world_rows:
			portals.append({
				"direction": dir_name,
				"target_coord": target_coord,
				"target_name": "Dominio [%d, %d]" % [target_coord.x, target_coord.y],
				"uv_pos": edge_positions[dir_name]
			})
	return portals


func _generate_sector_resources(_biome: String, grade: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var res_types := ["Madera Ancestral", "Vena de Mineral", "Piel Fiel", "Fibra Silvestre", "Canto de Roca"]
	for type_name in res_types:
		list.append({
			"name": type_name,
			"grade": grade,
			"abundance": randi_range(35, 95)
		})
	return list


func _generate_fallback_atlas() -> void:
	for y in range(world_rows):
		for x in range(world_columns):
			var coord := Vector2i(x, y)
			sectors_data[coord] = _enrich_sector_info(coord, {
				"coord": [x, y],
				"biome": _determine_biome_by_coord(coord)
			})


func get_sector_info(coord: Vector2i) -> Dictionary:
	if sectors_data.has(coord):
		return sectors_data[coord] as Dictionary
	return _enrich_sector_info(coord, {"coord": [coord.x, coord.y]})


func get_current_sector_info() -> Dictionary:
	return get_sector_info(current_player_sector)


func update_player_position(world_pos: Vector3) -> void:
	current_player_world_pos = world_pos
	var sec_meters := maxf(sector_size_meters, 1.0)
	var col := clampi(int((world_pos.x + (world_columns * sec_meters * 0.5)) / sec_meters), 0, world_columns - 1)
	var row := clampi(int((world_pos.z + (world_rows * sec_meters * 0.5)) / sec_meters), 0, world_rows - 1)
	var new_coord := Vector2i(col, row)
	
	if new_coord != current_player_sector:
		current_player_sector = new_coord
		current_sector_changed.emit(current_player_sector, get_current_sector_info())


func place_ping(uv_pos: Vector2, ping_type: String = "ALERT") -> void:
	var ping := {
		"id": randi(),
		"sector": current_player_sector,
		"uv_pos": uv_pos,
		"type": ping_type,
		"timestamp": Time.get_ticks_msec()
	}
	active_pings.append(ping)
	ping_placed.emit(ping)
	
	get_tree().create_timer(8.0).timeout.connect(func(): active_pings.erase(ping))
