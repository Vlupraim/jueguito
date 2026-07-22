extends Node

signal setting_changed(section: String, key: String, value: Variant)
signal settings_reset

const CONFIG_PATH := "user://settings.cfg"
const DEFAULTS := {
	"general": {
		"language": "es",
		"tutorial_hints": true,
		"confirm_exit": true,
		"ui_scale": 1.0,
		"remember_email": false,
		"remembered_email": ""
	},
	"video": {
		"window_mode": 0,
		"resolution": Vector2i(1280, 720),
		"vsync": 1,
		"max_fps": 60
	},
	"audio": {
		"master": 1.0,
		"music": 0.8,
		"sfx": 1.0,
		"ambience": 0.8,
		"ui": 1.0,
		"voice": 1.0
	},
	"controls": {
		"camera_sensitivity": 1.0,
		"zoom_speed": 1.0
	},
	"accessibility": {
		"colorblind_mode": 0,
		"colorblind_intensity": 1.0,
		"text_scale": 1.0,
		"reduce_camera_motion": false,
		"camera_shake": true
	}
}

var _settings: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	load_settings()
	apply_all()


func get_setting(section: String, key: String, fallback: Variant = null) -> Variant:
	if not _settings.has(section):
		return fallback
	return (_settings[section] as Dictionary).get(key, fallback)


func set_setting(section: String, key: String, value: Variant, apply_immediately := true) -> void:
	if not _settings.has(section):
		_settings[section] = {}
	(_settings[section] as Dictionary)[key] = value
	if apply_immediately:
		apply_section(section)
	save_settings()
	setting_changed.emit(section, key, value)


func load_settings() -> void:
	_settings = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			(_settings[section] as Dictionary)[key] = config.get_value(
				section,
				key,
				DEFAULTS[section][key]
			)


func save_settings() -> void:
	var config := ConfigFile.new()
	for section in _settings:
		for key in _settings[section]:
			config.set_value(section, key, _settings[section][key])
	var error := config.save(CONFIG_PATH)
	if error != OK:
		push_warning("No se pudieron guardar los ajustes: %s" % error_string(error))


func reset_all() -> void:
	_settings = DEFAULTS.duplicate(true)
	apply_all()
	save_settings()
	settings_reset.emit()


func apply_all() -> void:
	for section in ["general", "video", "audio"]:
		apply_section(section)


func apply_section(section: String) -> void:
	match section:
		"general":
			TranslationServer.set_locale(String(get_setting("general", "language", "es")))
		"video":
			_apply_video()
		"audio":
			_apply_audio()


func _apply_video() -> void:
	Engine.max_fps = int(get_setting("video", "max_fps", 60))
	DisplayServer.window_set_vsync_mode(
		int(get_setting("video", "vsync", DisplayServer.VSYNC_ENABLED)) as DisplayServer.VSyncMode
	)
	if DisplayServer.get_name().to_lower() == "headless":
		return

	var window_mode := int(get_setting("video", "window_mode", 0))
	match window_mode:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var resolution: Vector2i = get_setting("video", "resolution", Vector2i(1280, 720))
			DisplayServer.window_set_size(resolution)


func _apply_audio() -> void:
	var bus_settings := {
		"Master": "master",
		"Music": "music",
		"SFX": "sfx",
		"Ambience": "ambience",
		"UI": "ui",
		"Voice": "voice"
	}
	for bus_name in bus_settings:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			AudioServer.add_bus()
			bus_index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus_index, bus_name)
		var linear_value := float(get_setting("audio", bus_settings[bus_name], 1.0))
		AudioServer.set_bus_mute(bus_index, linear_value <= 0.001)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_value, 0.001)))
