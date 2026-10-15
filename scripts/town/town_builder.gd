class_name TownBuilder
## Builds a district from a map JSON: ground, roads, buildings, lamps, trees,
## props and NPCs. Everything is simple geometry until real art lands.

const SNOW := Color("8e9cae")
const ROAD := Color("2c2f38")
const LAMP := Color("e8a64a")


static func build(root: Node3D, map: Dictionary) -> Dictionary:
	var out := {"lamps": [], "neon": [], "npcs": [], "doors": []}
	var size: Array = map.get("size", [64, 48])
	_static_box(root, Vector3(0, -0.1, 0), Vector3(size[0] + 20, 0.2, size[1] + 20), SNOW, true)
	for r in map.get("roads", []):
		_static_box(root, Vector3(r.pos[0], 0.005, r.pos[1]), Vector3(r.size[0], 0.01, r.size[1]), ROAD, false)
	for b in map.get("buildings", []):
		_building(root, b, out)
	for l in map.get("lamps", []):
		out.lamps.append(_lamp(root, Vector3(l[0], 0, l[1])))
	for t in map.get("trees", []):
		_pine(root, Vector3(t[0], 0, t[1]))
	for p in map.get("props", []):
		_prop(root, p)
	return out


static func _building(root: Node3D, b: Dictionary, out: Dictionary) -> void:
	var size := Vector3(b.size[0], b.size[1], b.size[2])
	var pos := Vector3(b.pos[0], size.y / 2.0, b.pos[1])
	var body := _static_box(root, pos, size, Color(b.get("color", "cfc4a8")), true)
	body.name = "building_" + b.id
	# roof: a slightly wider slab
	_static_box(root, pos + Vector3(0, size.y / 2.0 + 0.15, 0), Vector3(size.x + 0.6, 0.3, size.z + 0.6), Color(b.get("roof", "3d4a5c")), false)
	# door and windows on the entrance side
	var door_side: String = b.get("door", "s")
	var normal: Vector3 = {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "e": Vector3(1, 0, 0), "w": Vector3(-1, 0, 0)}[door_side]
	var half := Vector3(size.x / 2.0, 0, size.z / 2.0)
	var door_pos: Vector3 = Vector3(b.pos[0], 0, b.pos[1]) + Vector3(normal.x * half.x, 0, normal.z * half.z)
	var door_mesh := _unshaded_quad(root, door_pos + normal * 0.03 + Vector3(0, 1.0, 0), Vector2(1.1, 2.0), Color("1b2238"), normal)
	door_mesh.name = "door_" + b.id
	var win_color := Color("e8a64a")
	var along := Vector3(normal.z, 0, -normal.x).abs()
	var span: float = size.x if along.x > 0.5 else size.z
	var count := int(span / 2.2)
	for i in count:
		var t := (i + 0.5) / float(count) - 0.5
		var wpos: Vector3 = door_pos + along * t * span + normal * 0.03 + Vector3(0, size.y * 0.62, 0)
		if abs(t) < 0.12:
			continue
		var w := _unshaded_quad(root, wpos, Vector2(0.9, 0.9), win_color, normal)
		out.neon.append(w)
	if b.has("neon"):
		var sign := _unshaded_quad(root, door_pos + normal * 0.06 + Vector3(0, size.y - 0.4, 0), Vector2(min(span * 0.7, 6.0), 0.7), Color(b.neon), normal)
		var light := OmniLight3D.new()
		light.light_color = Color(b.neon)
		light.light_energy = 1.6
		light.omni_range = 5.0
		light.position = door_pos + normal * 1.0 + Vector3(0, size.y - 0.4, 0)
		root.add_child(light)
		out.neon.append(sign)
		out.lamps.append(light)
	out.doors.append({"id": b.id, "name": b.get("name", b.id), "pos": door_pos + normal * 0.8})
	var label := Label3D.new()
	label.text = b.get("name", "")
	label.font_size = 48
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("d8e2ec")
	label.outline_modulate = Color("1b2238")
	label.outline_size = 10
	label.visibility_range_begin = 9.0
	label.visibility_range_begin_margin = 1.0
	label.position = door_pos + normal * 0.5 + Vector3(0, size.y + 0.9, 0)
	root.add_child(label)


static func _static_box(root: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	box.material = mat
	mesh.mesh = box
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		body.add_child(mesh)
		body.position = pos
		root.add_child(body)
		return body
	mesh.position = pos
	root.add_child(mesh)
	return mesh


static func _unshaded_quad(root: Node3D, pos: Vector3, size: Vector2, color: Color, normal: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	mesh.mesh = quad
	mesh.position = pos
	mesh.look_at_from_position(pos, pos + normal)
	mesh.rotate_y(PI)
	root.add_child(mesh)
	return mesh


static func _lamp(root: Node3D, pos: Vector3) -> OmniLight3D:
	_static_box(root, pos + Vector3(0, 1.6, 0), Vector3(0.14, 3.2, 0.14), Color("2a2a30"), true)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = LAMP
	mat.emission_energy_multiplier = 4.0
	sphere.material = mat
	bulb.mesh = sphere
	bulb.name = "bulb"
	bulb.position = pos + Vector3(0, 3.2, 0)
	root.add_child(bulb)
	var light := OmniLight3D.new()
	light.light_color = LAMP
	light.light_energy = 3.0
	light.omni_range = 7.0
	light.position = pos + Vector3(0, 3.0, 0)
	light.set_meta("bulb", bulb)
	root.add_child(light)
	return light


static func _pine(root: Node3D, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5
	cyl.height = 4.0
	shape.shape = cyl
	shape.position.y = 2.0
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.4
	cone.height = 4.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2f4a3a")
	cone.material = mat
	mesh.mesh = cone
	mesh.position.y = 2.4
	body.add_child(mesh)
	body.position = pos
	root.add_child(body)


static func _prop(root: Node3D, p: Dictionary) -> void:
	var pos := Vector3(p.pos[0], 0, p.pos[1])
	match p.get("kind", ""):
		"car":
			var c := Color(p.get("color", "6a3a5a"))
			_static_box(root, pos + Vector3(0, 0.45, 0), Vector3(4.2, 0.9, 1.9), c, true)
			_static_box(root, pos + Vector3(-0.3, 1.15, 0), Vector3(2.2, 0.6, 1.7), c.darkened(0.2), false)
		"pump":
			_static_box(root, pos + Vector3(0, 0.7, 0), Vector3(0.6, 1.4, 0.4), Color("8a2a2a"), true)
		"phone":
			_static_box(root, pos + Vector3(0, 1.1, 0), Vector3(0.9, 2.2, 0.9), Color("3a4a8a"), true)
		"mailbox":
			_static_box(root, pos + Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.4), Color("2e3a52"), true)
