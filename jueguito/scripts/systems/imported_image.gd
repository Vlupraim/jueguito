extends RefCounted
class_name ImportedImage

# Runtime images live in the PCK as imported textures; raw source PNGs are absent.
static func read(path: String) -> Image:
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			var source := texture.get_image()
			if source != null:
				var image := source.duplicate() as Image
				if image.is_compressed() and image.decompress() != OK: return null
				return image
	if FileAccess.file_exists(path): return Image.load_from_file(path)
	return null
