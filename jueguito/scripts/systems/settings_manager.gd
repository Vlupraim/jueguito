extends Node

signal setting_changed(section: String, key: String, value: Variant)
signal settings_reset

const CONFIG_PATH := "user://settings.cfg"
const SETTINGS_VERSION := 4
const LEGACY_HUD_POSITIONS := {
	"character_status_position": Vector2(0.018, 0.94),
	"action_bar_position": Vector2(0.5, 0.98),
	"minimap_position": Vector2(0.985, 0.94),
}
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
		"window_mode": 1,
		"resolution": Vector2i(1920, 1080),
		"vsync": 1,
		"max_fps": 60,
		"world_detail": 1
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
		"zoom_speed": 1.0,
		"camera_pitch": -15.0,
		"invert_camera_y": false,
		"camera_locked": true
	},
	"map": {
		"marker_color": Color("f3cf55"),
		"tilt": 0.9,
		"minimap_zoom": 1.0
	},
	"hud": {
		"character_status_position": Vector2(0.5, 1.0),
		"character_status_scale": 1.0,
		"action_bar_position": Vector2(0.5, 1.0),
		"action_bar_scale": 1.0,
		"minimap_position": Vector2(1.0, 0.0),
		"minimap_scale": 1.0,
		"currency_position": Vector2(0.5, 0.0),
		"currency_scale": 1.0,
		"action_left_position": Vector2(0.5, 1.0),
		"action_left_scale": 1.0,
		"action_center_position": Vector2(0.5, 1.0),
		"action_center_scale": 1.0,
		"action_right_position": Vector2(0.5, 1.0),
		"action_right_scale": 1.0,
		"stamina_position": Vector2(0.5, 1.0),
		"stamina_scale": 1.0,
		"module_order": ["character_status", "action_left", "action_center", "action_right", "stamina", "minimap", "currency"]
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
	var loaded_version := int(config.get_value("meta", "version", 0))
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			(_settings[section] as Dictionary)[key] = config.get_value(
				section,
				key,
				DEFAULTS[section][key]
			)
	_migrate_legacy_hud_positions()
	_migrate_video_defaults(loaded_version)
	if loaded_version < 3:
		_settings["controls"]["camera_pitch"] = -15.0
	if loaded_version < 4:
		_migrate_hud_scale(config)
	if loaded_version < SETTINGS_VERSION:
		save_settings()


func _migrate_hud_scale(config: ConfigFile) -> void:
	for key: String in DEFAULTS["hud"]:
		if not key.ends_with("_scale") or not config.has_section_key("hud", key):
			continue
		var previous := float(config.get_value("hud", key))
		var old_default := 0.65 if key in ["action_left_scale", "action_center_scale", "action_right_scale"] else 1.0
		# El default anterior pasa al nuevo 100%; los tamanos personalizados
		# conservan su dimension visual y solo cambian de porcentaje.
		_settings["hud"][key] = 1.0 if is_equal_approx(previous, old_default) else previous / 1.2


func _migrate_video_defaults(loaded_version: int) -> void:
	if loaded_version >= 2:
		return
	var video := _settings["video"] as Dictionary
	# La version anterior no tenia una resolucion interna de referencia coherente.
	# Esta migracion ocurre una sola vez; elecciones posteriores se conservan.
	video["window_mode"] = 1
	video["resolution"] = Vector2i(1920, 1080)


func _migrate_legacy_hud_positions() -> void:
	var hud_settings := _settings["hud"] as Dictionary
	var hud_defaults := DEFAULTS["hud"] as Dictionary
	for key in LEGACY_HUD_POSITIONS:
		if hud_settings.get(key) == LEGACY_HUD_POSITIONS[key]:
			hud_settings[key] = hud_defaults[key]


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", SETTINGS_VERSION)
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

	var window_mode := int(get_setting("video", "window_mode", 1))
	var resolution: Vector2i = get_setting("video", "resolution", Vector2i(1920, 1080))
	match window_mode:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
			var screen := DisplayServer.window_get_current_screen()
			var usable_rect := DisplayServer.screen_get_usable_rect(screen)
			var centered := usable_rect.position + (usable_rect.size - resolution) / 2
			DisplayServer.window_set_position(centered)


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
