class_name EvidencePanel
extends PanelContainer
## The evidence inventory: everything found so far by kind, with lean and
## weight, what has been exposed as false or spoiled, and samples at the lab.

var _text: RichTextLabel


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 24
	offset_right = -24
	offset_top = 16
	offset_bottom = -16
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0e1424", 0.95)
	style.border_color = Color("e8a64a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	visible = false
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	for f in ["normal_font_size", "bold_font_size"]:
		_text.add_theme_font_size_override(f, 11)
	_text.scroll_active = true
	add_child(_text)


func refresh() -> void:
	var case: Dictionary = Investigation.case_data(GameData, GameState)
	var evidence: Dictionary = case.get("evidence", {})
	var totals: Dictionary = Investigation.lean_totals(GameData, GameState)
	var s := "[color=#e8a64a][b]CASE FILE: %s[/b][/color]   Day %d   [color=#9ab0c8]Hoax %d · Natural %d · Unexplained %d[/color]\n" % [case.get("name", "").to_upper(), GameState.day, totals.hoax, totals.natural, totals.unexplained]
	var ch: Array = Investigation.chain(GameData, GameState)
	if not ch.is_empty():
		var idx := Investigation.chain_index(GameData, GameState, 0.3)
		s += "\n[color=#e8a64a][b]LEADS[/b][/color]\n"
		var ahead := 0
		for i in ch.size():
			var lead: Dictionary = ch[i]
			var done := Investigation.lead_done(GameData, GameState, lead, 0.3)
			if i > idx and not done:
				ahead += 1
				continue
			var mark := "[color=#6a6f7a]done[/color]" if done else "[color=#e0303c]NOW[/color]"
			if lead.get("optional", false) and not done:
				mark = "[color=#9ab0c8]side[/color]"
			s += "%s  [b]%s[/b]  [color=#c8d4e0]%s[/color]\n" % [mark, lead.get("title", ""), lead.get("goal", "") if not done else ""]
		if ahead > 0:
			s += "[color=#6a6f7a]· · ·  %d more lead%s to come[/color]\n" % [ahead, "" if ahead == 1 else "s"]
	var by_kind := {"testimony": [], "physical": [], "recording": [], "document": []}
	var notes := 0
	for id in GameState.evidence:
		if not Investigation.is_finding(GameData, GameState, id):
			notes += 1
			continue
		var e: Dictionary = GameData.evidence(GameState.case_id, id)
		by_kind.get(e.get("kind", "testimony"), by_kind.testimony).append(id)
	if GameState.evidence.is_empty():
		s += "\nNothing yet. Talk to people, and look closely at the ground.\n"
	elif notes > 0:
		s += "\n[color=#6a6f7a]%d note%s from conversations that do not bear on the verdict.[/color]\n" % [notes, "" if notes == 1 else "s"]
	for kind in by_kind:
		if by_kind[kind].is_empty():
			continue
		s += "\n[color=#e0303c][b]%s[/b][/color]\n" % kind.to_upper()
		for id in by_kind[kind]:
			var e: Dictionary = GameData.evidence(GameState.case_id, id)
			var tag := ""
			if id in GameState.exposed:
				tag = "  [color=#e0303c]FALSE[/color]"
			elif id in GameState.spoiled:
				tag = "  [color=#6a6f7a]SPOILED[/color]"
			else:
				tag = "  [color=#9ab0c8]%s %d[/color]" % [e.get("lean", ""), e.get("weight", 0)]
			s += "[b]%s[/b]%s\n[color=#c8d4e0]%s[/color]\n" % [e.get("title", id), tag, e.get("text", "")]
	if not GameState.samples.is_empty():
		s += "\n[color=#e8a64a][b]AT THE LAB[/b][/color]  (back after a night's sleep)\n"
		for id in GameState.samples:
			s += "· %s\n" % GameData.evidence(GameState.case_id, id).get("title", id).replace("Lab: ", "")
	if not GameState.items.is_empty():
		s += "\n[color=#e8a64a][b]FIELD KIT[/b][/color]\n"
		var parts := []
		for id in GameState.items:
			var it: Dictionary = GameData.items.get(id, {})
			parts.append("%s x%d" % [it.get("name", id), int(GameState.items[id])])
		s += "· " + " · ".join(parts) + "\n"
	s += "\n[color=#6a6f7a]Tab closes[/color]"
	_text.text = s
