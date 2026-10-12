extends VBoxContainer

@onready var address: LineEdit = $Address
@onready var port: SpinBox = $Port
@onready var nickname: LineEdit = $Nickname
@onready var key: LineEdit = $Key
@onready var status: Label = $Status
@onready var connect_button: Button = $Connect

func _ready() -> void:
	address.text = str(SettingsManager.get_setting("network","address","127.0.0.1"))
	nickname.text = str(SettingsManager.get_setting("network","nickname","Náufrago"))
	port.value = int(SettingsManager.get_setting("network","port",7777))
	status.text = CoopSession.status
	CoopSession.status_changed.connect(_status_changed)
	connect_button.pressed.connect(_connect)
	key.text_submitted.connect(func(_text): _connect())
	$Back.pressed.connect(func(): CoopSession.leave())

func _connect() -> void:
	SettingsManager.set_setting("network","address",address.text)
	SettingsManager.set_setting("network","nickname",nickname.text)
	SettingsManager.set_setting("network","port",int(port.value))
	CoopSession.join(address.text,int(port.value),nickname.text,key.text)
	connect_button.disabled = CoopSession.connecting

func _status_changed(message: String) -> void:
	status.text = message
	connect_button.disabled = CoopSession.connecting
	connect_button.text = "Conectando…" if CoopSession.connecting else "Entrar a la costa"
