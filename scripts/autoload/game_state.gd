extends Node
## The player's progress, and saving it. Saves are plain JSON in user://.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2

var party: Array = []          # roster ids, player character first
var player_class := "signals"  # the player's own class (roster ids map to classes.json)
var levels: Dictionary = {}    # id -> level
var xp: Dictionary = {}        # id -> xp
var case_id := "point_pleasant"
var day := 1
var dread := 1
var evidence: Array = []       # evidence ids found, in the order found
var exposed: Array = []        # evidence ids shown to be false
var spoiled: Array = []        # evidence ids ruined by the wrong method
var samples: Array = []        # evidence ids bagged, waiting on the lab
var facts: Array = []          # witness fact ids unlocked
var clues_done: Array = []     # clue ids already processed
var trust: Dictionary = {}     # witness id -> trust level
var failed_checks: Dictionary = {}  # "fact:tag" -> day it failed, closed until the next day
var flags: Dictionary = {}


func has_evidence(id: String) -> bool:
	return id in evidence


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "party": party, "player_class": player_class, "levels": levels, "xp": xp,
		"case_id": case_id, "day": day, "dread": dread, "evidence": evidence, "exposed": exposed,
		"spoiled": spoiled, "samples": samples, "facts": facts, "clues_done": clues_done,
		"trust": trust, "failed_checks": failed_checks, "flags": flags,
	}


func from_dict(d: Dictionary) -> void:
	party = d.get("party", [])
	player_class = d.get("player_class", "signals")
	levels = d.get("levels", {})
	xp = d.get("xp", {})
	case_id = d.get("case_id", "point_pleasant")
	day = int(d.get("day", 1))
	dread = int(d.get("dread", 1))
	evidence = d.get("evidence", [])
	exposed = d.get("exposed", [])
	spoiled = d.get("spoiled", [])
	samples = d.get("samples", [])
	facts = d.get("facts", [])
	clues_done = d.get("clues_done", [])
	trust = d.get("trust", {})
	failed_checks = d.get("failed_checks", {})
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
