# Notes for Claude

- Engine: Godot 4.3 stable. Web exports use `gl_compatibility` and `variant/thread_support=false`; don't use features that only work in Forward+ without a Compatibility fallback.
- Content is data: add cases, classes and foes in `data/*.json`, then extend `GameData.validate()` so CI catches broken references.
- Run `tests/run_tests.gd` headless before pushing; CI runs the same check and the web export.
- Placeholder art is drawn in `scripts/placeholder_art.gd` until real sprites land; real art follows the Season 1 art brief (32x48 sprites, nearest filtering).
- Design source of truth: the "Anomaly Files: JRPG Design Plan" doc, section "Systems v2" and "Season 1 build plan".
