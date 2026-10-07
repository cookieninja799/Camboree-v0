# UI manifest

Every UI asset and on-screen element. Keep this up to date when UI art, fonts, or HUD pieces change. Audio lives in [`audio-manifest.md`](audio-manifest.md).

## Files

| Asset | File | Used for | Notes |
|---|---|---|---|
| Font V1 | `assets/fonts/FontV1-Regular.ttf` | Every piece of UI text | Made in Calligraphr. Missing glyphs: `/ % + · — – # @ _ = < > [ ] *` |
| UI font setup | `resources/fonts/ui_font.tres` | Project-wide default font (`project.godot` → `gui/theme/custom_font`) | Wraps Font V1 with a system sans-serif fallback for the missing glyphs |
| App icon | `icon.svg` | Window/taskbar icon and project icon | Placeholder: a camera on a yellow rounded square |
| Polaroid frame style | `PolaroidStyle_1` StyleBoxFlat, inside `scenes/sandbox/scoring_sandbox.tscn` | The polaroid's off-white card and drop shadow | Not a separate file |

There are no image textures (PNG/SVG) for UI yet. Everything below is drawn in code.

## HUD elements (all drawn in code, all placeholders for real art)

| Element | Where it lives | What it looks like | When it shows |
|---|---|---|---|
| Setting dials ×5 (ISO, Shutter, Aperture, Zoom, Focus) | `scripts/ui/setting_dial.gd` | Half-circle dial rising from the bottom edge, with knurled ticks and value labels, a gold pointer, a big readout, the name, and a 1–5 key badge | Always. Compact while exploring, full size in the viewfinder |
| "Turn me" arrows | `setting_dial.gd` (`_draw_turn_arrows`) | Curved gold double-headed arrow over the selected dial | Selected dial |
| Star row | `scripts/ui/star_row.gd` | Five drawn stars, gold when filled, grey outline when empty, with a pop animation | Bottom of the polaroid during the shot reveal |
| Polaroid | `scenes/sandbox/scoring_sandbox.tscn` (`HUD/Overlay/Polaroid`) + `photo_hud.gd` | Off-white card with the captured photo and the star row. Drops in from the top with a tilt | After each shot (top-right) |
| Pillar bars, up to 6 (Focus, Exposure, Framing, Motion, Noise, In view) | `scripts/ui/photo_hud.gd` (`_build_bars`) | Rounded progress bars, green/yellow/red by score, with the weakest pillar's name highlighted. A pillar with weight 0 in the brief is hidden | After each shot (left) |
| Brief card / summary card | `photo_hud.gd` (`_build_card`) | Dark rounded panel, centered, with a yellow title and wrapped body text | At the start of each brief (hidden when the camera is raised), and at the end of the run (stays up until the next shot) |
| Sensor grain | `scripts/ui/grain_overlay.gd` + `resources/shaders/grain.gdshader` | Full-screen animated noise, stronger in shadows, with color blotches at ISO 12800. Kept in the polaroid | Viewfinder, at ISO 800 and above |
| Motion blur trail | `scripts/photo/motion_trail.gd` (3D, not HUD) | See-through copies of a moving subject along its path during the exposure | Viewfinder, when shutter × speed is long enough |
| Focus bracket | `photo_hud.gd` (`_draw_focus_bracket`) | Four corner brackets at the center: white while driving, green on lock, red on fail | Viewfinder |
| Rule-of-thirds guides | `photo_hud.gd` (`_draw`) | Thin white grid lines | Viewfinder |
| Framing zones ×5 | `photo_hud.gd` (`_draw`) | Ellipses marking the full-marks framing areas | Viewfinder |
| Aim dot | `photo_hud.gd` (`_draw`) | Small white dot with a dark ring | Exploring (third person) |
| Shutter flash | `HUD/Overlay/Flash` (ColorRect) | Full-screen white flash that fades out | Each shot |

## HUD text

All text uses Font V1.

| Text | Node | Style | When it shows |
|---|---|---|---|
| Brief line ("The Wanderer · Get a 4-star shot in 5 · 3 shots left", "BRIEF COMPLETE!") | `BriefLabel` | 30 px, outlined, centered at the top, green on win, red on loss | Always |
| Coach checklist (FIX / OK lines) | `Coach` (RichTextLabel) | 16 px, colored tags | First attempt at a coached brief (Round 1) |
| Tip ("Focus landed 3.9 m in front…") | `Result/TipLabel` | 22 px, yellow | After each shot |
| Focus readout and controls hint | `SettingsLabel` | 13 px, above the dials | Always (text changes per mode) |
| "Hold RMB to raise your camera" nudge | `NudgeLabel` | 22 px, yellow, fades out | Shooting with the camera lowered |

## Colors (in code)

| Name | Value | Used for |
|---|---|---|
| Good | `#73D966` | Green bars, OK tags, focus lock, win text |
| Okay | `#F2CC4D` | Yellow bars, coach hints, weakest pillar |
| Bad | `#F26659` | Red bars, FIX tags, focus fail, loss text |
| Dial accent | `#FFC733` | Pointer, selected mark, arrows, filled stars |
| Dial rim | `#E0DED1` | Dial outline, ticks, labels |
| Dial body | `#1A1A21` at 82% | Dial face |
| Guides | white at 35% | Thirds grid, framing zones |

## Wishlist (to make or replace)

See [`art-replacement.md`](art-replacement.md) for every placeholder, with screenshots and priorities.

- Add the missing glyphs to Font V1 (at least `/ % + · —`) so nothing falls back to the system font.
- Draw real art for the dials (the camera's dial faces), the polaroid frame, the stars, and the focus bracket.
- A real app icon.
- Menus (title, pause, settings) don't exist yet.
