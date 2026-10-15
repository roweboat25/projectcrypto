class_name PlaceholderArt
## Pixel-art stand-ins drawn in code, used until real sprites arrive.

const OUTLINE := Color("1b2238")


## A 32x48 front-facing investigator: coat, hair and skin colors vary.
static func investigator(coat: Color, hair: Color, skin: Color, hat := false) -> ImageTexture:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pants := coat.darkened(0.55)
	_rect(img, 12, 36, 3, 10, pants)        # legs
	_rect(img, 17, 36, 3, 10, pants)
	_rect(img, 11, 45, 4, 2, OUTLINE)       # shoes
	_rect(img, 17, 45, 4, 2, OUTLINE)
	_rect(img, 9, 20, 14, 18, coat)         # coat body
	_rect(img, 7, 21, 3, 13, coat.darkened(0.15))   # arms
	_rect(img, 22, 21, 3, 13, coat.darkened(0.15))
	_rect(img, 7, 34, 3, 2, skin)           # hands
	_rect(img, 22, 34, 3, 2, skin)
	_rect(img, 15, 20, 2, 16, coat.darkened(0.3))   # coat opening
	_rect(img, 11, 7, 10, 12, skin)         # head
	_rect(img, 10, 5, 12, 5, hair)          # hair
	_rect(img, 10, 9, 2, 6, hair)
	_rect(img, 20, 9, 2, 6, hair)
	_rect(img, 13, 12, 2, 2, OUTLINE)       # eyes
	_rect(img, 17, 12, 2, 2, OUTLINE)
	if hat:
		_rect(img, 8, 5, 16, 2, coat.darkened(0.6))
		_rect(img, 11, 1, 10, 5, coat.darkened(0.6))
	_outline(img)
	return ImageTexture.create_from_image(img)


## A tall dark figure with two red eyes, for the title screen.
static func watcher() -> ImageTexture:
	var img := Image.create(48, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color("14121a")
	for y in range(8, 92):
		var half := int(clamp(6 + (y - 8) * 0.22, 6, 20))
		if y > 70:
			half = int(20 - (y - 70) * 0.5)
		_rect(img, 24 - half, y, half * 2, 1, body)
	_rect(img, 15, 30, 5, 3, Color("e0303c"))
	_rect(img, 28, 30, 5, 3, Color("e0303c"))
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


static func _outline(img: Image) -> void:
	var src := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and src.get_pixelv(p).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break
