@tool
extends RefCounted

const ASSETS := "res://assets/environment/terrain/jueguito_terrain_assets.tres"

static func refresh(terrain: Terrain3D) -> bool:
	if terrain == null: return false
	var assets := terrain.assets
	var needs_assignment := assets == null or assets.get_texture_count() == 0
	if needs_assignment:
		assets = ResourceLoader.load(ASSETS, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Terrain3DAssets
	if assets == null: return false
	# Capture BEFORE assignment: the native binding can clear the shared list.
	var textures := assets.texture_list.duplicate()
	if textures.is_empty(): return false
	if needs_assignment: terrain.assets = assets
	for index in range(textures.size()): assets.set_texture(index, textures[index])
	if terrain.material != null: terrain.material.show_checkered = false
	return assets.get_texture_count() == textures.size()
