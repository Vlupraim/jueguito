extends Control

@onready var landing_view: VBoxContainer = %LandingView
@onready var login_view: VBoxContainer = %LoginView
@onready var credits_view: VBoxContainer = %CreditsView
@onready var options_menu: Control = %OptionsMenu
@onready var email_input: LineEdit = %EmailInput
@onready var password_input: LineEdit = %PasswordInput
@onready var show_password_check: CheckButton = %ShowPasswordCheck
@onready var remember_email_check: CheckButton = %RememberEmailCheck
@onready var login_button: Button = %LoginButton
@onready var status_label: Label = %StatusLabel
@onready var exit_confirmation: ConfirmationDialog = %ExitConfirmation


func _ready() -> void:
	%EnterButton.pressed.connect(_show_login)
	%OptionsButton.pressed.connect(func(): options_menu.call("open"))
	%CreditsButton.pressed.connect(func(): _show_view(credits_view))
	%ExitButton.pressed.connect(_request_exit)
	%LoginBackButton.pressed.connect(_show_landing)
	%CreditsBackButton.pressed.connect(_show_landing)
	login_button.pressed.connect(_on_login_pressed)
	email_input.text_submitted.connect(func(_text): password_input.grab_focus())
	password_input.text_submitted.connect(func(_text): _on_login_pressed())
	show_password_check.toggled.connect(func(show_password): password_input.secret = not show_password)
	exit_confirmation.confirmed.connect(func(): get_tree().quit())

	var remember_email := bool(SettingsManager.get_setting("general", "remember_email", false))
	remember_email_check.button_pressed = remember_email
	if remember_email:
		email_input.text = String(SettingsManager.get_setting("general", "remembered_email", ""))
	_show_landing()

	if not NetworkManager.login_completed.is_connected(_on_login_completed):
		NetworkManager.login_completed.connect(_on_login_completed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if options_menu.visible:
		options_menu.call("close")
	elif login_view.visible or credits_view.visible:
		_show_landing()
	else:
		_request_exit()
	get_viewport().set_input_as_handled()


func _show_view(view: Control) -> void:
	landing_view.visible = view == landing_view
	login_view.visible = view == login_view
	credits_view.visible = view == credits_view
	status_label.hide()


func _show_landing() -> void:
	_show_view(landing_view)
	%EnterButton.grab_focus()


func _show_login() -> void:
	_show_view(login_view)
	if email_input.text.is_empty():
		email_input.grab_focus()
	else:
		password_input.grab_focus()


func _request_exit() -> void:
	if bool(SettingsManager.get_setting("general", "confirm_exit", true)):
		exit_confirmation.popup_centered()
	else:
		get_tree().quit()


func _on_login_pressed() -> void:
	var account := email_input.text.strip_edges()
	var password := password_input.text
	if account.is_empty():
		_show_error("Escribe tu correo o nombre de cuenta.")
		email_input.grab_focus()
		return
	if password.is_empty():
		_show_error("Escribe tu contraseña.")
		password_input.grab_focus()
		return

	SettingsManager.set_setting("general", "remember_email", remember_email_check.button_pressed, false)
	SettingsManager.set_setting(
		"general",
		"remembered_email",
		account if remember_email_check.button_pressed else "",
		false
	)
	login_button.disabled = true
	login_button.text = "Conectando…"
	status_label.hide()
	GameManager.request_login(account, password)


func _on_login_completed(success: bool, error_msg: String) -> void:
	if success:
		return
	login_button.disabled = false
	login_button.text = "Ingresar"
	_show_error(error_msg if not error_msg.is_empty() else "No se pudo iniciar sesión.")


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.show()
