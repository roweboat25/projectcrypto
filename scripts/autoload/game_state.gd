extends Node
## The player's progress, and saving it. Saves are plain JSON in user://.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var party: Array = []          # roster ids, player character first
var levels: Dictionary = {}    # id -> level
var xp: Dictionary = {}        # id -> xp
var case_id := "point_pleasant"
var day := 1
var dread := 1
var evidence: Array = []       # evidence ids found
var flags: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "party": party, "levels": levels, "xp": xp,
		"case_id": case_id, "day": day, "dread": dread, "evidence": evidence, "flags": flags,
	}


func from_dict(d: Dictionary) -> void:
	party = d.get("party", [])
	levels = d.get("levels", {})
	xp = d.get("xp", {})
	case_id = d.get("case_id", "point_pleasant")
	day = int(d.get("day", 1))
	dread = int(d.get("dread", 1))
	evidence = d.get("evidence", [])
	flags = d.get("flags", {})


func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	from_dict(parsed)
	return true
