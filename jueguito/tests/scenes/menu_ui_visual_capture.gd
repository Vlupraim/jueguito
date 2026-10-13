extends Node

const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const CHARACTER_SELECTION_SCENE := preload("res://scenes/ui/character_selection_3d.tscn")
const OUTPUT_DIR := "res://docs/design/concepts/ui"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var menu := MAIN_MENU_SCENE.instantiate()
	add_child(menu)
	for _frame in range(4):
		await get_tree().process_frame
	_save_viewport("main_menu_product_v2.png")

	menu.call("_show_login")
	for _frame in range(3):
		await get_tree().process_frame
	_save_viewport("login_product_v2.png")

	menu.call("_show_view", menu.get("credits_view"))
	for _frame in range(3):
		await get_tree().process_frame
	_save_viewport("credits_product_v2.png")
	menu.call("_show_landing")
	menu.get("exit_confirmation").popup_centered()
	for _frame in range(3):
		await get_tree().process_frame
	_save_viewport("exit_confirmation_product_v2.png")
	menu.get("exit_confirmation").hide()

	var options: Control = menu.get("options_menu")
	options.call("open")
	var option_names := ["general", "video", "audio", "controls", "accessibility"]
	for tab_index in range(option_names.size()):
		options.get("tabs").current_tab = tab_index
		for _frame in range(2):
			await get_tree().process_frame
		_save_viewport("options_%s_product_v2.png" % option_names[tab_index])
	options.call("close")

	menu.queue_free()
	await get_tree().process_frame
	var selector := CHARACTER_SELECTION_SCENE.instantiate()
	add_child(selector)
	for _frame in range(12):
		await get_tree().process_frame
	_save_viewport("character_roster_product_v2.png")
	selector.call("_show_creator")
	for _frame in range(30):
		await get_tree().process_frame
	_save_viewport("character_creator_product_v2.png")

	selector.queue_free()
	await get_tree().process_frame
	print("MENU_UI_VISUAL_CAPTURE_OK")
	get_tree().quit(0)


func _save_viewport(file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_DIR.path_join(file_name))
	if error != OK:
		push_error("No se pudo guardar la captura %s" % file_name)
