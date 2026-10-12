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
	var grid := hud.find_child("InventoryGrid", true, false) as GridContainer
	var inventory_owner := hud.find_child("InventoryOwnerName", true, false) as Label
	var inventory_resources := hud.find_child("InventoryResources", true, false) as PanelContainer
	var inventory_gold := hud.find_child("InventoryGoldLabel", true, false) as Label
	var inventory_capacity := hud.find_child("InventoryCapacity", true, false) as Label
	var character_status := hud.find_child("CharacterStatus", true, false) as Control
	var action_bar := hud.find_child("ActionBar", true, false) as Control
	var signature_module := hud.find_child("SignatureHubModule", true, false) as Control
	var right_action_module := hud.find_child("RightActionModule", true, false) as Control
	var portrait := hud.find_child("Portrait", true, false) as PanelContainer
	var currency := hud.find_child("CurrencyDisplay", true, false) as Control
	var placeholder_stats := hud.find_child("PlaceholderStats", true, false) as PanelContainer
	var inventory_stats_toggle := hud.find_child("InventoryStatsToggle", true, false) as Button
	var equipment_grid := hud.find_child("EquipmentGrid", true, false) as GridContainer
	var mastery_button := hud.find_child("InventoryMasteryButton", true, false) as Button
	var mastery_backdrop := hud.find_child("MasteryTreeBackdrop", true, false) as ColorRect
	var slots := hud.find_child("Slots", true, false) as HBoxContainer
	if inventory == null or pause == null or grid == null or inventory_owner == null \
	or inventory_resources == null or inventory_gold == null or inventory_capacity == null:
		_fail("Faltan controles principales del HUD")
		return
	if character_status == null or action_bar == null or signature_module == null \
	or right_action_module == null or portrait == null \
	or currency == null or placeholder_stats == null or inventory_stats_toggle == null \
	or equipment_grid == null or mastery_button == null or mastery_backdrop == null:
		_fail("Faltan los modulos persistentes de personaje y acciones")
		return
	if currency.visible or character_status.visible:
		_fail("El HUD persistente todavía muestra moneda o el retrato anterior")
		return
	var signature_hub := hud.find_child("SignatureSkillHub", true, false) as Control
	var combat_health := hud.find_child("CombatHealthBar", true, false) as ProgressBar
	var combat_mana := hud.find_child("CombatManaBar", true, false) as ProgressBar
	if slots == null or signature_hub == null \
	or signature_hub.find_children("SignatureSlot*", "Button", false, false).size() != 4 \
	or combat_health == null or combat_mana == null:
		_fail("El HUD de combate no creó habilidades, núcleo insignia y recursos")
		return
	if not action_bar.is_ancestor_of(combat_health) \
	or not right_action_module.is_ancestor_of(combat_mana) \
	or not signature_module.is_ancestor_of(signature_hub):
		_fail("Vida, núcleo y maná no quedaron en tres módulos estructurales separados")
		return
	if str(action_bar.get("layout_key")) != "action_left" \
	or str(signature_module.get("layout_key")) != "action_center" \
	or str(right_action_module.get("layout_key")) != "action_right":
		_fail("Los tres módulos no guardan una personalización independiente")
		return
	var slot_one := hud.find_child("Slot1", true, false) as PanelContainer
	var slot_one_key := slot_one.find_child("Key", true, false) as Label if slot_one != null else null
	var slot_one_frame := slot_one.find_child("Frame", true, false) as TextureRect if slot_one != null else null
	var signature_slot := hud.find_child("SignatureSlot1", true, false) as Button
	var signature_key := signature_slot.find_child("HotkeyBadge", true, false) as Label \
		if signature_slot != null else null
	if slot_one == null or slot_one.custom_minimum_size.x > 42.0 or not slot_one.clip_contents \
	or slot_one_key == null or slot_one_key.horizontal_alignment != HORIZONTAL_ALIGNMENT_RIGHT \
	or slot_one_key.vertical_alignment != VERTICAL_ALIGNMENT_BOTTOM \
	or slot_one_frame == null or slot_one_frame.visible \
	or signature_slot == null or not signature_slot.text.is_empty() or signature_key == null:
		_fail("Las habilidades no usan ranuras compactas con la tecla en una esquina")
		return
	hud.call("reset_hud_layout")
	if not is_equal_approx(action_bar.scale.x, 1.2) \
	or not is_equal_approx(signature_module.scale.x, 1.2) \
	or not is_equal_approx(right_action_module.scale.x, 1.2):
		_fail("Restaurar no fija 100% como escala predeterminada de combate")
		return
	if not action_bar.global_position.x < signature_module.global_position.x \
	or not signature_module.global_position.x < right_action_module.global_position.x:
		_fail("La restauración recomendada no ordenó vida, núcleo y maná")
		return
	var left_end := action_bar.global_position.x + action_bar.size.x * action_bar.scale.x
	var center_end := signature_module.global_position.x + signature_module.size.x * signature_module.scale.x
	var left_gap := signature_module.global_position.x - left_end
	var right_gap := right_action_module.global_position.x - center_end
	var viewport_bottom := hud.get_viewport().get_visible_rect().end.y
	if left_gap < 0.0 or left_gap > 30.0 or right_gap < 0.0 or right_gap > 30.0 \
	or absf(action_bar.global_position.y + action_bar.size.y * action_bar.scale.y - viewport_bottom) > 2.0 \
	or absf(signature_module.global_position.y + signature_module.size.y * signature_module.scale.y - viewport_bottom) > 2.0 \
	or absf(right_action_module.global_position.y + right_action_module.size.y * right_action_module.scale.y - viewport_bottom) > 2.0:
		_fail("El default no centra y alinea abajo los tres módulos como una sola composición")
		return
	hud.call("set_hud_edit_mode", true)
	if character_status.mouse_filter != Control.MOUSE_FILTER_STOP \
	or action_bar.mouse_filter != Control.MOUSE_FILTER_STOP \
	or signature_module.mouse_filter != Control.MOUSE_FILTER_STOP \
	or right_action_module.mouse_filter != Control.MOUSE_FILTER_STOP \
	or not (hud.find_child("HUDEditToolbar", true, false) as Control).visible:
		_fail("El modo editable no habilitó los tres módulos de combate")
		return
	var resize_overlay := character_status.find_child("HUDResizeOverlay", false, false) as Node2D
	var resize_handle: Rect2 = character_status.call("_resize_handle_rect")
	if resize_overlay == null or not resize_overlay.visible or resize_handle.size.x < 18.0:
		_fail("El modo editable no mostro su caja y tirador de escala")
		return
	character_status.call("set_module_scale", 1.2)
	if not is_equal_approx(character_status.scale.x, 1.44):
		_fail("El modulo de personaje no admite escala proporcional")
		return
	character_status.call("reset_layout")
	action_bar.call("set_module_scale", 0.5)
	if not is_equal_approx(action_bar.scale.x, 0.6):
		_fail("La edición no permite reducir el HUD al 50% de la nueva base")
		return
	action_bar.call("reset_layout")
	signature_module.call("set_module_scale", 1.15)
	if not is_equal_approx(signature_module.scale.x, 1.38) \
	or not is_equal_approx(action_bar.scale.x, 1.2) \
	or not is_equal_approx(right_action_module.scale.x, 1.2):
		_fail("Escalar el núcleo también alteró uno de los módulos laterales")
		return
	hud.call("reset_hud_layout")
	if not is_equal_approx(signature_module.scale.x, 1.2):
		_fail("Restaurar no devolvió el núcleo a su escala recomendada")
		return
	hud.call("set_hud_edit_mode", false)
	if inventory.visible or pause.visible:
		_fail("El HUD no inicia cerrado")
		return
	if grid.get_child_count() != 24 or inventory_capacity.text != "7 / 24" \
	or inventory_gold.text != "DAÑO  —":
		_fail("La mochila o las estadísticas provisionales no se representaron correctamente")
		return
	var inventory_panel := hud.find_child("InventoryPanel", true, false) as PanelContainer
	var inventory_scroll := hud.find_child("InventoryScroll", true, false) as ScrollContainer
	var inventory_body := hud.find_child("InventoryBody", true, false) as VBoxContainer
	if inventory_panel == null or inventory_panel.custom_minimum_size.x > 390.0 \
	or not is_equal_approx(inventory_panel.anchor_left, 1.0) \
	or not is_equal_approx(inventory_panel.anchor_right, 1.0) \
	or inventory_scroll == null or inventory_scroll.custom_minimum_size.y > 92.0 \
	or inventory_body == null or grid.columns != 5 or inventory_panel.z_index < 40 \
	or grid.size.y <= inventory_scroll.size.y:
		_fail("El inventario no usa el panel lateral compacto con mochila desplazable")
		return
	if equipment_grid.columns != 3 or equipment_grid.get_child_count() != 9 \
	or hud.find_child("CharacterPreviewViewport", true, false) != null:
		_fail("El equipo no usa la matriz 3x3 liviana prevista para las ranuras futuras")
		return
	if placeholder_stats.visible:
		_fail("Las estadísticas no comienzan plegadas")
		return
	inventory_stats_toggle.pressed.emit()
	await get_tree().process_frame
	if not placeholder_stats.visible:
		_fail("El desplegable de estadísticas no se abre")
		return
	inventory_stats_toggle.pressed.emit()
	await get_tree().process_frame
	if placeholder_stats.visible:
		_fail("El desplegable de estadísticas no vuelve a plegarse")
		return
	var populated_slots := 0
	for child in grid.get_children():
		if child.has_meta("inventory_item"):
			populated_slots += 1
	if populated_slots != 7:
		_fail("El inventario no separó las dos espadas en ranuras individuales")
		return
	if _count_inventory_entries(grid, "Espada vikinga") != 2 \
	or _count_inventory_entries(grid, "Madera") != 1 \
	or _count_inventory_entries(grid, "Hierro") != 1:
		_fail("La política de apilado no separa equipo y recursos")
		return
	for child in grid.get_children():
		if child.has_meta("inventory_item"):
			var item_icon := child.find_child("ItemIcon", true, false) as TextureRect
			if item_icon == null or item_icon.texture == null:
				_fail("Un objeto real quedó sin icono 2D de inventario")
				return
	var wood_entry := _find_inventory_entry(grid, "Madera")
	var sword_entry := _find_inventory_entry(grid, "Espada vikinga")
	if wood_entry == null or wood_entry.find_child("StackQuantity", true, false) == null \
	or sword_entry == null or sword_entry.find_child("StackQuantity", true, false) != null:
		_fail("Las cantidades aparecen en equipo no apilable o faltan en recursos")
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
	if not GameManager.equipped_primary_item.is_empty() \
	or GameManager.equipped_secondary_item != "Escudo vikingo":
		_fail("El escudo no liberó la espada de dos manos")
		return
	_find_inventory_button(grid, "Arco vikingo").pressed.emit()
	if GameManager.equipped_primary_item != "Arco vikingo" \
	or not GameManager.equipped_secondary_item.is_empty():
		_fail("El arco de dos manos no libero la mano secundaria")
		return
	var primary_slot := hud.find_child("PrimaryEquipmentSlot", true, false) as Button
	if primary_slot == null or str(primary_slot.get_meta("equipment_item", "")) != "Arco vikingo" \
	or "Dos manos" not in primary_slot.tooltip_text:
		_fail("La interfaz no mostro el arco como arma de dos manos")
		return
	var secondary_slot := hud.find_child("SecondaryEquipmentSlot", true, false) as Button
	if secondary_slot == null \
	or str(secondary_slot.get_meta("equipment_item", "")) != "Arco vikingo" \
	or "Dos manos" not in secondary_slot.tooltip_text \
	or secondary_slot.icon == primary_slot.icon:
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
	if timed_panel.get_global_rect().intersects(signature_module.get_global_rect()):
		_fail("La barra temporal invade el nuevo núcleo de habilidades")
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
	await get_tree().process_frame
	await get_tree().process_frame
	for child in grid.get_children():
		var icon := child.find_child("ItemIcon", true, false) as TextureRect
		if icon != null and (absf(icon.get_global_rect().get_center().x - child.get_global_rect().get_center().x) > 1.0 \
		or absf(icon.get_global_rect().get_center().y - child.get_global_rect().get_center().y) > 5.0):
			_fail("La imagen de la mochila quedó fuera del centro de su ranura")
			return
	mastery_button.pressed.emit()
	await get_tree().process_frame
	if not mastery_backdrop.visible \
	or hud.find_child("MasteryTreeView", true, false) == null:
		_fail("El botón de maestrías no abrió el árbol documentado")
		return
	var mastery_scroll := hud.find_child("MasteryTreeViewport", true, false) as Control
	var mastery_tree := hud.find_child("MasteryTreeView", true, false) as MasteryTreeView
	var mastery_center_button := hud.find_child("MasteryHubButton", true, false) as Button
	var inventory_close := hud.find_child("InventoryCloseButton", true, false) as Button
	if mastery_scroll == null or mastery_tree == null or mastery_center_button == null \
	or mastery_center_button.icon == null or not mastery_center_button.text.is_empty() \
	or inventory_close == null or inventory_close.icon == null:
		_fail("Los controles de Maestrías y cierre no usan recursos visuales consistentes")
		return
	await get_tree().process_frame
	var pan: Vector2 = mastery_tree.get("_pan")
	if (pan + MasteryTreeView.ROOT_POINT * mastery_tree.zoom).distance_to(mastery_tree.size * 0.5) > 2.0:
		_fail("El Árbol de Maestrías no abrió centrado")
		return
	var anchor := Vector2(400, 300)
	var board_under_cursor := (anchor - pan) / mastery_tree.zoom
	mastery_tree.set_zoom(mastery_tree.zoom * 1.15, anchor)
	pan = mastery_tree.get("_pan")
	if ((anchor - pan) / mastery_tree.zoom).distance_to(board_under_cursor) > 1.0:
		_fail("El zoom no conserva el punto bajo el cursor")
		return
	var pan_before_drag: Vector2 = mastery_tree.get("_pan")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(400.0, 300.0)
	mastery_tree.call("_gui_input", press)
	var drag := InputEventMouseMotion.new()
	drag.position = press.position - Vector2(55.0, 0.0)
	drag.relative = Vector2(-55.0, 0.0)
	mastery_tree.call("_gui_input", drag)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = drag.position
	mastery_tree.call("_gui_input", release)
	pan = mastery_tree.get("_pan")
	if absf(pan.x - pan_before_drag.x + 55.0) > 1.0:
		_fail("El cursor de mano no permitió arrastrar el Árbol de Maestrías")
		return
	mastery_tree.focus_family("OFICIO")
	if hud.get("mastery_detail_title").text != "OFICIO":
		_fail("El enfoque de rama no actualiza su ficha")
		return
	var selected: Control = mastery_tree.get("_selected")
	if selected == null or not selected.get_node("Selection").visible:
		_fail("La rama elegida no tiene indicador visual")
		return
	var native_nodes: Array = mastery_tree.get("_nodes")
	if native_nodes.size() < 150:
		_fail("El árbol no tiene sus recorridos extensos guardados en la escena")
		return
	hud.call("close_mastery_tree")
	if mastery_backdrop.visible:
		_fail("No se cerró el Árbol de Maestrías")
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


func _count_inventory_entries(grid: GridContainer, item_name: String) -> int:
	var count := 0
	for child in grid.get_children():
		if str(child.get_meta("inventory_item", "")) == item_name:
			count += 1
	return count


func _find_inventory_entry(grid: GridContainer, item_name: String) -> Control:
	for child in grid.get_children():
		if str(child.get_meta("inventory_item", "")) == item_name:
			return child as Control
	return null
