extends SceneTree

const WORKSPACE_SCENE := "res://scenes/tools/editor/terrain3d_sector_workspace.tscn"
const EXPECTED_CATEGORIES := ["Rocks", "Vegetation", "Buildings", "NPCs", "Props"]


func _init() -> void:
	var packed := load(WORKSPACE_SCENE) as PackedScene
	if packed == null:
		_fail("No pude cargar " + WORKSPACE_SCENE)
		return

	var workspace := packed.instantiate()
	var sector_content := workspace.get_node_or_null("SectorContent")
	if sector_content == null:
		_fail("Falta SectorContent en el workspace.")
		return

	for category in EXPECTED_CATEGORIES:
		if sector_content.get_node_or_null(category) == null:
			_fail("Falta SectorContent/" + category + ".")
			return

	workspace.free()
	print("PASS: workspace con estructura SectorContent predeterminada.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
