extends Node

const WORLD_SCENE := preload("res://scenes/terrain3d_walk_preview.tscn")
const TUTORIAL_SECTOR := Vector2i(27, 30)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameManager.current_character = {
		"name": "Tutorial Intro Smoke",
		"current_sector": TUTORIAL_SECTOR,
		"tutorial_intro_completed": false,
	}
	GameManager.should_play_tutorial_intro = true
	var world := WORLD_SCENE.instantiate()
	add_child(world)
	for _frame in range(6):
		await get_tree().process_frame

	var player := world.get("player") as CharacterBody3D
	if player == null:
		_fail("La introduccion no creo al jugador")
		return
	if not bool(world.get("tutorial_intro_active")):
		_fail("La introduccion de un personaje nuevo no se activo")
		return
	if bool(player.get("gameplay_input_enabled")):
		_fail("El jugador conserva el control durante la cinematica")
		return
	if world.get("tutorial_intro_overlay") == null:
		_fail("Falta el fundido negro de la introduccion")
		return
	if not bool(player.call("hold_character_action_pose", &"stand_up1", 0.0)):
		_fail("El personaje no tiene disponible la animacion stand_up1")
		return
	print("TUTORIAL_INTRO_STAND_UP_DURATION=", player.call(
		"get_character_action_duration", &"stand_up1"
	))

	var deadline := Time.get_ticks_msec() + 30000
	while bool(world.get("tutorial_intro_active")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if bool(world.get("tutorial_intro_active")):
		_fail("La introduccion no termino dentro del tiempo esperado")
		return
	if not bool(player.get("gameplay_input_enabled")):
		_fail("La introduccion no devolvio el control al jugador")
		return
	if not bool(GameManager.current_character.get("tutorial_intro_completed", false)):
		_fail("La introduccion terminada no quedo registrada")
		return

	print("TUTORIAL_INTRO_SMOKE_OK spawn=", player.global_position.round())
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
