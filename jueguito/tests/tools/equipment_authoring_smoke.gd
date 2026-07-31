extends SceneTree


func _init() -> void:
	for item_name in [
		ItemCatalog.LUMBERJACK_AXE,
		ItemCatalog.VIKING_SWORD,
		ItemCatalog.VIKING_SHIELD,
		ItemCatalog.VIKING_BOW,
	]:
		var discovered := ItemCatalog.get_definition(item_name)
		if discovered.is_empty():
			_fail("No se descubrio la definicion de " + item_name)
			return
		var scene_path := String(discovered.get("model_path", ""))
		if load(scene_path) as PackedScene == null:
			_fail("No se pudo cargar la escena calibrada de " + item_name)
			return

	var definition := ItemCatalog.get_definition(ItemCatalog.LUMBERJACK_AXE)
	if definition.is_empty():
		_fail("No se descubrio la definicion editable del hacha")
		return
	if String(definition.get("attachment_primary_bone", "")) != "RightHand":
		_fail("La definicion no conserva el hueso primario")
		return
	if String(definition.get("attachment_secondary_bone", "")) != "LeftHand":
		_fail("La definicion no conserva el hueso secundario")
		return
	if String(definition.get("hand_usage", "")) != "two_hand":
		_fail("El hacha no quedo definida como item de dos manos")
		return
	if ItemCatalog.can_equip_in_slot(ItemCatalog.VIKING_SWORD, "secondary"):
		_fail("La espada permitio equiparse en la mano izquierda")
		return
	if ItemCatalog.can_equip_in_slot(ItemCatalog.VIKING_SHIELD, "primary"):
		_fail("El escudo permitio equiparse en la mano derecha")
		return
	var held_path := String(definition.get("model_path", ""))
	var held_scene := load(held_path) as PackedScene
	if held_scene == null:
		_fail("No se pudo cargar la escena calibrada")
		return
	var held := held_scene.instantiate() as Node3D
	root.add_child(held)
	var visual := held.find_child("Visual", true, false) as Node3D
	if visual == null:
		_fail("La escena calibrada no contiene Visual")
		return
	if not visual.transform.is_finite() or visual.scale.is_zero_approx():
		_fail("La escena calibrada contiene una transformacion invalida")
		return
	print("EQUIPMENT_AUTHORING_SMOKE_OK path=", held_path)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
