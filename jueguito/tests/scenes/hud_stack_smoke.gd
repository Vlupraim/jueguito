extends Node

const HUD_SCENE := preload("res://scenes/ui/gameplay_hud.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous: Dictionary = SettingsManager._settings.duplicate(true)
	var legacy := ConfigFile.new()
	legacy.set_value("hud", "action_left_scale", 0.65)
	legacy.set_value("hud", "action_center_scale", 1.5)
	SettingsManager._migrate_hud_scale(legacy)
	if not is_equal_approx(float(SettingsManager.get_setting("hud", "action_left_scale")), 1.0) \
	or not is_equal_approx(float(SettingsManager.get_setting("hud", "action_center_scale")), 1.25):
		_fail("La migracion no convierte el default ni conserva un tamano personalizado")
		return
	SettingsManager._settings = previous
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	hud.call("reset_hud_layout")
	var left := hud.find_child("ActionBar", true, false) as EditableHUDModule
	var center := hud.find_child("SignatureHubModule", true, false) as EditableHUDModule
	var stamina := hud.find_child("StaminaModule", true, false) as EditableHUDModule
	if not is_equal_approx(left.scale.x, 1.2) or not is_equal_approx(left.get_module_scale(), 1.0) \
	or stamina == null or not is_equal_approx(stamina.scale.x, 1.2):
		_fail("El antiguo 120% no es el nuevo default 100%")
		return
	left.global_position = Vector2(300, 400)
	center.global_position = Vector2(480, 400)
	hud.call("set_hud_edit_mode", true)
	center.bring_to_front()
	await _pointer(Vector2(320, 420), true)
	if not left._dragging or left.get_index() < center.get_index() or left.z_index <= center.z_index:
		_fail("Pulsar la parte visible no trae el modulo al frente")
		return
	await _pointer(Vector2(320, 420), false)
	await _pointer(Vector2(510, 430), true)
	if not left._dragging or center._dragging:
		_fail("El clic en la superposicion no pertenece al modulo de delante")
		return
	var before := left.global_position
	await _motion(Vector2(630, 480))
	if left.global_position.distance_to(before + Vector2(120, 50)) > 2.0:
		_fail("Arrastrar un modulo escalado desplaza una distancia incorrecta")
		return
	await _pointer(Vector2(630, 480), false)
	left.global_position = center.global_position
	if not left.get_global_rect().intersects(center.get_global_rect()):
		_fail("No se permite superponer modulos")
		return
	left.set_module_scale(1.15)
	left._save_layout()
	SettingsManager.load_settings()
	left._load_layout()
	if not is_equal_approx(left.get_module_scale(), 1.15) or not is_equal_approx(left.scale.x, 1.38) \
	or left.z_index <= center.z_index:
		_fail("El tamano o el orden no sobreviven a recargar ajustes")
		return
	hud.call("set_hud_edit_mode", false)
	var signature_button := hud.find_child("SignatureSlot1", true, false) as Button
	if signature_button.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("Finalizar la edicion no devuelve los clics a las habilidades")
		return
	print("HUD_STACK_SMOKE_OK default=100 old_scale=120 overlap=true click_front=true scaled_drag=true persisted=true")
	get_tree().quit(0)


func _pointer(point: Vector2, pressed: bool) -> void:
	await _motion(point)
	point = get_node("GameplayHUD/Screen").get_viewport_transform() * point
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame


func _motion(point: Vector2) -> void:
	point = get_node("GameplayHUD/Screen").get_viewport_transform() * point
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
	await get_tree().process_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
