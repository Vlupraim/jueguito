extends CanvasLayer

signal inventory_visibility_changed(is_visible: bool)
signal pause_visibility_changed(is_visible: bool)

@onready var inventory_panel: PanelContainer = %InventoryPanel
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var empty_inventory_label: Label = %EmptyInventoryLabel
@onready var inventory_close_button: Button = %InventoryCloseButton
@onready var pause_backdrop: ColorRect = %PauseBackdrop
@onready var pause_menu_panel: PanelContainer = %MenuPanel
@onready var continue_button: Button = %ContinueButton
@onready var options_button: Button = %PauseOptionsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_game_button: Button = %QuitGameButton
@onready var options_menu: Control = %OptionsMenu
@onready var leave_world_confirmation: ConfirmationDialog = %LeaveWorldConfirmation
@onready var quit_game_confirmation: ConfirmationDialog = %QuitGameConfirmation

var _owns_tree_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_panel.hide()
	pause_backdrop.hide()
	inventory_close_button.pressed.connect(close_inventory)
	continue_button.pressed.connect(close_pause_menu)
	options_button.pressed.connect(_open_options)
	main_menu_button.pressed.connect(_request_leave_world)
	quit_game_button.pressed.connect(_request_quit_game)
	options_menu.closed.connect(_on_options_closed)
	leave_world_confirmation.confirmed.connect(_leave_world_to_roster)
	quit_game_confirmation.confirmed.connect(_quit_game)
	if not GameManager.inventory_changed.is_connected(_render_inventory):
		GameManager.inventory_changed.connect(_render_inventory)
	_render_inventory(GameManager.player_inventory)


func _exit_tree() -> void:
	if _owns_tree_pause and get_tree() != null:
		get_tree().paused = false
	_owns_tree_pause = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if _is_key(key_event, KEY_I):
		if not pause_backdrop.visible:
			toggle_inventory()
		get_viewport().set_input_as_handled()
	elif _is_key(key_event, KEY_ESCAPE):
		if options_menu.visible:
			options_menu.call("close")
		elif inventory_panel.visible:
			close_inventory()
		elif pause_backdrop.visible:
			close_pause_menu()
		else:
			open_pause_menu()
		get_viewport().set_input_as_handled()


func toggle_inventory() -> void:
	if inventory_panel.visible:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	if pause_backdrop.visible:
		return
	inventory_panel.show()
	inventory_close_button.grab_focus()
	inventory_visibility_changed.emit(true)


func close_inventory() -> void:
	if not inventory_panel.visible:
		return
	inventory_panel.hide()
	inventory_visibility_changed.emit(false)


func open_pause_menu() -> void:
	close_inventory()
	pause_backdrop.show()
	pause_menu_panel.show()
	options_menu.hide()
	_owns_tree_pause = true
	get_tree().paused = true
	continue_button.grab_focus()
	pause_visibility_changed.emit(true)


func close_pause_menu() -> void:
	if not pause_backdrop.visible:
		return
	options_menu.hide()
	pause_backdrop.hide()
	if _owns_tree_pause:
		get_tree().paused = false
		_owns_tree_pause = false
	pause_visibility_changed.emit(false)


func _open_options() -> void:
	pause_menu_panel.hide()
	options_menu.call("open")


func _on_options_closed() -> void:
	if pause_backdrop.visible:
		pause_menu_panel.show()
		options_button.grab_focus()


func _request_leave_world() -> void:
	if bool(SettingsManager.get_setting("general", "confirm_exit", true)):
		leave_world_confirmation.popup_centered()
	else:
		_leave_world_to_roster()


func _leave_world_to_roster() -> void:
	if _owns_tree_pause:
		get_tree().paused = false
		_owns_tree_pause = false
	main_menu_button.disabled = true
	main_menu_button.text = "Guardando personaje…"
	GameManager.request_leave_world_to_roster()


func _request_quit_game() -> void:
	if bool(SettingsManager.get_setting("general", "confirm_exit", true)):
		quit_game_confirmation.popup_centered()
	else:
		_quit_game()


func _quit_game() -> void:
	if _owns_tree_pause:
		get_tree().paused = false
		_owns_tree_pause = false
	if not NetworkManager.current_character_name.is_empty():
		NetworkManager.request_despawn()
		await NetworkManager.player_despawned
	get_tree().quit()


func _render_inventory(inventory: Dictionary) -> void:
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()

	var item_names: Array[String] = []
	for item_name in inventory.keys():
		item_names.append(str(item_name))
	item_names.sort()
	empty_inventory_label.visible = item_names.is_empty()

	for item_name in item_names:
		inventory_grid.add_child(_create_item_slot(item_name, int(inventory.get(item_name, 0))))


func _create_item_slot(item_name: String, quantity: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(76.0, 82.0)
	slot.tooltip_text = item_name

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	slot.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(content)

	var icon_placeholder := Label.new()
	icon_placeholder.text = item_name.left(1).to_upper()
	icon_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_placeholder.add_theme_font_size_override("font_size", 22)
	icon_placeholder.add_theme_color_override("font_color", Color(0.55, 0.76, 1.0))
	content.add_child(icon_placeholder)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 11)
	content.add_child(name_label)

	var quantity_label := Label.new()
	quantity_label.text = "x%d" % quantity
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.96))
	content.add_child(quantity_label)
	return slot


func _is_key(event: InputEventKey, expected_key: Key) -> bool:
	return event.keycode == expected_key or event.physical_keycode == expected_key
