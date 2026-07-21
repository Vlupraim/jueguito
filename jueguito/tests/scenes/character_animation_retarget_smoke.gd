extends SceneTree

const AnimationRetargeter = preload("res://scripts/characters/player/character_animation_retargeter.gd")

const MODEL_PATHS := [
	"res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb",
]


func _init() -> void:
	var failures := PackedStringArray()
	for model_path in MODEL_PATHS:
		var failure := _validate_model(model_path)
		if not failure.is_empty():
			failures.append(failure)

	if failures.is_empty():
		print("CHARACTER_RETARGET_SMOKE_OK models=", MODEL_PATHS.size())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _validate_model(model_path: String) -> String:
	if not ResourceLoader.exists(model_path):
		return "No existe/importa el modelo: " + model_path
	var scene := load(model_path) as PackedScene
	if scene == null:
		return "El modelo no importa como PackedScene: " + model_path
	var root := scene.instantiate()
	if root == null:
		return "No se pudo instanciar: " + model_path
	var players := root.find_children("*", "AnimationPlayer", true, false)
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		root.free()
		return "Falta AnimationPlayer/Skeleton3D: " + model_path

	var player := players[0] as AnimationPlayer
	var report := AnimationRetargeter.install_shared_library(
		root,
		player,
		AnimationRetargeter.DEFAULT_SOURCE_PATH,
		true
	)
	var error := String(report.get("error", ""))
	var missing: PackedStringArray = report.get("missing_bones", PackedStringArray())
	var installed := int(report.get("installed", 0))
	var required := [
		AnimationRetargeter.shared_animation_name(&"idle"),
		AnimationRetargeter.shared_animation_name(&"walk"),
		AnimationRetargeter.shared_animation_name(&"run"),
	]
	for animation_name in required:
		if not player.has_animation(animation_name):
			error = "Falta clip %s" % String(animation_name)
		elif not _animation_tracks_resolve(player, player.get_animation(animation_name)):
			error = "Hay pistas sin destino en %s" % String(animation_name)
	root.free()
	if not error.is_empty():
		return "%s: %s" % [model_path, error]
	if not missing.is_empty():
		return "%s: huesos sin mapear: %s" % [model_path, ", ".join(missing)]
	if installed < 3:
		return "%s: clips instalados insuficientes (%d)" % [model_path, installed]
	print("CHARACTER_RETARGET_MODEL_OK path=", model_path, " clips=", installed)
	return ""


func _animation_tracks_resolve(player: AnimationPlayer, animation: Animation) -> bool:
	var animation_root := player.get_node_or_null(player.root_node)
	if animation_root == null:
		return false
	for track_index in range(animation.get_track_count()):
		var track_path := animation.track_get_path(track_index)
		var node_path := NodePath(track_path.get_concatenated_names())
		var target_node := animation_root.get_node_or_null(node_path)
		if target_node == null:
			return false
		if track_path.get_subname_count() > 0 and target_node is Skeleton3D:
			var bone_name := StringName(
				track_path.get_subname(track_path.get_subname_count() - 1)
			)
			if (target_node as Skeleton3D).find_bone(bone_name) < 0:
				return false
	return true
