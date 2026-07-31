extends SceneTree

const WATER_LEVEL := 2.0


func _init() -> void:
	var exporter_script := load("res://scripts/tools/editor/terrain3d_sector_exporter.gd") as Script
	var exporter: RefCounted = exporter_script.new()
	exporter.call("_setup_noises", Vector2i(15, 6))

	var deep_open := float(exporter.call("_height_for", 0.5, 0.5, 4, 1, 0.0, 1.0))
	var water_open := float(exporter.call("_height_for", 0.5, 0.5, 2, 1, 0.0, 1.0))
	var deep_shore := float(exporter.call("_height_for", 0.5, 0.5, 4, 1, 1.0, 1.0))
	var water_shore := float(exporter.call("_height_for", 0.5, 0.5, 2, 1, 1.0, 1.0))
	var coast := float(exporter.call("_height_for", 0.5, 0.5, 3, 1, 1.0, 1.0))
	var beach := float(exporter.call("_height_for", 0.5, 0.5, 1, 1, 1.0, 1.0))

	var failures: Array[String] = []
	if not deep_open < water_open:
		failures.append("El fondo profundo no queda bajo el fondo de agua normal.")
	if not water_open < water_shore:
		failures.append("El fondo marino no asciende progresivamente hacia la orilla.")
	if not water_shore < WATER_LEVEL:
		failures.append("El fondo somero debe permanecer bajo el nivel del agua.")
	if not coast > WATER_LEVEL or not beach > WATER_LEVEL:
		failures.append("Costa y playa deben quedar sobre el nivel del agua.")
	if absf(deep_shore - water_shore) > 0.001:
		failures.append("Agua profunda y normal no convergen al mismo fondo somero.")
	if coast - water_shore > 4.0 or beach - water_shore > 4.0:
		failures.append("El salto vertical costero sigue siendo demasiado alto.")

	print("COASTAL_PROFILE=", {
		"deep_open": deep_open,
		"water_open": water_open,
		"shallow": water_shore,
		"coast": coast,
		"beach": beach,
	})
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	quit(0)
