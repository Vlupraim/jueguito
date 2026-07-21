extends Control

@onready var username_input: LineEdit = %UsernameInput
@onready var login_button: Button = %LoginButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	login_button.pressed.connect(_on_login_pressed)
	username_input.text_submitted.connect(func(_text): _on_login_pressed())
	username_input.grab_focus()
	
	# Escuchar fallo de conexión
	NetworkManager.login_completed.connect(func(success, error_msg):
		if not success:
			login_button.disabled = false
			login_button.text = "Iniciar Aventura"
			status_label.text = error_msg
			status_label.show()
	)

func _on_login_pressed() -> void:
	var username := username_input.text.strip_edges()
	if username == "":
		status_label.text = "Escribe un nombre de usuario"
		status_label.show()
		return
		
	login_button.disabled = true
	login_button.text = "Conectando al Servidor..."
	status_label.hide()
	
	GameManager.request_login(username)
