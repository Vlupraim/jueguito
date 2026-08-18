@tool
extends SceneTree

const VARIANTS := [
	{
		"source": "res://assets/environment/terrain/textures/stylized/terrain_slots/02_pasto.png",
		"output": "res://assets/environment/terrain/textures/stylized/terrain_slots/06_pasto_sombrio.png",
		"value_scale": 0.62,
		"saturation_scale": 0.72,
		"cool_tint": Color(0.92, 0.97, 1.0, 1.0),
	},
	{
		"source": "res://assets/environment/terrain/textures/stylized/curated_ground/vegetacion_humedad/pasto_con_rocas_dispersas_070.png",
		"output": "res://assets/environment/terrain/textures/stylized/terrain_slots/23_pasto_rocas_sombrio.png",
		"value_scale": 0.68,
		"saturation_scale": 0.78,
		"cool_tint": Color(0.94, 0.97, 1.0, 1.0),
	},
]


func _initialize() -> void:
	for variant in VARIANTS:
		var source_path := str(variant.source)
		var output_path := str(variant.output)
		var source := load(source_path) as Texture2D
		if source == null:
			printerr("DARK_GRASS_TEXTURE_ERROR no se pudo cargar " + source_path)
			quit(2)
			return
		var image := source.get_image()
		if image == null or image.is_empty():
			printerr("DARK_GRASS_TEXTURE_ERROR imagen vacia " + source_path)
			quit(3)
			return
		# Terrain3D construye un Texture2DArray y exige que todos los albedos
		# compartan formato. La biblioteca existente usa RGB8 (sin alfa).
		image.convert(Image.FORMAT_RGB8)
		var value_scale := float(variant.value_scale)
		var saturation_scale := float(variant.saturation_scale)
		var cool_tint := variant.cool_tint as Color
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var source_color := image.get_pixel(x, y)
				var dark := Color.from_hsv(
					source_color.h,
					clampf(source_color.s * saturation_scale, 0.0, 1.0),
					clampf(source_color.v * value_scale, 0.0, 1.0),
					source_color.a
				)
				dark.r *= cool_tint.r
				dark.g *= cool_tint.g
				dark.b *= cool_tint.b
				image.set_pixel(x, y, dark)
		var error := image.save_png(ProjectSettings.globalize_path(output_path))
		if error != OK:
			printerr("DARK_GRASS_TEXTURE_ERROR " + error_string(error) + " en " + output_path)
			quit(4)
			return
		print("DARK_GRASS_TEXTURE_WRITTEN source=%s output=%s size=%s" % [source_path, output_path, str(image.get_size())])
	print("DARK_GRASS_TEXTURES_OK count=%d" % VARIANTS.size())
	quit(0)
