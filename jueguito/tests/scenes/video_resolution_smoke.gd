extends SceneTree


func _initialize() -> void:
	var viewport_width := int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	var startup_mode := int(ProjectSettings.get_setting("display/window/size/mode", -1))
	var stretch_aspect := str(ProjectSettings.get_setting("display/window/stretch/aspect", ""))
	if Vector2i(viewport_width, viewport_height) != Vector2i(1920, 1080):
		printerr("VIDEO_RESOLUTION_ERROR viewport=%dx%d" % [viewport_width, viewport_height])
		quit(2)
		return
	if startup_mode != 3:
		printerr("VIDEO_RESOLUTION_ERROR startup_mode=%d" % startup_mode)
		quit(3)
		return
	if stretch_aspect != "keep":
		printerr("VIDEO_RESOLUTION_ERROR stretch_aspect=%s" % stretch_aspect)
		quit(4)
		return
	var defaults: Dictionary = SettingsManager.DEFAULTS
	var video := defaults.get("video", {}) as Dictionary
	if int(video.get("window_mode", -1)) != 1 or video.get("resolution", Vector2i.ZERO) != Vector2i(1920, 1080):
		printerr("VIDEO_RESOLUTION_ERROR defaults=%s" % str(video))
		quit(5)
		return
	print("VIDEO_RESOLUTION_OK viewport=1920x1080 aspect=16:9 startup=fullscreen")
	quit(0)
