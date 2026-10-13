extends CanvasLayer

const ItemCatalog = preload("res://scripts/systems/items/item_catalog.gd")
const SignatureSkillHubScene = preload("res://scripts/ui/signature_skill_hub.gd")
const MasteryTreeViewScene = preload("res://scripts/ui/mastery_tree_view.gd")
const EditableHUDModuleScene = preload("res://scripts/ui/editable_hud_module.gd")
const MASTERY_ICON := preload("res://assets/ui/hud/generated/mastery_emblem.png")
const CLOSE_ICON := preload("res://assets/ui/icons/close.svg")
const CHEVRON_RIGHT_ICON := preload("res://assets/ui/icons/chevron_right.svg")
const CHEVRON_DOWN_ICON := preload("res://assets/ui/icons/chevron_down.svg")
const EQUIPMENT_BAG_ICON := preload("res://assets/ui/inventory/v1/equipment_bag.svg")
const EQUIPMENT_HEAD_ICON := preload("res://assets/ui/inventory/v1/equipment_head.svg")
const EQUIPMENT_CAPE_ICON := preload("res://assets/ui/inventory/v1/equipment_cape.svg")
const EQUIPMENT_MAIN_HAND_ICON := preload("res://assets/ui/inventory/v1/equipment_main_hand.svg")
const EQUIPMENT_CHEST_ICON := preload("res://assets/ui/inventory/v1/equipment_chest.svg")
const EQUIPMENT_OFFHAND_ICON := preload("res://assets/ui/inventory/v1/equipment_offhand.svg")
const EQUIPMENT_CONSUMABLE_ICON := preload("res://assets/ui/inventory/v1/equipment_consumable.svg")
const EQUIPMENT_FEET_ICON := preload("res://assets/ui/inventory/v1/equipment_feet.svg")
const EQUIPMENT_FOOD_ICON := preload("res://assets/ui/inventory/v1/equipment_food.svg")
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
var combat_health_bar: ProgressBar
var status_health_bar: ProgressBar
var _hud_edit_mode := false
var timed_action_panel: PanelContainer
var timed_action_label: Label
var timed_action_bar: ProgressBar
var timed_action_player: Node
var character_stats_popup: PanelContainer
var signature_skill_hub: SignatureSkillHub
var action_left_module: EditableHUDModule
var action_center_module: EditableHUDModule
var action_right_module: EditableHUDModule
var action_hud_modules: Array[EditableHUDModule] = []
var mastery_backdrop: ColorRect
var mastery_close_button: Button
var mastery_detail_title: Label
var mastery_detail_family: Label
var mastery_detail_description: Label
var inventory_mastery_button: Button
var inventory_stats_toggle: Button
var inventory_stats_panel: PanelContainer
var inventory_stats_expanded := false
var mastery_scroll: Control
var mastery_zoom_caption: Label
var mastery_tree_view: MasteryTreeView
var stamina_bar: ProgressBar
var stamina_caption: Label
var interaction_hint: Label
var interaction_hint_timer: Timer
var stamina_module: EditableHUDModule


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_action_hud_modules()
	_setup_character_hub()
	_setup_inventory_layout()
	_apply_inventory_skin()
	_setup_mastery_tree()
	_apply_generated_button_icons()
	currency_display.hide()
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
	_setup_stamina_display()


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
		if mastery_backdrop != null and mastery_backdrop.visible:
			close_mastery_tree()
		elif options_menu.visible:
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
	_owns_tree_pause = not CoopSession.active
	get_tree().paused = _owns_tree_pause
	(pause_menu_panel.get_node("Margin/Content/Title") as Label).text = "Menú" if CoopSession.active else "Pausa"
	(pause_menu_panel.get_node("Margin/Content/Subtitle") as Label).text = (
		"En línea: el mundo sigue activo y puedes recibir daño."
		if CoopSession.active else "Ajusta tu experiencia o vuelve al juego."
	)
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
	for module in action_hud_modules:
		module.set_edit_mode(enabled)
	stamina_module.set_edit_mode(enabled)
	if signature_skill_hub != null:
		signature_skill_hub.set_interaction_enabled(not enabled)
	hud_edit_mode_changed.emit(enabled)


func reset_hud_layout() -> void:
	SettingsManager.set_setting("hud", "module_order", SettingsManager.DEFAULTS["hud"]["module_order"].duplicate(), false)
	character_status.call("reset_layout")
	for module in action_hud_modules:
		module.reset_layout()
	stamina_module.reset_layout()


func _setup_action_hud_modules() -> void:
	var legacy_action_bar := action_bar
	var legacy_slots := legacy_action_bar.find_child("Slots", true, false) as HBoxContainer
	var health_bar := legacy_action_bar.find_child("CombatHealthBar", true, false) as ProgressBar
	combat_health_bar = health_bar
	status_health_bar = character_status.find_child("HealthBar",true,false) as ProgressBar
	if not CoopSession.combat_state_changed.is_connected(_on_combat_state_changed):
		CoopSession.combat_state_changed.connect(_on_combat_state_changed)
	var mana_bar := legacy_action_bar.find_child("CombatManaBar", true, false) as ProgressBar
	if legacy_slots == null or health_bar == null or mana_bar == null:
		return

	var left_slots: Array[Control] = []
	var right_slots: Array[Control] = []
	for index in range(1, 5):
		left_slots.append(legacy_slots.get_node("Slot%d" % index) as Control)
	for index in range(5, 9):
		right_slots.append(legacy_slots.get_node("Slot%d" % index) as Control)

	legacy_action_bar.name = "LegacyActionBar"
	action_left_module = _create_editable_action_module(
		"ActionBar", "action_left", Vector2(-265.0, 0.0), Vector2(216.0, 84.0)
	)
	action_center_module = _create_editable_action_module(
		"SignatureHubModule", "action_center", Vector2.ZERO, Vector2(180.0, 180.0), false
	)
	action_right_module = _create_editable_action_module(
		"RightActionModule", "action_right", Vector2(265.0, 0.0), Vector2(216.0, 84.0)
	)
	action_hud_modules.assign([
		action_left_module,
		action_center_module,
		action_right_module,
	])
	_build_action_wing(action_left_module, left_slots, health_bar, "VIDA")
	_setup_signature_skill_hub(action_center_module)
	_build_action_wing(action_right_module, right_slots, mana_bar, "MANA")
	action_bar = action_left_module
	legacy_action_bar.queue_free()
	_on_combat_state_changed()


func _on_combat_state_changed() -> void:
	if combat_health_bar == null:
		return
	var state: Dictionary = CoopSession.players.get(CoopSession.local_peer_id, {})
	combat_health_bar.max_value = 100.0
	combat_health_bar.value = float(state.get("health", 100.0))
	var caption := combat_health_bar.get_node_or_null("Caption") as Label
	if caption != null:
		caption.text = "VIDA  %d / 100" % int(combat_health_bar.value)
	if status_health_bar != null:
		status_health_bar.max_value = 100.0
		status_health_bar.value = combat_health_bar.value


func _create_editable_action_module(
	module_name: String,
	layout_key: String,
	default_offset: Vector2,
	module_size: Vector2,
	with_frame := true
) -> EditableHUDModule:
	var module := EditableHUDModuleScene.new() as EditableHUDModule
	module.name = module_name
	module.layout_key = layout_key
	module.default_normalized_position = Vector2(0.5, 1.0)
	module.default_position_offset = default_offset
	module.default_module_scale = 1.2
	module.custom_minimum_size = module_size
	module.size = module_size
	persistent_hud.add_child(module)
	if with_frame:
		var frame := PanelContainer.new()
		frame.name = "ModuleFrame"
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", _action_module_frame_style())
		module.add_child(frame)
	return module


func _build_action_wing(
	module: EditableHUDModule,
	slot_controls: Array[Control],
	resource_bar: ProgressBar,
	caption: String
) -> void:
	var frame := module.get_node("ModuleFrame") as PanelContainer
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 7)
	frame.add_child(margin)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	var slots := HBoxContainer.new()
	slots.name = "Slots"
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots.add_theme_constant_override("separation", 4)
	content.add_child(slots)
	for slot in slot_controls:
		slot.reparent(slots)
		_configure_compact_action_slot(slot)

	var bar_plate := PanelContainer.new()
	bar_plate.name = "%sPlate" % caption.to_pascal_case()
	bar_plate.custom_minimum_size = Vector2(0.0, 22.0)
	bar_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_plate.add_theme_stylebox_override("panel", _resource_bar_plate_style())
	content.add_child(bar_plate)
	var bar_margin := MarginContainer.new()
	bar_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_margin.add_theme_constant_override("margin_left", 6)
	bar_margin.add_theme_constant_override("margin_top", 4)
	bar_margin.add_theme_constant_override("margin_right", 6)
	bar_margin.add_theme_constant_override("margin_bottom", 4)
	bar_plate.add_child(bar_margin)
	resource_bar.reparent(bar_margin)
	resource_bar.custom_minimum_size = Vector2(0.0, 13.0)
	resource_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := resource_bar.get_node_or_null("Caption") as Label
	if label != null:
		label.text = caption
		label.add_theme_font_size_override("font_size", 9)


func _configure_compact_action_slot(slot: Control) -> void:
	slot.custom_minimum_size = Vector2(42.0, 42.0)
	slot.clip_contents = true
	if slot is PanelContainer:
		(slot as PanelContainer).add_theme_stylebox_override(
			"panel", _compact_action_slot_style()
		)
	var old_frame := slot.get_node_or_null("Frame") as TextureRect
	if old_frame != null:
		old_frame.hide()
	var key := slot.get_node_or_null("Key") as Label
	if key == null:
		return
	var placeholder := Label.new()
	placeholder.name = "AbilityPlaceholder"
	placeholder.text = "◇"
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.add_theme_color_override("font_color", Color("5f4b2d99"))
	slot.add_child(placeholder)
	var key_margin := MarginContainer.new()
	key_margin.name = "HotkeyBadge"
	key_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_margin.add_theme_constant_override("margin_left", 2)
	key_margin.add_theme_constant_override("margin_top", 2)
	key_margin.add_theme_constant_override("margin_right", 3)
	key_margin.add_theme_constant_override("margin_bottom", 2)
	slot.add_child(key_margin)
	key.reparent(key_margin)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	key.add_theme_font_size_override("font_size", 10)
	key.add_theme_color_override("font_color", Color("e8d7ac"))
	key.add_theme_color_override("font_outline_color", Color("080705"))
	key.add_theme_constant_override("outline_size", 2)


func _compact_action_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b0a08f2")
	style.border_color = Color("6e5833dc")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	style.shadow_size = 3
	return style


func _setup_signature_skill_hub(module: EditableHUDModule) -> void:
	signature_skill_hub = SignatureSkillHubScene.new() as SignatureSkillHub
	signature_skill_hub.name = "SignatureSkillHub"
	signature_skill_hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	signature_skill_hub.mastery_requested.connect(open_mastery_tree)
	module.add_child(signature_skill_hub)


func _action_module_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0c0a07e8")
	style.border_color = Color("796039e8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 4
	return style


func _resource_bar_plate_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("090805fa")
	style.border_color = Color("71582fff")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _setup_inventory_layout() -> void:
	var content := inventory_panel.get_node("Margin/Content") as VBoxContainer
	var header := content.get_node("Header") as HBoxContainer
	var header_portrait := header.get_node("HeaderPortrait") as Control
	header_portrait.hide()
	inventory_mastery_button = Button.new()
	inventory_mastery_button.name = "InventoryMasteryButton"
	inventory_mastery_button.text = "Maestrías"
	inventory_mastery_button.icon = MASTERY_ICON
	inventory_mastery_button.expand_icon = true
	inventory_mastery_button.add_theme_constant_override("icon_max_width", 22)
	inventory_mastery_button.tooltip_text = "Abrir Árbol de Maestrías"
	inventory_mastery_button.custom_minimum_size = Vector2(108.0, 34.0)
	inventory_mastery_button.pressed.connect(open_mastery_tree)
	header.add_child(inventory_mastery_button)
	header.move_child(inventory_mastery_button, header.get_child_count() - 2)

	var body := VBoxContainer.new()
	body.name = "InventoryBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	content.add_child(body)
	content.move_child(body, 2)

	var equipment_header := content.get_node("EquipmentHeader") as HBoxContainer
	var equipment_title := equipment_header.get_node("EquipmentTitle") as Label
	var equipment_hint := equipment_header.get_node("EquipmentHint") as Label
	equipment_hint.hide()
	equipment_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_header.reparent(body)

	var equipment_slots := content.get_node("EquipmentSlots") as HBoxContainer
	var equipment_grid := GridContainer.new()
	equipment_grid.name = "EquipmentGrid"
	equipment_grid.columns = 3
	equipment_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	equipment_grid.add_theme_constant_override("h_separation", 6)
	equipment_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(equipment_grid)
	var primary_slot := equipment_slots.get_node("PrimaryEquipmentSlot") as Button
	var secondary_slot := equipment_slots.get_node("SecondaryEquipmentSlot") as Button
	equipment_grid.add_child(_create_future_equipment_slot(
		"bag", "Mochila equipada · sistema futuro", EQUIPMENT_BAG_ICON
	))
	equipment_grid.add_child(_create_future_equipment_slot(
		"head", "Cabeza · casco o capucha · sistema futuro", EQUIPMENT_HEAD_ICON
	))
	equipment_grid.add_child(_create_future_equipment_slot(
		"cape", "Espalda · capa o accesorio · sistema futuro", EQUIPMENT_CAPE_ICON
	))
	primary_slot.reparent(equipment_grid)
	_configure_hand_equipment_slot(primary_slot, "primary")
	equipment_grid.add_child(_create_future_equipment_slot(
		"chest", "Torso · armadura · sistema futuro", EQUIPMENT_CHEST_ICON
	))
	secondary_slot.reparent(equipment_grid)
	_configure_hand_equipment_slot(secondary_slot, "secondary")
	equipment_grid.add_child(_create_future_equipment_slot(
		"consumable", "Consumible rápido · sistema futuro", EQUIPMENT_CONSUMABLE_ICON
	))
	equipment_grid.add_child(_create_future_equipment_slot(
		"feet", "Pies · botas · sistema futuro", EQUIPMENT_FEET_ICON
	))
	equipment_grid.add_child(_create_future_equipment_slot(
		"food", "Alimento · sistema futuro", EQUIPMENT_FOOD_ICON
	))
	equipment_slots.queue_free()

	_setup_inventory_stats(body)

	var bag_header := content.get_node("BagHeader") as HBoxContainer
	var bag_title := bag_header.get_node("BagTitle") as Label
	var bag_shortcut := bag_header.get_node("BagShortcut") as Label
	bag_shortcut.hide()
	bag_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	inventory_capacity.reparent(bag_header)
	inventory_capacity.size_flags_horizontal = Control.SIZE_SHRINK_END
	inventory_capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var inventory_resources := content.get_node("InventoryResources") as PanelContainer
	var empty_label := content.get_node("EmptyInventoryLabel") as Label
	var scroll := content.get_node("InventoryScroll") as ScrollContainer
	var footer := content.get_node("InventoryFooter") as HBoxContainer
	inventory_resources.reparent(body)
	bag_header.reparent(body)
	empty_label.reparent(body)
	scroll.reparent(body)
	footer.reparent(body)
	scroll.custom_minimum_size = Vector2(0.0, 92.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inventory_grid.columns = 5
	inventory_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inventory_grid.add_theme_constant_override("h_separation", 6)
	inventory_grid.add_theme_constant_override("v_separation", 6)
	var value_label := footer.get_node("InventoryValueLabel") as Label
	value_label.hide()
	inventory_free_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_free_slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inventory_gold_label.text = "DAÑO  —"
	inventory_gold_label.tooltip_text = "Daño total · sistema pendiente"
	inventory_item_count.text = "DEFENSA  —"
	inventory_item_count.tooltip_text = "Defensa total · sistema pendiente"
	inventory_capacity.text = "0 / %d" % INVENTORY_CAPACITY


func _setup_inventory_stats(parent: Control) -> void:
	inventory_stats_toggle = Button.new()
	inventory_stats_toggle.name = "InventoryStatsToggle"
	inventory_stats_toggle.text = "ESTADÍSTICAS"
	inventory_stats_toggle.icon = CHEVRON_RIGHT_ICON
	inventory_stats_toggle.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inventory_stats_toggle.expand_icon = true
	inventory_stats_toggle.add_theme_constant_override("icon_max_width", 18)
	inventory_stats_toggle.custom_minimum_size.y = 32.0
	inventory_stats_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	inventory_stats_toggle.tooltip_text = "Mostrar estadísticas"
	inventory_stats_toggle.pressed.connect(_toggle_inventory_stats)
	parent.add_child(inventory_stats_toggle)

	inventory_stats_panel = PanelContainer.new()
	inventory_stats_panel.name = "PlaceholderStats"
	inventory_stats_panel.add_theme_stylebox_override(
		"panel", _inventory_slot_style(Color("65543c"), Color("111516e8"))
	)
	parent.add_child(inventory_stats_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 7)
	inventory_stats_panel.add_child(margin)
	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 3)
	margin.add_child(stats)
	for stat_name in [
		"Daño", "Defensa", "Poder de objeto", "Precisión", "Resistencia", "Velocidad",
	]:
		var name_label := Label.new()
		name_label.text = stat_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", Color("aaa397"))
		name_label.add_theme_font_size_override("font_size", 9)
		stats.add_child(name_label)
		var value_label := Label.new()
		value_label.text = "—"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_color_override("font_color", Color("c5b58e"))
		value_label.add_theme_font_size_override("font_size", 9)
		stats.add_child(value_label)
	_set_inventory_stats_expanded(false)


func _toggle_inventory_stats() -> void:
	_set_inventory_stats_expanded(not inventory_stats_expanded)


func _set_inventory_stats_expanded(expanded: bool) -> void:
	inventory_stats_expanded = expanded
	inventory_stats_panel.visible = expanded
	inventory_stats_toggle.icon = CHEVRON_DOWN_ICON if expanded else CHEVRON_RIGHT_ICON
	inventory_stats_toggle.tooltip_text = (
		"Ocultar estadísticas" if expanded else "Mostrar estadísticas"
	)


func _configure_hand_equipment_slot(button: Button, slot_name: String) -> void:
	button.set_meta("equipment_slot", slot_name)
	button.custom_minimum_size = Vector2(74.0, 72.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 38)
	button.add_theme_font_size_override("font_size", 9)


func _create_future_equipment_slot(
		slot_name: String, description: String, icon: Texture2D
) -> Button:
	var button := Button.new()
	button.name = "EquipmentSlot_%s" % slot_name
	button.set_meta("equipment_slot", slot_name)
	button.custom_minimum_size = Vector2(74.0, 72.0)
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.icon = icon
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 38)
	button.add_theme_color_override("icon_disabled_color", Color("8c8066"))
	button.tooltip_text = description
	return button


func _setup_mastery_tree() -> void:
	mastery_backdrop = ColorRect.new()
	mastery_backdrop.name = "MasteryTreeBackdrop"
	mastery_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mastery_backdrop.color = Color("080c11ff")
	mastery_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	mastery_backdrop.z_index = 60
	get_node("Screen").add_child(mastery_backdrop)

	var shell := VBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 28.0
	shell.offset_top = 22.0
	shell.offset_right = -28.0
	shell.offset_bottom = -22.0
	shell.add_theme_constant_override("separation", 12)
	mastery_backdrop.add_child(shell)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 54.0
	shell.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	var title := Label.new()
	title.text = "ÁRBOL DE MAESTRÍAS"
	title.add_theme_color_override("font_color", Color("e6d3a5"))
	title.add_theme_font_size_override("font_size", 24)
	titles.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Practica para progresar · hasta tres maestrías enfocadas"
	subtitle.add_theme_color_override("font_color", Color("777f82"))
	subtitle.add_theme_font_size_override("font_size", 11)
	titles.add_child(subtitle)
	var points := Label.new()
	points.text = "PUNTOS DISPONIBLES  0"
	points.add_theme_color_override("font_color", Color("c6a45c"))
	points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(points)
	mastery_close_button = Button.new()
	mastery_close_button.text = "Cerrar  ×"
	mastery_close_button.custom_minimum_size = Vector2(48.0, 42.0)
	mastery_close_button.pressed.connect(close_mastery_tree)
	header.add_child(mastery_close_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	shell.add_child(body)
	mastery_scroll = Control.new()
	mastery_scroll.name = "MasteryTreeViewport"
	mastery_scroll.custom_minimum_size = Vector2(400.0, 400.0)
	mastery_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mastery_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(mastery_scroll)
	mastery_tree_view = MasteryTreeViewScene.new() as MasteryTreeView
	mastery_tree_view.name = "MasteryTreeView"
	mastery_scroll.add_child(mastery_tree_view)
	mastery_tree_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	shell.add_child(navigation)
	shell.move_child(navigation, 1)
	for family in ["MARCIALES", "MUNDO", "OFICIO", "INFLUENCIA"]:
		var family_button := Button.new()
		family_button.text = String(family).capitalize()
		var family_icons := {"MARCIALES": "main_hand", "MUNDO": "tree", "OFICIO": "hammer", "INFLUENCIA": "crown"}
		var family_colors := {"MARCIALES": "d59476", "MUNDO": "86c6a5", "OFICIO": "ddbe7b", "INFLUENCIA": "a9a2d4"}
		family_button.icon = load("res://assets/ui/inventory/v1/equipment_%s.svg" % family_icons[family])
		family_button.expand_icon = true
		family_button.add_theme_constant_override("icon_max_width", 24)
		family_button.add_theme_color_override("font_color", Color(family_colors[family]))
		family_button.custom_minimum_size = Vector2(116, 36)
		family_button.pressed.connect(mastery_tree_view.focus_family.bind(family))
		navigation.add_child(family_button)
	var spacer_nav := Control.new()
	spacer_nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer_nav)
	for action in ["−", "+", "Origen", "Ver todo"]:
		var button := Button.new()
		button.text = action
		button.custom_minimum_size = Vector2(44, 36)
		if action == "−":
			button.pressed.connect(func(): mastery_tree_view.set_zoom(mastery_tree_view.zoom / 1.15))
		elif action == "+":
			button.pressed.connect(func(): mastery_tree_view.set_zoom(mastery_tree_view.zoom * 1.15))
		elif action == "Origen":
			button.pressed.connect(mastery_tree_view.center_on_root)
		else:
			button.pressed.connect(mastery_tree_view.show_entire_tree)
		navigation.add_child(button)
	mastery_zoom_caption = Label.new()
	mastery_zoom_caption.custom_minimum_size.x = 64
	navigation.add_child(mastery_zoom_caption)
	mastery_tree_view.zoom_changed.connect(func(value): mastery_zoom_caption.text = "%d%%" % roundi(value * 100.0))
	call_deferred("_center_mastery_tree")

	var detail := PanelContainer.new()
	detail.custom_minimum_size.x = 280.0
	detail.add_theme_stylebox_override(
		"panel", load("res://resources/ui/mastery/detail_panel.tres")
	)
	body.add_child(detail)
	var detail_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		detail_margin.add_theme_constant_override(side, 18)
	detail.add_child(detail_margin)
	var detail_content := VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 10)
	detail_margin.add_child(detail_content)
	mastery_detail_family = Label.new()
	mastery_detail_family.text = "MUNDO · AVENTURA"
	mastery_detail_family.add_theme_color_override("font_color", Color("70c7a2"))
	mastery_detail_family.add_theme_font_size_override("font_size", 11)
	detail_content.add_child(mastery_detail_family)
	mastery_detail_title = Label.new()
	mastery_detail_title.text = "Exploración"
	mastery_detail_title.add_theme_color_override("font_color", Color("eee4cf"))
	mastery_detail_title.add_theme_font_size_override("font_size", 22)
	detail_content.add_child(mastery_detail_title)
	var rank := Label.new()
	rank.text = "RECORRIDO DE MAESTRÍA"
	rank.add_theme_color_override("font_color", Color("b69755"))
	detail_content.add_child(rank)
	var progress := ProgressBar.new()
	progress.max_value = 100.0
	progress.value = 0.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 12.0
	detail_content.add_child(progress)
	mastery_detail_description = Label.new()
	mastery_detail_description.text = (
		"Maestría visible durante el tutorial. Sus rangos y Legados se desbloquearán con práctica significativa."
	)
	mastery_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mastery_detail_description.add_theme_color_override("font_color", Color("a49f95"))
	detail_content.add_child(mastery_detail_description)
	var focus_title := Label.new()
	focus_title.text = "ENFOQUES ACTIVOS"
	focus_title.add_theme_color_override("font_color", Color("c9ad70"))
	focus_title.add_theme_font_size_override("font_size", 12)
	detail_content.add_child(focus_title)
	for focus_text in ["◇ Sin enfoque", "◇ Sin enfoque", "◇ Sin enfoque"]:
		var focus := Label.new()
		focus.text = focus_text
		focus.add_theme_color_override("font_color", Color("777d80"))
		detail_content.add_child(focus)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_content.add_child(spacer)
	var legacy := Label.new()
	legacy.text = "LEGADOS DE GRAN MAESTRO\nVista previa disponible al alcanzar los rangos superiores. La elección final será permanente."
	legacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legacy.add_theme_color_override("font_color", Color("787167"))
	legacy.add_theme_font_size_override("font_size", 10)
	detail_content.add_child(legacy)
	mastery_tree_view.mastery_selected.connect(_on_mastery_selected)
	mastery_backdrop.hide()


func open_mastery_tree() -> void:
	if pause_backdrop.visible:
		return
	mastery_backdrop.show()
	mastery_close_button.grab_focus()
	inventory_visibility_changed.emit(true)
	call_deferred("_center_mastery_tree")


func close_mastery_tree() -> void:
	if mastery_backdrop == null or not mastery_backdrop.visible:
		return
	mastery_backdrop.hide()
	inventory_visibility_changed.emit(inventory_panel.visible)
	if inventory_panel.visible and inventory_close_button != null:
		inventory_close_button.grab_focus()


func _on_mastery_selected(title: String, family: String, description: String) -> void:
	mastery_detail_title.text = title
	mastery_detail_family.text = family
	var colors := {"MARCIALES": "d59476", "MUNDO": "86c6a5", "OFICIO": "ddbe7b", "INFLUENCIA": "a9a2d4"}
	mastery_detail_family.add_theme_color_override("font_color", Color(colors.get(family, "f0d599")))
	mastery_detail_description.text = description


func _center_mastery_tree() -> void:
	if mastery_scroll == null or mastery_tree_view == null:
		return
	mastery_tree_view.center_on_root()


func _apply_generated_button_icons() -> void:
	inventory_close_button.text = ""
	inventory_close_button.icon = CLOSE_ICON
	inventory_close_button.expand_icon = true
	inventory_close_button.add_theme_constant_override("icon_max_width", 27)
	inventory_close_button.tooltip_text = "Cerrar inventario (I o Esc)"
	mastery_close_button.text = ""
	mastery_close_button.icon = CLOSE_ICON
	mastery_close_button.expand_icon = true
	mastery_close_button.add_theme_constant_override("icon_max_width", 28)
	mastery_close_button.tooltip_text = "Cerrar Árbol de Maestrías (Esc)"


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
		if timed_action_player.has_signal("stamina_changed") and timed_action_player.is_connected("stamina_changed", _on_stamina_changed):
			timed_action_player.disconnect("stamina_changed", _on_stamina_changed)
		if timed_action_player.has_signal("interaction_out_of_range") and timed_action_player.is_connected("interaction_out_of_range", _show_interaction_hint):
			timed_action_player.disconnect("interaction_out_of_range", _show_interaction_hint)
	timed_action_player = player
	if timed_action_player == null:
		return
	timed_action_player.connect("timed_action_started", _on_timed_action_started)
	timed_action_player.connect("timed_action_progress", _on_timed_action_progress)
	timed_action_player.connect("timed_action_finished", _on_timed_action_finished)
	if player.has_signal("stamina_changed"):
		player.connect("stamina_changed", _on_stamina_changed)
		_on_stamina_changed(float(player.get("stamina")), float(player.get("max_stamina")))
	if player.has_signal("interaction_out_of_range"):
		player.connect("interaction_out_of_range", _show_interaction_hint)


func _setup_stamina_display() -> void:
	stamina_module = _create_editable_action_module(
		"StaminaModule", "stamina", Vector2(0.0, -245.0), Vector2(220.0, 20.0), false
	)
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stamina_bar.show_percentage = false
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("151b1fee")
	background.border_color = Color("a78d56")
	background.set_border_width_all(1)
	background.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("779c57")
	fill.set_corner_radius_all(5)
	stamina_bar.add_theme_stylebox_override("background", background)
	stamina_bar.add_theme_stylebox_override("fill", fill)
	stamina_module.add_child(stamina_bar)
	stamina_caption = Label.new()
	stamina_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stamina_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamina_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamina_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_caption.add_theme_font_size_override("font_size", 11)
	stamina_bar.add_child(stamina_caption)
	_on_stamina_changed(100.0, 100.0)
	interaction_hint = Label.new()
	interaction_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_hint.offset_left = -200.0
	interaction_hint.offset_right = 200.0
	interaction_hint.offset_top = -300.0
	interaction_hint.offset_bottom = -275.0
	interaction_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_hint.text = "Acércate para interactuar"
	persistent_hud.add_child(interaction_hint)
	interaction_hint.hide()
	interaction_hint_timer = Timer.new()
	interaction_hint_timer.one_shot = true
	interaction_hint_timer.timeout.connect(interaction_hint.hide)
	add_child(interaction_hint_timer)


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_caption.text = "ESTAMINA  %d / %d" % [roundi(current), roundi(maximum)]


func _show_interaction_hint() -> void:
	interaction_hint.show()
	interaction_hint_timer.start(2.5)


func _setup_timed_action_progress() -> void:
	timed_action_panel = PanelContainer.new()
	timed_action_panel.name = "TimedActionProgress"
	timed_action_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	timed_action_panel.offset_left = -190.0
	timed_action_panel.offset_top = -370.0
	timed_action_panel.offset_right = 190.0
	timed_action_panel.offset_bottom = -310.0
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
	GameManager.request_quit_game()


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
	var item_entries: Array[Dictionary] = []
	for item_name in item_names:
		var quantity := maxi(int(inventory.get(item_name, 0)), 0)
		if quantity <= 0:
			continue
		if ItemCatalog.is_stackable(item_name):
			item_entries.append({
				"item_name": item_name,
				"quantity": quantity,
				"instance_index": 0,
			})
		else:
			for instance_index in range(quantity):
				item_entries.append({
					"item_name": item_name,
					"quantity": 1,
					"instance_index": instance_index,
				})
	empty_inventory_label.visible = item_entries.is_empty()
	inventory_item_count.text = "DEFENSA  —"
	inventory_capacity.text = "%d / %d" % [item_entries.size(), INVENTORY_CAPACITY]
	var free_slots := maxi(INVENTORY_CAPACITY - item_entries.size(), 0)
	inventory_free_slots.text = "%d espacios libres" % free_slots

	for entry in item_entries:
		inventory_grid.add_child(_create_item_slot(
			String(entry.get("item_name", "")),
			int(entry.get("quantity", 1)),
			int(entry.get("instance_index", 0))
		))
	for index in range(free_slots):
		inventory_grid.add_child(_create_empty_inventory_slot(index))


func _update_currency_display(inventory: Dictionary) -> void:
	# La economia se retiró del HUD hasta que tenga una función jugable clara.
	# Este resumen queda reservado para atributos reales cuando existan.
	gold_amount_label.text = ""
	silver_amount_label.text = ""
	inventory_gold_label.text = "DAÑO  —"
	inventory_gold_label.tooltip_text = "Daño total · sistema pendiente"


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
		button.text = ""
		button.icon = (
			EQUIPMENT_MAIN_HAND_ICON if label == "Mano principal" else EQUIPMENT_OFFHAND_ICON
		)
		button.tooltip_text = label + " · vacía"
		button.set_meta("equipment_item", "")
		button.disabled = true
		return
	var suffix := ""
	if ItemCatalog.get_hand_usage(item_name) == "two_hand":
		suffix = " (Dos manos)"
	button.text = ""
	button.icon = ItemCatalog.get_icon(item_name)
	if label == "Mano secundaria" and ItemCatalog.get_hand_usage(item_name) == "two_hand":
		button.icon = load("res://assets/ui/inventory/v1/two_hand_reserved.svg")
	button.tooltip_text = label + " · " + item_name + suffix + "\nClic para desequipar"
	button.set_meta("equipment_item", item_name)
	button.disabled = false


func _create_item_slot(item_name: String, quantity: int, instance_index := 0) -> Control:
	var slot: Control
	var stackable := ItemCatalog.is_stackable(item_name)
	if ItemCatalog.is_equippable(item_name):
		var button := Button.new()
		button.pressed.connect(GameManager.toggle_item_equipped.bind(item_name))
		button.focus_mode = Control.FOCUS_ALL
		slot = button
	else:
		slot = PanelContainer.new()
	slot.set_meta("inventory_item", item_name)
	slot.set_meta("inventory_instance_index", instance_index)
	slot.set_meta("inventory_stackable", stackable)
	slot.custom_minimum_size = Vector2(60.0, 66.0)
	slot.tooltip_text = item_name
	if slot is Button:
		var slot_button := slot as Button
		slot_button.add_theme_stylebox_override(
			"normal", _inventory_slot_style(Color("665637d9"), Color("17140feb"))
		)
		slot_button.add_theme_stylebox_override(
			"hover", load("res://resources/ui/inventory/slot_hover.tres")
		)
		slot_button.add_theme_stylebox_override(
			"pressed", load("res://resources/ui/inventory/slot_hover.tres")
		)
	else:
		var slot_panel := slot as PanelContainer
		slot_panel.add_theme_stylebox_override(
			"panel", _inventory_slot_style(Color("665637d9"), Color("17140feb"))
		)
	if ItemCatalog.is_equippable(item_name):
		slot.tooltip_text += "\nClic para equipar o guardar"

	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(content)
	if slot is Button:
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var icon := ItemCatalog.get_icon(item_name)
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.name = "ItemIcon"
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon_rect)
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 8
		icon_rect.offset_top = 7
		icon_rect.offset_right = -8
		icon_rect.offset_bottom = -14
	else:
		var icon_placeholder := Label.new()
		icon_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_placeholder.text = item_name.left(1).to_upper()
		icon_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_placeholder.add_theme_font_size_override("font_size", 16)
		icon_placeholder.add_theme_color_override("font_color", Color("c7a85c"))
		content.add_child(icon_placeholder)
		icon_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if stackable and quantity > 1:
		var quantity_label := Label.new()
		quantity_label.name = "StackQuantity"
		quantity_label.text = "x%d" % quantity
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity_label.add_theme_font_size_override("font_size", 9)
		quantity_label.add_theme_color_override("font_color", Color("d5c59d"))
		content.add_child(quantity_label)
		quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quantity_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		quantity_label.offset_right = -6
		quantity_label.offset_bottom = -4
		quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	if ItemCatalog.get_hand_usage(item_name) == "two_hand":
		slot.tooltip_text += "\nOcupa ambas manos"
		var hand_badge := Label.new()
		hand_badge.name = "HandUsage"
		hand_badge.text = "2M"
		hand_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hand_badge.add_theme_font_size_override("font_size", 9)
		hand_badge.add_theme_color_override("font_color", Color("d5c59d"))
		content.add_child(hand_badge)
		hand_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hand_badge.offset_right = -6
		hand_badge.offset_top = 4
	var equipped_count := 0
	if GameManager.equipped_primary_item == item_name:
		equipped_count += 1
	if GameManager.equipped_secondary_item == item_name:
		equipped_count += 1
	if not stackable and instance_index < equipped_count:
		var equipped_label := Label.new()
		equipped_label.name = "EquippedState"
		if ItemCatalog.get_hand_usage(item_name) == "two_hand":
			equipped_label.text = "Dos manos"
		else:
			equipped_label.text = "Equipado"
		equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipped_label.add_theme_font_size_override("font_size", 8)
		equipped_label.add_theme_color_override("font_color", Color(0.42, 0.95, 0.55))
		content.add_child(equipped_label)
		equipped_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equipped_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		equipped_label.offset_bottom = -3
		equipped_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return slot


func _create_empty_inventory_slot(index: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.name = "EmptySlot%02d" % (index + 1)
	slot.custom_minimum_size = Vector2(60.0, 66.0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override(
		"panel", _inventory_slot_style(Color("443a29a3"), Color("100e0ab8"))
	)
	return slot


func _inventory_slot_style(_border_color: Color, background_color: Color) -> StyleBox:
	var state := "empty" if background_color.a < 0.8 else "normal"
	return load("res://resources/ui/inventory/slot_%s.tres" % state) as StyleBox


func _apply_inventory_skin() -> void:
	inventory_panel.get_node("Visual").hide()
	inventory_panel.add_theme_stylebox_override("panel", load("res://resources/ui/inventory/parchment_panel.tres"))
	for label in inventory_panel.find_children("*", "Label", true, false):
		if not inventory_stats_panel.is_ancestor_of(label):
			(label as Label).add_theme_color_override("font_color", Color("45351f"))
	inventory_gold_label.add_theme_color_override("font_color", Color("e0c68c"))
	inventory_item_count.add_theme_color_override("font_color", Color("e0c68c"))
	for button in inventory_panel.find_children("*", "Button", true, false):
		if button.has_meta("equipment_slot"):
			(button as Button).add_theme_stylebox_override("normal", load("res://resources/ui/inventory/slot_normal.tres"))
			(button as Button).add_theme_stylebox_override("disabled", load("res://resources/ui/inventory/slot_empty.tres"))
			(button as Button).add_theme_stylebox_override("hover", load("res://resources/ui/inventory/slot_hover.tres"))
			(button as Button).add_theme_color_override("icon_disabled_color", Color.WHITE)


func _is_key(event: InputEventKey, expected_key: Key) -> bool:
	return event.keycode == expected_key or event.physical_keycode == expected_key
