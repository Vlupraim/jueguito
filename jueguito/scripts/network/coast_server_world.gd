extends RefCounted

var heights: Array[Image] = []
var trees: Dictionary = {}
var build_id := ""

func load_world() -> bool:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/network/coast_session_catalog.json"))
	if not catalog is Dictionary: return false
	trees = catalog.get("trees", {})
	build_id = str(catalog.get("build_id", ""))
	for name in ["terrain3d_00_00.res","terrain3d_01_00.res","terrain3d_00_01.res","terrain3d_01_01.res"]:
		var region := load("res://data/terrain3d_edits/sector_27_30/"+name) as Terrain3DRegion
		if region == null: return false
		heights.append(region.get_map(Terrain3DRegion.TYPE_HEIGHT))
	return true

func height_at(point: Vector3) -> float:
	var x := clampf(point.x, 0, 510.99)
	var z := clampf(point.z, 0, 510.99)
	var ix := floori(x)
	var iz := floori(z)
	return lerpf(lerpf(_sample(ix,iz),_sample(ix+1,iz),x-ix),lerpf(_sample(ix,iz+1),_sample(ix+1,iz+1),x-ix),z-iz)

func _sample(x: int,z: int) -> float:
	return heights[(z/256)*2+x/256].get_pixel(x%256,z%256).r

func spawn(slot: int) -> Vector3:
	var point := Vector3(283+(slot%4)*2.4,0,211+(slot/4)*2.4)
	point.y = height_at(point)+0.78
	return point

func valid_position(point: Vector3) -> bool:
	if not point.is_finite() or point.x < 1 or point.z < 1 or point.x > 510 or point.z > 510: return false
	var ground := height_at(point)+0.78
	return point.y >= ground-0.65 and point.y <= maxf(ground,2.78)+3.0

func tree_position(id: String) -> Vector3:
	var p: Array = trees[id]["position"]
	return Vector3(p[0],p[1],p[2])
