extends Node

const HUD_SCENE := preload("res://scenes/ui/gameplay_hud.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameManager.player_inventory = {"Madera": 10, "Hierro": 5}
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	await get_tree().process_frame

	var inventory := hud.get_node("Screen/InventoryPanel") as PanelContainer
	var pause := hud.get_node("Screen/PauseBackdrop") as ColorRect
	var grid := hud.get_node("Screen/InventoryPanel/Margin/Content/InventoryScroll/InventoryGrid") as GridContainer
	if inventory == null or pause == null or grid == null:
		_fail("Faltan controles principales del HUD")
		return
	if inventory.visible or pause.visible:
		_fail("El HUD no inicia cerrado")
		return
	if grid.get_child_count() != 2:
		_fail("El inventario no represento sus dos items")
		return

	hud.call("open_inventory")
	if not inventory.visible:
		_fail("No se abrio el inventario")
		return
	hud.call("close_inventory")
	hud.call("open_pause_menu")
	if not pause.visible or not get_tree().paused:
		_fail("El menu no pauso el arbol")
		return
	hud.call("close_pause_menu")
	if pause.visible or get_tree().paused:
		_fail("Continuar no reanudo el arbol")
		return

	hud.queue_free()
	await get_tree().process_frame
	print("GAMEPLAY_HUD_SMOKE_OK")
	get_tree().quit(0)


func _fail(message: String) -> void:
	get_tree().paused = false
	push_error(message)
	get_tree().quit(1)
