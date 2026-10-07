# Camboree

A cozy, silly, low-poly photography RPG for 1–4 players. Think Stardew Valley meets Pokémon Snap, with some WarioWare and Katamari in the mix.

- Game design document: [`docs/design/GDD.md`](docs/design/GDD.md)
- Photo scoring spec: [`docs/design/scoring-v0.md`](docs/design/scoring-v0.md)
- Audio manifest (every music track and sound effect): [`docs/audio-manifest.md`](docs/audio-manifest.md)
- UI manifest (fonts, icon, every HUD element and color): [`docs/ui-manifest.md`](docs/ui-manifest.md)
- Art to replace (code-drawn placeholders, with screenshots): [`docs/art-replacement.md`](docs/art-replacement.md)

## Getting started

1. Install **[Godot 4.7](https://godotengine.org/download)** (standard build, GDScript only, no .NET needed).
2. Clone this repo and open `project.godot` in Godot (**Import** → select the folder).
3. Press **F5**. It opens the scoring sandbox.

## Scoring sandbox controls

| Action | Keyboard / mouse | Controller |
|---|---|---|
| Move / look | WASD / mouse | Left stick / right stick |
| Raise camera (aim down sights) | **Hold** right click | **Hold** left trigger |
| Jump | Space | A |
| Shoot (camera raised) | Left click | Right trigger |
| Autofocus (camera raised): tap = once, hold = track | Shift | X |
| Jump to a dial: 1 ISO, 2 shutter, 3 aperture, 4 zoom, 5 focus | **1–5** | — |
| Step to the previous / next dial | Q / E | LB / RB or D-pad left / right |
| Turn the selected dial | **Mouse wheel** (or ↑ / ↓) | D-pad up / down |
| Pause / resume music | M | Back |
| Free / capture mouse | Esc | Start |

**Two views:** you explore in third person with an over-the-shoulder camera, so you can see your photographer. Like Fortnite, the character always faces where your crosshair points: turning the camera turns the body, A/D strafe, and the head tilts with your aim. Hold right click to raise the camera to your eye, like aiming down sights in a shooter: the view slides from your shoulder into the camera in 0.15 s, the field of view narrows to the lens, and it opens exactly where your aim dot was. You can slow-walk while aiming, look sensitivity drops on longer lenses, and releasing snaps you back out. You can only shoot with the camera raised. The viewfinder shows the camera's real exposure and depth of field, while the shoulder view always looks normal.

**Autofocus is a motor, not a snap:** Shift racks the lens toward whatever is under the focus bracket over about a third of a second, with a whir, then a double beep and a green bracket on lock. Shoot before it locks and you can miss focus. Hold Shift to keep tracking a moving subject. With nothing under the bracket (sky), the lens hunts and gives up with a red bracket.

**First start:** the camera begins with its settings out of whack (exposure 2–3.5 stops off, focus far too close). During the first round a coach checklist under the brief shows what's wrong live, phrased for the dial you have selected ("3.0 stops too bright · close the APERTURE (scroll up)"), and turns green when everything is fixed. You can still shoot at any time, but a bad setup scores badly. `scramble_on_start` and `coach_rounds` on the root node control this.

**The HUD:** five camera dials rise from the bottom of the screen: ISO, shutter, aperture, zoom, and focus. Keys 1–5 jump straight to a dial (each shows its number), and Q/E step between neighbors. The selected dial lifts and shows curved arrows, and the mouse wheel turns it with a click. Focus is a lens ring marked 0.3 m to infinity (spaced like a real lens scale): each wheel notch turns it a third of a mark, and autofocus turns it for you as the lens racks. The dials work in both views: compact while exploring (so you can preset exposure before the action), full size in the viewfinder.

**The round:** get a 4-star shot of the wanderer within 5 shots. After each shot, the photo drops in as a polaroid. Stars pop in one at a time with rising chimes (a sad "bwomp" means 0 stars), bars fill in for each pillar (Focus, Exposure, Framing, In view), and a tip coaches your weakest pillar. Shoot again after a round ends to start a new one. You can tune `target_stars` and `shots_per_round` on the scene's root node.

UI font: *Font V1* (`assets/fonts/FontV1-Regular.ttf`), set project-wide through `resources/fonts/ui_font.tres`. Characters the font doesn't have yet (`/ % + · —` …) fall back to the system sans-serif font.

Background music: *Journey to Tomorrow* (`assets/audio/music/`), looping. Sound effects are still placeholders synthesized in code (`scripts/audio/sfx.gd`). The scene's lighting is set by `scene_ev` on the root node, and every scoring constant is in `resources/scoring/default_scoring_config.tres`.

## Project layout

```
docs/design/       Design docs (GDD, scoring spec)
scenes/sandbox/    Prototype scenes
scripts/photo/     Camera, subject, and scoring code (ShotData, ScoringConfig, PhotoScoring)
scripts/player/    The photographer: third-person explore + ADS viewfinder
scripts/sandbox/   Sandbox-only helpers (round logic, input setup)
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
