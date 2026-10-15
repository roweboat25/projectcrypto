# The Casebook of Unquiet Places

A top-down pixel-art investigation JRPG about real anomalous events, built in Godot 4.3.
It is 1994, and the Sutton Office sends a small team to the sites of famous
sightings to find out what really happened: Hoax, Natural or Unexplained.

Season 1 covers three cases: Point Pleasant (Mothman), Sandown (the Sandown
Clown) and Kelly (the Kelly-Hopkinsville encounter).

## Play

Every push to `main` builds the game for the web and publishes it to GitHub
Pages: https://roweboat25.github.io/projectcrypto/

WASD walks the party, Space talks to witnesses, inspects clues and opens doors,
Tab opens the case file, T flips day and night, F5 saves and F9 loads.
Speech checks roll a d6 plus the party's best stat against a difficulty; a
failed check is closed until you sleep at the motel, which also brings back
lab results on anything you bagged.

The loop: the Sutton Office is home. The station wagon in the loading dock
drives to a case (or, for Sandown, to Dulles and a flight, a train, a hovercraft
and the Island Line), the road has stops with events and a radio to tune, and a
verdict filed at the Office case board pays budget that opens rooms and
upgrades. G opens the gear bag. Sandown runs on the tide: the HUD shows it, and
the beach under Culver cliffs opens only at low water.

## Layout

| Path | What lives there |
| --- | --- |
| `data/` | All game content as JSON: classes, partners, foes, cases (with per-district fragments), one map per district, scripted dialogue, items |
| `docs/` | `content-format.md`, the schema for maps, cases, dialogue and items |
| `assets/` | Generated tiles, props, storefronts, character sheets and portraits (see `assets/CREDITS.md`) |
| `tools/` | `build_art.py`, which composes `assets/` from LPC Revised sheets, and `check_content.py`, which checks data references |
| `scripts/autoload/` | `GameData` (loads and validates content) and `GameState` (progress and saves) |
| `scripts/` | Scene scripts; `investigation.gd` holds the speech check and evidence rules |
| `scenes/` | Godot scenes; `boot.tscn` is the entry point |
| `tests/` | Headless checks run in CI |

## Develop

```sh
godot --headless --path . --import
python3 tools/check_content.py                            # data references, no Godot needed
godot --headless --path . -s res://tests/run_tests.gd   # rules, saves, scripts compile
godot --headless --path . --export-release "Web" build/web/index.html
```

The web export uses the Compatibility renderer and no threads, so it runs on
GitHub Pages without special server headers.

Art comes from the LPC Revised project (CC-BY 3.0 / OGA-BY 3.0). To rebuild it
after changing a recipe in `tools/build_art.py`:

```sh
git clone https://github.com/ElizaWy/LPC /tmp/lpc
LPC_SRC=/tmp/lpc python3 tools/build_art.py
```
