extends Node

const BUILDER := preload("res://scripts/ui/local_map_texture_builder.gd")
const SURFACE := preload("res://data/terrain3d_exports/sector_27_30/surface_reference.png")
const HEIGHT := preload("res://data/terrain3d_exports/sector_27_30/height_preview.png")


func _ready() -> void:
	var texture: ImageTexture = BUILDER.build(SURFACE, HEIGHT)
	if texture == null:
		_fail("El generador no devolvio una textura")
		return
	var image := texture.get_image()
	if image == null or image.get_size() != Vector2i(512, 512):
		_fail("La carta local no conserva la resolucion 512x512")
		return
	var sampled_colors := {}
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			sampled_colors[image.get_pixel(x, y).to_html(false)] = true
	if sampled_colors.size() < 80:
		_fail("La carta sigue pareciendo una mascara plana sin pinceladas ni suavizado")
		return
	var texture_without_height: ImageTexture = BUILDER.build(SURFACE, null)
	var image_without_height := texture_without_height.get_image()
	for y in range(0, image.get_height(), 32):
		for x in range(0, image.get_width(), 32):
			if image.get_pixel(x, y) != image_without_height.get_pixel(x, y):
				_fail("La altura 3D sigue introduciendo relieve en la carta ilustrada")
				return
	print("LOCAL_MAP_TEXTURE_OK colors=", sampled_colors.size(), " size=", image.get_size())
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
