extends RefCounted

var heights: Array[Image] = []
var trees: Dictionary = {}
var build_id := ""
var combat_blockers: Array = []
var collider_root: Node3D

func load_world() -> bool:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/network/coast_session_catalog.json"))
	if not catalog is Dictionary: return false
	trees = catalog.get("trees", {})
	build_id = str(catalog.get("build_id", ""))
	combat_blockers = catalog.get("combat_blockers", [])
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
	if not point.is_finite() or point.x < 48 or point.z < 48 or point.x >= 464 or point.z >= 464: return false
	var ground := height_at(point)+0.78
	return point.y >= ground-0.65 and point.y <= maxf(ground,2.78)+3.0

func tree_position(id: String) -> Vector3:
	var p: Array = trees[id]["position"]
	return Vector3(p[0],p[1],p[2])

func install_combat_colliders(parent: Node) -> void:
	collider_root = Node3D.new()
	collider_root.name = "ServerCombatGeometry"
	parent.add_child(collider_root)
	for data: Dictionary in combat_blockers:
		var shape: Shape3D
		match str(data["type"]):
			"BoxShape3D":
				shape = BoxShape3D.new()
				shape.size = _vector(data["size"])
			"SphereShape3D":
				shape = SphereShape3D.new()
				shape.radius = float(data["radius"])
			"CapsuleShape3D", "CylinderShape3D":
				shape = CapsuleShape3D.new() if data["type"] == "CapsuleShape3D" else CylinderShape3D.new()
				shape.radius = float(data["radius"])
				shape.height = float(data["height"])
			"ConvexPolygonShape3D", "ConcavePolygonShape3D":
				var points := PackedVector3Array()
				for point: Array in data["points"]: points.append(_vector(point))
				if data["type"] == "ConvexPolygonShape3D":
					shape = ConvexPolygonShape3D.new()
					shape.points = points
				else:
					shape = ConcavePolygonShape3D.new()
					shape.set_faces(points)
					shape.backface_collision = true
		if shape == null: continue
		var body := StaticBody3D.new()
		body.set_meta("resource_id",str(data.get("resource_id","")))
		body.collision_layer = 8
		body.collision_mask = 0
		var values: Array = data["transform"]
		body.transform = Transform3D(Basis(_vector(values[0]),_vector(values[1]),_vector(values[2])),_vector(values[3]))
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		collider_root.add_child(body)

func combat_line_clear(from: Vector3, to: Vector3, depleted: Dictionary = {}) -> bool:
	var start := from + Vector3.UP * 0.55
	var end := to + Vector3.UP * 0.55
	for index in range(1,8):
		var sample := start.lerp(end,index/8.0)
		if height_at(sample) > sample.y: return false
	if is_instance_valid(collider_root):
		var query := PhysicsRayQueryParameters3D.create(start,end,8)
		var excluded: Array[RID] = []
		for body: StaticBody3D in collider_root.get_children():
			var resource_id := str(body.get_meta("resource_id",""))
			if float(depleted.get(resource_id,0.0)) > Time.get_unix_time_from_system(): excluded.append(body.get_rid())
		query.exclude = excluded
		if not collider_root.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
	return true

func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))
