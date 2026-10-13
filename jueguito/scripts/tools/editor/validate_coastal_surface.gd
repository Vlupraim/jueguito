extends SceneTree

func _initialize() -> void:
	var report := {"regions":0,"height_maps_identical":true,"navigation_holes_identical":true,"changed_surface_pixels":0}
	var texture_mask := (31<<27)|(31<<22)|(255<<14)
	for filename in ["terrain3d_00_00.res","terrain3d_00_01.res","terrain3d_01_00.res","terrain3d_01_01.res"]:
		var before := load("res://data/terrain3d_edit_backups/coast_surface_v2_before/"+filename) as Terrain3DRegion
		var after := load("res://data/terrain3d_edits/sector_27_30/"+filename) as Terrain3DRegion
		if before == null or after == null:
			push_error("Missing local before/after region: "+filename)
			quit(1)
			return
		if before.get_map(Terrain3DRegion.TYPE_HEIGHT).get_data() != after.get_map(Terrain3DRegion.TYPE_HEIGHT).get_data(): report.height_maps_identical = false
		var old := before.get_map(Terrain3DRegion.TYPE_CONTROL).get_data()
		var fresh := after.get_map(Terrain3DRegion.TYPE_CONTROL).get_data()
		for offset in range(0,old.size(),4):
			var a := int(old.decode_u32(offset))
			var b := int(fresh.decode_u32(offset))
			if a != b: report.changed_surface_pixels += 1
			if (a & ~texture_mask) != (b & ~texture_mask): report.navigation_holes_identical = false
		report.regions += 1
	FileAccess.open("res://../art/environment/material_audit_v1/coast_paint_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COAST_PAINT_VALIDATION ",report)
	quit(0 if report.height_maps_identical and report.navigation_holes_identical else 1)
