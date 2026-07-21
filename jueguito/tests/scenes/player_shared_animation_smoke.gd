extends Node

const WORLD_SCENE := preload("res://scenes/terrain3d_walk_preview.tscn")
const START_SECTOR := Vector2i(27, 30)
const AnimationRetargeter = preload(
	"res://scripts/characters/player/character_animation_retargeter.gd"
)

const MODEL_PATHS := [
	"res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	for model_path in MODEL_PATHS:
		var failure := await _validate_player_model(model_path)
		if not failure.is_empty():
			failures.append(failure)

	GameManager.current_character = {}
	if failures.is_empty():
		print("PLAYER_SHARED_ANIMATION_SMOKE_OK models=", MODEL_PATHS.size())
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _validate_player_model(model_path: String) -> String:
	GameManager.current_character = {
		"name": "Smoke Test",
		"current_sector": START_SECTOR,
		"position": Vector3(0.0, 1.45, 0.0),
		"model_path": model_path,
		"animation_source_path": AnimationRetargeter.DEFAULT_SOURCE_PATH,
		"visual_scale": 1.0,
		"hair_path": "",
	}
	var world := WORLD_SCENE.instantiate()
	add_child(world)
	for frame in range(5):
		await get_tree().process_frame
	var player := world.get("player") as CharacterBody3D

	var failure := ""
	var character_instance: Node3D
	var animation_player: AnimationPlayer
	if world.get("current_sector") != START_SECTOR:
		failure = "El mundo no cargo el sector inicial (27, 30)"
	elif player == null:
		failure = "El mundo Terrain3D no instancio al Player: " + model_path
	else:
		character_instance = player.get("character_instance") as Node3D
		animation_player = player.get("character_animation_player") as AnimationPlayer
	if failure.is_empty() and character_instance == null:
		failure = "No se instancio el cuerpo: " + model_path
	elif failure.is_empty() and character_instance.scene_file_path != model_path:
		failure = "El Player cargo otro cuerpo para: " + model_path
	elif failure.is_empty() and animation_player == null:
		failure = "El cuerpo no expuso AnimationPlayer: " + model_path
	elif failure.is_empty():
		for alias in [&"idle", &"walk", &"run"]:
			var animation_name := AnimationRetargeter.shared_animation_name(alias)
			if not animation_player.has_animation(animation_name):
				failure = "Falta %s en Player: %s" % [animation_name, model_path]
				break
		if failure.is_empty():
			var library := animation_player.get_animation_library(
				AnimationRetargeter.LIBRARY_NAME
			)
			if library == null or library.get_animation_list().size() < 20:
				failure = "No se instalo la biblioteca completa: " + model_path

	if failure.is_empty():
		print("PLAYER_SHARED_ANIMATION_MODEL_OK path=", model_path)
	world.queue_free()
	await get_tree().process_frame
	return failure
