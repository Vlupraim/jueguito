extends SceneTree

const SELECTOR_SCENE := "res://scenes/ui/character_selection_3d.tscn"
const EXPECTED_MODELS := 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SELECTOR_SCENE) as PackedScene
	if packed == null:
		_fail("No se pudo cargar el selector 3D")
		return
	var selector := packed.instantiate()
	root.add_child(selector)
	await process_frame
	await process_frame

	var option := selector.find_child("ModelOptionButton", true, false) as OptionButton
	if option == null or option.item_count != EXPECTED_MODELS:
		_fail("El selector no expone solamente el Strongman")
		return

	for index in range(EXPECTED_MODELS):
		selector.call("_on_model_item_selected", index)
		await process_frame
		await process_frame
		var character := selector.get("current_spawned_character") as Node3D
		var animation_player := selector.get("current_animation_player") as AnimationPlayer
		if character == null or animation_player == null:
			_fail("No se instancio cuerpo/AnimationPlayer en indice %d" % index)
			return
		if not animation_player.has_animation(&"shared/idle"):
			_fail("El cuerpo %d no recibio shared/idle" % index)
			return
		print(
			"CHARACTER_SELECTOR_MODEL_OK index=", index,
			" label=", option.get_item_text(index),
			" node=", character.name
		)

	selector.queue_free()
	await process_frame
	print("CHARACTER_SELECTION_3D_SMOKE_OK models=", EXPECTED_MODELS)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
