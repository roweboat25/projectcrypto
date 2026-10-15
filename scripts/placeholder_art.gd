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


## A 4x3 sheet of 32x48 frames: columns face down, left, right, up;
## rows are idle, walk A, walk B. Used by Sprite3D with hframes=4, vframes=3.
static func investigator_sheet(coat: Color, hair: Color, skin: Color, hat := false) -> ImageTexture:
	var img := Image.create(128, 144, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for dir in 4:
		for step in 3:
			var frame := Image.create(32, 48, false, Image.FORMAT_RGBA8)
			frame.fill(Color(0, 0, 0, 0))
			_draw_body(frame, dir, step, coat, hair, skin, hat)
			_outline(frame)
			img.blit_rect(frame, Rect2i(0, 0, 32, 48), Vector2i(dir * 32, step * 48))
	return ImageTexture.create_from_image(img)


static func _draw_body(img: Image, dir: int, step: int, coat: Color, hair: Color, skin: Color, hat: bool) -> void:
	var pants := coat.darkened(0.55)
	var side := dir == 1 or dir == 2
	var lift_a := 2 if step == 1 else 0
	var lift_b := 2 if step == 2 else 0
	var bob := 1 if step != 0 else 0
	if side:
		var fwd := -1 if dir == 1 else 1
		_rect(img, 14 + fwd * (2 if step == 1 else 0), 36, 4, 10 - lift_a, pants)
		_rect(img, 14 - fwd * (2 if step == 2 else 0), 36, 4, 10 - lift_b, pants.darkened(0.2))
		_rect(img, 11, 20 + bob, 10, 18, coat)
		_rect(img, 14 + fwd * 2, 22 + bob, 3, 12, coat.darkened(0.2))
		_rect(img, 11, 7 + bob, 10, 12, skin)
		_rect(img, 10, 5 + bob, 12, 5, hair)
		if dir == 1:
			_rect(img, 17, 8 + bob, 4, 8, hair)
			_rect(img, 12, 12 + bob, 2, 2, OUTLINE)
		else:
			_rect(img, 11, 8 + bob, 4, 8, hair)
			_rect(img, 18, 12 + bob, 2, 2, OUTLINE)
	else:
		_rect(img, 12, 36, 3, 10 - lift_a, pants)
		_rect(img, 17, 36, 3, 10 - lift_b, pants)
		_rect(img, 9, 20 + bob, 14, 18, coat)
		_rect(img, 7, 21 + bob + lift_b, 3, 13, coat.darkened(0.15))
		_rect(img, 22, 21 + bob + lift_a, 3, 13, coat.darkened(0.15))
		_rect(img, 11, 7 + bob, 10, 12, skin)
		_rect(img, 10, 5 + bob, 12, 5, hair)
		if dir == 0:
			_rect(img, 15, 20 + bob, 2, 16, coat.darkened(0.3))
			_rect(img, 10, 9 + bob, 2, 6, hair)
			_rect(img, 20, 9 + bob, 2, 6, hair)
			_rect(img, 13, 12 + bob, 2, 2, OUTLINE)
			_rect(img, 17, 12 + bob, 2, 2, OUTLINE)
		else:
			_rect(img, 10, 5 + bob, 12, 12, hair)
	if hat:
		_rect(img, 8, 5 + bob, 16, 2, coat.darkened(0.6))
		_rect(img, 11, 1 + bob, 10, 5, coat.darkened(0.6))
