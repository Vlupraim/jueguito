@tool
extends SceneTree
const TARGET := "res://assets/environment/terrain/textures/natural_v1/"
const SIZE := 256
func _initialize() -> void:
	call_deferred("_run")
func field(noise: FastNoiseLite, x: float, y: float) -> float:
	var ax := x * TAU / SIZE
	var ay := y * TAU / SIZE
	return noise.get_noise_3d(sin(ax) * 80, cos(ax) * 80 + sin(ay) * 80, cos(ay) * 80)
func _run() -> void:
	for profile in [["fine", 0.30, 0.14, 0.96], ["earth", 0.18, 0.23, 0.91], ["stone", 0.11, 0.32, 0.87], ["grass", 0.22, 0.19, 0.97]]:
		var noise := FastNoiseLite.new()
		noise.seed = 721
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = profile[1]
		noise.fractal_octaves = 3
		var image := Image.create(SIZE, SIZE, true, Image.FORMAT_RGBA8)
		for y in range(SIZE):
			for x in range(SIZE):
				var dx: float = (field(noise, x + 1, y) - field(noise, x - 1, y)) * profile[2]
				var dy: float = (field(noise, x, y + 1) - field(noise, x, y - 1)) * profile[2]
				var n := Vector3(-dx, dy, 1).normalized()
				var roughness := clampf(profile[3] + field(noise, x, y) * 0.04, 0, 1)
				image.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, roughness))
		image.clear_mipmaps()
		image.save_png(TARGET + "micro_%s_normal_roughness.png" % profile[0])
	print("MICRO_NORMALS_AUTHORED_RGBA roughness=alpha mode=procedural_micrograin")
	quit()
