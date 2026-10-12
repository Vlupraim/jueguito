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
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(FileAccess.get_file_as_bytes("res://scenes/world/sectors/handmade/tutorial_coast_dressing.tscn"))
	var files := DirAccess.get_files_at("res://data/terrain3d_edits/sector_27_30")
	files.sort()
	for file in files:
		if file.ends_with(".res"): hash_context.update(FileAccess.get_file_as_bytes("res://data/terrain3d_edits/sector_27_30/"+file))
	var catalog := {"build_id":hash_context.finish().hex_encode().substr(0,16),"trees":trees}
	DirAccess.make_dir_recursive_absolute("res://data/network")
	var output := FileAccess.open("res://data/network/coast_session_catalog.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(catalog,"\t"))
	output.close()
	print("COOP_CATALOG ",trees.size()," trees build=",catalog["build_id"])
	sector.queue_free()
	await process_frame
	quit()
