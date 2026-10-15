class_name BattleBackdrop
extends Control
## The scene behind a fight, drawn from the field: a sky by phase, a treeline or
## a wall, ground that recedes in bands, a moon or a low sun, and the weather's
## tint. Deterministic from the field so the same place looks the same twice.

const SKIES := {
	"night": ["070a16", "121a30"], "dusk": ["2a1430", "6a3a3a"], "morning": ["2e3e52", "8a9aa8"],
	"day": ["3e5a6a", "8aa0a8"], "inside": ["1a1410", "2e2418"],
}
const GROUNDS := {"night": "141a2e", "dusk": "3a2a3a", "morning": "5a6a7a", "day": "5a7a5a", "inside": "2e2418"}

var field: Dictionary = {}


func _init(p_field: Dictionary) -> void:
	field = p_field
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var inside: bool = field.get("inside", false)
	var key: String = "inside" if inside else str(field.get("phase", "night"))
	if not SKIES.has(key):
		key = "night"
	var sky: Array = SKIES[key]
	var top := Color(sky[0])
	var bottom := Color(sky[1])
	var ground := Color(GROUNDS[key])
	var snow: bool = field.get("weather", "") == "snow"
	if snow and not inside:
		ground = ground.lightened(0.45)
	# sky in bands (dithered gradient)
	for i in 20:
		var t := float(i) / 19.0
		draw_rect(Rect2(0, i * 10, 640, 10), top.lerp(bottom, t))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key + str(field.get("weather", "")))
	if inside:
		# wall planks and a baseboard
		for i in 10:
			var c := bottom.darkened(0.15 + 0.08 * float(i % 2))
			draw_rect(Rect2(0, i * 20, 640, 20), c)
			draw_line(Vector2(0, i * 20), Vector2(640, i * 20), Color(0, 0, 0, 0.35), 1.0)
		for i in 7:
			var x := 40 + i * 95 + rng.randi_range(-10, 10)
			draw_rect(Rect2(x, 0, 2, 198), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(0, 186, 640, 12), bottom.darkened(0.45))
		# a lamp's glow
		for r in [60.0, 42.0, 26.0]:
			draw_circle(Vector2(320, 120), r, Color("ffd080", 0.05))
	else:
		# a moon or a low sun
		if key == "night":
			draw_circle(Vector2(330, 50), 14, Color("e8e2d0", 0.9))
			draw_circle(Vector2(336, 46), 11, top.lerp(bottom, 0.3))
			for i in 40:
				draw_rect(Rect2(rng.randi_range(0, 639), rng.randi_range(0, 150), 1, 1), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
		elif key == "dusk":
			for r in [70.0, 50.0, 30.0]:
				draw_circle(Vector2(110, 196), r, Color("ff9a50", 0.08))
			draw_circle(Vector2(110, 196), 16, Color("ffb070", 0.8))
		else:
			for r in [90.0, 60.0]:
				draw_circle(Vector2(330, 40), r, Color("ffffff", 0.06))
		# far hills and a treeline
		var hill := PackedVector2Array([Vector2(0, 198)])
		for i in 17:
			hill.append(Vector2(i * 40, 170 + rng.randi_range(-12, 10)))
		hill.append(Vector2(640, 198))
		draw_colored_polygon(hill, bottom.darkened(0.35))
		var tree_col := ground.darkened(0.55)
		var x := -10
		while x < 650:
			var h := rng.randi_range(22, 54)
			var w := rng.randi_range(14, 26)
			var conifer := rng.randf() < (0.7 if snow else 0.4)
			if conifer:
				draw_colored_polygon(PackedVector2Array([Vector2(x, 198), Vector2(x + w / 2.0, 198 - h), Vector2(x + w, 198)]), tree_col)
				if snow:
					draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.3, 198 - h * 0.55), Vector2(x + w / 2.0, 198 - h), Vector2(x + w * 0.7, 198 - h * 0.55)]), Color(1, 1, 1, 0.25))
			else:
				draw_rect(Rect2(x + w / 2.0 - 2, 198 - h * 0.5, 4, h * 0.5), tree_col)
				draw_circle(Vector2(x + w / 2.0, 198 - h * 0.6), w * 0.55, tree_col)
			x += rng.randi_range(10, 24)
	# ground: bands that recede, lighter near the horizon
	for i in 8:
		var t := float(i) / 7.0
		draw_rect(Rect2(0, 198 + i * 8, 640, 8), ground.lightened(0.18 * (1.0 - t)))
	draw_rect(Rect2(0, 196, 640, 2), ground.lightened(0.35))
	if not inside:
		for i in 60:
			var gx := rng.randi_range(0, 639)
			var gy := rng.randi_range(200, 258)
			draw_rect(Rect2(gx, gy, rng.randi_range(2, 6), 1), ground.darkened(0.25) if not snow else Color(1, 1, 1, 0.35))
	else:
		for i in 9:
			draw_line(Vector2(0, 204 + i * 7), Vector2(640, 204 + i * 7), Color(0, 0, 0, 0.18), 1.0)
	# weather tint
	match str(field.get("weather", "")):
		"mist":
			draw_rect(Rect2(0, 0, 640, 262), Color("c0c8d0", 0.18))
		"rain", "gale":
			draw_rect(Rect2(0, 0, 640, 262), Color("4a5a70", 0.18))
