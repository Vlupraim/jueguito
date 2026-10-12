extends Node

const WORLD_SCENE := preload("res://scenes/terrain3d_walk_preview.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	GameManager.should_play_tutorial_intro = false
	GameManager.clear_equipment()
	GameManager.player_inventory = {
		"Oro": 120, "Madera": 10, "Hierro": 5,
		"Espada vikinga": 1, "Escudo vikingo": 1,
		"Arco vikingo": 1, "Hacha de leñador": 1,
	}
	var world := WORLD_SCENE.instantiate()
	add_child(world)
	var player: CharacterBody3D
	for _frame in range(180):
		await get_tree().process_frame
		player = world.get("player")
		if player != null and player.position.x > 250.0:
			break
	if player == null:
		get_tree().quit(1)
		return
	await _frames(10)
	var hud: CanvasLayer = world.get("gameplay_hud")
	hud.call("reset_hud_layout")
	world.call("_reset_minimap_hud_layout")
	player.call("set_camera_locked", true)
	await _capture("camera_lock_preview")
	player.call("try_jump")
	for _tick in range(10):
		await get_tree().physics_frame
	await _capture("jump_animation_preview")
	for _tick in range(30):
		await get_tree().physics_frame
	GameManager.toggle_item_equipped("Espada vikinga")
	hud.call("open_inventory")
	await _capture("inventory_yggdrasil_preview")
	hud.call("open_mastery_tree")
	await _capture("mastery_origin_preview")
	var tree: MasteryTreeView = hud.get("mastery_tree_view")
	tree.show_entire_tree()
	await _capture("mastery_overview_preview")
	tree.focus_family("MUNDO")
	await _capture("mastery_world_preview")
	hud.call("close_mastery_tree")
	hud.call("close_inventory")
	print("UI_VISUAL_CAPTURE_OK")
	get_tree().quit(0)

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _capture(filename: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/%s.png" % filename)
