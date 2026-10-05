# Scoring v0 (locked for prototyping)

```
Shot = Gate × (0.5·Focus + 0.3·Exposure + 0.2·Placement)
```

One subject, one style, no brief system yet. Every pillar is a 0–1 float.
Code: `scripts/photo/photo_scoring.gd`. Constants: `resources/scoring/default_scoring_config.tres`.

| Pillar | Definition |
|---|---|
| **Gate** | Fraction of the subject's sample points (head, torso, feet) that are in the frustum and not blocked by a raycast. |
| **Focus** | `1 − smoothstep(0.5·c, 3·c, blur)` on the subject's key point (the head), using thin-lens blur with `c = 0.03 mm`. |
| **Exposure** | `EV_set = log2(N²/t) − log2(ISO/100)`, `error = EV_set − EV_scene`, score `1 − smoothstep(0.5, 2.5, |error|)`. Positive error means too dark. |
| **Placement** | Best Gaussian fit (σ = 0.1 screen units) of the subject's screen position to any rule-of-thirds intersection or the center. |

**Blur:** `blur = f² · |d − s| / (N · d · (s − f))`, where `f` = focal length, `s` = focus distance, `d` = subject depth along the view axis, `N` = f-number. Distances are in meters and the result is converted to mm.

Reference values (these are covered by `tests/test_scoring.gd`):

| Shot | Blur | Focus score |
|---|---|---|
| 85 mm f/1.8, focus 3 m, subject 3.5 m | 0.197 mm | 0.00 |
| 85 mm f/8, same distances | 0.044 mm | 0.66 |

**Stars:** one per threshold reached: `0.2, 0.4, 0.6, 0.8, 0.9`. Below 0.2 scores 0★, and 0.9+ scores 5★.

**Reason codes:** the result includes the `best` pillar (not counting the gate), the `worst` pillar (counting the gate), and a one-line `tip` for the worst pillar, such as "1.5 stops too dark."

## Decisions

- Units: meters in the world, millimeters for focal length and blur.
- `EV_scene` is a single exported float on the scene (`scene_ev`, default 13 ≈ hazy sun; full sun is 15).
- Scoring runs on shutter press only.
- All constants live in `ScoringConfig` so they can be tuned in the inspector.
- **Visuals match grading:** `PhotoCamera` drives `CameraAttributesPhysical` (focal length → FOV, focus distance + aperture → depth of field) from the same values the scorer reads. Physical light units are off, so brightness is driven by `exposure_multiplier = 2^(−EV error)`, which uses the same number as the exposure pillar.
- Gear is **not** a score multiplier. Gear unlocks briefs (see the GDD).

## Not yet scored (next candidates)

- Motion blur: shutter speed vs. subject and camera speed.
- ISO noise / film grain trade-off.
- Subject size in frame and edge cropping.
- Briefs: per-client weights and requirements ("blurred background", "3 birds").
- Tagged composition helpers: leading lines, balance, repetition, and color harmony.
