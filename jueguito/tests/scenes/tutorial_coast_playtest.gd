extends Node

const WORLD := preload("res://scenes/terrain3d_walk_preview.tscn")
const WORKSPACE := preload("res://scenes/tools/editor/terrain3d_sector_workspace.tscn")
const OUTPUT := "res://../art/environment/material_audit_v1/"

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	GameManager.should_play_tutorial_intro = false
	NetworkManager.current_character_name = "Vlupraim"
	GameManager.player_inventory = {"Hacha de leñador":1,"Madera":10}
	assert(GameManager.equip_tool("Hacha de leñador"))
	var world := WORLD.instantiate()
	add_child(world)
	for _frame in range(50): await get_tree().physics_frame
	var terrain: Terrain3D = world.get("terrain")
	var ocean: OceanWater = world.get("ocean_water")
	var dressing := world.get_node("SectorContent/Vegetation/CoastDressing")
	var trees := dressing.get_node("HarvestableTrees").get_children()
	assert(trees.size() == 11)
	var ids := {}
	for tree: HarvestableTree in trees:
		assert(tree.model_scene.resource_path.ends_with("harvestable_tree_01.glb"), "Tree from another biome remained on coast")
		var painted := terrain.data.get_texture_id(tree.global_position)
		var dominant := int(painted.x if painted.z < 0.5 else painted.y)
		assert(dominant == 2, "Pine remains on sand or rock")
		assert(not ids.has(tree.resource_id), "Duplicate harvest resource ID")
		ids[tree.resource_id] = true
		assert(absf(tree.global_position.y - terrain.data.get_height(tree.global_position)) < 0.03, "Floating tree")
		assert(not bool(ocean.get_water_info(tree.global_position,tree.global_position.y).get("in_water",false)), "Tree in water")
		assert(tree.get_node("TrunkBody/CollisionShape3D").shape != null)
	var player: CharacterBody3D = world.get("player")
	if DisplayServer.get_name() != "headless":
		await _capture(world,player,"costa_con_arboles_v1",Vector3(280,10,214),Vector3(287,9,267))
	var tree: HarvestableTree = trees[0]
	var near := tree.global_position + Vector3(1.8,0,-1.8)
	near.y = terrain.data.get_height(near) + float(player.get("ground_clearance"))
	player.position = near
	player.velocity = Vector3.ZERO
	for _tick in range(5): await get_tree().physics_frame
	assert(tree.can_interact(player), "Equipped axe was not recognized")
	assert(player.request_interaction_with(tree), "Player could not start harvesting")
	await get_tree().create_timer(1.8).timeout
	assert(tree.busy, "Harvest never started")
	if DisplayServer.get_name() != "headless":
		await _capture(world,player,"tala_en_costa_v1",player.position + Vector3(3,1.8,-3),tree.global_position + Vector3.UP*1.8)
	await get_tree().create_timer(6.5).timeout
	assert(not tree.available and tree.get_node("StumpVisual").visible, "Harvested tree did not leave a stump")
	assert(int(GameManager.player_inventory.get("Madera",0)) == 14, "Wood reward was not delivered")
	print("TUTORIAL_COAST_PLAYTEST_OK trees=11 pine_only=true grass_under_all=true grounded=true dry=true axe=true chop=true wood=4 stump=true")
	world.queue_free()
	await get_tree().process_frame
	var workspace := WORKSPACE.instantiate()
	add_child(workspace)
	await get_tree().process_frame
	await get_tree().process_frame
	var importer := workspace.get_node("Importer") as Terrain3D
	assert(importer.assets.get_texture_count() == 25)
	assert(not importer.material.show_checkered)
	assert(workspace.get_node("SectorContent/Vegetation/CoastDressing/HarvestableTrees").get_child_count() == 11)
	if DisplayServer.get_name() != "headless":
		var camera := workspace.get_node("WorkspaceCamera") as Camera3D
		workspace.get_node("SectorGuide").hide()
		camera.position = Vector3(337,42,290)
		camera.look_at(Vector3(282,5,219))
		camera.current = true
		importer.set_camera(camera)
		for _frame in range(20): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+"workspace_costa_v1.png"))
	print("TUTORIAL_COAST_WORKSPACE_OK slots=25 checkered=false trees=11")
	workspace.queue_free()
	await get_tree().process_frame
	var reopened := WORLD.instantiate()
	add_child(reopened)
	for _frame in range(3): await get_tree().process_frame
	var reopened_terrain: Terrain3D = reopened.get("terrain")
	assert(reopened_terrain.assets.get_texture_count() == 25, "Returning to gameplay lost texture arrays")
	assert(not reopened_terrain.material.show_checkered)
	print("TUTORIAL_COAST_REENTRY_OK slots=25 checkered=false")
	reopened.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _capture(world: Node, player: CharacterBody3D, filename: String, position: Vector3, target: Vector3) -> void:
	var camera := world.get_node_or_null("CoastCaptureCamera") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "CoastCaptureCamera"
		world.add_child(camera)
	camera.fov = 65
	camera.far = 1600
	camera.position = position
	camera.look_at(target)
	camera.current = true
	(world.get("terrain") as Terrain3D).set_camera(camera)
	for _frame in range(10): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename+".png"))
