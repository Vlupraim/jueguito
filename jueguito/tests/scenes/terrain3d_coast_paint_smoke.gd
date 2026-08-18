extends SceneTree

const CURRENT_DIR := "res://data/terrain3d_edits/sector_27_30"
const BACKUP_DIR := "res://data/terrain3d_edit_backups/20260802_133038_before_coast_paint/sector_27_30"
const FILES := ["terrain3d_00_00.res", "terrain3d_01_00.res", "terrain3d_00_01.res", "terrain3d_01_01.res"]


func _initialize() -> void:
	var max_height_delta := 0.0
	var changed_controls := 0
	var max_texture_id := 0
	for file_name in FILES:
		var current := ResourceLoader.load(CURRENT_DIR + "/" + file_name, "", ResourceLoader.CACHE_MODE_IGNORE) as Terrain3DRegion
		var backup := ResourceLoader.load(BACKUP_DIR + "/" + file_name, "", ResourceLoader.CACHE_MODE_IGNORE) as Terrain3DRegion
		if current == null or backup == null:
			printerr("COAST_PAINT_SMOKE_ERROR no se pudo cargar " + file_name)
			quit(2)
			return
		var current_height := current.get_map(Terrain3DRegion.TYPE_HEIGHT)
		var backup_height := backup.get_map(Terrain3DRegion.TYPE_HEIGHT)
		for y in range(current_height.get_height()):
			for x in range(current_height.get_width()):
				max_height_delta = maxf(max_height_delta, absf(current_height.get_pixel(x, y).r - backup_height.get_pixel(x, y).r))
		var current_control := current.get_map(Terrain3DRegion.TYPE_CONTROL).get_data()
		var backup_control := backup.get_map(Terrain3DRegion.TYPE_CONTROL).get_data()
		for offset in range(0, current_control.size(), 4):
			var packed := int(current_control.decode_u32(offset))
			max_texture_id = maxi(max_texture_id, (packed >> 27) & 0x1F)
			max_texture_id = maxi(max_texture_id, (packed >> 22) & 0x1F)
			if packed != backup_control.decode_u32(offset):
				changed_controls += 1

	if max_height_delta > 0.00001 or changed_controls == 0 or max_texture_id >= 24:
		printerr("COAST_PAINT_SMOKE_ERROR height_delta=%.7f changed_controls=%d max_texture_id=%d" % [max_height_delta, changed_controls, max_texture_id])
		quit(1)
		return
	print("COAST_PAINT_SMOKE_OK height_delta=%.7f changed_controls=%d max_texture_id=%d regions=4" % [max_height_delta, changed_controls, max_texture_id])
	quit(0)
