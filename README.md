# Hearthmere (working title)

An original 2D god-sandbox civilization simulator built with Godot 4.7.

Canonical project memory lives in `docs/` — start with `docs/GAME_SPEC.md` and `docs/ARCHITECTURE.md`.

## Running

```
godot --path .                                   # play
godot --headless --path . -s res://tests/run_tests.gd -- --skip-slow   # fast tests
godot --headless --path . -s res://tests/run_tests.gd                  # all tests incl. 100k-tick runs
godot --headless --path . -s res://tools/smoke.gd -- <ticks> <seed> <size>
```
