extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameManager.clear_equipment()
	GameManager.player_inventory = {
		"Hacha de leñador": 1,
		"Espada vikinga": 2,
		"Escudo vikingo": 1,
		"Arco vikingo": 1,
	}
	GameManager.toggle_item_equipped("Escudo vikingo")
	GameManager.toggle_item_equipped("Espada vikinga")
	var player := PLAYER_SCENE.instantiate()
	player.set("use_generator_ground_snap", false)
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(4)
	if not _validate_attachment(player, "PrimaryItemAttachment", "RightHand", "viking_sword_held.tscn"):
		return
	if player.find_child("SecondaryItemAttachment", true, false) != null:
		_fail("La espada de dos manos dejó el escudo en la secundaria")
		return
	if not bool(player.call("play_primary_equipment_action")):
		_fail("La espada no encontro su animacion attack")
		return

	GameManager.toggle_item_equipped("Arco vikingo")
	await _frames(2)
	if not _validate_attachment(player, "PrimaryItemAttachment", "RightHand", "viking_bow_held.tscn"):
		return
	if player.find_child("SecondaryItemAttachment", true, false) != null:
		_fail("El arco de dos manos dejo un item montado en la mano secundaria")
		return
	if not bool(player.call("play_primary_equipment_action")):
		_fail("El arco no encontro su animacion archery_shot")
		return

	GameManager.toggle_item_equipped("Arco vikingo")
	GameManager.toggle_item_equipped("Hacha de leñador")
	await _frames(2)
	if not GameManager.equipped_secondary_item.is_empty():
		_fail("El hacha de dos manos no libero la ranura secundaria real")
		return
	if not GameManager.has_equipped_tool_type("axe"):
		_fail("El nuevo sistema dejo de reconocer el hacha para la tala")
		return
	print("HAND_EQUIPMENT_FLOW_SMOKE_OK")
	get_tree().quit(0)


func _validate_attachment(
		player: Node,
		attachment_name: String,
		bone_name: String,
		expected_scene_suffix: String
	) -> bool:
	var attachment := player.find_child(attachment_name, true, false) as BoneAttachment3D
	if attachment == null or attachment.bone_name != bone_name:
		_fail("Montaje incorrecto en " + attachment_name)
		return false
	var item := attachment.find_child("Equipped*Item", true, false) as Node3D
	if item == null or not item.scene_file_path.ends_with(expected_scene_suffix):
		_fail("Modelo inesperado en " + attachment_name)
		return false
	return true


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
