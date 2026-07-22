extends Control

signal closed

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

@onready var tabs: TabContainer = %SettingsTabs
@onready var language_option: OptionButton = %LanguageOption
@onready var tutorial_hints_check: CheckButton = %TutorialHintsCheck
@onready var confirm_exit_check: CheckButton = %ConfirmExitCheck
@onready var ui_scale_slider: HSlider = %UIScaleSlider
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_option: OptionButton = %VsyncOption
@onready var fps_option: OptionButton = %FpsOption
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var ambience_slider: HSlider = %AmbienceSlider
@onready var ui_slider: HSlider = %UISlider
@onready var voice_slider: HSlider = %VoiceSlider
@onready var camera_sensitivity_slider: HSlider = %CameraSensitivitySlider
@onready var zoom_speed_slider: HSlider = %ZoomSpeedSlider
@onready var colorblind_option: OptionButton = %ColorblindOption
@onready var colorblind_intensity_slider: HSlider = %ColorblindIntensitySlider
@onready var text_scale_slider: HSlider = %TextScaleSlider
@onready var reduce_motion_check: CheckButton = %ReduceMotionCheck
@onready var camera_shake_check: CheckButton = %CameraShakeCheck

var _loading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_options()
	_connect_controls()
	_refresh_controls()


func open(initial_tab := 0) -> void:
	_refresh_controls()
	tabs.current_tab = clampi(initial_tab, 0, tabs.get_tab_count() - 1)
	show()
	%CloseOptionsButton.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _populate_options() -> void:
	_add_options(language_option, ["Español", "English"])
	_add_options(window_mode_option, ["Ventana", "Pantalla completa", "Pantalla completa exclusiva"])
	for resolution in RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
	_add_options(vsync_option, ["Desactivado", "Activado", "Adaptativo"])
	_add_options(fps_option, ["30", "60", "120", "144", "Sin límite"])
	_add_options(colorblind_option, ["Desactivado", "Protanopia", "Deuteranopia", "Tritanopia"])


func _add_options(control: OptionButton, labels: Array[String]) -> void:
	for label in labels:
		control.add_item(label)


func _connect_controls() -> void:
	%CloseOptionsButton.pressed.connect(close)
	%ResetSettingsButton.pressed.connect(_reset_settings)
	%ApplyVideoButton.pressed.connect(func(): SettingsManager.apply_section("video"))
	language_option.item_selected.connect(func(index): _write_setting("general", "language", ["es", "en"][index]))
	tutorial_hints_check.toggled.connect(func(value): _write_setting("general", "tutorial_hints", value))
	confirm_exit_check.toggled.connect(func(value): _write_setting("general", "confirm_exit", value))
	ui_scale_slider.value_changed.connect(func(value): _write_setting("general", "ui_scale", value))
	window_mode_option.item_selected.connect(func(index): _write_setting("video", "window_mode", index, false))
	resolution_option.item_selected.connect(func(index): _write_setting("video", "resolution", RESOLUTIONS[index], false))
	vsync_option.item_selected.connect(func(index): _write_setting("video", "vsync", index, false))
	fps_option.item_selected.connect(func(index): _write_setting("video", "max_fps", [30, 60, 120, 144, 0][index], false))
	_bind_slider(master_slider, "audio", "master")
	_bind_slider(music_slider, "audio", "music")
	_bind_slider(sfx_slider, "audio", "sfx")
	_bind_slider(ambience_slider, "audio", "ambience")
	_bind_slider(ui_slider, "audio", "ui")
	_bind_slider(voice_slider, "audio", "voice")
	_bind_slider(camera_sensitivity_slider, "controls", "camera_sensitivity")
	_bind_slider(zoom_speed_slider, "controls", "zoom_speed")
	colorblind_option.item_selected.connect(func(index): _write_setting("accessibility", "colorblind_mode", index))
	_bind_slider(colorblind_intensity_slider, "accessibility", "colorblind_intensity")
	_bind_slider(text_scale_slider, "accessibility", "text_scale")
	reduce_motion_check.toggled.connect(func(value): _write_setting("accessibility", "reduce_camera_motion", value))
	camera_shake_check.toggled.connect(func(value): _write_setting("accessibility", "camera_shake", value))


func _bind_slider(control: HSlider, section: String, key: String) -> void:
	control.value_changed.connect(func(value): _write_setting(section, key, value))


func _write_setting(section: String, key: String, value: Variant, apply_immediately := true) -> void:
	if _loading:
		return
	SettingsManager.set_setting(section, key, value, apply_immediately)


func _refresh_controls() -> void:
	_loading = true
	language_option.select(0 if SettingsManager.get_setting("general", "language", "es") == "es" else 1)
	tutorial_hints_check.button_pressed = bool(SettingsManager.get_setting("general", "tutorial_hints", true))
	confirm_exit_check.button_pressed = bool(SettingsManager.get_setting("general", "confirm_exit", true))
	ui_scale_slider.value = float(SettingsManager.get_setting("general", "ui_scale", 1.0))
	window_mode_option.select(int(SettingsManager.get_setting("video", "window_mode", 0)))
	_select_resolution(SettingsManager.get_setting("video", "resolution", Vector2i(1280, 720)))
	vsync_option.select(int(SettingsManager.get_setting("video", "vsync", 1)))
	var fps_values := [30, 60, 120, 144, 0]
	fps_option.select(maxi(0, fps_values.find(int(SettingsManager.get_setting("video", "max_fps", 60)))))
	master_slider.value = float(SettingsManager.get_setting("audio", "master", 1.0))
	music_slider.value = float(SettingsManager.get_setting("audio", "music", 0.8))
	sfx_slider.value = float(SettingsManager.get_setting("audio", "sfx", 1.0))
	ambience_slider.value = float(SettingsManager.get_setting("audio", "ambience", 0.8))
	ui_slider.value = float(SettingsManager.get_setting("audio", "ui", 1.0))
	voice_slider.value = float(SettingsManager.get_setting("audio", "voice", 1.0))
	camera_sensitivity_slider.value = float(SettingsManager.get_setting("controls", "camera_sensitivity", 1.0))
	zoom_speed_slider.value = float(SettingsManager.get_setting("controls", "zoom_speed", 1.0))
	colorblind_option.select(int(SettingsManager.get_setting("accessibility", "colorblind_mode", 0)))
	colorblind_intensity_slider.value = float(SettingsManager.get_setting("accessibility", "colorblind_intensity", 1.0))
	text_scale_slider.value = float(SettingsManager.get_setting("accessibility", "text_scale", 1.0))
	reduce_motion_check.button_pressed = bool(SettingsManager.get_setting("accessibility", "reduce_camera_motion", false))
	camera_shake_check.button_pressed = bool(SettingsManager.get_setting("accessibility", "camera_shake", true))
	_loading = false


func _select_resolution(value: Vector2i) -> void:
	var index := RESOLUTIONS.find(value)
	resolution_option.select(maxi(index, 0))


func _reset_settings() -> void:
	SettingsManager.reset_all()
	_refresh_controls()
