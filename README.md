# The Casebook of Unquiet Places

An HD-2D investigation JRPG about real anomalous events, built in Godot 4.3.
It is 1994, and the Sutton Office sends a small team to the sites of famous
sightings to find out what really happened: Hoax, Natural or Unexplained.

Season 1 covers three cases: Point Pleasant (Mothman), Sandown (the Sandown
Clown) and Kelly (the Kelly-Hopkinsville encounter).

## Play

Every push to `main` builds the game for the web and publishes it to GitHub
Pages: https://roweboat25.github.io/projectcrypto/

## Layout

| Path | What lives there |
| --- | --- |
| `data/` | All game content as JSON: classes, partners, foes, and one file per case |
| `scripts/autoload/` | `GameData` (loads and validates content) and `GameState` (progress and saves) |
| `scripts/` | Scene scripts and code-drawn placeholder art |
| `scenes/` | Godot scenes; `boot.tscn` is the entry point |
| `tests/` | Headless checks run in CI |

## Develop

```sh
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd   # data and save checks
godot --headless --path . --export-release "Web" build/web/index.html
```

The web export uses the Compatibility renderer and no threads, so it runs on
GitHub Pages without special server headers. Desktop builds use Forward+.
