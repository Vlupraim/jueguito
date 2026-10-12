extends Node3D

var display_name := ""
var target_position := Vector3.ZERO
var target_yaw := 0.0
var initialized := false
var animator: AnimationPlayer
var character_instance: Node3D
var equipment_signature := ""

func _ready() -> void:
	character_instance = load(CharacterAnimationRetargeter.DEFAULT_SOURCE_PATH).instantiate()
	character_instance.position.y = -0.78
	character_instance.rotation.y = PI
	add_child(character_instance)
	animator = character_instance.find_children("*","AnimationPlayer",true,false)[0]
	CharacterAnimationRetargeter.install_shared_library(character_instance,animator,CharacterAnimationRetargeter.DEFAULT_SOURCE_PATH,true)
	var label := Label3D.new()
	label.text = display_name
	label.position.y = 1.35
	label.font_size = 40
	label.pixel_size = 0.004
	label.modulate = Color("f4e7bf")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)

func apply_snapshot(state: Dictionary) -> void:
	target_position = state["position"]
	target_yaw = float(state["yaw"])
	if not initialized:
		global_position = target_position
		rotation.y = target_yaw
		initialized = true
	var animation := "shared/"+str(state.get("animation","idle"))
	if animator.has_animation(animation) and (animator.current_animation != animation or not animator.is_playing()):
		animator.play(animation,0.12)
	var signature := str(state["primary"])+"|"+str(state["secondary"])
	if signature != equipment_signature:
		equipment_signature = signature
		_refresh_equipped_items(str(state["primary"]),str(state["secondary"]))

func _process(delta: float) -> void:
	if not initialized: return
	global_position = global_position.lerp(target_position,1.0-exp(-18.0*delta))
	rotation.y = lerp_angle(rotation.y,target_yaw,1.0-exp(-18.0*delta))

func _refresh_equipped_items(primary: String, secondary: String) -> void:
	var skeleton := character_instance.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	for attachment_name in ["PrimaryItemAttachment","SecondaryItemAttachment"]:
		var old := skeleton.get_node_or_null(attachment_name)
		if old != null: old.free()
	var slot := ItemCatalog.get_visual_slot(primary)
	var candidates: Array[String] = ["RightHand","right_hand","hand_r"]
	if slot == "secondary": candidates = ["LeftHand","left_hand","hand_l"]
	_attach_item_to_hand(skeleton,primary,slot,candidates)
	_attach_item_to_hand(skeleton,secondary,"secondary",["LeftHand","left_hand","hand_l"])
func _attach_item_to_hand(
		skeleton: Skeleton3D,
		item_name: String,
		slot_name: String,
		bone_candidates: Array[String]
	) -> void:
	if item_name.is_empty():
		return
	var definition := ItemCatalog.get_definition(item_name)
	var item_scene := ItemCatalog.get_model_scene(item_name)
	if definition.is_empty() or item_scene == null:
		return
	var configured_bone := String(definition.get(
		"attachment_%s_bone" % slot_name,
		definition.get("attachment_bone", "")
	))
	var resolved_candidates := bone_candidates.duplicate()
	if not configured_bone.is_empty():
		resolved_candidates.push_front(configured_bone)
	var hand_bone := _find_bone_name(skeleton, resolved_candidates)
	if hand_bone.is_empty():
		push_warning("Player: no se encontro el hueso para " + slot_name)
		return

	var attachment := BoneAttachment3D.new()
	attachment.name = "PrimaryItemAttachment" if slot_name == "primary" \
		else "SecondaryItemAttachment"
	attachment.bone_name = hand_bone
	skeleton.add_child(attachment)

	# El armature del personaje usa una escala de importacion 0.01. Este pivote
	# la compensa para que los items puedan definirse normalmente en metros.
	var scale_compensator := Node3D.new()
	scale_compensator.name = "ScaleCompensator"
	var armature := skeleton.get_parent() as Node3D
	if armature != null:
		scale_compensator.scale = Vector3(
			1.0 / maxf(absf(armature.scale.x), 0.0001),
			1.0 / maxf(absf(armature.scale.y), 0.0001),
			1.0 / maxf(absf(armature.scale.z), 0.0001)
		)
	attachment.add_child(scale_compensator)

	var item := item_scene.instantiate() as Node3D
	item.name = "EquippedPrimaryItem" if slot_name == "primary" \
		else "EquippedSecondaryItem"
	item.position = definition.get(
		"held_%s_position" % slot_name,
		definition.get("held_position", Vector3.ZERO)
	)
	item.rotation_degrees = definition.get(
		"held_%s_rotation_degrees" % slot_name,
		definition.get("held_rotation_degrees", Vector3.ZERO)
	)
	item.scale = Vector3.ONE * float(definition.get(
		"held_%s_scale" % slot_name,
		definition.get("held_scale", 1.0)
	))
	scale_compensator.add_child(item)


func _find_bone_name(skeleton: Skeleton3D, candidates: Array[String]) -> String:
	for candidate in candidates:
		if skeleton.find_bone(candidate) >= 0:
			return candidate
	var side := "right" if "right" in candidates[0].to_lower() else "left"
	for bone_index in range(skeleton.get_bone_count()):
		var normalized := skeleton.get_bone_name(bone_index).to_lower().replace("_", "")
		if side in normalized and "hand" in normalized:
			return skeleton.get_bone_name(bone_index)
	return ""


