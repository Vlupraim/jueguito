extends RefCounted
class_name CharacterAnimationRetargeter

const DEFAULT_SOURCE_PATH := "res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb"
const LIBRARY_NAME := &"shared"

const ALIAS_TO_CANONICAL := {
	&"idle": &"idle_11",
	&"walk": &"walking_man",
	&"run": &"running",
	&"jump": &"basic_jump",
	&"gather": &"collect_object",
	&"attack": &"attack",
	&"swim_idle": &"swim_idle",
}

const LOOPING_CLIPS := {
	"idle_11": true,
	"walking_man": true,
	"running": true,
	"swim_idle": true,
}


static func install_shared_library(
		target_root: Node,
		target_player: AnimationPlayer,
		source_path: String = DEFAULT_SOURCE_PATH,
		aliases_only: bool = false
	) -> Dictionary:
	var report := {
		"installed": 0,
		"source_clips": 0,
		"missing_bones": PackedStringArray(),
		"error": "",
	}
	if target_root == null or target_player == null:
		report["error"] = "Destino de animacion incompleto"
		return report
	if not ResourceLoader.exists(source_path):
		report["error"] = "No existe la biblioteca fuente: " + source_path
		return report

	var source_scene := load(source_path) as PackedScene
	if source_scene == null:
		report["error"] = "La biblioteca fuente no es una escena GLB valida"
		return report
	var source_root := source_scene.instantiate()
	if source_root == null:
		report["error"] = "No se pudo instanciar la biblioteca fuente"
		return report

	var source_player := _find_animation_player(source_root)
	var source_skeleton := _find_skeleton(source_root)
	var target_skeleton := _find_skeleton(target_root)
	if source_player == null or source_skeleton == null or target_skeleton == null:
		report["error"] = "Falta AnimationPlayer o Skeleton3D en fuente/destino"
		source_root.free()
		return report

	if target_player.has_animation_library(LIBRARY_NAME):
		target_player.remove_animation_library(LIBRARY_NAME)
	var library := AnimationLibrary.new()
	target_player.add_animation_library(LIBRARY_NAME, library)

	var installed_by_name: Dictionary = {}
	var missing_bones: Dictionary = {}
	var source_names := source_player.get_animation_list()
	report["source_clips"] = source_names.size()
	for source_name in source_names:
		if String(source_name).to_lower() == "reset":
			continue
		var canonical_name := _canonical_clip_name(String(source_name))
		if aliases_only and not canonical_name in ALIAS_TO_CANONICAL.values():
			continue
		if library.has_animation(canonical_name):
			canonical_name = StringName(String(canonical_name) + "_variant")

		var source_animation := source_player.get_animation(source_name)
		var retargeted := _retarget_animation(
			source_animation,
			source_skeleton,
			target_skeleton,
			target_player,
			missing_bones
		)
		if retargeted == null:
			continue
		retargeted.resource_name = String(canonical_name)
		retargeted.loop_mode = (
			Animation.LOOP_LINEAR
			if LOOPING_CLIPS.has(String(canonical_name))
			else Animation.LOOP_NONE
		)
		library.add_animation(canonical_name, retargeted)
		installed_by_name[canonical_name] = retargeted
		report["installed"] = int(report["installed"]) + 1

	for alias in ALIAS_TO_CANONICAL:
		var canonical: StringName = ALIAS_TO_CANONICAL[alias]
		if installed_by_name.has(canonical) and not library.has_animation(alias):
			library.add_animation(alias, installed_by_name[canonical])

	var missing_list := PackedStringArray()
	for bone_name in missing_bones:
		missing_list.append(String(bone_name))
	missing_list.sort()
	report["missing_bones"] = missing_list
	source_root.free()
	return report


static func shared_animation_name(alias: StringName) -> StringName:
	return StringName(String(LIBRARY_NAME) + "/" + String(alias))


static func _retarget_animation(
		source_animation: Animation,
		source_skeleton: Skeleton3D,
		target_skeleton: Skeleton3D,
		target_player: AnimationPlayer,
		missing_bones: Dictionary
	) -> Animation:
	if source_animation == null:
		return null
	var animation := source_animation.duplicate(true) as Animation
	# AnimationMixer evalua las pistas desde `root_node`, no desde el propio
	# AnimationPlayer. Los GLB importados usan ".." como raiz, por lo que una
	# ruta calculada desde el player agregaria un "../" invalido a cada pista.
	var animation_root := target_player.get_node_or_null(target_player.root_node)
	if animation_root == null:
		animation_root = target_player
	var target_skeleton_path := animation_root.get_path_to(target_skeleton)
	var tracks_to_remove: Array[int] = []

	for track_index in range(animation.get_track_count()):
		var track_path := animation.track_get_path(track_index)
		if track_path.get_subname_count() == 0:
			tracks_to_remove.append(track_index)
			continue
		var bone_name := StringName(track_path.get_subname(track_path.get_subname_count() - 1))
		var source_bone := source_skeleton.find_bone(bone_name)
		var target_bone := target_skeleton.find_bone(bone_name)
		if source_bone < 0 or target_bone < 0:
			missing_bones[bone_name] = true
			tracks_to_remove.append(track_index)
			continue

		animation.track_set_path(
			track_index,
			NodePath("%s:%s" % [String(target_skeleton_path), String(bone_name)])
		)
		_retarget_track_keys(
			animation,
			track_index,
			source_skeleton.get_bone_rest(source_bone),
			target_skeleton.get_bone_rest(target_bone)
		)

	tracks_to_remove.sort()
	tracks_to_remove.reverse()
	for track_index in tracks_to_remove:
		animation.remove_track(track_index)
	return animation


static func _retarget_track_keys(
		animation: Animation,
		track_index: int,
		source_rest: Transform3D,
		target_rest: Transform3D
	) -> void:
	var track_type := animation.track_get_type(track_index)
	for key_index in range(animation.track_get_key_count(track_index)):
		var source_value: Variant = animation.track_get_key_value(track_index, key_index)
		match track_type:
			Animation.TYPE_POSITION_3D:
				var position := source_value as Vector3
				animation.track_set_key_value(
					track_index,
					key_index,
					target_rest.origin + (position - source_rest.origin)
				)
			Animation.TYPE_ROTATION_3D:
				var rotation := source_value as Quaternion
				var source_rest_rotation := source_rest.basis.orthonormalized().get_rotation_quaternion()
				var target_rest_rotation := target_rest.basis.orthonormalized().get_rotation_quaternion()
				var delta := source_rest_rotation.inverse() * rotation
				animation.track_set_key_value(
					track_index,
					key_index,
					(target_rest_rotation * delta).normalized()
				)
			Animation.TYPE_SCALE_3D:
				var scale := source_value as Vector3
				var source_rest_scale := source_rest.basis.get_scale()
				var target_rest_scale := target_rest.basis.get_scale()
				animation.track_set_key_value(
					track_index,
					key_index,
					target_rest_scale * _safe_component_divide(scale, source_rest_scale)
				)


static func _safe_component_divide(value: Vector3, divisor: Vector3) -> Vector3:
	return Vector3(
		value.x / divisor.x if absf(divisor.x) > 0.000001 else value.x,
		value.y / divisor.y if absf(divisor.y) > 0.000001 else value.y,
		value.z / divisor.z if absf(divisor.z) > 0.000001 else value.z
	)


static func _canonical_clip_name(source_name: String) -> StringName:
	var parts := source_name.split("|")
	var clip_name := source_name
	if parts.size() >= 2:
		clip_name = parts[1]
	clip_name = clip_name.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if source_name.ends_with(".001"):
		clip_name += "_variant"
	return StringName(clip_name)


static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	var players := root.find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if not players.is_empty() else null


static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	return skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
