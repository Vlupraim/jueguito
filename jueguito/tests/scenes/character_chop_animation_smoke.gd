extends SceneTree

const AnimationRetargeter = preload(
	"res://scripts/characters/player/character_animation_retargeter.gd"
)
const MODEL_PATH := "res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb"


func _init() -> void:
	var root := _instantiate(MODEL_PATH)
	if root == null:
		quit(1)
		return
	var player := _find_animation_player(root)
	if player == null:
		push_error("Falta AnimationPlayer en el Strongman")
		root.free()
		quit(1)
		return

	var report := AnimationRetargeter.install_shared_library(root, player)
	var error := String(report.get("error", ""))
	var missing_bones: PackedStringArray = report.get("missing_bones", PackedStringArray())
	var chop_name := AnimationRetargeter.shared_animation_name(&"chop")
	var source_name := AnimationRetargeter.shared_animation_name(&"attack")
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	if not missing_bones.is_empty():
		push_error("Huesos sin mapear: %s" % ", ".join(missing_bones))
		quit(1)
		return
	if not player.has_animation(chop_name) or not player.has_animation(source_name):
		push_error("Falta shared/chop o shared/attack")
		quit(1)
		return
	var chop := player.get_animation(chop_name)
	var source := player.get_animation(source_name)
	if chop == null or chop != source or chop.length <= 0.1:
		push_error("shared/chop no referencia el ataque basico incorporado")
		quit(1)
		return
	if not _animation_tracks_resolve(player, chop):
		push_error("shared/chop contiene pistas invalidas")
		quit(1)
		return

	print("CHARACTER_CHOP_ANIMATION_SMOKE_OK length=", chop.length)
	root.free()
	quit(0)


func _instantiate(path: String) -> Node:
	if not ResourceLoader.exists(path):
		push_error("No existe/importa: " + path)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("No importa como PackedScene: " + path)
		return null
	return scene.instantiate()


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	var players := root.find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if not players.is_empty() else null


func _animation_tracks_resolve(player: AnimationPlayer, animation: Animation) -> bool:
	var animation_root := player.get_node_or_null(player.root_node)
	if animation_root == null:
		return false
	for track_index in range(animation.get_track_count()):
		var track_path := animation.track_get_path(track_index)
		var target_node := animation_root.get_node_or_null(
			NodePath(track_path.get_concatenated_names())
		)
		if target_node == null:
			return false
		if track_path.get_subname_count() > 0 and target_node is Skeleton3D:
			var bone_name := StringName(
				track_path.get_subname(track_path.get_subname_count() - 1)
			)
			if (target_node as Skeleton3D).find_bone(bone_name) < 0:
				return false
	return true
