extends Node

const TREE_SCENES := [
	"res://scenes/world/resources/trees/pine_tall_01.tscn",
	"res://scenes/world/resources/trees/palm_curved_01.tscn",
	"res://scenes/world/resources/trees/acacia_01.tscn",
	"res://scenes/world/resources/trees/broadleaf_01.tscn",
	"res://scenes/world/resources/trees/pine_dense_01.tscn",
	"res://scenes/world/resources/trees/willow_rooted_01.tscn",
]

class FakePlayer extends Node3D:
	var has_axe := true

	func has_equipped_tool(tool_type: String) -> bool:
		return has_axe and tool_type == "axe"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	for path in TREE_SCENES:
		var failure := await _validate_tree_scene(path)
		if not failure.is_empty():
			failures.append(failure)
	if failures.is_empty():
		var flow_failure := await _validate_harvest_and_respawn()
		if not flow_failure.is_empty():
			failures.append(flow_failure)

	if failures.is_empty():
		print("HARVESTABLE_TREE_FLOW_SMOKE_OK variants=", TREE_SCENES.size())
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _validate_tree_scene(path: String) -> String:
	if not ResourceLoader.exists(path):
		return "No existe/importa la escena: " + path
	var scene := load(path) as PackedScene
	if scene == null:
		return "No carga como PackedScene: " + path
	var tree := scene.instantiate() as Node3D
	if tree == null:
		return "No se pudo instanciar: " + path
	add_child(tree)
	await get_tree().process_frame
	var failure := ""
	var visual_pivot := tree.get_node_or_null("VisualPivot") as Node3D
	var trunk := tree.get_node_or_null("TrunkBody/CollisionShape3D") as CollisionShape3D
	var interaction := tree.get_node_or_null(
		"InteractionArea/CollisionShape3D"
	) as CollisionShape3D
	if visual_pivot == null or visual_pivot.get_child_count() != 1:
		failure = "No se instancio el visual: " + path
	elif trunk == null or not (trunk.shape is CapsuleShape3D):
		failure = "Falta hitbox de tronco: " + path
	elif interaction == null or not (interaction.shape is BoxShape3D):
		failure = "Falta area de interaccion: " + path
	elif not bool(tree.call("can_interact", null)):
		failure = "El arbol no inicia disponible: " + path
	tree.queue_free()
	await get_tree().process_frame
	return failure


func _validate_harvest_and_respawn() -> String:
	var scene := load(TREE_SCENES[0]) as PackedScene
	var tree := scene.instantiate() as Node3D
	tree.set("resource_id", "smoke/pine_001")
	tree.set("respawn_seconds", 0.05)
	tree.set("respawn_player_radius", 10.0)
	add_child(tree)
	var fake_player := FakePlayer.new()
	fake_player.name = "FakePlayer"
	fake_player.add_to_group("player")
	add_child(fake_player)
	await get_tree().process_frame

	NetworkManager.current_character_name = "Vlupraim"
	fake_player.has_axe = false
	if bool(tree.call("can_interact", fake_player)):
		return "El pino permitio talar sin un hacha equipada"
	if bool(tree.call("begin_interaction", fake_player)):
		return "El pino inicio la tala sin un hacha equipada"
	fake_player.has_axe = true
	if not bool(tree.call("begin_interaction", fake_player)):
		return "El pino de prueba no acepto begin_interaction"
	if not bool(tree.call("complete_interaction", fake_player)):
		return "El servidor mock rechazo la tala de prueba"
	if bool(tree.call("can_interact", fake_player)):
		return "El pino siguio disponible despues de talarlo"

	# Time.get_unix_time_from_system puede tener resolucion de un segundo segun
	# la plataforma, por lo que el smoke deja margen aunque el respawn sea 0.05.
	await get_tree().create_timer(1.1).timeout
	await get_tree().process_frame
	if not bool(tree.call("can_interact", fake_player)):
		return "El pino no reaparecio con un jugador cercano"
	tree.queue_free()
	fake_player.queue_free()
	return ""
