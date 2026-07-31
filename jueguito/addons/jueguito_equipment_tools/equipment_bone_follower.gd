@tool
extends Node3D

@export var character_path: NodePath = NodePath("../CharacterPreview")
@export var bone_name := "RightHand"


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	sync_to_bone()


func sync_to_bone() -> void:
	var character := get_node_or_null(character_path) as Node3D
	if character == null:
		return
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone_index := skeleton.find_bone(bone_name)
	if bone_index < 0:
		return
	global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)
