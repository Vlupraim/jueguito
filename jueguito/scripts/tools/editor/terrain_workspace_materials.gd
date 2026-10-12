@tool
extends Node3D

func _ready() -> void:
	call_deferred("_refresh")

func _refresh() -> void:
	var terrain := get_node_or_null("Importer") as Terrain3D
	if not preload("res://scripts/tools/editor/terrain_texture_binding.gd").refresh(terrain):
		push_warning("Workspace: no se pudo reconstruir la biblioteca Terrain3D")
