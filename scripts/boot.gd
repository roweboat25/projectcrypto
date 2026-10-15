extends Node3D
## Title screen: a small night diorama of Point Pleasant in the HD-2D style,
## used to prove the rendering pipeline (pixel sprites, real lights, fog, snow).

const NIGHT := Color("1b2238")
const LAMP := Color("e8a64a")

var _camera: Camera3D
var _orbit := 0.0
var _prompt: Label


func _ready() -> void:
	_build_world()
	_build_ui()


func _process(delta: float) -> void:
	_orbit += delta * 0.08
	_camera.position = Vector3(sin(_orbit) * 17.0, 9.0, cos(_orbit) * 17.0)
	_camera.look_at(Vector3(0, 1.2, 0))
	_prompt.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 400.0)


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = NIGHT.darkened(0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3d4a5c")
	env.ambient_light_energy = 0.22
	env.fog_enabled = true
	env.fog_light_color = Color("141a2c")
	env.fog_density = 0.028
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color("9ab0c8")
	moon.light_energy = 0.22
	moon.rotation_degrees = Vector3(-50, 30, 0)
	moon.shadow_enabled = true
	add_child(moon)

	_box(Vector3(0, -0.05, 0), Vector3(40, 0.1, 40), Color("aab6c4"))        # snow
	_box(Vector3(0, 0.0, 0), Vector3(30, 0.02, 3.2), Color("2c2f38"))        # road
	_box(Vector3(-5.5, 1.6, -4.5), Vector3(5, 3.2, 4), Color("7a3b2e"))      # brick diner
	_box(Vector3(5, 1.2, -4.8), Vector3(4, 2.4, 3.6), Color("cfc4a8"))       # clapboard house
	_box(Vector3(-7, 1.0, 8.5), Vector3(6, 2.0, 3), Color("5e6e72"))          # motel
	for x in [-8.0, -3.0, 2.0, 7.0]:
		_lamp(Vector3(x, 0, 2.2))
	for p in [Vector3(-11, 0, -9), Vector3(10, 0, -10), Vector3(12, 0, 4), Vector3(-12, 0, 6), Vector3(-2, 0, -11)]:
		_pine(p)

	_sprite(PlaceholderArt.investigator(Color("b8a27a"), Color("5a3a22"), Color("e0b48e")), Vector3(-1.0, 0, 1.0))
	_sprite(PlaceholderArt.investigator(Color("6b4a33"), Color("2a2420"), Color("c99068"), true), Vector3(0.0, 0, 1.4))
	_sprite(PlaceholderArt.investigator(Color("3f6b4f"), Color("1d1b1f"), Color("b8805a")), Vector3(1.0, 0, 1.0))
	var watcher := _sprite(PlaceholderArt.watcher(), Vector3(3.5, 0, -9.5))
	watcher.shaded = false

	var snow := CPUParticles3D.new()
	snow.amount = 600
	snow.lifetime = 8.0
	snow.preprocess = 8.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(13, 0.5, 13)
	snow.position = Vector3(0, 6.5, 0)
	snow.direction = Vector3(0.2, -1, 0)
	snow.spread = 10
	snow.gravity = Vector3(0, -0.6, 0)
	snow.initial_velocity_min = 0.6
	snow.initial_velocity_max = 1.2
	var flake := QuadMesh.new()
	flake.size = Vector2(0.06, 0.06)
	var flake_mat := StandardMaterial3D.new()
	flake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake_mat.albedo_color = Color(1, 1, 1, 0.85)
	flake.material = flake_mat
	snow.mesh = flake
	add_child(snow)

	_camera = Camera3D.new()
	_camera.fov = 32
	add_child(_camera)


func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	box.material = mat
	mesh.mesh = box
	mesh.position = pos
	add_child(mesh)


func _lamp(pos: Vector3) -> void:
	_box(pos + Vector3(0, 1.5, 0), Vector3(0.12, 3.0, 0.12), Color("2a2a30"))
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = LAMP
	mat.emission_energy_multiplier = 4.0
	sphere.material = mat
	bulb.mesh = sphere
	bulb.position = pos + Vector3(0, 3.0, 0)
	add_child(bulb)
	var light := OmniLight3D.new()
	light.light_color = LAMP
	light.light_energy = 3.0
	light.omni_range = 6.0
	light.position = pos + Vector3(0, 2.8, 0)
	add_child(light)


func _pine(pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.3
	cone.height = 4.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2f4a3a")
	cone.material = mat
	mesh.mesh = cone
	mesh.position = pos + Vector3(0, 2.25, 0)
	add_child(mesh)


func _sprite(tex: Texture2D, pos: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 0.035
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.centered = false
	s.offset = Vector2(-tex.get_width() / 2.0, 0)
	s.position = pos
	add_child(s)
	return s


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-400, 70)
	box.size = Vector2(800, 200)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(box)

	var title := Label.new()
	title.text = "THE CASEBOOK OF\nUNQUIET PLACES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("e0303c"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Case 1: Point Pleasant, West Virginia"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color("d8e2ec"))
	box.add_child(sub)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_prompt = Label.new()
	_prompt.text = "Milestone 0 build. The walkable town arrives in Milestone 1."
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-400, -90)
	_prompt.size = Vector2(800, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	root.add_child(_prompt)

	var errors := GameData.validate()
	var status := Label.new()
	if errors.is_empty():
		status.text = "Data OK: %d classes, %d partners, %d foes, %d case(s)  ·  v%s" % [
			GameData.classes.size(), GameData.roster.size(), GameData.foes.size(),
			GameData.cases.size(), ProjectSettings.get_setting("application/config/version")]
	else:
		status.text = "Data problems: " + "; ".join(errors)
		status.add_theme_color_override("font_color", Color("e0303c"))
	status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status.position = Vector2(16, -34)
	status.add_theme_font_size_override("font_size", 13)
	status.modulate.a = 0.7
	root.add_child(status)
