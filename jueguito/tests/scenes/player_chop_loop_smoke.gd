extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")
const EXPECTED_SPEED := 1.30


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	player.set("use_generator_ground_snap", false)
	add_child(player)
	player.set_physics_process(false)
	await get_tree().process_frame

	var animation_player := player.get("character_animation_player") as AnimationPlayer
	if animation_player == null:
		_fail("El Player no expuso su AnimationPlayer")
		return
	var interactable := Node3D.new()
	add_child(interactable)
	player.set("active_interactable", interactable)
	player.set("timed_action_animation", &"chop")
	if not bool(player.call("play_character_action", &"chop")):
		_fail("No se pudo iniciar shared/chop")
		return
	if not is_equal_approx(animation_player.get_playing_speed(), EXPECTED_SPEED):
		_fail("shared/chop no se reprodujo a 1.30x")
		return

	var chop_name := StringName("shared/chop")
	var finished_name: StringName = await animation_player.animation_finished
	await get_tree().process_frame
	if finished_name != chop_name:
		_fail("Finalizo una animacion distinta de shared/chop")
		return
	if StringName(player.get("character_action_animation")) != chop_name:
		_fail("El loop de chop limpio la accion entre golpes")
		return
	if not animation_player.is_playing():
		_fail("El loop de chop no reinicio la reproduccion")
		return
	if not is_equal_approx(animation_player.get_playing_speed(), EXPECTED_SPEED):
		_fail("El reinicio de chop perdio la velocidad configurada")
		return

	player.call("_cancel_timed_interaction")
	if not StringName(player.get("character_action_animation")).is_empty():
		_fail("Cancelar la tala no limpio la accion")
		return
	if animation_player.is_playing():
		_fail("Cancelar la tala no detuvo la animacion")
		return

	print("PLAYER_CHOP_LOOP_SMOKE_OK speed=", EXPECTED_SPEED, " capture=0.28")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
