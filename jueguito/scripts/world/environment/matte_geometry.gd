@tool
extends Node3D

@export var surface_material: Material

func _ready() -> void:
	if surface_material == null: return
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = surface_material
		mesh.visibility_range_end = 180.0
		mesh.visibility_range_end_margin = 15.0
