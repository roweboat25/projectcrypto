extends StaticBody3D
## A townsperson standing in the street. Faces the player when talked to.

var npc_id := ""
var display_name := ""
var sprite: Sprite3D


func setup(data: Dictionary) -> void:
	npc_id = data.id
	display_name = data.get("name", data.id)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	shape.shape = capsule
	shape.position.y = 0.7
	add_child(shape)
	sprite = Sprite3D.new()
	sprite.texture = PlaceholderArt.investigator_sheet(Color(data.get("coat", "cfc4a8")), Color(data.get("hair", "3a2a1e")), Color(data.get("skin", "e0b48e")), data.get("hat", false))
	sprite.hframes = 4
	sprite.vframes = 3
	sprite.frame = 0
	sprite.pixel_size = 0.036
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.position.y = 0.86
	add_child(sprite)
	add_to_group("interactable")
	set_meta("prompt", "Talk to " + display_name)
