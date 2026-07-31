extends RefCounted

# Convierte las mascaras tecnicas del export en una carta local continua. La
# geometria jugable no cambia: el suavizado existe solo en la representacion.

const REFERENCE_WATER := Color8(31, 91, 160)
const REFERENCE_SAND := Color8(212, 187, 122)
const REFERENCE_LAND := Color8(70, 134, 63)

const INK := Color("342f28")
const COAST_INK := Color("4a5148")
const WATER := Color("416873")
const WATER_LIGHT := Color("63828a")
const WATER_DARK := Color("31545f")
const SAND := Color("bea677")
const SAND_LIGHT := Color("d0bb8e")
const SAND_DARK := Color("9f875e")
const LAND := Color("647452")
const LAND_LIGHT := Color("7f8b63")
const LAND_DARK := Color("4f6043")


static func build(surface_texture: Texture2D, _height_texture: Texture2D) -> ImageTexture:
	if surface_texture == null:
		return null
	var surface := surface_texture.get_image()
	if surface == null or surface.is_empty():
		return null
	# El suavizado redimensiona su copia de trabajo. Nunca debe alterar la imagen
	# importada compartida, porque otras cartas pueden reutilizar la textura.
	surface = surface.duplicate() as Image
	if surface.is_compressed():
		surface.decompress()
	surface.convert(Image.FORMAT_RGBA8)

	var target_size := surface.get_size()
	# Las tres superficies se convierten primero en mascaras y se difuminan con
	# una campana gaussiana. El contorno resultante es curvo incluso cuando la
	# fuente fue pintada sobre celdas grandes y ortogonales.
	var surface_mask := _build_smoothed_surface_mask(surface, target_size)

	var output := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	for y in range(target_size.y):
		for x in range(target_size.x):
			var mask_color := surface_mask.get_pixel(x, y)
			# Reafirmar la separacion cromatica despues del blur mantiene la curva
			# organica, pero evita que playa y agua parezcan una mancha desenfocada.
			var weights := Vector3(
				pow(mask_color.r, 8.0),
				pow(mask_color.g, 8.0),
				pow(mask_color.b, 8.0)
			)
			weights /= maxf(weights.x + weights.y + weights.z, 0.0001)
			var water_weight: float = weights.x
			var sand_weight: float = weights.y
			var land_weight: float = weights.z
			var map_color := WATER * water_weight + SAND * sand_weight + LAND * land_weight

			# Lavados y pinceladas dependen solo del papel, nunca de la altura 3D.
			# Esto evita que el mar parezca una capa elevada sobre la playa.
			var broad_wash := (
				sin(float(x) * 0.021 + sin(float(y) * 0.013) * 1.7)
				+ sin(float(y) * 0.026 - float(x) * 0.008)
			) * 0.25
			var water_brush := (
				sin(float(y) * 0.105 + sin(float(x) * 0.018) * 2.1)
				+ sin(float(y) * 0.047 + float(x) * 0.012)
			) * 0.25 + broad_wash
			var sand_brush := (
				sin(float(x) * 0.062 + float(y) * 0.019)
				+ sin(float(x) * 0.025 - float(y) * 0.041)
			) * 0.25 + broad_wash
			var land_brush := (
				sin(float(x) * 0.044 + sin(float(y) * 0.031) * 2.4)
				+ sin(float(y) * 0.058 - float(x) * 0.017)
			) * 0.25 + broad_wash
			map_color = map_color.lerp(
				WATER_LIGHT if water_brush >= 0.0 else WATER_DARK,
				absf(water_brush) * 0.28 * water_weight
			)
			map_color = map_color.lerp(
				SAND_LIGHT if sand_brush >= 0.0 else SAND_DARK,
				absf(sand_brush) * 0.24 * sand_weight
			)
			map_color = map_color.lerp(
				LAND_LIGHT if land_brush >= 0.0 else LAND_DARK,
				absf(land_brush) * 0.30 * land_weight
			)

			# Marcas de cerdas: bandas largas en agua, barrido seco en arena y
			# manchas cruzadas en vegetacion. Son pigmento plano, no iluminacion.
			var water_brush_mark := pow(absf(sin(
				float(y) * 0.112 + sin(float(x) * 0.014) * 2.8
			)), 12.0) * water_weight
			map_color = map_color.lerp(WATER_LIGHT, water_brush_mark * 0.13)
			var sand_brush_mark := pow(absf(sin(
				float(x) * 0.083 + float(y) * 0.027 + sin(float(y) * 0.016)
			)), 14.0) * sand_weight
			map_color = map_color.lerp(SAND_LIGHT, sand_brush_mark * 0.10)
			var land_brush_mark := pow(maxf(
				sin(float(x) * 0.061 + sin(float(y) * 0.022) * 2.0)
				* sin(float(y) * 0.049 - float(x) * 0.013),
				0.0
			), 3.0) * land_weight
			map_color = map_color.lerp(LAND_LIGHT, land_brush_mark * 0.17)

			# Tinta plana y continua en la costa. Al estar centrada sobre ambos lados
			# funciona como dibujo de contorno, no como luz/sombra o escalon elevado.
			var shoreline := exp(-pow((water_weight - 0.5) * 8.5, 2.0))
			map_color = map_color.lerp(COAST_INK, shoreline * 0.58)
			var vegetation_edge := exp(-pow((land_weight - 0.5) * 9.0, 2.0)) * (1.0 - water_weight)
			map_color = map_color.lerp(INK, vegetation_edge * 0.16)

			# Fibra leve de papel; las variaciones grandes vienen de las pinceladas.
			var grain_seed := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
			var grain := 0.982 + fposmod(grain_seed, 1.0) * 0.028
			map_color.r *= grain
			map_color.g *= grain
			map_color.b *= grain
			map_color.a = 1.0
			output.set_pixel(x, y, map_color)

	return ImageTexture.create_from_image(output)


static func _build_smoothed_surface_mask(surface: Image, target_size: Vector2i) -> Image:
	var mask_size := Vector2i(
		maxi(target_size.x / 4, 64),
		maxi(target_size.y / 4, 64)
	)
	surface.resize(mask_size.x, mask_size.y, Image.INTERPOLATE_LANCZOS)
	var weights := PackedVector3Array()
	weights.resize(mask_size.x * mask_size.y)
	for y in range(mask_size.y):
		for x in range(mask_size.x):
			weights[y * mask_size.x + x] = _nearest_surface(surface.get_pixel(x, y))
	weights = _gaussian_blur_mask(weights, mask_size.x, mask_size.y, 10, 6.5)

	var mask_image := Image.create(mask_size.x, mask_size.y, false, Image.FORMAT_RGBF)
	for y in range(mask_size.y):
		for x in range(mask_size.x):
			var value := weights[y * mask_size.x + x]
			var total := maxf(value.x + value.y + value.z, 0.0001)
			value /= total
			mask_image.set_pixel(x, y, Color(value.x, value.y, value.z, 1.0))
	mask_image.resize(target_size.x, target_size.y, Image.INTERPOLATE_CUBIC)
	return mask_image


static func _gaussian_blur_mask(
	source: PackedVector3Array,
	width: int,
	height: int,
	radius: int,
	sigma: float
) -> PackedVector3Array:
	var kernel := PackedFloat32Array()
	kernel.resize(radius * 2 + 1)
	var kernel_total := 0.0
	for offset in range(-radius, radius + 1):
		var weight := exp(-float(offset * offset) / (2.0 * sigma * sigma))
		kernel[offset + radius] = weight
		kernel_total += weight
	for index in range(kernel.size()):
		kernel[index] /= kernel_total

	var horizontal := PackedVector3Array()
	horizontal.resize(width * height)
	for y in range(height):
		for x in range(width):
			var value := Vector3.ZERO
			for offset in range(-radius, radius + 1):
				var sample_x := clampi(x + offset, 0, width - 1)
				value += source[y * width + sample_x] * kernel[offset + radius]
			horizontal[y * width + x] = value

	var blurred := PackedVector3Array()
	blurred.resize(width * height)
	for y in range(height):
		for x in range(width):
			var value := Vector3.ZERO
			for offset in range(-radius, radius + 1):
				var sample_y := clampi(y + offset, 0, height - 1)
				value += horizontal[sample_y * width + x] * kernel[offset + radius]
			blurred[y * width + x] = value
	return blurred


static func _nearest_surface(color: Color) -> Vector3:
	var water_distance := _color_distance_squared(color, REFERENCE_WATER)
	var sand_distance := _color_distance_squared(color, REFERENCE_SAND)
	var land_distance := _color_distance_squared(color, REFERENCE_LAND)
	if water_distance <= sand_distance and water_distance <= land_distance:
		return Vector3(1.0, 0.0, 0.0)
	if sand_distance <= land_distance:
		return Vector3(0.0, 1.0, 0.0)
	return Vector3(0.0, 0.0, 1.0)


static func _color_distance_squared(a: Color, b: Color) -> float:
	var delta := Vector3(a.r - b.r, a.g - b.g, a.b - b.b)
	return delta.length_squared()
