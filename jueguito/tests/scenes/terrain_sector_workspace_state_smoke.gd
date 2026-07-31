extends SceneTree

const DOCK_SCRIPT := preload("res://addons/jueguito_terrain_tools/terrain_map_dock.gd")


class FakeImporter extends Node3D:
	var data_directory := "res://data/terrain3d_edits/sector_27_30"
	var height_file_name := "res://data/terrain3d_exports/sector_28_30/height.exr"

	func start_import(_do_import: bool = true) -> void:
		pass

	func reset_terrain(_clear: bool = true) -> void:
		pass


class FakeSelection extends RefCounted:
	func get_selected_nodes() -> Array:
		return []

	func clear() -> void:
		pass


class FakeEditorInterface extends RefCounted:
	var workspace: Node
	var selection := FakeSelection.new()
	var marked_unsaved := false

	func _init(root: Node) -> void:
		workspace = root

	func get_edited_scene_root() -> Node:
		return workspace

	func get_selection() -> FakeSelection:
		return selection

	func mark_scene_as_unsaved() -> void:
		marked_unsaved = true


func _init() -> void:
	var dock = DOCK_SCRIPT.new()
	var workspace := Node3D.new()
	workspace.name = "Terrain3DSectorWorkspace"
	var importer := FakeImporter.new()
	importer.name = "Importer"
	workspace.add_child(importer)
	var unassigned := dock.call("_create_empty_sector_content", Vector2i(27, 30)) as Node3D
	unassigned.remove_meta("sector_x")
	unassigned.remove_meta("sector_y")
	var rock := Node3D.new()
	rock.name = "RecoveredWorkspaceRock"
	unassigned.get_node("Rocks").add_child(rock)
	rock.owner = unassigned
	var misplaced_ocean := Node3D.new()
	misplaced_ocean.name = "OceanPreview"
	unassigned.get_node("Rocks").add_child(misplaced_ocean)
	misplaced_ocean.owner = unassigned
	workspace.add_child(unassigned)

	var fake_editor := FakeEditorInterface.new(workspace)
	dock.set("editor_interface", fake_editor)
	dock.call("_initialize_workspace_state")

	if dock.get("loaded_sector") != Vector2i(27, 30) or dock.get("loaded_content_sector") != Vector2i(27, 30):
		_fail("El workspace no recupero el sector indicado por data_directory.", dock, workspace)
		return
	var recovered := workspace.get_node_or_null("SectorContent") as Node3D
	if recovered == null or recovered.get_node_or_null("Rocks/RecoveredWorkspaceRock") == null:
		_fail("Se perdio el contenido sin coordenadas durante la recuperacion.", dock, workspace)
		return
	if workspace.get_node_or_null("OceanPreview") != misplaced_ocean or recovered.find_child("OceanPreview", true, false) != null:
		_fail("La infraestructura mal ubicada no volvio a la raiz del workspace.", dock, workspace)
		return
	if recovered.get_node_or_null("Props/ShipDeckSurface") == null:
		_fail("La recuperacion sobrescribio el contenido artesanal que ya existia.", dock, workspace)
		return
	if recovered.owner != workspace or recovered.get_node("Rocks").owner != workspace:
		_fail("SectorContent sigue oculto como un unico bloque no editable.", dock, workspace)
		return
	if recovered.get_node("Rocks/RecoveredWorkspaceRock").owner != workspace:
		_fail("Los objetos recuperados no quedaron visibles en el arbol del workspace.", dock, workspace)
		return
	if not fake_editor.marked_unsaved:
		_fail("La recuperacion no marco el workspace para guardado.", dock, workspace)
		return

	dock.free()
	workspace.free()
	print("PASS: el estado del workspace se recupera sin confundir sector seleccionado y cargado.")
	quit(0)


func _fail(message: String, dock: Node, workspace: Node) -> void:
	push_error(message)
	dock.free()
	workspace.free()
	quit(1)
