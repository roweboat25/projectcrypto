class_name BattleHud
extends Control
## The fight's readout, drawn rather than typed: a card per party member with a
## portrait, a Composure bar that drains with a pale ghost behind it and a Focus
## bar under it, a bar or phase pips over each foe with chips for its weak points,
## status pills, the turn order as a row of chips, and the Evidence meter.

const PORTRAIT_DIR := "res://assets/portraits/"
const INK := Color("0e1424")
const PAPER := Color("f0e6d2")
const GOLD := Color("e8a64a")
const RED := Color("e0303c")
const GREEN := Color("5fc46a")
const BLUE := Color("5aa0e0")
const STATUS_COLOURS := {
	"unnerved": "b48cff", "blinded": "9aa0a8", "jammed": "5ad6ff", "cursed": "6a9a4a", "bound": "b07a4a",
	"exposed": "ffe24a", "marked": "ff6a5a", "counter": "ffa040", "ward": "5aa0e0", "charged": "ffffff", "haste": "7fffb0",
}
const STATUS_SHORT := {
	"unnerved": "NRV", "blinded": "BLD", "jammed": "JAM", "cursed": "CRS", "bound": "BND",
	"exposed": "EXP", "marked": "MRK", "counter": "CTR", "ward": "WRD", "charged": "CHG", "haste": "HST",
}

var b: Dictionary = {}
var sprites: Dictionary = {}       # actor key -> Node2D
var current := ""                  # key of the actor whose turn it is
var _shown: Dictionary = {}        # actor key -> composure as drawn (lags the real value)
var _portraits: Dictionary = {}
var _font: Font


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func refresh(p_b: Dictionary, p_sprites: Dictionary) -> void:
	b = p_b
	sprites = p_sprites
	queue_redraw()


func _process(delta: float) -> void:
	if b.is_empty():
		return
	var moving := false
	for a in b.actors:
		var real := float(a.composure)
		var shown: float = _shown.get(a.key, real)
		if absf(shown - real) > 0.01:
			shown = lerpf(shown, real, clampf(delta * 6.0, 0.0, 1.0))
			if absf(shown - real) < 0.3:
				shown = real
			moving = true
		_shown[a.key] = shown
	if moving:
		queue_redraw()


func _draw() -> void:
	if b.is_empty():
		return
	for a in b.actors:
		if a.broken and a.side == "foe":
			continue
		var node: Node2D = sprites.get(a.key)
		if node == null:
			continue
		if a.side == "party":
			_draw_party_card(a, node.position.x)
		else:
			_draw_foe_card(a, node.position.x)
	_draw_turns()
	_draw_meter()


func _text(pos: Vector2, s: String, size: int, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_font, pos + Vector2(1, 1), s, align, width, size, Color(0, 0, 0, 0.85))
	draw_string(_font, pos, s, align, width, size, colour)


func _bar(rect: Rect2, v: float, maxv: float, colour: Color, ghost := -1.0) -> void:
	draw_rect(rect, Color(INK, 0.9))
	var inner := Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2))
	var frac := clampf(v / maxf(1.0, maxv), 0.0, 1.0)
	if ghost > v:
		var g := clampf(ghost / maxf(1.0, maxv), 0.0, 1.0)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * g, inner.size.y)), Color(PAPER, 0.7))
	if frac > 0.0:
		draw_rect(Rect2(inner.position, Vector2(maxf(1.0, inner.size.x * frac), inner.size.y)), colour)
	draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.0)


func _pills(pos: Vector2, statuses: Dictionary, centre_x := -1.0) -> void:
	if statuses.is_empty():
		return
	var w := 0.0
	for s in statuses:
		w += 20.0
	var x := pos.x if centre_x < 0.0 else centre_x - w / 2.0
	for s in statuses:
		var col := Color(STATUS_COLOURS.get(s, "9aa0a8"))
		draw_rect(Rect2(x, pos.y, 18, 8), Color(INK, 0.9))
		draw_rect(Rect2(x, pos.y, 18, 8), col, false, 1.0)
		draw_string(_font, Vector2(x + 1, pos.y + 7), STATUS_SHORT.get(s, str(s).left(3).to_upper()), HORIZONTAL_ALIGNMENT_CENTER, 16, 7, col)
		x += 20.0


func _portrait(id: String) -> Texture2D:
	if _portraits.has(id):
		return _portraits[id]
	var path := PORTRAIT_DIR + id + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_portraits[id] = tex
	return tex


func _draw_party_card(a: Dictionary, sx: float) -> void:
	var w := 72.0
	var x := sx - w / 2.0
	var y := 64.0
	var card := Rect2(x, y, w, 36)
	draw_rect(card, Color(INK, 0.88))
	draw_rect(card, GOLD if a.key == current else Color(GOLD, 0.45), false, 1.0)
	if a.key == current:
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 4, y - 7), Vector2(sx + 4, y - 7), Vector2(sx, y - 2)]), GOLD)
	var tex := _portrait(a.id)
	if tex != null:
		draw_texture_rect(tex, Rect2(x + 3, y + 3, 22, 22), false, Color(1, 1, 1, 0.45 if a.broken else 1.0))
		draw_rect(Rect2(x + 3, y + 3, 22, 22), Color(GOLD, 0.6), false, 1.0)
	var cx := x + 28.0
	_text(Vector2(cx, y + 10), a.name, 8, GOLD if not a.broken else Color("9aa0a8"))
	if a.broken:
		_text(Vector2(cx, y + 22), "broken", 8, RED)
		return
	var frac := float(a.composure) / maxf(1.0, float(a.max_composure))
	var col := GREEN if frac > 0.5 else (GOLD if frac > 0.25 else RED)
	_bar(Rect2(cx, y + 13, 41, 6), float(a.composure), float(a.max_composure), col, _shown.get(a.key, float(a.composure)))
	_text(Vector2(cx, y + 28), str(a.composure), 7, PAPER)
	_bar(Rect2(cx + 14, y + 22, 27, 4), float(a.focus), float(a.max_focus), BLUE)
	_text(Vector2(cx + 14, y + 33), "FOCUS %d" % a.focus, 6, Color(BLUE, 0.9))
	_pills(Vector2(0, y + 38), a.statuses, sx)


func _draw_foe_card(a: Dictionary, sx: float) -> void:
	var w := 84.0
	var x := sx - w / 2.0
	var y := 206.0
	_text(Vector2(x, y + 8), a.name, 9, PAPER, HORIZONTAL_ALIGNMENT_CENTER, w)
	if a.key == current:
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 4, y - 6), Vector2(sx + 4, y - 6), Vector2(sx, y - 1)]), RED)
	if a.anomaly:
		var n: int = max(1, a.tells.size())
		var px := sx - (n * 10.0) / 2.0
		for i in n:
			var lit: bool = i < a.phase
			draw_rect(Rect2(px + i * 10, y + 12, 8, 6), Color("b48cff") if lit else Color(INK, 0.9))
			draw_rect(Rect2(px + i * 10, y + 12, 8, 6), Color("b48cff", 0.8), false, 1.0)
		var left: int = max(0, a.turns - b.round)
		_text(Vector2(x, y + 27), "hold %d" % left, 7, Color("b48cff"), HORIZONTAL_ALIGNMENT_CENTER, w)
	else:
		_bar(Rect2(sx - 35, y + 11, 70, 6), float(a.composure), float(a.max_composure), RED, _shown.get(a.key, float(a.composure)))
		var chips: Array = []
		if a.known:
			chips = a.weak.duplicate()
		elif not a.weak.is_empty():
			chips = ["?"]
		if not chips.is_empty():
			var cx := sx - (chips.size() * 12.0) / 2.0
			_text(Vector2(cx - 24, y + 25), "weak", 6, Color(PAPER, 0.7))
			for c in chips:
				var col := Color(Battle.TYPE_COLOURS.get(c, "9aa0a8"))
				draw_rect(Rect2(cx, y + 19, 10, 8), Color(INK, 0.9))
				draw_rect(Rect2(cx, y + 19, 10, 8), col, false, 1.0)
				draw_string(_font, Vector2(cx, y + 26), str(c).left(1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 10, 7, col)
				cx += 12.0
	_pills(Vector2(0, y + 30), a.statuses, sx)


func _draw_turns() -> void:
	var x := 8.0
	var y := 5.0
	_text(Vector2(x, y + 10), "NEXT", 7, Color(PAPER, 0.7))
	x += 26.0
	for p in BattleRules.preview(b, 6):
		var name: String = p.name
		var tw: float = _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var cw: float = tw + 8.0
		if x + cw > 430.0:
			break
		var col := GOLD if p.side == "party" else RED
		draw_rect(Rect2(x, y, cw, 13), Color(INK, 0.85))
		draw_rect(Rect2(x, y, cw, 13), Color(col, 0.8), false, 1.0)
		draw_string(_font, Vector2(x + 4, y + 10), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		x += cw + 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, y + 4), Vector2(x - 5, y + 9), Vector2(x - 2, y + 6.5)]), Color(PAPER, 0.5))


func _draw_meter() -> void:
	var x := 452.0
	var y := 5.0
	_text(Vector2(x, y + 10), "EVIDENCE", 7, GOLD)
	x += 46.0
	for i in BattleRules.METER_MAX:
		var lit: bool = i < b.meter
		draw_rect(Rect2(x + i * 9, y + 3, 7, 8), GOLD if lit else Color(INK, 0.85))
		draw_rect(Rect2(x + i * 9, y + 3, 7, 8), Color(GOLD, 0.7), false, 1.0)
	x += 96.0
	for i in BattleRules.INSIGHT_MAX:
		var lit: bool = i < b.insight
		var c := Vector2(x + i * 11 + 4, y + 7)
		var d := PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)])
		draw_colored_polygon(d, Color("5ad6ff") if lit else Color(INK, 0.85))
		draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), Color("5ad6ff", 0.8), 1.0)
