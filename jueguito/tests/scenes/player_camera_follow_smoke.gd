extends Node3D

const PLAYER := preload("res://scenes/characters/player/player.tscn")
var failures: Array[String] = []

func get_player_ground_info(point: Vector3) -> Dictionary:
	return {"walkable":true,"position":Vector3(point.x,0,point.z),"water":{"in_water":false,"state":"dry"}}

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := PLAYER.instantiate() as CharacterBody3D
	player.position.y = 0.78
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.call("set_camera_locked",true)
	var pivot := player.get_node("CameraPivot") as Node3D
	var visual := player.get_node("Visual") as Node3D
	for fps in [30,120]:
		pivot.rotation.y = 0
		visual.rotation.y = 0
		player.position = Vector3(0,0.78,0)
		player.call("_movement_input_direction") # clear previous gesture
		Input.action_press("player_left")
		for tick in range(fps*2):
			var before := player.position
			var camera_before := pivot.rotation.y
			player.call("_physics_process",1.0/fps)
			player.call("_process",1.0/fps)
			var travel := player.position-before
			if travel.length() > 0.001:
				check(travel.normalized().dot(Vector3(-sin(visual.rotation.y),0,-cos(visual.rotation.y))) > 0.999,"Body slides sideways during a locked turn")
			check(absf(angle_difference(camera_before,pivot.rotation.y)) <= deg_to_rad(player.get("camera_follow_speed_degrees"))/fps+0.001,"Camera exceeds turn speed limit")
			if tick == 0: check(absf(pivot.rotation.y) < 0.001,"Camera snaps on key press")
		Input.action_release("player_left")
		check(absf(angle_difference(PI/2,visual.rotation.y)) < 0.01,"Held A causes a circular trajectory")
		check(absf(angle_difference(PI/2,pivot.rotation.y)) < 0.02,"Camera does not settle behind body")
		check(player.position.x < -6.0 and absf(player.position.z) < 0.5,"Held A does not continue straight")
		player.call("_movement_input_direction")
		Input.action_press("player_backward")
		for tick in range(fps*2):
			player.call("_physics_process",1.0/fps)
			player.call("_process",1.0/fps)
		Input.action_release("player_backward")
		check(absf(angle_difference(-PI/2,visual.rotation.y)) < 0.04,"S does not turn body toward movement")
		check(absf(angle_difference(-PI/2,pivot.rotation.y)) < 0.04,"Camera fails a 180-degree turn")
	# RMB keeps manual orbit independent of movement, and releases cleanly.
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	player.call("_unhandled_input",mouse)
	player.call("orbit_camera",Vector2(100,0))
	var orbit_yaw := pivot.rotation.y
	Input.action_press("player_forward")
	player.call("_physics_process",0.1)
	player.call("_process",0.1)
	check(is_equal_approx(pivot.rotation.y,orbit_yaw),"Auto-follow fights mouse orbit")
	mouse.pressed = false
	player.call("_unhandled_input",mouse)
	var after_release: Vector3 = player.call("_movement_input_direction")
	check(after_release.distance_to(pivot.global_basis*Vector3.FORWARD) < 0.01,"Orbit release changes held movement unexpectedly")
	Input.action_release("player_forward")
	player.call("set_camera_distance",0.0)
	var first_person_yaw := pivot.rotation.y
	Input.action_press("player_left")
	player.call("_physics_process",0.1)
	player.call("_process",0.5)
	Input.action_release("player_left")
	check(is_equal_approx(pivot.rotation.y,first_person_yaw),"First person auto-spins when strafing")
	print("CAMERA_FOLLOW_SMOKE ","PASS" if failures.is_empty() else "FAIL", " ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
