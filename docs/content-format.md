# Content format

Everything the game shows is data under `data/`. The engine builds maps from
`data/maps`, rules from `data/cases`, conversations from `data/dialogue`, and
items from `data/items.json`. Positions are in 32px tiles; fractions are fine
(`[12.5, 23]`). `python3 tools/check_content.py` checks every reference below
and `tests/run_tests.gd` runs the same checks plus the rules.

## Maps: `data/maps/<case>_<district>.json`

```
{
  "id": "point_pleasant_riverfront",   // file name without .json
  "name": "Riverfront",                // shown in the HUD
  "case": "point_pleasant",
  "district": "riverfront",            // key in the case's districts table
  "size": [56, 40],
  "spawn": [10, 20],                   // where the party stands if it arrives with no exit
  "ground": "snow",                    // base tile; "<ground>2" and "<ground>3" variants are mixed in
  "fills": [ {"rect": [x, y, w, h], "tiles": "asphalt" | ["snow", "snow2"], "every": 2} ],
  "scatter": [ {"rect": [x, y, w, h], "tiles": ["snow_drift"], "chance": 0.06} ],
  "facades": [ {"id": "bait_shop", "facade": "bait_shop", "name": "Bait and Tackle", "pos": [4, 17],
                "locked": "Closed until morning.", "gate": "floodgate"} ],
  "houses":  [ {"id": "house_c", "name": "The Mason house", "prop": "house_brick", "pos": [37, 31], "door": [35.5, 31]} ],
  "props":   [ {"kind": "lamp_post", "pos": [14, 17.5]},
               {"kind": "bulletin_board", "pos": [20, 16.5], "name": "Bulletin board",
                "look": "Lost cat, 1991. Still hopeful." | [["teddy", "Patsy Cline, twice."]]},
               {"kind": "crate", "pos": [3, 5], "pickup": "bolt_cutters"} ],
  "npcs":    [ {"id": "ham", "name": "Orville Pace", "pos": [12, 8], "facing": "down",
                "sprite": "ham", "when": ["morning", "day"]} ],
  "clues":   [ {"id": "crane_feather", "name": "A grey feather", "pos": [12, 35.6], "prop": "clue_fur",
                "text": "...", "methods": {"bag": "crane_feather", "photograph": "feather_photo", "cast": "spoil"},
                "requires": "evidence_id", "night": 3} ],
  "exits":   [ {"rect": [0, 18, 1, 4], "to": "point_pleasant_main_street", "at": [58, 20], "name": "Main Street", "gate": "floodgate"} ],
  "interiors": {
    "bait_shop": {"size": [10, 8], "floor": ["wood_grey", "wood_grey2"], "wall": "grey",
                  "props": [...], "npcs": [...], "clues": [...], "bed": [1.5, 5.5]}
  }
}
```

Rules:
- `fills` tiles that start with `wall_`, `brick_`, `stone_`, `drywall_`, `window_`, `frame_`, `void`, `water` and `cement_edge` are solid. Everything else is walkable.
- A `facades` entry needs an `interiors` entry with the same `id` unless it is `locked`. `facade` names the drawn storefront in `assets/facades` and defaults to `id`, so two buildings can share a look.
- `houses` are whole-house props (`house_brick`, `house_brick_b`, `house_panel`) with a `door` tile; they also take `interiors`.
- A prop `pos` is the bottom-centre tile; a facade `pos` is the bottom-left tile.
- `look` makes a prop inspectable. A plain string is narration; a list of `[speaker, text]` lines plays as dialogue. Party members only speak their line when they are in the party.
- `pickup` puts an item from `data/items.json` in the field kit once. New items a district needs go in its case fragment under `"items": {...}` with the same shape as `data/items.json`.
- A prop with `"use": "<panel>"` and a `name` opens an engine panel when used: `board` (the case board: file a verdict, see the standing evidence), `ledger` (spend budget on Office and car upgrades), `catalog` (the card catalog: evidence archive, verdict history, Drawer S), `radio_log` (stations logged on the road), `shop` (a counter that sells the stock of `"shop": "<shop id>"`). A prop with `"travel": "<leg id>"` and a `name` starts that road leg (the station wagon).
- A prop with `"gate": "<gate id>"` and a `name` is a barrier (a fence section, a chained door). Interacting tries the gate; once it opens the prop is gone for good.
- `npcs.when` lists the day phases the person is there: `morning` (6 to 10), `day` (10 to 17), `dusk` (17 to 19), `night` (19 to 6). Missing means always. The same `id` can stand in several maps and rooms at different phases. `sprite` picks a sheet from `assets/sprites` when the id has none.
- `clues.night` makes a trail sign that only exists from that night of the case on. `requires` hides a clue until that evidence is held. Methods are `photograph`, `bag`, `cast`, `measure`; a value of `"spoil"` ruins the others.
- `exits` are walk-on rectangles. `at` is where the party appears in the target map. A `gate` names an entry in the case's `gates` table.
- Interiors: the exit is the whole bottom row. `size` is the floor; walls and the void border are added around it. Room kit sizes: diner 16x10, newspaper 14x12, police 14x12, home 10x8 to 16x12, shop 10x8, church 12x16, records 10x10, motel room 8x6.

## Cases: `data/cases/<case>.json` plus fragments in `data/cases/<case>/*.json`

Fragments are merged into the case at load: dictionaries (`witnesses`, `evidence`,
`contradictions`, `gates`, `locations`, `districts`) by key, lists (`leads`,
`trail`) appended. A district's content lives in its own fragment.

```
"districts": {"riverfront": {"name": "Riverfront", "map": "point_pleasant_riverfront"}},
"gates": {
  "floodgate": {"name": "The floodgate", "locked": "The floodgate is shut for the night.",
    "opens": [ {"item": "sheriff_key"}, {"check": {"voice": "nerve", "difficulty": 9, "prompt": "Climb the floodwall stairs"}},
               {"trust": {"npc": "deputy", "level": 3}}, {"class": "crypto"}, {"flag": "warden_pass"}, {"evidence": "id"}, {"phase": ["morning", "day"]} ]}
},
"trail": [ {"night": 1, "roost": "Abandoned church, Route 62", "map": "point_pleasant_route_62", "clues": ["church_prints", "church_feather"], "herring": ["owl_pellets"]} ],
"witnesses": {"ham": {"trust": 1, "facts": [ {"id": "ham_log", "title": "The 1966 log", "gates": [ {"check": "tech", "difficulty": 8, "prompt": "..."} | {"show": "evidence_id"} | {"contradiction": "id"} | {"trust": 2} ],
                                              "lines": [["ham", "..."]], "evidence": "ham_log_1966"} ]}},
"evidence": {"ham_log_1966": {"title": "...", "text": "...", "lean": "unexplained", "weight": 2, "kind": "document",
                              "red_herring": false, "exposes": ["other_id"], "lab": "lab_result_id", "reliability": "B"}},
"contradictions": {"id": {"prompt": "...", "evidence": ["a", "b"], "witness": "ham"}}
```

A gate opens when any one condition holds. A `check` gate rolls once a day.
Witness facts are the quick format; a witness with a file in `data/dialogue`
gets that script instead, and its `{"topics": true}` option offers the facts.

## Dialogue: `data/dialogue/<case>/<witness>.json`

```
{
  "id": "marlene", "start": "open",
  "nodes": {
    "open": {
      "speaker": "marlene",
      "lines": [["marlene", "I'll tell it once more and that's it."], ["teddy", "She checks the door every time it opens."]],
      "passives": [ {"voice": "empathy", "threshold": 8, "line": "She says 'once more' like someone laughed at ninety times."},
                    {"voice": "logic", "threshold": 10, "line": "Her sister lived the other direction.", "flag": "marlene_sister"} ],
      "static": {"min_dread": 3, "line": "She's lying about the sister. Ask her now."},
      "options": [
        {"tone": "kind", "text": "Take your time.", "next": "story"},
        {"check": {"voice": "press", "kind": "white", "difficulty": 9, "evidence_bonus": {"original_report": 2}},
         "text": "Who laughed at you first?", "pass": "first", "fail": {"next": "earl", "trust": {"earl": -1}, "dread": 1}},
        {"tone": "silent", "text": "(Say nothing.)", "next": "refill", "trust": 1},
        {"requires": {"evidence": ["call_log"], "flag": ["marlene_sister"], "not_flag": [], "trust": 2}, "text": "...", "next": "x"},
        {"topics": true},
        {"show": true},
        {"leave": true, "text": "That's all for now."}
      ],
      "gives": {"evidence": "marlene_statement", "fact": "marlene_open", "flag": "met_marlene", "trust": {"marlene": 1}, "dread": 0},
      "next": "menu"        // where to go when a node has no options
    }
  }
}
```

- Voices: `logic`, `tech`, `recall` (Reason); `press`, `rapport`, `bluff` (Charm); `nerve`, `intimidate`, `fieldcraft` (Grit); `empathy`, `lore`, `arcana` (Intuition). `static` is the thirteenth and needs no level.
- A voice level is the lead's stat (1 to 4) +2 when their class boosts the voice, +1 per partner in the party whose class boosts it, −1 at Dread 3 and −2 at Dread 5. A passive plays when the voice level + 3 meets the threshold, so thresholds of 7 to 10 suit levels of 4 to 7; use 7 for things most leads notice and 10 for a specialist only. A white check rolls 2d6 + voice level + evidence bonus + trust modifier against the difficulty and locks until tomorrow on a failure. A red check locks for the case. Every red check needs a `fail`.
- Tones are `kind`, `hard`, `wry`, `silent`; they colour the option and feed partner approval.
- A node with `"end": true` closes the conversation after its lines. Nodes are visited at most once per day unless `"repeat": true`.
- Voice lines are short, present tense, second person. Voices judge the lead, never the witness.

## Items: `data/items.json`

```
"bolt_cutters": {"name": "Bolt cutters", "text": "Opens chain gates.", "kind": "kit", "price": 40, "reusable": true, "shop": ["variety", "office_store"]},
"slide_rule":   {"name": "Slide rule", "text": "+1 Reason. [Logic] rerolls once a day.", "kind": "tool", "class": "skeptic",
                 "tier": "local", "price": 30, "shop": ["pp_pawn"], "stat": {"reason": 1}, "voice": {"logic": 1}},
"barn_coat":    {"name": "Duck-canvas barn coat", "kind": "coat", "tier": "local", "price": 35, "shop": ["variety"], "stat": {"grit": 1}, "composure": 5},
"bridge_token": {"name": "Silver Bridge memorial token", "kind": "charm", "tier": "local", "price": 12, "shop": ["variety"], "stat": {"intuition": 1}},
"red_eye_lens": {"name": "Red-eye lens", "kind": "relic", "tier": "relic", "case": "point_pleasant", "verdict": "unexplained", "stat": {"intuition": 2}},
"coffee":       {"name": "Coffee", "kind": "consumable", "price": 1, "shop": ["variety"], "restore": {"composure": 20}}
```

- Kinds: `tool` (one per class, `class` names it), `coat`, `charm` (two slots), `relic` (goes in a charm slot, dropped by a verdict: `case` + `verdict`), `kit` (processing and gates; `reusable` is not used up), `consumable` (`restore` composure or dread, `cure`).
- Tiers: `issue` (starting kit), `store`, `local`, `vintage`, `relic`. `shop` lists the shop ids that stock it (an NPC with `"shop": "<id>"` sells that stock; a map prop with `pickup` and `price` sells one item).
- Every class has exactly one `issue` tier tool, equipped from the start; the Office trench is the issue coat.
- Equipped gear adds `stat` to the wearer's stats and `voice` to voice levels when they lead; `composure` adds to max composure.

## Shops

An NPC with `"shop": "variety"` in a map opens a buy menu listing every item whose `shop` list has that id, priced by `price`, paid from the party's cash. A prop with `"pickup": "film", "price": 4` sells one; add `"restock": true` for one a day.

## The Office: `data/office.json`

```
{
  "rooms": {"darkroom": {"name": "Darkroom", "text": "...", "opens": {"verdicts": 1} | {"tier": 2} | {}}},
  "upgrades": {"enlarger": {"name": "Enlarger", "room": "darkroom", "cost": 2, "tier": 2, "text": "...", "flag": "office_enlarger"}},
  "car": {"cb_radio": {"name": "CB radio", "cost": 3, "text": "...", "flag": "car_cb_radio"}},
  "tiers": [0, 4, 8],
  "budget": {"verdict": 1, "truth": 2, "rating_a": 1}
}
```

Rooms are interiors of the Sutton map (`data/maps/sutton_office.json`); a room whose `opens` is not met is a locked facade (gate `office_<room>`). Upgrades and car upgrades cost budget points; buying one sets its `flag`, which gates and dialogue can read. Budget comes from filing verdicts at the sorting-room case board: `verdict` points for any verdict, `truth` more when it matches the case's `truth`, `rating_a` more for an A rating.

## The road: `data/road.json`

```
{
  "legs": {
    "sutton_to_point_pleasant": {"name": "Sutton to Point Pleasant", "from": "sutton", "to": "point_pleasant",
      "arrive_map": "point_pleasant_main_street", "arrive_at": [12, 26], "hours": 4,
      "stops": [ {"name": "Gassaway", "text": "...", "highway": "I-79 south", "back": "Route 4 along the Elk",
                  "events": ["pie_diner"], "sights": "..."} ],
      "deck": ["hitchhiker", "breakdown", "lights"], "stations": ["wchs", "wvaq", "numbers_1", "tone"]}
  },
  "events": {
    "hitchhiker": {"title": "A hitchhiker with a guitar case", "text": "...", "when": ["day"], "roads": ["back"],
      "options": [ {"text": "Give him a ride", "line": "...", "gives": {"flag": "road_song", "item": "x", "cash": -5, "gas": -1, "dread": 1, "composure": -10, "hours": 1}},
                   {"text": "Fix it yourself", "check": {"voice": "fieldcraft", "difficulty": 8}, "line": "...", "fail": {"line": "...", "gives": {"hours": 5}}},
                   {"text": "Drive on"} ]}
  },
  "stations": {"wchs": {"name": "WCHS 580", "band": "am", "freq": 580, "kind": "local", "when": ["day", "night"], "text": "...", "gives": {"flag": "heard_wchs"}}}
}
```

- A leg is five to eight stops. At each the party picks highway (one hour, few events) or back road (two hours, an event from the stop's `events` or the leg's `deck`, filtered by `when` phase and `roads`), scans the radio, and can spend cash on gas or a motel. `gives` keys: `item`, `flag`, `cash`, `gas`, `dread`, `composure`, `hours`, `evidence`.
- Station kinds: `local` (news previews the case), `callin`, `numbers`, `tone` (the three-note tone, night only, near a case). `freq` is in the band's range (88 to 108 FM, 540 to 1600 AM). Logging a station adds it to the radio log and applies `gives` once.
