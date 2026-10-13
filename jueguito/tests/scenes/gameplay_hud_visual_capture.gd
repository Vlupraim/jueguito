extends Node

const HUD_SCENE := preload("res://scenes/ui/gameplay_hud.tscn")
const OUTPUT_DIR := "res://tests/output"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_capture")


func _capture() -> void:
	get_window().size = Vector2i(1280, 720)
	GameManager.current_character = {
		"name": "Vlupraim",
		"level": 1,
		"model_path": "res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb",
		"animation_source_path": "res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb",
	}
	GameManager.player_inventory = {
		"Madera": 10,
		"Hierro": 5,
		"Hacha de leñador": 1,
		"Espada vikinga": 2,
		"Escudo vikingo": 1,
		"Arco vikingo": 1,
	}
	var backdrop := ColorRect.new()
	backdrop.color = Color("24372f")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	for _frame in range(20):
		await get_tree().process_frame
	_save("gameplay_hud_redesign.png")
	hud.call("set_hud_edit_mode", true)
	for _frame in range(3):
		await get_tree().process_frame
	_save("gameplay_hud_edit_three_modules.png")
	hud.call("set_hud_edit_mode", false)
	hud.call("open_inventory")
	for _frame in range(20):
		await get_tree().process_frame
	_save("inventory_hud_redesign.png")
	hud.call("_toggle_inventory_stats")
	for _frame in range(3):
		await get_tree().process_frame
	_save("inventory_hud_stats_expanded.png")
	hud.call("_toggle_inventory_stats")
	hud.call("open_mastery_tree")
	for _frame in range(8):
		await get_tree().process_frame
	_save("mastery_tree_redesign.png")
	hud.call("close_mastery_tree")
	hud.call("close_inventory")
	hud.call("open_pause_menu")
	for _frame in range(4):
		await get_tree().process_frame
	_save("pause_menu_product_v2.png")
	hud.call("_open_options")
	for _frame in range(4):
		await get_tree().process_frame
	_save("options_ingame_product_v2.png")
	hud.get("options_menu").call("close")
	hud.get("leave_world_confirmation").popup_centered()
	for _frame in range(3):
		await get_tree().process_frame
	_save("leave_world_confirmation_product_v2.png")
	hud.get("leave_world_confirmation").hide()
	hud.get("quit_game_confirmation").popup_centered()
	for _frame in range(3):
		await get_tree().process_frame
	_save("quit_game_confirmation_product_v2.png")
	hud.get("quit_game_confirmation").hide()
	hud.queue_free()
	backdrop.queue_free()
	for _frame in range(4):
		await get_tree().process_frame
	print("GAMEPLAY_HUD_VISUAL_CAPTURE_OK")
	get_tree().quit(0)


func _save(file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_DIR.path_join(file_name))
	if error != OK:
		push_error("No se pudo guardar " + file_name)
