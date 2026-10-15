extends Area2D
## A townsperson standing in a room or a street. Faces the party when talked to.

const ROW := {"down": 0, "left": 1, "right": 2, "up": 3}

var npc_id := ""
var display_name := ""
var sprite: Sprite2D


func setup(data: Dictionary) -> void:
	npc_id = data.id
	display_name = data.get("name", data.id)
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/sprites/shadow.png")
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	sprite = Sprite2D.new()
	var path := "res://assets/sprites/%s.png" % data.get("sprite", npc_id)
	sprite.texture = load(path if ResourceLoader.exists(path) else "res://assets/sprites/regulars.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = 9
	sprite.vframes = 4
	sprite.position = Vector2(0, -29)
	add_child(sprite)
	face(data.get("facing", "down"))
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 10)
	shape.shape = rect
	shape.position = Vector2(0, -5)
	body.add_child(shape)
	add_child(body)
	add_to_group("interactable")
	set_meta("prompt", "Talk to " + display_name)


func face(dir: String) -> void:
	sprite.frame = ROW.get(dir, 0) * 9


func face_toward(target: Vector2) -> void:
	var d := target - global_position
	if absf(d.x) > absf(d.y):
		face("right" if d.x > 0.0 else "left")
	else:
		face("down" if d.y > 0.0 else "up")
