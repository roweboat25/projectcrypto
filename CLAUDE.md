# Notes for Claude

- Engine: Godot 4.3 stable. Everything is 2D (`gl_compatibility`, `variant/thread_support=false`, 640x360 viewport scaled with integer `canvas_items` stretch). Don't use features that only work in Forward+.
- Art style follows "The Hunger Beneath Us": flat top-down LPC Revised 32px pixel art, layered characters, 96px portraits in the dialogue box. Keep `texture_filter` nearest and everything on whole pixels.
- Art is generated, not hand-placed: `tools/build_art.py` (Pillow) composes `assets/tiles`, `assets/props`, `assets/facades`, `assets/characters` and `assets/portraits` from the LPC Revised sheets kept in `assets/lpc_src`. Run it with `LPC_SRC=<full LPC checkout>` (and `GEN_PORTRAITS=<dir of generated faces>`) after changing a recipe; commit the output. Every sheet used must be listed in `assets/CREDITS.md` (the script writes it).
- Content is data: cases, witnesses, evidence and contradictions live in `data/cases/*.json`, maps and interiors in `data/maps/*.json`, classes and foes in `data/*.json`. Extend `GameData.validate()` and `tests/run_tests.gd` so CI catches broken references.
- Speech checks and evidence rules are in `scripts/investigation.gd` (static, no scene access) so tests can drive them with forced rolls.
- Run `tests/run_tests.gd` headless before pushing; CI runs the same check and the web export.
- Web debug: `?inside=<room>`, `?at=x,y` (tiles) and `?time=0..1` on the index URL jump the party around for screenshots.
- Design source of truth: the "Anomaly Files: JRPG Design Plan" doc, section "Systems v2" and "Season 1 build plan".
