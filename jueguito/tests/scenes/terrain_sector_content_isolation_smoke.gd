extends SceneTree

const DOCK_SCRIPT := preload("res://addons/jueguito_terrain_tools/terrain_map_dock.gd")
const TEST_SECTOR := Vector2i(12, 34)


func _init() -> void:
	var dock = DOCK_SCRIPT.new()
	var legacy_prepared: Dictionary = dock.call("_prepare_sector_content", Vector2i(27, 30))
	if not bool(legacy_prepared.get("ok", false)):
		_fail("No se pudo normalizar la escena artesanal existente: " + str(legacy_prepared.get("message", "")), dock, Node3D.new())
		return
	var legacy_content := legacy_prepared.get("node") as Node3D
	if legacy_content == null or legacy_content.get_node("Props").get_child_count() == 0:
		if legacy_content != null:
			legacy_content.free()
		_fail("La escena heredada no se migro a las categorias predeterminadas.", dock, Node3D.new())
		return
	var unassigned := dock.call("_create_empty_sector_content", Vector2i(27, 30)) as Node3D
	var recovered_rock := Node3D.new()
	recovered_rock.name = "RecoveredRock"
	unassigned.get_node("Rocks").add_child(recovered_rock)
	recovered_rock.owner = unassigned
	dock.call("_merge_sector_content_nodes", unassigned, legacy_content, Vector2i(27, 30))
	if legacy_content.get_node_or_null("Rocks/RecoveredRock") == null or legacy_content.get_node("Props").get_child_count() == 0:
		unassigned.free()
		legacy_content.free()
		_fail("La recuperacion no conservo simultaneamente contenido nuevo y artesanal previo.", dock, Node3D.new())
		return
	unassigned.free()
	legacy_content.free()

	var workspace := Node3D.new()
	workspace.name = "Terrain3DSectorWorkspace"
	var content := dock.call("_create_empty_sector_content", TEST_SECTOR) as Node3D
	workspace.add_child(content)
	content.owner = workspace

	var rocks := content.get_node("Rocks")
	var rock := Node3D.new()
	rock.name = "TestRock"
	rocks.add_child(rock)
	rock.owner = workspace
	dock.call("_make_sector_content_editable", content, workspace)
	if rocks.owner != workspace or rock.owner != workspace:
		_fail("La vista editable no promovio categorias y objetos al workspace.", dock, workspace)
		return

	var reassigned: Array[Node] = []
	dock.call("_collect_workspace_owned_content_nodes", content, workspace, reassigned)
	if reassigned.size() != 6 or not reassigned.has(rocks) or not reassigned.has(rock):
		_fail("No se detecto toda la jerarquia visible antes de empaquetar.", dock, workspace)
		return
	for node in reassigned:
		node.owner = content
	var packed := PackedScene.new()
	var pack_error := packed.pack(content)
	for node in reassigned:
		node.owner = workspace
	if pack_error != OK:
		_fail("PackedScene.pack fallo con error " + str(pack_error) + ".", dock, workspace)
		return

	var path := "res://.godot/terrain_sector_content_isolation_smoke.tscn"
	if ResourceSaver.save(packed, path) != OK:
		_fail("No se pudo guardar la escena temporal.", dock, workspace)
		return
	var expected_manifest: Array[String] = dock.call("_content_manifest", content)
	var result: Dictionary = dock.call("_validate_saved_content_scene", path, TEST_SECTOR, expected_manifest)
	if not bool(result.get("ok", false)):
		_fail(str(result.get("message", "Validacion desconocida.")), dock, workspace)
		return

	var loaded_packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var loaded := loaded_packed.instantiate()
	if loaded.get_node_or_null("Rocks/TestRock") == null:
		loaded.free()
		_fail("El objeto no reaparecio dentro de la categoria Rocks.", dock, workspace)
		return
	loaded.free()

	var other_content := dock.call("_create_empty_sector_content", Vector2i(13, 34)) as Node3D
	if other_content.find_child("TestRock", true, false) != null:
		other_content.free()
		_fail("Un sector nuevo heredo objetos de otro sector.", dock, workspace)
		return
	var forbidden := Node3D.new()
	forbidden.name = "Importer"
	other_content.get_node("Props").add_child(forbidden)
	forbidden.owner = other_content
	var forbidden_error: String = dock.call("_validate_sector_content", other_content, Vector2i(13, 34), true)
	other_content.free()
	if forbidden_error.is_empty():
		_fail("La validacion permitio guardar infraestructura dentro de SectorContent.", dock, workspace)
		return
	dock.free()
	workspace.free()
	print("PASS: SectorContent se empaqueta aislado, conserva categorias y valida coordenadas.")
	quit(0)


func _fail(message: String, dock: Node, workspace: Node) -> void:
	push_error(message)
	dock.free()
	workspace.free()
	quit(1)
