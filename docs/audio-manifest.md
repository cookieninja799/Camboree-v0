# Audio manifest

Every sound the game uses. Keep this up to date whenever audio is added, replaced, or removed.

## Music (files)

| Track | File | Length | Format | Where it plays | Source / license |
|---|---|---|---|---|---|
| Journey to Tomorrow | `assets/audio/music/journey_to_tomorrow.mp3` | 2:02 | MP3, 192 kbps, 44.1 kHz stereo, ~2.9 MB | Scoring sandbox background, looping at −10 dB (`Music` node in `scenes/sandbox/scoring_sandbox.tscn`). M / Back pauses it. | _TBD, fill in_ |

Looping is set in the import settings (`journey_to_tomorrow.mp3.import`: `loop=true`).

**Retired:** *As You Fall (Maybe)* (`as_you_fall_maybe.mp3`) was replaced on 2026-10-05. It's still in git history at commit `857d467`.

## Sound effects (synthesized placeholders, no files)

There are no sound-effect files yet. Every effect is generated in code by `scripts/audio/sfx.gd` (sine tones or a noise burst, 22.05 kHz mono) and cached after first use. Each row is a slot to fill with a real recording later.

| Sound | Made by | What it is | When it plays (triggered from) |
|---|---|---|---|
| Shutter click | `Sfx.click()` | 0.06 s noise burst | Every shot (`Sfx.play_result`) |
| Camera raise | `Sfx.click()` (reused) | Same noise burst | Raising the camera to your eye (`player.gd`). Placeholder: wants its own "clack". |
| Star chimes | `Sfx.play_result()` → `tone()` | One 0.25 s sine per star, rising C4, D4, E4, G4, A4 (0.15 s, then every 0.12 s) | Shot reveal, synced with the stars popping in |
| 5-star flourish | `Sfx.play_result()` → `tone()` | 0.5 s sine at C6 after the fifth chime | Shot reveal, 5 stars only |
| Zero-star "bwomp" | `Sfx.play_result()` → `tone()` | 0.35 s low sine at 150 Hz | Shot reveal, 0 stars |
| Dial tick | `Sfx.dial_tick()` | 0.03 s sine at 2.4 kHz | Turning a dial onto a new mark (`setting_dial.gd`), and each manual focus-ring notch (`photo_camera.gd`) |
| Autofocus motor | `Sfx.af_motor()` | 0.1 s sine at 140 Hz, retriggered every 0.09 s | While autofocus racks the lens (`photo_camera.gd`) |
| Focus lock | `Sfx.play_af_lock()` | Two 0.05 s beeps at 2 kHz, 0.08 s apart | Autofocus locks (`photo_camera.gd`) |
| Focus fail | `Sfx.af_fail()` | 0.18 s sine at 320 Hz | Autofocus hunts and gives up, e.g. on empty sky (`photo_camera.gd`) |

## Wishlist (from the GDD, not made yet)

- Real recordings for every placeholder above, especially the shutter, which needs weight and should feel tactile and satisfying.
- Film loading / advance, and a darkroom ambience for the developing minigame.
- Per-location music (same "sound font", different songs).
- Character voices as gibberish speech.
