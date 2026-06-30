extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/sector_world_generator.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)

	for index in range(8):
		await physics_frame

	var player := scene.get_node_or_null("PlayerTest") as Node3D
	if player == null:
		push_error("PlayerTest no fue instanciado.")
		quit(1)
		return

	print("SMOKE_PLAYER_POSITION=", player.global_position)
	if player.global_position.y < -100.0:
		push_error("El player sigue cayendo bajo el mundo.")
		quit(1)
		return

	quit(0)
