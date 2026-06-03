extends RefCounted

const MAX_TEXTURE_SIZE := 2048


static func load_from_path(path: String) -> Texture2D:
	if path.is_empty():
		return null

	var image: Image = Image.new()
	var load_err: Error = image.load(path)
	if load_err == OK and not image.is_empty():
		return from_image(image)

	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return clamp_texture(loaded as Texture2D)
		if loaded is Image:
			return from_image(loaded as Image)
	return null


static func clamp_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return texture
	return from_image(image)


static func from_image(image: Image) -> Texture2D:
	if image == null or image.is_empty():
		return null
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0:
		return null
	if width <= MAX_TEXTURE_SIZE and height <= MAX_TEXTURE_SIZE:
		return ImageTexture.create_from_image(image)

	var scale: float = minf(
		float(MAX_TEXTURE_SIZE) / float(width),
		float(MAX_TEXTURE_SIZE) / float(height)
	)
	var copy: Image = image.duplicate()
	copy.resize(
		maxi(1, int(width * scale)),
		maxi(1, int(height * scale)),
		Image.INTERPOLATE_LANCZOS
	)
	return ImageTexture.create_from_image(copy)
