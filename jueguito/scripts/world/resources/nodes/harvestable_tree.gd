@tool
extends Node3D
class_name HarvestableTree

signal depleted(resource_id: String, respawn_at: float)
signal respawned(resource_id: String)

@export var resource_id := ""
@export var display_name := "Arbol"
@export var item_name := "Madera"
@export var amount := 3
@export var harvest_duration := 7.0
@export var respawn_seconds := 540.0
@export var interaction_range := 3.2
@export var respawn_player_radius := 60.0
@export var required_tool_type := "axe"
@export var model_scene: PackedScene
@export var visual_height := 8.0
@export var visual_yaw_degrees := 0.0
@export var trunk_radius := 0.42
@export var trunk_height := 4.5

@onready var visual_pivot: Node3D = $VisualPivot
@onready var trunk_collision: CollisionShape3D = $TrunkBody/CollisionShape3D
@onready var interaction_collision: CollisionShape3D = $InteractionArea/CollisionShape3D
@onready var stump_visual: MeshInstance3D = $StumpVisual

var available := true
var busy := false
var reserved_player_id := 0
var respawn_at := 0.0
var model_bounds := AABB()


func _ready() -> void:
	_instantiate_model()
	_configure_collisions()
	# Las variantes guardan solo la referencia al GLB. En el editor mostramos ese
	# mismo modelo como preview; la logica de cosecha debe ejecutarse solo en juego.
	if Engine.is_editor_hint():
		set_process(false)
		return
	add_to_group("harvestable_trees")
	var network_manager := get_node_or_null("/root/NetworkManager")
	if network_manager != null and network_manager.has_method("get_resource_respawn_at"):
		respawn_at = float(network_manager.call(
			"get_resource_respawn_at",
			_resolved_resource_id()
		))
	if respawn_at > Time.get_unix_time_from_system():
		_apply_depleted_visual(false)
	else:
		_apply_available_visual()


func _process(_delta: float) -> void:
	if available or respawn_at <= 0.0:
		return
	if Time.get_unix_time_from_system() < respawn_at:
		return
	if not _has_nearby_player():
		return
	respawn_at = 0.0
	_apply_available_visual()
	respawned.emit(_resolved_resource_id())


func can_interact(player: Node = null) -> bool:
	if not available or busy:
		return false
	if player == null or required_tool_type.is_empty():
		return true
	return player.has_method("has_equipped_tool") \
		and bool(player.call("has_equipped_tool", required_tool_type))


func interact(player: Node) -> void:
	if player != null and player.has_method("request_interaction_with"):
		player.call("request_interaction_with", self)


func get_interaction_position(player_position: Vector3) -> Vector3:
	var direction := player_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	return global_position + direction.normalized() * maxf(interaction_range - 0.55, 0.6)


func get_interaction_range() -> float:
	return interaction_range


func get_interaction_duration() -> float:
	return harvest_duration


func get_interaction_label() -> String:
	return "Talando %s" % display_name


func get_interaction_animation() -> StringName:
	return &"chop"


func begin_interaction(player: Node) -> bool:
	if not can_interact(player):
		return false
	busy = true
	reserved_player_id = player.get_instance_id() if player != null else 0
	return true


func cancel_interaction(player: Node) -> void:
	if reserved_player_id != 0 and player != null:
		if reserved_player_id != player.get_instance_id():
			return
	busy = false
	reserved_player_id = 0


func complete_interaction(player: Node) -> bool:
	if not available or not busy:
		return false
	if reserved_player_id != 0 and player != null:
		if reserved_player_id != player.get_instance_id():
			return false
	var network_manager := get_node_or_null("/root/NetworkManager")
	if network_manager == null or not network_manager.has_method("request_resource_harvest"):
		busy = false
		reserved_player_id = 0
		return false
	var response: Variant = network_manager.call(
		"request_resource_harvest",
		_resolved_resource_id(),
		item_name,
		amount,
		respawn_seconds
	)
	var result := response as Dictionary
	busy = false
	reserved_player_id = 0
	if not bool(result.get("success", false)):
		return false
	respawn_at = float(result.get("respawn_at", 0.0))
	_apply_depleted_visual(true)
	depleted.emit(_resolved_resource_id(), respawn_at)
	return true


func _resolved_resource_id() -> String:
	if not resource_id.is_empty():
		return resource_id
	return "%s@%.2f,%.2f,%.2f" % [
		scene_file_path,
		global_position.x,
		global_position.y,
		global_position.z,
	]


func _instantiate_model() -> void:
	var previous_model := visual_pivot.get_node_or_null("TreeModel")
	if previous_model != null:
		previous_model.free()
	if model_scene == null:
		push_warning("HarvestableTree sin model_scene: " + name)
		return
	var model := model_scene.instantiate() as Node3D
	if model == null:
		push_warning("No se pudo instanciar el modelo de " + name)
		return
	model.name = "TreeModel"
	visual_pivot.add_child(model)
	model_bounds = _calculate_model_bounds(model)
	if model_bounds.size.y <= 0.001:
		return
	var model_scale := visual_height / model_bounds.size.y
	model.scale = Vector3.ONE * model_scale
	model.position.y = -model_bounds.position.y * model_scale
	model.rotation_degrees.y = visual_yaw_degrees


func _calculate_model_bounds(model: Node3D) -> AABB:
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var has_bounds := false
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var relative := _transform_relative_to(mesh_instance, model)
		var mesh_bounds := relative * mesh_instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	return bounds


func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func _configure_collisions() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = trunk_radius
	capsule.height = maxf(trunk_height, trunk_radius * 2.0)
	trunk_collision.shape = capsule
	trunk_collision.position.y = trunk_height * 0.5

	var interaction_box := BoxShape3D.new()
	var interaction_size := Vector3(
		maxf(model_bounds.size.x * visual_height / maxf(model_bounds.size.y, 0.001), 1.2),
		visual_height,
		maxf(model_bounds.size.z * visual_height / maxf(model_bounds.size.y, 0.001), 1.2)
	)
	interaction_box.size = interaction_size
	interaction_collision.shape = interaction_box
	interaction_collision.position.y = visual_height * 0.5


func _apply_depleted_visual(animate_fall: bool) -> void:
	available = false
	busy = false
	reserved_player_id = 0
	trunk_collision.set_deferred("disabled", true)
	interaction_collision.set_deferred("disabled", true)
	set_process(true)
	if not animate_fall:
		visual_pivot.hide()
		stump_visual.show()
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(visual_pivot, "rotation_degrees:z", 78.0, 0.7)
	tween.tween_callback(visual_pivot.hide)
	tween.tween_callback(stump_visual.show)


func _apply_available_visual() -> void:
	available = true
	busy = false
	reserved_player_id = 0
	visual_pivot.rotation = Vector3.ZERO
	visual_pivot.show()
	stump_visual.hide()
	trunk_collision.set_deferred("disabled", false)
	interaction_collision.set_deferred("disabled", false)
	set_process(false)


func _has_nearby_player() -> bool:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	for node in players:
		if node is Node3D:
			if global_position.distance_to((node as Node3D).global_position) <= respawn_player_radius:
				return true
	return false
