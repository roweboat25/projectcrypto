class_name RadioDial
extends Control
## The car radio: a strip of dial, a needle and a signal meter. Turning the
## dial slowly brings a station out of the static; holding the needle in its
## lock window for two seconds logs it.

signal locked(station_id: String)

const BANDS := {"fm": [88.0, 108.0, 0.6], "am": [540.0, 1600.0, 25.0]}   # low, high, lock width

var stations: Array = []     # [{id, band, freq, name}] available now
var band := "fm"
var needle := 92.0
var signal_strength := 0.0
var _hold := 0.0
var _best := ""
var heard: Array = []        # station ids logged this leg (dimmer ticks)


func _ready() -> void:
	custom_minimum_size = Vector2(560, 90)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -280
	offset_right = 280
	offset_top = -45
	offset_bottom = 45
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not visible:
		return
	var lo: float = BANDS[band][0]
	var hi: float = BANDS[band][1]
	var speed: float = (hi - lo) * 0.12
	if Input.is_action_pressed("move_left"):
		needle = max(lo, needle - speed * delta)
	if Input.is_action_pressed("move_right"):
		needle = min(hi, needle + speed * delta)
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		band = "am" if band == "fm" else "fm"
		needle = (BANDS[band][0] + BANDS[band][1]) * 0.5
		_hold = 0.0
	signal_strength = 0.0
	_best = ""
	for st in stations:
		if st.band != band:
			continue
		var s: float = clamp(1.0 - abs(needle - float(st.freq)) / BANDS[band][2], 0.0, 1.0)
		if s > signal_strength:
			signal_strength = s
			_best = st.id
	if signal_strength > 0.75 and _best != "":
		_hold += delta
		if _hold >= 2.0:
			_hold = 0.0
			locked.emit(_best)
	else:
		_hold = 0.0
	queue_redraw()


func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(0, 0, w, size.y), Color("0e1424", 0.92))
	draw_rect(Rect2(0, 0, w, size.y), Color("e8a64a"), false, 1.0)
	var lo: float = BANDS[band][0]
	var hi: float = BANDS[band][1]
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8, 16), "%s  %s" % [band.to_upper(), ("%.1f" % needle) if band == "fm" else str(int(needle))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f0e6d2"))
	draw_string(font, Vector2(w - 250, 16), "A/D tune · W/S band · X done", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("9ab0c8"))
	var y0 := 34.0
	var x0 := 16.0
	var x1 := w - 16.0
	draw_line(Vector2(x0, y0 + 12), Vector2(x1, y0 + 12), Color("9ab0c8"), 1.0)
	var steps := 10
	for i in steps + 1:
		var f: float = lo + (hi - lo) * i / steps
		var x: float = x0 + (x1 - x0) * i / steps
		draw_line(Vector2(x, y0 + 6), Vector2(x, y0 + 18), Color("9ab0c8"), 1.0)
		draw_string(font, Vector2(x - 10, y0 + 30), str(int(f)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("6a6f7a"))
	for st in stations:
		if st.band != band:
			continue
		var x: float = x0 + (x1 - x0) * (float(st.freq) - lo) / (hi - lo)
		draw_line(Vector2(x, y0 + 8), Vector2(x, y0 + 16), Color("e8a64a", 0.35 if st.id in heard else 0.12), 2.0)
	var nx: float = x0 + (x1 - x0) * (needle - lo) / (hi - lo)
	draw_line(Vector2(nx, y0), Vector2(nx, y0 + 24), Color("e0303c"), 2.0)
	# signal meter
	var mx := w - 16.0 - 120.0
	draw_rect(Rect2(mx, size.y - 18, 120, 8), Color("2c3454"))
	draw_rect(Rect2(mx, size.y - 18, 120 * signal_strength, 8), Color("e8a64a") if signal_strength < 0.75 else Color("8fd18f"))
	draw_string(font, Vector2(mx - 44, size.y - 10), "signal", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("9ab0c8"))
	if _hold > 0.0:
		draw_rect(Rect2(mx, size.y - 8, 120 * (_hold / 2.0), 3), Color("8fd18f"))
	# static
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec() / 90)
	var dots := int(24 * (1.0 - signal_strength))
	for i in dots:
		draw_rect(Rect2(rng.randf_range(x0, x1), rng.randf_range(y0 - 2, y0 + 26), 2, 2), Color(1, 1, 1, 0.25))
