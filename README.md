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
| Pick dial (ISO, shutter, aperture, zoom) | Q / E | LB / RB |
| Turn the selected dial | R / F or ↑ / ↓ | D-pad up / down |
| Pause / resume music | M | Back |
| Free / capture mouse | Esc | Start |

**First start:** the camera begins with its settings out of whack (exposure 2–3.5 stops off, focus far too close). During the first round a coach checklist under the brief shows what's wrong live, phrased for the dial you have selected ("3.0 stops too bright · close the APERTURE (R)"), and turns green when everything is fixed. You can still shoot at any time, but a bad setup scores badly. `scramble_on_start` and `coach_rounds` on the root node control this.

**The HUD:** four camera dials rise from the bottom of the screen: ISO, shutter, aperture, and zoom. Q/E moves between them. The selected dial lifts and shows curved arrows, and R/F turns it with a click.

**The round:** get a 4-star shot of the wanderer within 5 shots. After each shot, the photo drops in as a polaroid. Stars pop in one at a time with rising chimes (a sad "bwomp" means 0 stars), bars fill in for each pillar (Focus, Exposure, Framing, In view), and a tip coaches your weakest pillar. Shoot again after a round ends to start a new one. You can tune `target_stars` and `shots_per_round` on the scene's root node.

Background music: *Journey to Tomorrow* (`assets/audio/music/`), looping. Sound effects are still placeholders synthesized in code (`scripts/audio/sfx.gd`). The scene's lighting is set by `scene_ev` on the root node, and every scoring constant is in `resources/scoring/default_scoring_config.tres`.

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
