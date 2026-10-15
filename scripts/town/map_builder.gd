class_name MapBuilder
## Builds a district or a room from a map JSON: ground and wall tiles from
## assets/tiles, storefront facades, props, lamps, townspeople and clues. All
## positions in the JSON are in 32px tiles; everything that stands on the
## ground goes under a y-sorted "Actors" node so the party walks behind it.

const T := 32
const TILESET := "res://assets/tiles/tileset.tres"

static var atlas: Dictionary = {}
static var props_index: Dictionary = {}
static var facades_index: Dictionary = {}


static func load_indexes() -> void:
	if atlas.is_empty():
		atlas = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/atlas.json"))
		props_index = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/props.json"))
		facades_index = JSON.parse_string(FileAccess.get_file_as_string("res://assets/facades/facades.json"))


## Builds the outdoor map at tile offset `origin`. Returns the nodes the town needs.
static func build_district(root: Node2D, map: Dictionary, origin: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	load_indexes()
	var out := {"lamps": [], "neon": [], "npcs": [], "clues": [], "doors": [], "actors": null, "rect": Rect2(), "exits": [], "appears": []}
	var size: Array = map.get("size", [40, 30])
	out.rect = Rect2(Vector2(origin) * T, Vector2(size[0], size[1]) * T)
	var ground := _layer(root, "Ground")
	var walls := _layer(root, "Walls")
	var base: String = map.get("ground", "snow")
	var base_variants := [base, base, base, base + "2", base + "3"]
	for y in size[1]:
		for x in size[0]:
			_tile(ground, origin + Vector2i(x, y), _pick(base_variants, rng))
	for f in map.get("fills", []):
		_fill(ground, walls, origin, f, rng)
	for s in map.get("scatter", []):
		var r: Array = s.rect
		for y in range(r[1], r[1] + r[3]):
			for x in range(r[0], r[0] + r[2]):
				if rng.randf() < float(s.get("chance", 0.05)):
					_tile(ground, origin + Vector2i(x, y), _pick(s.tiles, rng))
	var actors := Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	root.add_child(actors)
	out.actors = actors
	for f in map.get("facades", []):
		_facade(actors, f, origin, out)
	for h in map.get("houses", []):
		var node := prop(actors, h.prop, _px(h.pos, origin))
		node.name = "house_" + h.id
		if h.has("appears"):
			out.appears.append({"node": node, "gate": h.appears})
		out.doors.append({"id": h.id, "name": h.name, "pos": _px(h.door, origin), "locked": h.get("locked", ""), "gate": h.get("gate", ""), "appears": h.get("appears", "")})
	_props(actors, map.get("props", []), origin, map.get("id", "map"), out)
	for n in map.get("npcs", []):
		out.npcs.append(npc(actors, n, _px(n.pos, origin)))
	for c in map.get("clues", []):
		out.clues.append(clue(actors, c, _px(c.pos, origin)))
	for e in map.get("exits", []):
		var r: Array = e.rect
		out.exits.append({"rect": Rect2(Vector2(Vector2i(r[0], r[1]) + origin) * T, Vector2(r[2], r[3]) * T),
			"to": e.to, "at": e.get("at", [2, 2]), "name": e.get("name", e.to), "gate": e.get("gate", "")})
	return out


## Places a list of props; ones with Look text, a pickup or a gate get a hotspot the party can use.
static func _props(actors: Node2D, list: Array, origin: Vector2i, map_id: String, out: Dictionary) -> void:
	for i in list.size():
		var p: Dictionary = list[i]
		var key := "%s:%d" % [map_id, i]
		if (p.has("pickup") or p.has("gate")) and (key in GameState.picked or (p.get("restock", false) and ("%s:%d" % [key, GameState.day]) in GameState.picked)):
			continue
		var node := prop(actors, p.kind, _px(p.pos, origin))
		if p.has("appears"):
			out.appears.append({"node": node, "gate": p.appears})
		if p.kind.begins_with("lamp_post"):
			out.lamps.append(_light(node, Vector2(0, -78), Color("ffb860"), 1.1, 150.0))
		if p.has("look") or p.has("pickup") or p.has("gate") or p.has("use") or p.has("travel") or p.has("enter"):
			var spot := Area2D.new()
			spot.set_script(load("res://scripts/town/hotspot.gd"))
			node.add_child(spot)
			spot.setup(p, key)
			spot.set_meta("node", node)


## Builds one room at tile offset `origin`. The exit is the whole bottom edge.
static func build_room(root: Node2D, id: String, room: Dictionary, origin: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	load_indexes()
	var out := {"lamps": [], "neon": [], "npcs": [], "clues": [], "doors": [], "actors": null, "rect": Rect2(), "bed": Vector2.ZERO, "exit_y": 0.0, "entry": Vector2.ZERO}
	var w: int = room.size[0]
	var h: int = room.size[1]
	var ground := _layer(root, "Ground_" + id)
	var walls := _layer(root, "Walls_" + id)
	var wall: String = room.get("wall", "cream")
	# void border, two rows of painted wall along the top, floor below
	for y in range(-1, h + 2):
		for x in range(-1, w + 1):
			var c := origin + Vector2i(x, y)
			if y == -1 or x == -1 or x == w or y == h + 1:
				_tile(walls, c, "void")
			elif y == 0:
				_tile(walls, c, "wall_%s_top" % wall)
			elif y == 1:
				_tile(walls, c, "wall_%s_bot" % wall)
			else:
				_tile(ground, c, _pick(room.get("floor", ["wood_warm"]), rng))
	# the doorway in the bottom edge
	var door_x: int = w / 2
	_erase(walls, origin + Vector2i(door_x, h + 1))
	_tile(ground, origin + Vector2i(door_x, h + 1), "concrete_dark")   # a walkable threshold: void tiles are solid
	var actors := Node2D.new()
	actors.name = "Actors_" + id
	actors.y_sort_enabled = true
	root.add_child(actors)
	out.actors = actors
	out.rect = Rect2(Vector2(origin - Vector2i(1, 1)) * T, Vector2(w + 2, h + 3) * T)
	out.exit_y = float(origin.y + h + 1) * T + 4
	out.entry = Vector2((origin.x + door_x) * T + T / 2.0, (origin.y + h) * T + T / 2.0)
	_props(actors, room.get("props", []), origin, id, out)
	for n in room.get("npcs", []):
		out.npcs.append(npc(actors, n, _px(n.pos, origin)))
	for c in room.get("clues", []):
		out.clues.append(clue(actors, c, _px(c.pos, origin)))
	if room.has("bed"):
		out.bed = _px(room.bed, origin)
	# a warm room light
	var light := PointLight2D.new()
	light.texture = light_texture()
	light.color = Color("ffe0b8")
	light.energy = 0.8
	light.texture_scale = max(w, h) * 32.0 / 128.0
	light.position = Vector2((origin.x + w / 2.0) * T, (origin.y + h / 2.0) * T)
	root.add_child(light)
	out.lamps.append(light)
	return out


# ---------- pieces ----------

static func prop(parent: Node2D, kind: String, pos: Vector2) -> Node2D:
	var info: Dictionary = props_index.get(kind, {})
	var node := Node2D.new()
	node.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/props/%s.png" % kind)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var h: float = float(info.get("h", 32))
	sprite.position = Vector2(0, -h / 2.0)
	node.add_child(sprite)
	var solid := int(info.get("solid", 0))
	if solid > 0:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var w: float = float(info.get("w", 32))
		rect.size = Vector2(w - 6, min(solid * T, h) - 6)
		shape.shape = rect
		shape.position = Vector2(0, -rect.size.y / 2.0 - 3)
		body.add_child(shape)
		node.add_child(body)
	elif kind.begins_with("neon") or kind.begins_with("clue"):
		node.z_index = 1
	parent.add_child(node)
	return node


static func _facade(parent: Node2D, f: Dictionary, origin: Vector2i, out: Dictionary) -> void:
	var asset: String = f.get("facade", f.id)
	var info: Dictionary = facades_index.get(asset, {})
	var w: float = float(info.get("w", 96))
	var h: float = float(info.get("h", 96))
	var bottom_left := Vector2(Vector2i(f.pos[0], f.pos[1]) + origin) * T
	var node := Node2D.new()
	node.name = "facade_" + f.id
	node.position = bottom_left + Vector2(w / 2.0, 0)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/facades/%s.png" % asset)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0, -h / 2.0)
	node.add_child(sprite)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# steeples and other tall tops are drawn, not walked into
	var solid_h: float = float(info.get("solid_h", h))
	rect.size = Vector2(w, solid_h - 6)
	shape.shape = rect
	shape.position = Vector2(0, -solid_h / 2.0 - 3)
	body.add_child(shape)
	node.add_child(body)
	# the name over the door
	var label := Label.new()
	label.text = f.get("name", f.id)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("f0e6d2"))
	label.add_theme_color_override("font_outline_color", Color("101018"))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(w, 14)
	label.position = Vector2(-w / 2.0, -float(info.get("wall_h", 64)) - (30 if info.get("neon", "") != "" else 14))
	node.add_child(label)
	if info.get("neon", "") != "":
		var door_x: float = float(info.get("door_x", 0)) - w / 2.0 + 16
		var neon := Sprite2D.new()
		neon.texture = load("res://assets/props/%s.png" % info.neon)
		neon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		neon.position = Vector2(door_x, -float(info.get("wall_h", 64)) + 2)
		node.add_child(neon)
		var colour := Color("ff5060") if info.neon == "neon_red" else Color("ffb860")
		var light := _light(node, neon.position + Vector2(0, 20), colour, 0.9, 110.0)
		out.neon.append(neon)
		out.lamps.append(light)
	parent.add_child(node)
	if f.has("appears"):
		out.appears.append({"node": node, "gate": f.appears})
	for dx in info.get("doors", [info.get("door_x", 0)]):
		out.doors.append({"id": f.id, "name": f.get("name", f.id), "pos": bottom_left + Vector2(float(dx) + 16, 0), "locked": f.get("locked", ""), "gate": f.get("gate", ""), "appears": f.get("appears", "")})


static func npc(parent: Node2D, n: Dictionary, pos: Vector2) -> Node:
	var node := Area2D.new()
	node.set_script(load("res://scripts/town/npc.gd"))
	parent.add_child(node)
	node.setup(n)
	node.position = pos
	node.set_meta("when", n.get("when", []))
	if n.has("appears"):
		node.set_meta("appears", n.appears)
	return node


static func clue(parent: Node2D, c: Dictionary, pos: Vector2) -> Node:
	var node := Area2D.new()
	node.set_script(load("res://scripts/town/clue.gd"))
	parent.add_child(node)
	node.setup(c)
	node.position = pos
	return node


static func _light(parent: Node2D, offset: Vector2, colour: Color, energy: float, radius: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = light_texture()
	light.color = colour
	light.energy = energy
	light.texture_scale = radius / 128.0
	light.position = offset
	light.shadow_enabled = false
	parent.add_child(light)
	return light


static var _light_tex: GradientTexture2D


static func light_texture() -> GradientTexture2D:
	if _light_tex == null:
		_light_tex = GradientTexture2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(1.0, 0.5)
		_light_tex.width = 256
		_light_tex.height = 256
	return _light_tex


# ---------- tiles ----------

static func _layer(root: Node2D, name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = name
	layer.tile_set = load(TILESET)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(layer)
	return layer


static func _tile(layer: TileMapLayer, coords: Vector2i, tile: String) -> void:
	var a: Array = atlas.get(tile, atlas.get("snow"))
	layer.set_cell(coords, 0, Vector2i(a[0], a[1]))


static func _erase(layer: TileMapLayer, coords: Vector2i) -> void:
	layer.erase_cell(coords)


static func _fill(ground: TileMapLayer, walls: TileMapLayer, origin: Vector2i, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var r: Array = f.rect
	var every := int(f.get("every", 1))
	for y in range(r[1], r[1] + r[3]):
		for x in range(r[0], r[0] + r[2]):
			if every > 1 and x % every != 0:
				continue
			var tile: String = _pick(f.tiles, rng)
			var solid := tile == "void" or tile.begins_with("water")
			_tile(walls if solid else ground, origin + Vector2i(x, y), tile)


static func _pick(tiles: Variant, rng: RandomNumberGenerator) -> String:
	if tiles is String:
		return tiles
	return tiles[rng.randi() % tiles.size()]


static func _px(pos: Array, origin: Vector2i) -> Vector2:
	return (Vector2(pos[0], pos[1]) + Vector2(origin)) * T
