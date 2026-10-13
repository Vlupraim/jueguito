extends SceneTree

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	var sector := load("res://scenes/world/sectors/handmade/sector_27_30.tscn").instantiate() as Node3D
	root.add_child(sector)
	var trees := {}
	for node: Node in sector.find_children("*","Node3D",true,false):
		if node is HarvestableTree:
			var point: Vector3 = node.global_position
			trees[node.resource_id] = {"position":[point.x,point.y,point.z],"amount":node.amount,"respawn_seconds":node.respawn_seconds}
	if trees.is_empty():
		push_error("No harvestable trees found; the existing catalog was preserved.")
		quit(1)
		return
	var hash_context := HashingContext.new()
	var blockers := []
	for node: Node in sector.find_children("*","CollisionShape3D",true,false):
		if not node.get_parent() is StaticBody3D or node.disabled or node.shape == null: continue
		var shape: Shape3D = node.shape
		var data := {"type":shape.get_class()}
		var owner_node: Node = node.get_parent()
		while owner_node != null and owner_node != sector:
			if owner_node is HarvestableTree:
				data["resource_id"] = owner_node.resource_id
				break
			owner_node = owner_node.get_parent()
		if shape is BoxShape3D:
			data["size"] = _vector(shape.size)
		elif shape is SphereShape3D:
			data["radius"] = shape.radius
		elif shape is CapsuleShape3D or shape is CylinderShape3D:
			data["radius"] = shape.radius
			data["height"] = shape.height
		elif shape is ConvexPolygonShape3D or shape is ConcavePolygonShape3D:
			var points: PackedVector3Array = shape.points if shape is ConvexPolygonShape3D else shape.get_faces()
			data["points"] = []
			for point in points: data["points"].append(_vector(point))
		else:
			push_error("Unsupported server combat collider: "+shape.get_class())
			quit(1)
			return
		var transform: Transform3D = node.global_transform
		data["transform"] = [_vector(transform.basis.x),_vector(transform.basis.y),_vector(transform.basis.z),_vector(transform.origin)]
		blockers.append(data)
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(JSON.stringify(blockers).to_utf8_buffer())
	hash_context.update(FileAccess.get_file_as_bytes("res://scenes/world/sectors/handmade/tutorial_coast_dressing.tscn"))
	var files := DirAccess.get_files_at("res://data/terrain3d_edits/sector_27_30")
	files.sort()
	for file in files:
		if file.ends_with(".res"): hash_context.update(FileAccess.get_file_as_bytes("res://data/terrain3d_edits/sector_27_30/"+file))
	var catalog := {"build_id":hash_context.finish().hex_encode().substr(0,16),"trees":trees,"combat_blockers":blockers}
	DirAccess.make_dir_recursive_absolute("res://data/network")
	var output := FileAccess.open("res://data/network/coast_session_catalog.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(catalog,"\t"))
	output.close()
	print("COOP_CATALOG ",trees.size()," trees build=",catalog["build_id"])
	sector.queue_free()
	await process_frame
	quit()

func _vector(point: Vector3) -> Array:
	return [point.x,point.y,point.z]
