class_name Minimap
extends Control
## A small map of the district (or the room) in the top-right corner: one cell per tile
## in the tile's average colour, buildings as dark blocks, doors and exits as marks, the
## witnesses about as small dots, and the party as a white dot that follows the leader.

const MAX_PX := 160
const PAD := 6

var _image_tex: ImageTexture = null
var _rect := Rect2()          # the mapped area, in world pixels
var _scale := 2.0             # screen px per tile
var _origin := Vector2.ZERO   # world px of the top-left tile
var _marks: Array = []        # {pos: Vector2 (world), color}
var _npcs: Array = []         # nodes to follow
var _track: Node2D = null
var _exits: Array = []        # world rects

static var _avg_cache: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)


## Builds the picture from the layers. `rect` is the area in world pixels; `exits` are
## world rects; `doors` world points; `npcs` the NPC nodes (hidden ones are skipped later).
func build(ground: TileMapLayer, walls: TileMapLayer, rect: Rect2, actors: Node2D, exits: Array, doors: Array, npcs: Array, track: Node2D) -> void:
	_rect = rect
	_track = track
	_npcs = npcs
	_exits = exits
	var w := int(rect.size.x / 32)
	var h := int(rect.size.y / 32)
	_scale = clamp(floor(float(MAX_PX) / float(max(w, h, 1))), 1.0, 3.0)
	var ox := int(rect.position.x / 32)
	var oy := int(rect.position.y / 32)
	_origin = rect.position
	var img := Image.create(max(1, w), max(1, h), false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := Vector2i(ox + x, oy + y)
			var col := _tile_colour(walls, c)
			if col.a == 0.0:
				col = _tile_colour(ground, c)
			if col.a == 0.0:
				col = Color("0e1424")
			img.set_pixel(x, y, col)
	# buildings: any big sprite in the actors (facades, barns, the plant)
	for node in actors.get_children():
		_paint_big(img, node, rect)
	_image_tex = ImageTexture.create_from_image(img)
	_marks.clear()
	for d in doors:
		_marks.append({"pos": d.pos, "color": Color("e8a64a")})
	size = Vector2(w, h) * _scale + Vector2(PAD * 2, PAD * 2)
	offset_left = -size.x - 6
	offset_top = 6
	offset_right = -6
	offset_bottom = 6 + size.y
	queue_redraw()


func _paint_big(img: Image, node: Node, rect: Rect2) -> void:
	if node is Sprite2D and node.texture != null and node.texture.get_width() >= 64:
		var s: Sprite2D = node
		var size_px: Vector2 = s.texture.get_size() * s.scale
		if s.hframes > 1:
			size_px.x /= s.hframes
		var top_left: Vector2 = s.global_position + s.offset - (size_px / 2.0 if s.centered else Vector2.ZERO)
		var x0 := int((top_left.x - rect.position.x) / 32)
		var y0 := int((top_left.y - rect.position.y) / 32)
		var x1 := int((top_left.x + size_px.x - rect.position.x - 1) / 32)
		var y1 := int((top_left.y + size_px.y - rect.position.y - 1) / 32)
		for y in range(max(0, y0), min(img.get_height() - 1, y1) + 1):
			for x in range(max(0, x0), min(img.get_width() - 1, x1) + 1):
				img.set_pixel(x, y, Color("2a2230"))
	for child in node.get_children():
		_paint_big(img, child, rect)


func _tile_colour(layer: TileMapLayer, c: Vector2i) -> Color:
	if layer == null:
		return Color(0, 0, 0, 0)
	var sid := layer.get_cell_source_id(c)
	if sid < 0:
		return Color(0, 0, 0, 0)
	var at := layer.get_cell_atlas_coords(c)
	var key := Vector2i(sid * 1000 + at.x, at.y)
	if _avg_cache.has(key):
		return _avg_cache[key]
	var src: TileSetAtlasSource = layer.tile_set.get_source(sid)
	var tex_img: Image = src.texture.get_image()
	var ts: Vector2i = src.texture_region_size
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for yy in range(4, ts.y, 8):
		for xx in range(4, ts.x, 8):
			var p := tex_img.get_pixel(at.x * ts.x + xx, at.y * ts.y + yy)
			if p.a < 0.5:
				continue
			r += p.r
			g += p.g
			b += p.b
			n += 1
	var col := Color("0e1424") if n == 0 else Color(r / n, g / n, b / n)
	_avg_cache[key] = col
	return col


func _process(_delta: float) -> void:
	if visible and _image_tex != null:
		queue_redraw()


func _to_local_px(world: Vector2) -> Vector2:
	return (world - _origin) / 32.0 * _scale + Vector2(PAD, PAD)


func _draw() -> void:
	if _image_tex == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("0e1424", 0.88))
	draw_rect(Rect2(Vector2.ZERO, size), Color("e0303c", 0.9), false, 1.0)
	draw_texture_rect(_image_tex, Rect2(Vector2(PAD, PAD), Vector2(_image_tex.get_width(), _image_tex.get_height()) * _scale), false)
	for e in _exits:
		var r: Rect2 = e.rect
		draw_rect(Rect2(_to_local_px(r.position), r.size / 32.0 * _scale), Color("e0303c", 0.9))
	for m in _marks:
		draw_rect(Rect2(_to_local_px(m.pos) - Vector2(1, 1), Vector2(2, 2)), m.color)
	for n in _npcs:
		if is_instance_valid(n) and n.visible and n.is_inside_tree():
			draw_rect(Rect2(_to_local_px(n.global_position) - Vector2(1, 1), Vector2(2, 2)), Color("f0e060"))
	if _track != null and is_instance_valid(_track):
		var p := _to_local_px(_track.global_position)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(1, 1, 1))
