extends Node
## The player's progress, and saving it. Saves are plain JSON in user://.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2

var party: Array = []          # roster ids, player character first
var player_class := "signals"  # the player's own class (roster ids map to classes.json)
var player_name := ""         # what the new hire wrote on the form
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
var locked_checks: Dictionary = {}  # "witness:node:index" -> day locked, or -1 for the whole case
var items: Dictionary = {}     # item id -> count in the field kit
var gates_open: Array = []     # gate ids opened for good
var picked: Array = []         # "map:index" of pickups and barriers already taken
var visited: Dictionary = {}   # "witness:node" -> day last seen
var flags: Dictionary = {}
var cash := 120               # dollars, shared by the party
var gas := 6                  # tank units; a stop on the highway burns one
var composure := 100          # 0..100, the party's nerve on the road and in the field
var gear: Dictionary = {}     # member id -> {tool, coat, charm1, charm2}
var verdicts: Dictionary = {} # case id -> {lean, rating, budget, day}
var budget := 0               # unspent Office budget points
var budget_earned := 0        # every point ever paid, sets the tier
var radio_log: Array = []     # station ids heard


func has_evidence(id: String) -> bool:
	return id in evidence


func has_item(id: String) -> bool:
	return int(items.get(id, 0)) > 0


func add_item(id: String, count := 1) -> void:
	items[id] = int(items.get(id, 0)) + count
	if items[id] <= 0:
		items.erase(id)


func take_item(id: String, count := 1) -> bool:
	if int(items.get(id, 0)) < count:
		return false
	add_item(id, -count)
	return true


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "party": party, "player_class": player_class, "player_name": player_name, "levels": levels, "xp": xp,
		"case_id": case_id, "day": day, "dread": dread, "evidence": evidence, "exposed": exposed,
		"spoiled": spoiled, "samples": samples, "facts": facts, "clues_done": clues_done,
		"trust": trust, "failed_checks": failed_checks, "locked_checks": locked_checks, "items": items,
		"gates_open": gates_open, "picked": picked, "visited": visited, "flags": flags,
		"cash": cash, "gas": gas, "composure": composure, "gear": gear, "verdicts": verdicts,
		"budget": budget, "budget_earned": budget_earned, "radio_log": radio_log,
	}


func from_dict(d: Dictionary) -> void:
	party = d.get("party", [])
	player_class = d.get("player_class", "signals")
	player_name = str(d.get("player_name", ""))
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
	locked_checks = d.get("locked_checks", {})
	items = d.get("items", {})
	gates_open = d.get("gates_open", [])
	picked = d.get("picked", [])
	visited = d.get("visited", {})
	flags = d.get("flags", {})
	cash = int(d.get("cash", 120))
	gas = int(d.get("gas", 6))
	composure = int(d.get("composure", 100))
	gear = d.get("gear", {})
	verdicts = d.get("verdicts", {})
	budget = int(d.get("budget", 0))
	budget_earned = int(d.get("budget_earned", 0))
	radio_log = d.get("radio_log", [])


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
