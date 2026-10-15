#!/usr/bin/env python3
"""Checks every reference in data/ against the art library and the other data
files, the same checks GameData.validate() runs in the engine, so content can
be checked without Godot. Exit status 1 when anything is broken."""
import glob
import json
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
VOICES = ["logic", "tech", "recall", "press", "rapport", "bluff", "nerve", "intimidate", "fieldcraft", "empathy", "lore", "arcana"]
TONES = ["kind", "hard", "wry", "silent"]
PHASES = ["morning", "day", "dusk", "night"]
METHODS = ["photograph", "bag", "cast", "measure"]
STATS = ["reason", "charm", "grit", "intuition"]
ITEM_KINDS = ["tool", "coat", "charm", "kit", "consumable", "relic"]
TIERS = ["issue", "store", "local", "vintage", "relic"]
VERDICTS = ["hoax", "natural", "unexplained"]
GIVES_KEYS = ["item", "flag", "cash", "gas", "dread", "composure", "hours", "evidence"]
SOLID = ("wall_", "brick_", "stone_", "drywall_", "window_", "frame_", "void", "water", "cement_edge")


def load(path):
    with open(path) as f:
        return json.load(f)


def main():
    errors = []
    warnings = []

    def err(msg):
        errors.append(msg)

    props = load(os.path.join(ROOT, "assets/props/props.json"))
    tiles = load(os.path.join(ROOT, "assets/tiles/atlas.json"))
    facades = load(os.path.join(ROOT, "assets/facades/facades.json"))
    sprites = {os.path.basename(p)[:-4] for p in glob.glob(os.path.join(ROOT, "assets/sprites/*.png"))}
    items = load(os.path.join(ROOT, "data/items.json")) if os.path.exists(os.path.join(ROOT, "data/items.json")) else {}
    roster = load(os.path.join(ROOT, "data/roster.json"))
    classes = load(os.path.join(ROOT, "data/classes.json"))

    # cases with fragments merged
    cases = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "data/cases/*.json"))):
        c = load(path)
        cid = c.get("id", os.path.basename(path)[:-5])
        for frag in sorted(glob.glob(os.path.join(ROOT, "data/cases", cid, "*.json"))):
            f = load(frag)
            for k, v in f.items():
                if k.startswith("_"):
                    continue
                if isinstance(v, dict):
                    dup = set(v) & set(c.get(k, {}))
                    if dup:
                        err("%s redefines %s %s" % (os.path.relpath(frag, ROOT), k, sorted(dup)))
                    c.setdefault(k, {}).update(v)
                elif isinstance(v, list):
                    c.setdefault(k, []).extend(v)
                else:
                    c[k] = v
        cases[cid] = c
        items.update(c.get("items", {}))
    maps = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "data/maps/*.json"))):
        m = load(path)
        maps[m.get("id", os.path.basename(path)[:-5])] = m
    dialogues = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "data/dialogue/*/*.json"))):
        d = load(path)
        case_id = os.path.basename(os.path.dirname(path))
        dialogues.setdefault(case_id, {})[d.get("id", os.path.basename(path)[:-5])] = d

    def tile_ok(t, where):
        for name in ([t] if isinstance(t, str) else t):
            if name not in tiles:
                err("%s uses unknown tile %s" % (where, name))

    road_path = os.path.join(ROOT, "data/road.json")
    road = load(road_path) if os.path.exists(road_path) else {}
    all_gates = {}
    for c in cases.values():
        all_gates.update(c.get("gates", {}))
    shops = set()
    for m in maps.values():
        for n in m.get("npcs", []):
            if n.get("shop"):
                shops.add(n["shop"])
        for room in m.get("interiors", {}).values():
            for n in room.get("npcs", []):
                if n.get("shop"):
                    shops.add(n["shop"])

    for mid, m in maps.items():
        case = cases.get(m.get("case", ""), {})
        evidence = case.get("evidence", {})
        witnesses = case.get("witnesses", {})
        gates = all_gates
        if m.get("case") not in cases:
            err("map %s has unknown case %s" % (mid, m.get("case")))
        ground = m.get("ground", "snow")
        for v in (ground, ground + "2", ground + "3"):
            if v not in tiles:
                err("map %s ground variant %s missing" % (mid, v))
        for f in m.get("fills", []):
            tile_ok(f["tiles"], "map %s fill %s" % (mid, f.get("rect")))
        for s in m.get("scatter", []):
            tile_ok(s["tiles"], "map %s scatter" % mid)
        building_ids = []
        for f in m.get("facades", []):
            building_ids.append(f["id"])
            if f.get("facade", f["id"]) not in facades:
                err("map %s facade %s has no drawn storefront" % (mid, f.get("facade", f["id"])))
            if f.get("gate") and f["gate"] not in gates:
                err("map %s facade %s uses unknown gate %s" % (mid, f["id"], f["gate"]))
            if not f.get("locked") and f["id"] not in m.get("interiors", {}):
                err("map %s facade %s is open but has no interior" % (mid, f["id"]))
        for h in m.get("houses", []):
            building_ids.append(h["id"])
            if h["prop"] not in props:
                err("map %s house %s uses unknown prop %s" % (mid, h["id"], h["prop"]))
            if not h.get("locked") and h["id"] not in m.get("interiors", {}):
                err("map %s house %s is open but has no interior" % (mid, h["id"]))
        for iid in m.get("interiors", {}):
            if iid not in building_ids:
                err("map %s interior %s has no facade or house" % (mid, iid))

        def check_props(plist, where):
            for p in plist:
                if p["kind"] not in props:
                    err("%s prop %s unknown" % (where, p["kind"]))
                if p.get("pickup") and p["pickup"] not in items:
                    err("%s pickup %s is not in items.json" % (where, p["pickup"]))
                if p.get("restock") and not p.get("price"):
                    err("%s prop restocks but has no price" % where)
                if p.get("travel") and p["travel"] not in road.get("legs", {}):
                    err("%s prop drives unknown leg %s" % (where, p["travel"]))
                if p.get("gate") and p["gate"] not in gates:
                    err("%s prop gate %s unknown" % (where, p["gate"]))
                look = p.get("look")
                if isinstance(look, list):
                    for line in look:
                        if not (isinstance(line, list) and len(line) == 2):
                            err("%s look line %r is not [speaker, text]" % (where, line))

        def check_npcs(nlist, where):
            for n in nlist:
                sheet = n.get("sprite", n["id"])
                if sheet not in sprites:
                    err("%s npc %s has no sprite sheet %s" % (where, n["id"], sheet))
                for ph in n.get("when", []):
                    if ph not in PHASES:
                        err("%s npc %s has unknown phase %s" % (where, n["id"], ph))
                if n.get("shop") and not any(n["shop"] in it.get("shop", []) for it in items.values() if isinstance(it, dict)):
                    err("%s npc %s runs shop %s but no item is stocked there" % (where, n["id"], n["shop"]))
                if n["id"] not in witnesses and n["id"] not in dialogues.get(m.get("case", ""), {}) and not n.get("shop"):
                    warnings.append("%s npc %s has no witness entry or dialogue (will use a stock line)" % (where, n["id"]))

        def check_clues(clist, where):
            for c in clist:
                if c.get("prop", "clue_prints") not in props:
                    err("%s clue %s uses unknown prop" % (where, c["id"]))
                if not c.get("methods"):
                    err("%s clue %s has no methods" % (where, c["id"]))
                for method, result in c.get("methods", {}).items():
                    if method not in METHODS:
                        err("%s clue %s has unknown method %s" % (where, c["id"], method))
                    if result != "spoil" and result not in evidence:
                        err("%s clue %s method %s gives missing evidence %s" % (where, c["id"], method, result))
                if c.get("requires") and c["requires"] not in evidence:
                    err("%s clue %s requires missing evidence %s" % (where, c["id"], c["requires"]))

        check_props(m.get("props", []), "map %s" % mid)
        check_npcs(m.get("npcs", []), "map %s" % mid)
        check_clues(m.get("clues", []), "map %s" % mid)
        for iid, room in m.get("interiors", {}).items():
            where = "map %s room %s" % (mid, iid)
            if "size" not in room:
                err(where + " has no size")
            for v in room.get("floor", ["wood_warm"]):
                if v not in tiles:
                    err("%s floor tile %s missing" % (where, v))
            if "wall_%s_top" % room.get("wall", "cream") not in tiles:
                err("%s wall colour %s missing" % (where, room.get("wall")))
            check_props(room.get("props", []), where)
            check_npcs(room.get("npcs", []), where)
            check_clues(room.get("clues", []), where)
        for e in m.get("exits", []):
            if e["to"] not in maps:
                err("map %s exit to unknown map %s" % (mid, e["to"]))
            if e.get("gate") and e["gate"] not in gates:
                err("map %s exit uses unknown gate %s" % (mid, e["gate"]))

    for iid, it in items.items():
        if not isinstance(it, dict):
            continue
        w = "item %s" % iid
        if it.get("kind") not in ITEM_KINDS:
            err("%s has unknown kind %s" % (w, it.get("kind")))
        if "tier" in it and it["tier"] not in TIERS:
            err("%s has unknown tier %s" % (w, it["tier"]))
        if it.get("kind") == "tool" and it.get("class") not in classes:
            err("%s is a tool with no class" % w)
        for st in it.get("stat", {}):
            if st not in STATS:
                err("%s boosts unknown stat %s" % (w, st))
        for v in it.get("voice", {}):
            if v not in VOICES:
                err("%s boosts unknown voice %s" % (w, v))
        if it.get("kind") == "relic":
            if it.get("case") not in cases:
                err("%s relic names unknown case" % w)
            if it.get("verdict") not in VERDICTS:
                err("%s relic needs a verdict (hoax, natural, unexplained)" % w)
        for sh in it.get("shop", []):
            if sh not in shops:
                warnings.append("%s is stocked in shop %s, which no npc runs" % (w, sh))
        if it.get("shop") and not it.get("price"):
            err("%s is in a shop with no price" % w)

    office_path = os.path.join(ROOT, "data/office.json")
    office = load(office_path) if os.path.exists(office_path) else {}
    for rid, r in office.get("rooms", {}).items():
        for k in r.get("opens", {}):
            if k not in ("verdicts", "tier", "flag"):
                err("office room %s opens on unknown key %s" % (rid, k))
    for uid, u in list(office.get("upgrades", {}).items()) + list(office.get("car", {}).items()):
        if "cost" not in u or "flag" not in u:
            err("office upgrade %s needs cost and flag" % uid)
        if u.get("room") and u["room"] not in office.get("rooms", {}):
            err("office upgrade %s names unknown room %s" % (uid, u["room"]))
        if u.get("tier") and u["tier"] > len(office.get("tiers", [0])):
            err("office upgrade %s needs a tier that does not exist" % uid)

    def check_gives(gv, where):
        for k in gv:
            if k not in GIVES_KEYS:
                err("%s gives unknown key %s" % (where, k))
        if gv.get("item") and gv["item"] not in items:
            err("%s gives unknown item %s" % (where, gv["item"]))

    events = road.get("events", {})
    stations = road.get("stations", {})
    for lid, leg in road.get("legs", {}).items():
        w = "road leg %s" % lid
        if leg.get("from") not in list(cases) + ["sutton"] or leg.get("to") not in list(cases) + ["sutton"]:
            err("%s runs between unknown places %s and %s" % (w, leg.get("from"), leg.get("to")))
        if leg.get("arrive_map") not in maps:
            err("%s arrives at unknown map %s" % (w, leg.get("arrive_map")))
        if not 3 <= len(leg.get("stops", [])) <= 8:
            err("%s should have 3 to 8 stops, has %d" % (w, len(leg.get("stops", []))))
        for st in leg.get("stops", []):
            for e in st.get("events", []):
                if e not in events:
                    err("%s stop %s names unknown event %s" % (w, st.get("name"), e))
        for e in leg.get("deck", []):
            if e not in events:
                err("%s deck names unknown event %s" % (w, e))
        for st in leg.get("stations", []):
            if st not in stations:
                err("%s names unknown station %s" % (w, st))
    for eid, ev in events.items():
        w = "road event %s" % eid
        for ph in ev.get("when", []):
            if ph not in PHASES:
                err("%s has unknown phase %s" % (w, ph))
        for rd in ev.get("roads", []):
            if rd not in ("highway", "back"):
                err("%s has unknown road kind %s" % (w, rd))
        if not ev.get("options"):
            err("%s has no options" % w)
        for o in ev.get("options", []):
            check_gives(o.get("gives", {}), w)
            if "check" in o:
                if o["check"].get("voice") not in VOICES:
                    err("%s check has unknown voice" % w)
                if "fail" not in o:
                    err("%s check option needs a fail" % w)
                check_gives(o.get("fail", {}).get("gives", {}), w)
    for sid, st in stations.items():
        w = "road station %s" % sid
        if st.get("band") not in ("am", "fm"):
            err("%s band must be am or fm" % w)
        lo, hi = (540, 1600) if st.get("band") == "am" else (88, 108)
        if not lo <= float(st.get("freq", 0)) <= hi:
            err("%s frequency %s is off the dial" % (w, st.get("freq")))
        if st.get("kind") not in ("local", "callin", "numbers", "tone"):
            err("%s has unknown kind %s" % (w, st.get("kind")))
        check_gives(st.get("gives", {}), w)

    for cid, c in cases.items():
        evidence = c.get("evidence", {})
        witnesses = c.get("witnesses", {})
        contradictions = c.get("contradictions", {})
        for e, ev in evidence.items():
            if ev.get("lean") not in ("hoax", "natural", "unexplained"):
                err("case %s evidence %s has a bad lean" % (cid, e))
            for x in ev.get("exposes", []):
                if x not in evidence:
                    err("case %s evidence %s exposes missing %s" % (cid, e, x))
            if ev.get("lab") and ev["lab"] not in evidence:
                err("case %s evidence %s has a missing lab result" % (cid, e))
        for wid, w in witnesses.items():
            for fact in w.get("facts", []):
                if fact.get("evidence") and fact["evidence"] not in evidence:
                    err("case %s witness %s fact %s gives missing evidence" % (cid, wid, fact.get("id")))
                if not fact.get("gates"):
                    err("case %s witness %s fact %s has no gate" % (cid, wid, fact.get("id")))
                for gate in fact.get("gates", []):
                    if "check" in gate and gate["check"] not in VOICES:
                        err("case %s fact %s has unknown voice %s" % (cid, fact.get("id"), gate["check"]))
                    if "check" in gate and "prompt" not in gate:
                        err("case %s fact %s check has no prompt" % (cid, fact.get("id")))
                    if "show" in gate and gate["show"] not in evidence:
                        err("case %s fact %s asks for missing evidence %s" % (cid, fact.get("id"), gate["show"]))
                    if "contradiction" in gate and gate["contradiction"] not in contradictions:
                        err("case %s fact %s uses missing contradiction" % (cid, fact.get("id")))
        for xid, x in contradictions.items():
            for e in x.get("evidence", []):
                if e not in evidence:
                    err("case %s contradiction %s uses missing evidence %s" % (cid, xid, e))
            if x.get("witness") not in witnesses:
                err("case %s contradiction %s has no witness" % (cid, xid))
        for gid, g in c.get("gates", {}).items():
            if not g.get("opens"):
                err("case %s gate %s has no way through" % (cid, gid))
            for cond in g.get("opens", []):
                if "item" in cond and cond["item"] not in items:
                    err("case %s gate %s needs unknown item %s" % (cid, gid, cond["item"]))
                if "trust" in cond and cond["trust"].get("npc") not in witnesses:
                    err("case %s gate %s trusts unknown witness" % (cid, gid))
                if "check" in cond and cond["check"].get("voice") not in VOICES:
                    err("case %s gate %s has unknown voice" % (cid, gid))
                if "class" in cond and cond["class"] not in classes:
                    err("case %s gate %s has unknown class" % (cid, gid))
                if "evidence" in cond and cond["evidence"] not in evidence:
                    err("case %s gate %s needs unknown evidence" % (cid, gid))
                if "phase" in cond and any(ph not in PHASES for ph in cond["phase"]):
                    err("case %s gate %s has an unknown phase" % (cid, gid))
        for d in c.get("districts", {}).values():
            if d.get("map") not in maps:
                err("case %s district %s has unknown map %s" % (cid, d.get("name"), d.get("map")))
        clue_nights = {}
        for mid, m in maps.items():
            if m.get("case") != cid:
                continue
            for cl in m.get("clues", []):
                clue_nights[cl["id"]] = cl.get("night", 0)
            for room in m.get("interiors", {}).values():
                for cl in room.get("clues", []):
                    clue_nights[cl["id"]] = cl.get("night", 0)
        for t in c.get("trail", []):
            if t.get("map") not in maps:
                err("case %s trail night %s names unknown map" % (cid, t.get("night")))
            for cl in t.get("clues", []) + t.get("herring", []):
                if cl not in clue_nights:
                    err("case %s trail night %s names unknown clue %s" % (cid, t.get("night"), cl))
                elif cl in t.get("clues", []) and clue_nights[cl] != t.get("night"):
                    err("case %s trail clue %s is placed with night %s, not %s" % (cid, cl, clue_nights[cl], t.get("night")))

    for cid, scripts in dialogues.items():
        case = cases.get(cid, {})
        evidence = case.get("evidence", {})
        witnesses = case.get("witnesses", {})
        for wid, d in scripts.items():
            nodes = d.get("nodes", {})
            where = "dialogue %s/%s" % (cid, wid)
            if d.get("start") not in nodes:
                err("%s start node missing" % where)
            for nid, n in nodes.items():
                w = "%s node %s" % (where, nid)
                if not n.get("lines") and not n.get("line"):
                    err(w + " has no lines")
                for line in n.get("lines", []):
                    if not (isinstance(line, list) and len(line) == 2):
                        err("%s line %r is not [speaker, text]" % (w, line))
                for p in n.get("passives", []):
                    if p.get("voice") not in VOICES:
                        err("%s passive has unknown voice %s" % (w, p.get("voice")))
                if n.get("next") and n["next"] not in nodes:
                    err("%s next %s missing" % (w, n["next"]))
                g = n.get("gives", {})
                if g.get("evidence") and g["evidence"] not in evidence:
                    err("%s gives missing evidence %s" % (w, g["evidence"]))
                for o in n.get("options", []):
                    if o.get("topics") or o.get("show") or o.get("leave"):
                        continue
                    if "text" not in o:
                        err("%s option without text" % w)
                    if o.get("tone") and o["tone"] not in TONES:
                        err("%s option has unknown tone %s" % (w, o["tone"]))
                    if o.get("next") and o["next"] not in nodes:
                        err("%s option next %s missing" % (w, o["next"]))
                    if "check" in o:
                        ch = o["check"]
                        if ch.get("voice") not in VOICES:
                            err("%s check has unknown voice %s" % (w, ch.get("voice")))
                        if ch.get("kind", "white") not in ("white", "red"):
                            err("%s check kind must be white or red" % w)
                        for e in ch.get("evidence_bonus", {}):
                            if e not in evidence:
                                err("%s evidence_bonus names missing evidence %s" % (w, e))
                        if o.get("pass") not in nodes:
                            err("%s check pass node missing" % w)
                        fail = o.get("fail")
                        if ch.get("kind") == "red" and not fail:
                            err("%s red check has no fail branch" % w)
                        if fail and fail.get("next") and fail["next"] not in nodes:
                            err("%s fail next %s missing" % (w, fail["next"]))
                    elif "next" not in o:
                        err("%s option '%s' goes nowhere" % (w, o.get("text")))
                    req = o.get("requires", {})
                    for e in req.get("evidence", []):
                        if e not in evidence:
                            err("%s option requires missing evidence %s" % (w, e))
                    gv = o.get("gives", {})
                    if gv.get("evidence") and gv["evidence"] not in evidence:
                        err("%s option gives missing evidence %s" % (w, gv["evidence"]))
            if wid not in witnesses:
                warnings.append("%s has no witness entry (topics option will be empty)" % where)

    for w in warnings:
        print("warning:", w)
    for e in errors:
        print("error:", e)
    print("%d maps, %d cases, %d dialogue scripts, %d errors, %d warnings" % (len(maps), len(cases), sum(len(v) for v in dialogues.values()), len(errors), len(warnings)))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
