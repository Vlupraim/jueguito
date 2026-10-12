extends Node

const PLAYER := preload("res://scenes/characters/player/player.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := PLAYER.instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.set_gameplay_input_enabled(false)
	var animation := player.get("character_animation_player") as AnimationPlayer
	var skeleton := player.find_child("Skeleton3D", true, false) as Skeleton3D
	var hip := skeleton.find_bone("Hips")
	if not player.hold_character_action_pose(&"stand_up1", 0.0):
		_fail("No se pudo preparar la pose acostada del tutorial")
		return
	var lying := skeleton.get_bone_pose_position(hip)
	player.play_character_action(&"stand_up1", 0.0)
	animation.seek(player.get_character_action_duration(&"stand_up1") - 0.005, true)
	var standing := skeleton.get_bone_pose_position(hip)
	var standing_tolerance := standing.distance_to(lying) * 0.15
	# Cross the actual end signal, before physics can choose idle next frame.
	animation.advance(0.01)
	if not String(player.get("character_action_animation")).is_empty():
		_fail("La acción de levantarse no terminó")
		return
	if skeleton.get_bone_pose_position(hip).distance_to(standing) > standing_tolerance:
		_fail("Al terminar stand_up1 reaparece la pose acostada antes del siguiente frame")
		return
	# HUD/input handoff and all blend frames must remain upright.
	player.set_gameplay_input_enabled(true)
	player.call("_update_locomotion", Vector3.ZERO, player.get("walk_speed"))
	for _frame in range(20):
		animation.advance(1.0 / 60.0)
		if skeleton.get_bone_pose_position(hip).distance_to(standing) > standing_tolerance:
			_fail("La mezcla hacia reposo volvió a acostar al personaje")
			return
	# Cancellation uses the same path; preserve the current pose until locomotion.
	player.play_character_action(&"stand_up1", 0.0)
	animation.seek(player.get_character_action_duration(&"stand_up1") - 0.01, true)
	player.stop_character_action()
	if skeleton.get_bone_pose_position(hip).distance_to(standing) > standing_tolerance:
		_fail("Cancelar una acción restablece su pose inicial")
		return
	print("TUTORIAL_POSE_TRANSITION_SMOKE_OK finish=true idle_blend=true cancellation=true")
	player.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
