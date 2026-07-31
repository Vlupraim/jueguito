extends CanvasLayer

const ItemCatalog = preload("res://scripts/systems/items/item_catalog.gd")
const INVENTORY_CAPACITY := 24

signal inventory_visibility_changed(is_visible: bool)
signal pause_visibility_changed(is_visible: bool)
signal hud_edit_mode_changed(enabled: bool)

@onready var inventory_panel: PanelContainer = %InventoryPanel
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var empty_inventory_label: Label = %EmptyInventoryLabel
@onready var inventory_close_button: Button = %InventoryCloseButton
@onready var inventory_owner_name: Label = %InventoryOwnerName
@onready var inventory_gold_label: Label = %InventoryGoldLabel
@onready var inventory_item_count: Label = %InventoryItemCount
@onready var inventory_capacity: Label = %InventoryCapacity
@onready var inventory_free_slots: Label = %InventoryFreeSlots
@onready var primary_equipment_slot: Button = %PrimaryEquipmentSlot
@onready var secondary_equipment_slot: Button = %SecondaryEquipmentSlot
@onready var pause_backdrop: ColorRect = %PauseBackdrop
@onready var pause_menu_panel: PanelContainer = %MenuPanel
@onready var continue_button: Button = %ContinueButton
@onready var options_button: Button = %PauseOptionsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_game_button: Button = %QuitGameButton
@onready var edit_hud_button: Button = %EditHUDButton
@onready var persistent_hud: Control = %PersistentHUD
@onready var character_status: Control = %CharacterStatus
@onready var action_bar: Control = %ActionBar
@onready var currency_display: Control = %CurrencyDisplay
@onready var portrait_button: Button = %ToggleStats
@onready var character_status_details: VBoxContainer = %Status
@onready var gold_amount_label: Label = %GoldAmount
@onready var silver_amount_label: Label = %SilverAmount
@onready var hud_edit_toolbar: PanelContainer = %HUDEditToolbar
@onready var hud_edit_reset: Button = %Reset
@onready var hud_edit_done: Button = %Done
@onready var character_name_label: Label = %CharacterName
@onready var options_menu: Control = %OptionsMenu
@onready var leave_world_confirmation: ConfirmationDialog = %LeaveWorldConfirmation
@onready var quit_game_confirmation: ConfirmationDialog = %QuitGameConfirmation

var _owns_tree_pause := false
var _hud_edit_mode := false
var timed_action_panel: PanelContainer
var timed_action_label: Label
var timed_action_bar: ProgressBar
var timed_action_player: Node
var character_stats_popup: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_character_hub()
	inventory_panel.hide()
	pause_backdrop.hide()
	inventory_close_button.pressed.connect(close_inventory)
	primary_equipment_slot.pressed.connect(GameManager.unequip_slot.bind("primary"))
	secondary_equipment_slot.pressed.connect(GameManager.unequip_slot.bind("secondary"))
	continue_button.pressed.connect(close_pause_menu)
	options_button.pressed.connect(_open_options)
	main_menu_button.pressed.connect(_request_leave_world)
	quit_game_button.pressed.connect(_request_quit_game)
	edit_hud_button.pressed.connect(_start_hud_edit_from_pause)
	hud_edit_reset.pressed.connect(reset_hud_layout)
	hud_edit_done.pressed.connect(set_hud_edit_mode.bind(false))
	options_menu.closed.connect(_on_options_closed)
	leave_world_confirmation.confirmed.connect(_leave_world_to_roster)
	quit_game_confirmation.confirmed.connect(_quit_game)
	if not GameManager.inventory_changed.is_connected(_render_inventory):
		GameManager.inventory_changed.connect(_render_inventory)
	if not GameManager.equipment_changed.is_connected(_on_equipment_changed):
		GameManager.equipment_changed.connect(_on_equipment_changed)
	_render_inventory(GameManager.player_inventory)
	_render_equipment_slots()
	if not GameManager.current_character.is_empty():
		var character_name := str(GameManager.current_character.get("name", "Aventurero"))
		character_name_label.text = character_name
		inventory_owner_name.text = character_name
	_setup_timed_action_progress()


func _process(_delta: float) -> void:
	if character_stats_popup != null and character_stats_popup.visible:
		_position_character_stats_popup()


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

	if _is_key(key_event, KEY_F10):
		set_hud_edit_mode(not _hud_edit_mode)
		get_viewport().set_input_as_handled()
	elif _hud_edit_mode and _is_key(key_event, KEY_ESCAPE):
		set_hud_edit_mode(false)
		get_viewport().set_input_as_handled()
	elif _is_key(key_event, KEY_I):
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


func set_persistent_hud_visible(is_visible: bool) -> void:
	persistent_hud.visible = is_visible
	if not is_visible and _hud_edit_mode:
		set_hud_edit_mode(false)


func set_hud_edit_mode(enabled: bool) -> void:
	_hud_edit_mode = enabled
	persistent_hud.show()
	hud_edit_toolbar.visible = enabled
	if character_stats_popup != null:
		character_stats_popup.hide()
	portrait_button.disabled = enabled
	portrait_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP
	character_status.call("set_edit_mode", enabled)
	action_bar.call("set_edit_mode", enabled)
	currency_display.call("set_edit_mode", enabled)
	hud_edit_mode_changed.emit(enabled)


func reset_hud_layout() -> void:
	character_status.call("reset_layout")
	action_bar.call("reset_layout")
	currency_display.call("reset_layout")


func toggle_character_stats() -> void:
	if _hud_edit_mode or character_stats_popup == null:
		return
	character_stats_popup.visible = not character_stats_popup.visible
	portrait_button.tooltip_text = (
		"Ocultar estadisticas del personaje"
		if character_stats_popup.visible
		else "Mostrar estadisticas del personaje"
	)
	if character_stats_popup.visible:
		call_deferred("_position_character_stats_popup")


func _setup_character_hub() -> void:
	character_stats_popup = PanelContainer.new()
	character_stats_popup.name = "CharacterStatsPopup"
	character_stats_popup.z_index = 8
	character_stats_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.055, 0.047, 0.034, 0.96)
	popup_style.border_color = Color(0.55, 0.43, 0.24, 0.94)
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(9)
	popup_style.shadow_color = Color(0, 0, 0, 0.55)
	popup_style.shadow_size = 8
	character_stats_popup.add_theme_stylebox_override("panel", popup_style)
	persistent_hud.add_child(character_stats_popup)

	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 12)
	stats_margin.add_theme_constant_override("margin_top", 10)
	stats_margin.add_theme_constant_override("margin_right", 12)
	stats_margin.add_theme_constant_override("margin_bottom", 10)
	character_stats_popup.add_child(stats_margin)
	character_status_details.reparent(stats_margin)
	character_stats_popup.hide()
	portrait_button.pressed.connect(toggle_character_stats)


func _position_character_stats_popup() -> void:
	if character_stats_popup == null or not character_stats_popup.visible:
		return
	var portrait_rect := character_status.get_global_rect()
	character_stats_popup.scale = character_status.scale
	var popup_visual_size := character_stats_popup.size * character_stats_popup.scale
	var viewport_rect := get_viewport().get_visible_rect()
	character_stats_popup.global_position = Vector2(
		clampf(
			portrait_rect.get_center().x - popup_visual_size.x * 0.5,
			viewport_rect.position.x + 8.0,
			viewport_rect.end.x - popup_visual_size.x - 8.0
		),
		maxf(
			portrait_rect.position.y - popup_visual_size.y - 8.0,
			viewport_rect.position.y + 8.0
		)
	)


func bind_player(player: Node) -> void:
	if timed_action_player != null and is_instance_valid(timed_action_player):
		if timed_action_player.is_connected("timed_action_started", _on_timed_action_started):
			timed_action_player.disconnect("timed_action_started", _on_timed_action_started)
		if timed_action_player.is_connected("timed_action_progress", _on_timed_action_progress):
			timed_action_player.disconnect("timed_action_progress", _on_timed_action_progress)
		if timed_action_player.is_connected("timed_action_finished", _on_timed_action_finished):
			timed_action_player.disconnect("timed_action_finished", _on_timed_action_finished)
	timed_action_player = player
	if timed_action_player == null:
		return
	timed_action_player.connect("timed_action_started", _on_timed_action_started)
	timed_action_player.connect("timed_action_progress", _on_timed_action_progress)
	timed_action_player.connect("timed_action_finished", _on_timed_action_finished)


func _setup_timed_action_progress() -> void:
	timed_action_panel = PanelContainer.new()
	timed_action_panel.name = "TimedActionProgress"
	timed_action_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	timed_action_panel.offset_left = -190.0
	timed_action_panel.offset_top = -138.0
	timed_action_panel.offset_right = 190.0
	timed_action_panel.offset_bottom = -78.0
	timed_action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.04, 0.03, 0.94)
	panel_style.border_color = Color(0.62, 0.47, 0.22, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	timed_action_panel.add_theme_stylebox_override("panel", panel_style)
	persistent_hud.add_child(timed_action_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	timed_action_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	timed_action_label = Label.new()
	timed_action_label.name = "TimedActionLabel"
	timed_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timed_action_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.66))
	timed_action_label.add_theme_font_size_override("font_size", 14)
	content.add_child(timed_action_label)

	timed_action_bar = ProgressBar.new()
	timed_action_bar.name = "TimedActionBar"
	timed_action_bar.custom_minimum_size = Vector2(350.0, 17.0)
	timed_action_bar.show_percentage = false
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.08, 0.07, 0.05, 1.0)
	background_style.set_corner_radius_all(4)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.68, 0.45, 0.16, 1.0)
	fill_style.set_corner_radius_all(4)
	timed_action_bar.add_theme_stylebox_override("background", background_style)
	timed_action_bar.add_theme_stylebox_override("fill", fill_style)
	content.add_child(timed_action_bar)
	timed_action_panel.hide()


func _on_timed_action_started(label: String, duration: float) -> void:
	timed_action_label.text = label
	timed_action_bar.max_value = maxf(duration, 0.05)
	timed_action_bar.value = 0.0
	timed_action_panel.show()


func _on_timed_action_progress(elapsed: float, duration: float) -> void:
	timed_action_bar.max_value = maxf(duration, 0.05)
	timed_action_bar.value = clampf(elapsed, 0.0, timed_action_bar.max_value)


func _on_timed_action_finished(_completed: bool) -> void:
	timed_action_panel.hide()


func _start_hud_edit_from_pause() -> void:
	close_pause_menu()
	set_hud_edit_mode(true)


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
	_update_currency_display(inventory)
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()

	var item_names: Array[String] = []
	for item_name in inventory.keys():
		var display_name := str(item_name)
		if display_name in ["Oro", "Monedas de oro", "Gold", "Plata", "Monedas de plata", "Silver"]:
			continue
		item_names.append(display_name)
	item_names.sort()
	empty_inventory_label.visible = item_names.is_empty()
	var total_items := 0
	for item_name in item_names:
		total_items += maxi(int(inventory.get(item_name, 0)), 0)
	inventory_item_count.text = "OBJETOS  %d" % total_items
	inventory_capacity.text = "%d / %d" % [item_names.size(), INVENTORY_CAPACITY]
	var free_slots := maxi(INVENTORY_CAPACITY - item_names.size(), 0)
	inventory_free_slots.text = "%d espacios libres" % free_slots

	for item_name in item_names:
		inventory_grid.add_child(_create_item_slot(item_name, int(inventory.get(item_name, 0))))
	for index in range(free_slots):
		inventory_grid.add_child(_create_empty_inventory_slot(index))


func _update_currency_display(inventory: Dictionary) -> void:
	var gold := int(GameManager.current_character.get("gold", 0))
	for key in ["Oro", "Monedas de oro", "Gold"]:
		if inventory.has(key):
			gold = int(inventory[key])
			break
	var silver := int(GameManager.current_character.get("silver", 0))
	for key in ["Plata", "Monedas de plata", "Silver"]:
		if inventory.has(key):
			silver = int(inventory[key])
			break
	gold_amount_label.text = _format_compact_number(gold)
	gold_amount_label.tooltip_text = "%d monedas de oro" % gold
	silver_amount_label.text = _format_compact_number(silver)
	silver_amount_label.tooltip_text = "%d monedas de plata" % silver
	inventory_gold_label.text = "ORO  %s" % _format_compact_number(gold)
	inventory_gold_label.tooltip_text = "%d monedas de oro" % gold


func _format_compact_number(value: int) -> String:
	if value >= 1_000_000:
		return "%.1f M" % (float(value) / 1_000_000.0)
	if value >= 10_000:
		return "%.1f K" % (float(value) / 1_000.0)
	return str(value)


func _on_equipment_changed(_primary_item: String, _secondary_item: String) -> void:
	_render_inventory(GameManager.player_inventory)
	_render_equipment_slots()


func _render_equipment_slots() -> void:
	var secondary_display := GameManager.equipped_secondary_item
	if ItemCatalog.get_hand_usage(GameManager.equipped_primary_item) == "two_hand":
		secondary_display = GameManager.equipped_primary_item
	_set_equipment_button(
		primary_equipment_slot,
		"Mano principal",
		GameManager.equipped_primary_item
	)
	_set_equipment_button(
		secondary_equipment_slot,
		"Mano secundaria",
		secondary_display
	)


func _set_equipment_button(button: Button, label: String, item_name: String) -> void:
	if item_name.is_empty():
		button.text = label + "\nVacía"
		button.icon = null
		button.tooltip_text = label
		button.disabled = true
		return
	var suffix := ""
	if ItemCatalog.get_hand_usage(item_name) == "two_hand":
		suffix = " (Dos manos)"
	button.text = label + "\n" + item_name + suffix
	button.icon = ItemCatalog.get_icon(item_name)
	button.tooltip_text = "Clic para desequipar " + item_name
	button.disabled = false


func _create_item_slot(item_name: String, quantity: int) -> Control:
	var slot: Control
	if ItemCatalog.is_equippable(item_name):
		var button := Button.new()
		button.pressed.connect(GameManager.toggle_item_equipped.bind(item_name))
		button.focus_mode = Control.FOCUS_ALL
		slot = button
	else:
		slot = PanelContainer.new()
	slot.set_meta("inventory_item", item_name)
	slot.custom_minimum_size = Vector2(76.0, 82.0)
	slot.tooltip_text = item_name
	if slot is Button:
		var slot_button := slot as Button
		slot_button.add_theme_stylebox_override(
			"normal", _inventory_slot_style(Color("665637d9"), Color("17140feb"))
		)
		slot_button.add_theme_stylebox_override(
			"hover", _inventory_slot_style(Color("c6a557f2"), Color("292217f5"))
		)
		slot_button.add_theme_stylebox_override(
			"pressed", _inventory_slot_style(Color("e2c677f2"), Color("100e0bf5"))
		)
	else:
		var slot_panel := slot as PanelContainer
		slot_panel.add_theme_stylebox_override(
			"panel", _inventory_slot_style(Color("665637d9"), Color("17140feb"))
		)
	if ItemCatalog.is_equippable(item_name):
		slot.tooltip_text += "\nClic para equipar o guardar"

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	slot.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var icon := ItemCatalog.get_icon(item_name)
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(44.0, 44.0)
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon_rect)
	else:
		var icon_placeholder := Label.new()
		icon_placeholder.text = item_name.left(1).to_upper()
		icon_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_placeholder.add_theme_font_size_override("font_size", 22)
		icon_placeholder.add_theme_color_override("font_color", Color("c7a85c"))
		content.add_child(icon_placeholder)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color("d8cfb9"))
	content.add_child(name_label)

	var quantity_label := Label.new()
	quantity_label.text = "x%d" % quantity
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.add_theme_font_size_override("font_size", 11)
	quantity_label.add_theme_color_override("font_color", Color("d5c59d"))
	content.add_child(quantity_label)
	var equipped_count := 0
	if GameManager.equipped_primary_item == item_name:
		equipped_count += 1
	if GameManager.equipped_secondary_item == item_name:
		equipped_count += 1
	if equipped_count > 0:
		var equipped_label := Label.new()
		if ItemCatalog.get_hand_usage(item_name) == "two_hand":
			equipped_label.text = "Dos manos"
		else:
			equipped_label.text = "Equipado" + (" x2" if equipped_count == 2 else "")
		equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipped_label.add_theme_font_size_override("font_size", 10)
		equipped_label.add_theme_color_override("font_color", Color(0.42, 0.95, 0.55))
		content.add_child(equipped_label)
	return slot


func _create_empty_inventory_slot(index: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.name = "EmptySlot%02d" % (index + 1)
	slot.custom_minimum_size = Vector2(76.0, 82.0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override(
		"panel", _inventory_slot_style(Color("443a29a3"), Color("100e0ab8"))
	)
	return slot


func _inventory_slot_style(border_color: Color, background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _is_key(event: InputEventKey, expected_key: Key) -> bool:
	return event.keycode == expected_key or event.physical_keycode == expected_key
