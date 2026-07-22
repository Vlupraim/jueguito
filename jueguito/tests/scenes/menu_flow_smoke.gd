extends Node

const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := MAIN_MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame

	var landing := menu.find_child("LandingView", true, false) as Control
	var login := menu.find_child("LoginView", true, false) as Control
	var credits := menu.find_child("CreditsView", true, false) as Control
	var password := menu.find_child("PasswordInput", true, false) as LineEdit
	var options := menu.find_child("OptionsMenu", true, false) as Control
	if landing == null or login == null or credits == null or password == null or options == null:
		_fail("La portada no contiene todas sus vistas")
		return
	if not landing.visible or login.visible or credits.visible:
		_fail("La portada no inicia en la vista principal")
		return

	menu.call("_show_login")
	if landing.visible or not login.visible or not password.secret:
		_fail("Ingresar no abrio un formulario de login con contraseña oculta")
		return
	menu.call("_show_landing")
	menu.call("_show_view", credits)
	if not credits.visible or landing.visible:
		_fail("La navegacion hacia creditos no funciona")
		return

	options.call("open")
	var tabs := options.find_child("SettingsTabs", true, false) as TabContainer
	var resolution := options.find_child("ResolutionOption", true, false) as OptionButton
	if not options.visible or tabs == null or tabs.get_tab_count() != 5:
		_fail("Opciones no contiene las cinco pestañas definidas")
		return
	if resolution == null or resolution.item_count < 5:
		_fail("Resolucion no usa una lista desplegable con alternativas")
		return
	options.call("close")
	if options.visible:
		_fail("Opciones no se pudo cerrar")
		return

	menu.queue_free()
	await get_tree().process_frame
	print("MENU_FLOW_SMOKE_OK")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
