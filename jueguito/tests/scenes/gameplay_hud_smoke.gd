extends Node

const HUD_SCENE := preload("res://scenes/ui/gameplay_hud.tscn")

class FakeActionPlayer extends Node:
	signal timed_action_started(label: String, duration: float)
	signal timed_action_progress(elapsed: float, duration: float)
	signal timed_action_finished(completed: bool)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameManager.clear_equipment()
	GameManager.player_inventory = {
		"Oro": 12345,
		"Madera": 10,
		"Hierro": 5,
		"Hacha de leñador": 1,
		"Espada vikinga": 2,
		"Escudo vikingo": 1,
		"Arco vikingo": 1,
	}
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	await get_tree().process_frame

	var inventory := hud.get_node("Screen/InventoryPanel") as PanelContainer
	var pause := hud.get_node("Screen/PauseBackdrop") as ColorRect
	var grid := hud.get_node("Screen/InventoryPanel/Margin/Content/InventoryScroll/InventoryGrid") as GridContainer
	var inventory_owner := hud.find_child("InventoryOwnerName", true, false) as Label
	var inventory_resources := hud.find_child("InventoryResources", true, false) as PanelContainer
	var inventory_gold := hud.find_child("InventoryGoldLabel", true, false) as Label
	var inventory_capacity := hud.find_child("InventoryCapacity", true, false) as Label
	var character_status := hud.find_child("CharacterStatus", true, false) as Control
	var action_bar := hud.find_child("ActionBar", true, false) as Control
	var portrait := hud.find_child("Portrait", true, false) as PanelContainer
	var currency := hud.find_child("CurrencyDisplay", true, false) as Control
	var gold_amount := hud.find_child("GoldAmount", true, false) as Label
	var silver_amount := hud.find_child("SilverAmount", true, false) as Label
	var stats_toggle := hud.find_child("ToggleStats", true, false) as Button
	var stats_popup := hud.find_child("CharacterStatsPopup", true, false) as PanelContainer
	var slots := hud.find_child("Slots", true, false) as HBoxContainer
	if inventory == null or pause == null or grid == null or inventory_owner == null \
	or inventory_resources == null or inventory_gold == null or inventory_capacity == null:
		_fail("Faltan controles principales del HUD")
		return
	if character_status == null or action_bar == null or portrait == null \
	or currency == null or gold_amount == null or silver_amount == null \
	or stats_toggle == null or stats_popup == null:
		_fail("Faltan los modulos persistentes de personaje y acciones")
		return
	if stats_popup.visible or gold_amount.text != "12.3 K" or silver_amount.text != "0":
		_fail("El nucleo de personaje no inicio colapsado o el oro minimo es incorrecto")
		return
	stats_toggle.pressed.emit()
	await get_tree().process_frame
	if not stats_popup.visible or stats_popup.global_position.y >= character_status.global_position.y:
		_fail("El retrato no desplego las estadisticas hacia arriba")
		return
	stats_toggle.pressed.emit()
	if slots == null or slots.get_child_count() != 13 \
	or hud.find_child("Signature1", true, false) == null \
	or hud.find_child("CombatHealthBar", true, false) == null \
	or hud.find_child("CombatManaBar", true, false) == null:
		_fail("La barra de combate no separo habilidades, insignias, objetos y recursos")
		return
	hud.call("set_hud_edit_mode", true)
	if character_status.mouse_filter != Control.MOUSE_FILTER_STOP \
	or not (hud.find_child("HUDEditToolbar", true, false) as Control).visible:
		_fail("El modo editable no habilito el arrastre de modulos")
		return
	var resize_overlay := character_status.find_child("HUDResizeOverlay", false, false) as Node2D
	var resize_handle: Rect2 = character_status.call("_resize_handle_rect")
	if resize_overlay == null or not resize_overlay.visible or resize_handle.size.x < 18.0:
		_fail("El modo editable no mostro su caja y tirador de escala")
		return
	character_status.call("set_module_scale", 1.2)
	if not is_equal_approx(character_status.scale.x, 1.2):
		_fail("El modulo de personaje no admite escala proporcional")
		return
	character_status.call("reset_layout")
	hud.call("set_hud_edit_mode", false)
	if inventory.visible or pause.visible:
		_fail("El HUD no inicia cerrado")
		return
	if grid.get_child_count() != 24 or inventory_capacity.text != "6 / 24" \
	or inventory_gold.text != "ORO  12.3 K":
		_fail("La mochila no completo sus 24 espacios o calculo mal la ocupacion")
		return
	var populated_slots := 0
	for child in grid.get_children():
		if child.has_meta("inventory_item"):
			populated_slots += 1
	if populated_slots != 6:
		_fail("El inventario no represento sus seis items reales")
		return
	var sword_slot := _find_inventory_button(grid, "Espada vikinga")
	var shield_slot := _find_inventory_button(grid, "Escudo vikingo")
	var bow_slot := _find_inventory_button(grid, "Arco vikingo")
	var axe_slot := _find_inventory_button(grid, "Hacha de leñador")
	if sword_slot == null or shield_slot == null or bow_slot == null or axe_slot == null:
		_fail("Faltan botones para uno o mas items equipables")
		return
	sword_slot.pressed.emit()
	if GameManager.equipped_primary_item != "Espada vikinga" \
	or not GameManager.equipped_secondary_item.is_empty():
		_fail("La espada no quedo fijada a la mano principal")
		return
	_find_inventory_button(grid, "Escudo vikingo").pressed.emit()
	if GameManager.equipped_primary_item != "Espada vikinga" \
	or GameManager.equipped_secondary_item != "Escudo vikingo":
		_fail("El escudo no reemplazo correctamente la mano secundaria")
		return
	_find_inventory_button(grid, "Arco vikingo").pressed.emit()
	if GameManager.equipped_primary_item != "Arco vikingo" \
	or not GameManager.equipped_secondary_item.is_empty():
		_fail("El arco de dos manos no libero la mano secundaria")
		return
	var primary_slot := hud.find_child("PrimaryEquipmentSlot", true, false) as Button
	if primary_slot == null or "Dos manos" not in primary_slot.text:
		_fail("La interfaz no mostro el arco como arma de dos manos")
		return
	var secondary_slot := hud.find_child("SecondaryEquipmentSlot", true, false) as Button
	if secondary_slot == null or "Arco vikingo" not in secondary_slot.text \
	or "Dos manos" not in secondary_slot.text:
		_fail("La interfaz no marco la secundaria como reservada por el arco")
		return
	primary_slot.pressed.emit()
	_find_inventory_button(grid, "Hacha de leñador").pressed.emit()
	if not GameManager.has_equipped_tool_type("axe"):
		_fail("El hacha equipada dejo de cumplir el requisito de tala")
		return
	var fake_player := FakeActionPlayer.new()
	add_child(fake_player)
	hud.call("bind_player", fake_player)
	fake_player.timed_action_started.emit("Talando Pino", 7.0)
	fake_player.timed_action_progress.emit(3.5, 7.0)
	var timed_panel := hud.find_child("TimedActionProgress", true, false) as PanelContainer
	if timed_panel == null or not timed_panel.visible:
		_fail("La barra de tala no se mostro al iniciar la accion")
		return
	var timed_bar := timed_panel.find_child("TimedActionBar", true, false) as ProgressBar
	if timed_bar == null or not is_equal_approx(timed_bar.value, 3.5):
		_fail("La barra de tala no reflejo el progreso")
		return
	fake_player.timed_action_finished.emit(true)
	if timed_panel.visible:
		_fail("La barra de tala no se oculto al terminar")
		return

	hud.call("open_inventory")
	if not inventory.visible:
		_fail("No se abrio el inventario")
		return
	hud.call("close_inventory")
	var menu_panel := hud.find_child("MenuPanel", true, false) as PanelContainer
	hud.call("open_pause_menu")
	if not pause.visible or not get_tree().paused:
		_fail("El menu no pauso el arbol")
		return
	var pause_rect := menu_panel.get_global_rect()
	var viewport_rect := hud.get_viewport().get_visible_rect()
	if not viewport_rect.encloses(pause_rect):
		_fail("El menu de pausa excede la pantalla visible")
		return
	var pause_options := hud.find_child("PauseOptionsButton", true, false) as Button
	var quit_game := hud.find_child("QuitGameButton", true, false) as Button
	var edit_hud := hud.find_child("EditHUDButton", true, false) as Button
	var options_menu := hud.find_child("OptionsMenu", true, false) as Control
	if pause_options == null or quit_game == null or edit_hud == null or options_menu == null:
		_fail("El menu de pausa no contiene todas sus acciones")
		return
	hud.call("_open_options")
	if not options_menu.visible or menu_panel.visible:
		_fail("Opciones no reemplazo temporalmente al panel de pausa")
		return
	options_menu.call("close")
	if options_menu.visible or not menu_panel.visible:
		_fail("Cerrar opciones no regreso al menu de pausa")
		return
	hud.call("close_pause_menu")
	if pause.visible or get_tree().paused:
		_fail("Continuar no reanudo el arbol")
		return

	hud.queue_free()
	fake_player.queue_free()
	await get_tree().process_frame
	print("GAMEPLAY_HUD_SMOKE_OK")
	get_tree().quit(0)


func _fail(message: String) -> void:
	get_tree().paused = false
	push_error(message)
	get_tree().quit(1)


func _find_inventory_button(grid: GridContainer, item_name: String) -> Button:
	for child in grid.get_children():
		if child is Button and String(child.tooltip_text).begins_with(item_name):
			return child as Button
	return null
