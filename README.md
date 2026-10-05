# Camboree

A cozy, silly, low-poly photography RPG for 1–4 players, set in **Ayesso City**. Think Stardew Valley meets Pokémon Snap, with some WarioWare and Katamari in the mix.

- Game design document: [`docs/design/GDD.md`](docs/design/GDD.md)
- Photo scoring spec: [`docs/design/scoring-v0.md`](docs/design/scoring-v0.md)

## Getting started

1. Install **[Godot 4.7](https://godotengine.org/download)** (standard build, GDScript only, no .NET needed).
2. Clone this repo and open `project.godot` in Godot (**Import** → select the folder).
3. Press **F5**. It opens the scoring sandbox.

## Scoring sandbox controls

| Action | Keyboard / mouse | Controller |
|---|---|---|
| Move / look | WASD / mouse | Left stick / right stick |
| Shoot | Left click or Space | A |
| Autofocus (center of frame) | Right click or T | Left trigger |
| Manual focus | Mouse wheel or Z / X | D-pad left / right |
| Pick setting (aperture, shutter, ISO, focal length) | Q / E | LB / RB |
| Change value | R / F or ↑ / ↓ | D-pad up / down |
| Free / capture mouse | Esc | Start |

Every shot shows a star rating, a per-pillar breakdown (focus, exposure, placement, visibility), and a tip. The scene's lighting is set by `scene_ev` on the root node, and every scoring constant is in `resources/scoring/default_scoring_config.tres`.

## Project layout

```
docs/design/       Design docs (GDD, scoring spec)
scenes/sandbox/    Prototype scenes
scripts/photo/     Camera, subject, and scoring code (ShotData, ScoringConfig, PhotoScoring)
scripts/sandbox/   Sandbox-only helpers (player controller, input setup)
scripts/ui/        HUD
resources/         Tunable .tres resources
assets/            Models, textures, audio, fonts
tests/             Headless test scripts
```

## Running tests

```sh
godot --headless --import --path .
godot --headless --path . -s res://tests/test_scoring.gd
godot --headless --path . -s res://tests/test_sandbox.gd
```

GitHub Actions runs the same commands on every push (`.github/workflows/ci.yml`).
