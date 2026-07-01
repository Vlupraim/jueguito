@tool
extends SceneTree

const EXPORTER_SCRIPT := preload("res://scripts/tools/editor/terrain3d_sector_exporter.gd")
const TERRAIN3D_EXPORT_DIR := "res://data/terrain3d_exports"
const TERRAIN3D_EDIT_DIR := "res://data/terrain3d_edits"
const TERRAIN3D_EDIT_BACKUP_DIR := "res://data/terrain3d_edit_backups"
const EXPECTED_EXPORT_RESOLUTION := 512

const KEEP_2X2_REGIONS := {
	"terrain3d_00_00.res": true,
	"terrain3d_00_01.res": true,
	"terrain3d_01_00.res": true,
	"terrain3d_01_01.res": true,
}


func _initialize() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	if not bool(options.get("ok", false)):
		printerr(str(options.get("message", "Argumentos invalidos.")))
		_print_usage()
		quit(2)
		return

	var sectors := _resolve_sectors(options)
	if sectors.is_empty():
		printerr("No hay sectores para procesar.")
		_print_usage()
		quit(2)
		return

	var limit := int(options.get("limit", 0))
	if limit > 0 and sectors.size() > limit:
		sectors = sectors.slice(0, limit)

	var dry_run := bool(options.get("dry_run", true))
	var regenerate := bool(options.get("regenerate", false))
	var edit_mode := str(options.get("edit_mode", "none"))
	var use_biomes := bool(options.get("use_biomes", true))
	var backup_root := ""
	if edit_mode != "none":
		backup_root = _make_backup_root(dry_run)

	print("Terrain3D maintenance")
	print("  sectores: " + str(sectors.size()))
	print("  regenerar exports: " + str(regenerate))
	print("  ediciones: " + edit_mode)
	print("  dry-run: " + str(dry_run))
	if backup_root != "":
		print("  backup: " + backup_root)

	var exporter: RefCounted = EXPORTER_SCRIPT.new()
	var failed := 0
	var regenerated := 0
	var edit_files_moved := 0
	for sector in sectors:
		var label := _sector_label(sector)
		if regenerate:
			if dry_run:
				print(label + " export se regeneraria a " + str(EXPECTED_EXPORT_RESOLUTION) + ".")
			else:
				var result: Dictionary = exporter.call("export_sector", sector, use_biomes)
				if not bool(result.get("ok", false)):
					failed += 1
					printerr(label + " error exportando: " + str(result.get("message", "error desconocido")))
					continue
				regenerated += 1
				print(label + " export regenerado.")

		if edit_mode != "none":
			var moved := _maintain_edit_dir(sector, edit_mode, backup_root, dry_run)
			edit_files_moved += moved
			if moved > 0:
				print(label + " ediciones movidas a backup: " + str(moved))

	print("Listo. Exports regenerados: " + str(regenerated) + ". Archivos de edicion movidos: " + str(edit_files_moved) + ". Fallos: " + str(failed) + ".")
	quit(1 if failed > 0 else 0)


func _parse_options(args: PackedStringArray) -> Dictionary:
	var options := {
		"ok": true,
		"dry_run": true,
		"regenerate": false,
		"edit_mode": "none",
		"use_biomes": true,
		"all_exported": false,
		"only_old": false,
		"limit": 0,
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
			"--regenerate":
				options["regenerate"] = true
			"--trim-edits":
				options["edit_mode"] = "trim"
			"--clear-edits":
				options["edit_mode"] = "clear"
			"--all-exported":
				options["all_exported"] = true
			"--only-old":
				options["only_old"] = true
			"--no-biomes":
				options["use_biomes"] = false
			"--sector":
				if index + 2 >= args.size():
					return {"ok": false, "message": "--sector necesita X Y."}
				var sector := Vector2i(int(args[index + 1]), int(args[index + 2]))
				(options["sectors"] as Array).append(sector)
				index += 2
			"--limit":
				if index + 1 >= args.size():
					return {"ok": false, "message": "--limit necesita un numero."}
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

	if bool(options.get("only_old", false)) and not bool(options.get("all_exported", false)):
		options["all_exported"] = true
	return options


func _resolve_sectors(options: Dictionary) -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	for value in options.get("sectors", []):
		if value is Vector2i:
			sectors.append(value)

	if bool(options.get("all_exported", false)):
		sectors = _list_exported_sectors()

	if bool(options.get("only_old", false)):
		var old_sectors: Array[Vector2i] = []
		for sector in sectors:
			if _export_resolution(sector) != EXPECTED_EXPORT_RESOLUTION:
				old_sectors.append(sector)
		sectors = old_sectors

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


func _export_resolution(sector: Vector2i) -> int:
	var metadata_path := ProjectSettings.globalize_path(_export_dir(sector) + "/metadata.json")
	if not FileAccess.file_exists(metadata_path):
		return -1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not (parsed is Dictionary):
		return -1
	return int((parsed as Dictionary).get("export_resolution", -1))


func _maintain_edit_dir(sector: Vector2i, mode: String, backup_root: String, dry_run: bool) -> int:
	var edit_abs := ProjectSettings.globalize_path(_edit_dir(sector))
	var dir := DirAccess.open(edit_abs)
	if dir == null:
		return 0

	var moved := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "res":
			var should_move := mode == "clear" or not KEEP_2X2_REGIONS.has(file_name)
			if should_move:
				moved += 1
				if not dry_run:
					var backup_sector_abs := backup_root.path_join(_sector_dir_name(sector))
					var backup_error := DirAccess.make_dir_recursive_absolute(backup_sector_abs)
					if backup_error != OK:
						printerr(_sector_label(sector) + " no pude crear backup: " + backup_sector_abs)
					else:
						var source_abs := edit_abs.path_join(file_name)
						var backup_abs := backup_sector_abs.path_join(file_name)
						var copy_error := _copy_file(source_abs, backup_abs)
						if copy_error != OK:
							printerr(_sector_label(sector) + " no pude copiar backup de " + file_name + ".")
						else:
							dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return moved


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
	var stamp := Time.get_datetime_string_from_system(false, true)
	stamp = stamp.replace(":", "").replace("-", "").replace("T", "_")
	var backup_root := ProjectSettings.globalize_path(TERRAIN3D_EDIT_BACKUP_DIR).path_join(stamp)
	if not dry_run:
		DirAccess.make_dir_recursive_absolute(backup_root)
	return backup_root


func _export_dir(sector: Vector2i) -> String:
	return TERRAIN3D_EXPORT_DIR + "/" + _sector_dir_name(sector)


func _edit_dir(sector: Vector2i) -> String:
	return TERRAIN3D_EDIT_DIR + "/" + _sector_dir_name(sector)


func _sector_dir_name(sector: Vector2i) -> String:
	return "sector_%d_%d" % [sector.x, sector.y]


func _sector_label(sector: Vector2i) -> String:
	return "[" + str(sector.x) + ", " + str(sector.y) + "]"


func _print_usage() -> void:
	print("Uso:")
	print("  godot --headless --path . --script res://scripts/tools/editor/terrain3d_export_maintenance.gd -- --sector 12 9 --regenerate --clear-edits --apply")
	print("  godot --headless --path . --script res://scripts/tools/editor/terrain3d_export_maintenance.gd -- --all-exported --only-old --regenerate --apply")
	print("Opciones:")
	print("  --dry-run       Solo muestra lo que haria. Es el modo por defecto.")
	print("  --apply         Aplica cambios reales.")
	print("  --regenerate    Reexporta height/control/metadata con el generador actual.")
	print("  --clear-edits   Mueve todas las regiones guardadas del sector a backup.")
	print("  --trim-edits    Mueve solo regiones fuera del 2x2 a backup.")
	print("  --all-exported  Procesa todas las carpetas en data/terrain3d_exports.")
	print("  --only-old      Procesa solo exports con resolucion distinta de 512.")
