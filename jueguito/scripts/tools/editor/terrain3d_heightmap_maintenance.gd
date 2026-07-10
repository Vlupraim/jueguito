@tool
extends SceneTree

const NORMALIZER_SCRIPT := preload("res://scripts/tools/editor/terrain3d_heightmap_normalizer.gd")
const TERRAIN3D_EXPORT_DIR := "res://data/terrain3d_exports"
const TERRAIN3D_EXPORT_BACKUP_DIR := "res://data/terrain3d_export_backups"


func _initialize() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	if not bool(options.get("ok", false)):
		printerr(str(options.get("message", "Argumentos invalidos.")))
		_print_usage()
		quit(2)
		return

	var sectors := _resolve_sectors(options)
	if sectors.is_empty():
		printerr("No hay sectores para normalizar.")
		_print_usage()
		quit(2)
		return

	var limit := int(options.get("limit", 0))
	if limit > 0 and sectors.size() > limit:
		sectors = sectors.slice(0, limit)

	var dry_run := bool(options.get("dry_run", true))
	var normalizer_options := _normalizer_options(options)
	var backup_root := _make_backup_root(dry_run)
	var normalizer: RefCounted = NORMALIZER_SCRIPT.new()
	var changed := 0
	var failed := 0
	var touched_pixels := 0

	print("Terrain3D heightmap maintenance")
	print("  sectores: " + str(sectors.size()))
	print("  modo: " + str(normalizer_options.get("mode", "")))
	print("  umbral m: " + str(normalizer_options.get("max_step", 0.0)))
	print("  fuerza: " + str(normalizer_options.get("strength", 0.0)))
	print("  pasadas: " + str(normalizer_options.get("iterations", 0)))
	print("  permitir cortes: " + str(normalizer_options.get("allow_intentional_cuts", false)))
	print("  dry-run: " + str(dry_run))
	if backup_root != "":
		print("  backup: " + backup_root)

	for sector in sectors:
		var label := _sector_label(sector)
		var height_resource_path := _export_dir(sector) + "/height.exr"
		var height_abs_path := ProjectSettings.globalize_path(height_resource_path)
		if not FileAccess.file_exists(height_abs_path):
			failed += 1
			printerr(label + " no tiene height.exr.")
			continue

		var image := Image.new()
		var load_error := image.load(height_abs_path)
		if load_error != OK:
			failed += 1
			printerr(label + " no pude cargar height.exr: " + error_string(load_error))
			continue

		var result: Dictionary = normalizer.call("process_height_map", image, normalizer_options)
		var pixels := int(result.get("pixels", 0))
		if pixels <= 0:
			print(label + " sin cortes sobre umbral.")
			continue

		touched_pixels += pixels
		changed += 1
		if dry_run:
			print(label + " cambiaria " + str(pixels) + " pixeles.")
			continue

		var backup_sector_dir := backup_root.path_join(_sector_dir_name(sector))
		var backup_error := DirAccess.make_dir_recursive_absolute(backup_sector_dir)
		if backup_error != OK:
			failed += 1
			printerr(label + " no pude crear backup.")
			continue
		var backup_error_file := _copy_file(height_abs_path, backup_sector_dir.path_join("height.exr"))
		if backup_error_file != OK:
			failed += 1
			printerr(label + " no pude copiar backup: " + error_string(backup_error_file))
			continue

		var save_error := image.save_exr(height_abs_path, true)
		if save_error != OK:
			failed += 1
			printerr(label + " no pude guardar height.exr: " + error_string(save_error))
			continue
		var preview_error := _save_height_preview(image, ProjectSettings.globalize_path(_export_dir(sector) + "/height_preview.png"))
		if preview_error != OK:
			printerr(label + " height normalizado, pero no pude actualizar preview: " + error_string(preview_error))
		print(label + " normalizado: " + str(pixels) + " pixeles.")

	print("Listo. Sectores tocados: " + str(changed) + ". Pixeles: " + str(touched_pixels) + ". Fallos: " + str(failed) + ".")
	quit(1 if failed > 0 else 0)


func _parse_options(args: PackedStringArray) -> Dictionary:
	var options := {
		"ok": true,
		"dry_run": true,
		"mode": NORMALIZER_SCRIPT.MODE_REPAIR_CUTS,
		"allow_intentional_cuts": false,
		"limit": 0,
		"all_exported": false,
		"sectors": [],
	}

	var index := 0
	while index < args.size():
		var arg := String(args[index])
		match arg:
			"--apply":
				options["dry_run"] = false
			"--dry-run":
				options["dry_run"] = true
			"--all-exported":
				options["all_exported"] = true
			"--smooth":
				options["mode"] = NORMALIZER_SCRIPT.MODE_SMOOTH
			"--repair-cuts":
				options["mode"] = NORMALIZER_SCRIPT.MODE_REPAIR_CUTS
			"--allow-cuts":
				options["allow_intentional_cuts"] = true
			"--threshold":
				if index + 1 >= args.size():
					return {"ok": false, "message": "--threshold necesita metros."}
				options["max_step"] = float(args[index + 1])
				index += 1
			"--strength":
				if index + 1 >= args.size():
					return {"ok": false, "message": "--strength necesita valor 0..1."}
				options["strength"] = float(args[index + 1])
				index += 1
			"--iterations":
				if index + 1 >= args.size():
					return {"ok": false, "message": "--iterations necesita numero."}
				options["iterations"] = int(args[index + 1])
				index += 1
			"--sector":
				if index + 2 >= args.size():
					return {"ok": false, "message": "--sector necesita X Y."}
				(options["sectors"] as Array).append(Vector2i(int(args[index + 1]), int(args[index + 2])))
				index += 2
			"--limit":
				if index + 1 >= args.size():
					return {"ok": false, "message": "--limit necesita numero."}
				options["limit"] = int(args[index + 1])
				index += 1
			_:
				if arg.begins_with("--sector="):
					var coords := arg.trim_prefix("--sector=").split(",", false)
					if coords.size() != 2:
						return {"ok": false, "message": "--sector debe tener formato X,Y."}
					(options["sectors"] as Array).append(Vector2i(int(coords[0]), int(coords[1])))
				else:
					return {"ok": false, "message": "Argumento no reconocido: " + arg}
		index += 1
	return options


func _normalizer_options(options: Dictionary) -> Dictionary:
	var mode := str(options.get("mode", NORMALIZER_SCRIPT.MODE_REPAIR_CUTS))
	var repair_cuts := mode == NORMALIZER_SCRIPT.MODE_REPAIR_CUTS
	var iterations := int(options.get("iterations", 8 if repair_cuts else 3))
	var strength := float(options.get("strength", 0.95 if repair_cuts else 0.55))
	return {
		"mode": mode,
		"iterations": iterations,
		"strength": strength,
		"max_step": float(options.get("max_step", 1.5 if repair_cuts else 2.5)),
		"preserve_outer_edges": true,
		"repair_seams": false,
		"allow_intentional_cuts": bool(options.get("allow_intentional_cuts", false)),
		"repair_radius": 22 if repair_cuts else 0,
		"smooth_radius": 4 if repair_cuts else 1,
		"limit_radius": 4 if repair_cuts else 0,
		"strict_passes": maxi(iterations + 4, 12) if repair_cuts else iterations,
		"target_step_factor": 0.45 if repair_cuts else 1.0,
	}


func _resolve_sectors(options: Dictionary) -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	for value in options.get("sectors", []):
		if value is Vector2i:
			sectors.append(value)

	if bool(options.get("all_exported", false)):
		sectors = _list_exported_sectors()

	sectors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)
	return sectors


func _list_exported_sectors() -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	var dir := DirAccess.open(ProjectSettings.globalize_path(TERRAIN3D_EXPORT_DIR))
	if dir == null:
		return sectors
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and file_name.begins_with("sector_"):
			var sector := _sector_from_dir_name(file_name)
			if sector.x >= 0 and sector.y >= 0:
				sectors.append(sector)
		file_name = dir.get_next()
	dir.list_dir_end()
	return sectors


func _sector_from_dir_name(file_name: String) -> Vector2i:
	var parts := file_name.split("_", false)
	if parts.size() != 3:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[1]), int(parts[2]))


func _save_height_preview(image: Image, preview_abs_path: String) -> Error:
	var width := image.get_width()
	var height := image.get_height()
	var min_height := INF
	var max_height := -INF
	for y in range(height):
		for x in range(width):
			var value := image.get_pixel(x, y).r
			min_height = minf(min_height, value)
			max_height = maxf(max_height, value)

	var span := maxf(0.001, max_height - min_height)
	var preview := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var value := clampf((image.get_pixel(x, y).r - min_height) / span, 0.0, 1.0)
			preview.set_pixel(x, y, Color(value, value, value, 1.0))
	return preview.save_png(preview_abs_path)


func _copy_file(source_abs: String, target_abs: String) -> Error:
	var bytes := FileAccess.get_file_as_bytes(source_abs)
	if bytes.is_empty() and FileAccess.get_open_error() != OK:
		return FileAccess.get_open_error()
	var file := FileAccess.open(target_abs, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	return OK


func _make_backup_root(dry_run: bool) -> String:
	if dry_run:
		return ""
	var stamp := Time.get_datetime_string_from_system(false, true)
	stamp = stamp.replace(":", "").replace("-", "").replace("T", "_")
	var backup_root := ProjectSettings.globalize_path(TERRAIN3D_EXPORT_BACKUP_DIR).path_join(stamp)
	DirAccess.make_dir_recursive_absolute(backup_root)
	return backup_root


func _export_dir(sector: Vector2i) -> String:
	return TERRAIN3D_EXPORT_DIR + "/" + _sector_dir_name(sector)


func _sector_dir_name(sector: Vector2i) -> String:
	return "sector_%d_%d" % [sector.x, sector.y]


func _sector_label(sector: Vector2i) -> String:
	return "[" + str(sector.x) + ", " + str(sector.y) + "]"


func _print_usage() -> void:
	print("Uso:")
	print("  godot --headless --path . --script res://scripts/tools/editor/terrain3d_heightmap_maintenance.gd -- --sector 12 9 --repair-cuts --threshold 1.5 --apply")
	print("  godot --headless --path . --script res://scripts/tools/editor/terrain3d_heightmap_maintenance.gd -- --all-exported --repair-cuts --dry-run")
	print("Opciones:")
	print("  --dry-run       Solo informa cambios. Es el modo por defecto.")
	print("  --apply         Escribe height.exr y actualiza height_preview.png.")
	print("  --repair-cuts   Limita saltos verticales no intencionales.")
	print("  --smooth        Suaviza todo el heightmap.")
	print("  --allow-cuts    Conserva saltos muy fuertes como cortes intencionales.")
	print("  --threshold N   Salto maximo permitido en metros. Default repair: 1.5; smooth: 2.5.")
	print("  --strength N    Fuerza 0..1. Default repair: 0.95; smooth: 0.55.")
	print("  --iterations N  Pasadas. Default repair: 8; smooth: 3.")
	print("  --sector X Y    Procesa un sector.")
	print("  --all-exported  Procesa todas las carpetas exportadas.")
	print("  --limit N       Limita cantidad de sectores.")
