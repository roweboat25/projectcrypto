extends Area2D
## A physical clue lying in the world: a small mark on the ground that only
## gets a ring around it when the party is close enough to notice.

var data: Dictionary
var _ring: Sprite2D


func setup(clue: Dictionary) -> void:
	data = clue
	var mark := Sprite2D.new()
	var path := "res://assets/props/%s.png" % clue.get("prop", "clue_prints")
	mark.texture = load(path)
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.position = Vector2(0, -mark.texture.get_height() / 2.0)
	add_child(mark)
	z_index = -1
	_ring = Sprite2D.new()
	_ring.texture = _ring_texture()
	_ring.position = mark.position
	_ring.visible = false
	add_child(_ring)
	add_to_group("interactable")
	set_meta("prompt", "Look closely")
	set_meta("clue", true)


func set_near(near: bool) -> void:
	_ring.visible = near and not data.id in GameState.clues_done


static var _tex: ImageTexture


static func _ring_texture() -> ImageTexture:
	if _tex == null:
		var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
		for y in 40:
			for x in 40:
				var d := Vector2(x - 19.5, y - 19.5).length()
				if d > 16.0 and d < 18.5:
					img.set_pixel(x, y, Color("e8a64a"))
		_tex = ImageTexture.create_from_image(img)
	return _tex
