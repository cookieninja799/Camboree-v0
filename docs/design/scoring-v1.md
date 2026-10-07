# Scoring v1

```
Shot = Gate × (wF·Focus + wE·Exposure + wP·Placement + wM·Motion + wN·Noise) / Σw
```

Every pillar is a 0–1 float. The weights come from the `ScoringConfig`, and each brief can carry its own. A pillar with weight 0 is left out entirely: it doesn't count toward the score, it can't be `best` or `worst`, and it gets no tip. The default config (Round 1) uses 0.5 / 0.3 / 0.2 / 0 / 0, which gives exactly the v0 scores.
Code: `scripts/photo/photo_scoring.gd`. Constants: `resources/scoring/default_scoring_config.tres`.

| Pillar | Definition |
|---|---|
| **Gate** | Fraction of the subject's sample points (head, torso, feet) that are in the frustum and not blocked by a raycast. |
| **Focus** | `1 − smoothstep(0.5·c, 3·c, blur)` on the subject's key point (the head), using thin-lens blur with `c = 0.03 mm`. |
| **Exposure** | `EV_set = log2(N²/t) − log2(ISO/100)`, `error = EV_set − EV_scene`, score `1 − smoothstep(0.5, 2.5, |error|)`. Positive error means too dark. |
| **Placement** ("Framing") | Distance `d` from the subject's key point to the nearest rule-of-thirds intersection or the center, in normalized screen units. Score `1 − smoothstep(0.05, 0.22, d)`: full marks inside the 0.05 zone (drawn in the viewfinder), 0 near the edges, and **0 if the key point is off screen**. |
| **Motion** | `1 − smoothstep(tol, 3·tol, smear)` with `tol = 0.1 mm`. `smear` is the motion blur on the sensor (below). |
| **Noise** | `stops = log2(ISO/100)`, score `1 − smoothstep(2, 6, stops)`. ISO 400 or lower scores 1, ISO 1600 scores 0.5, and ISO 6400 scores 0. |

**Blur:** `blur = f² · |d − s| / (N · d · (s − f))`, where `f` = focal length, `s` = focus distance, `d` = subject depth along the view axis, `N` = f-number. Distances are in meters and the result is converted to mm.

Reference values (these are covered by `tests/test_scoring.gd`):

| Shot | Blur | Focus score |
|---|---|---|
| 85 mm f/1.8, focus 3 m, subject 3.5 m | 0.197 mm | 0.00 |
| 85 mm f/8, same distances | 0.044 mm | 0.66 |

**Motion blur (smear):** `smear = m · v⊥ · t` with magnification `m = f / (d − f)`. Here `v⊥` is the subject's speed across the frame (its velocity with the component along the view axis removed) and `t` is the shutter time. `PhotoSubject.global_velocity` is measured from its position change each physics frame, and `PhotoCamera.capture()` stores `v⊥` as `ShotData.subject_speed_mps`. The result key is `motion_blur_mm`, separate from `blur_mm`, which is defocus blur.

A 5 m/s runner at 10 m with an 85 mm lens:

| Shutter | Smear | Motion score |
|---|---|---|
| 1/125 | 0.343 mm | 0.00 |
| 1/250 | 0.171 mm | 0.71 |
| 1/500 | 0.086 mm | 1.00 |

**Stars:** one per threshold reached: `0.2, 0.4, 0.6, 0.8, 0.9`. Below 0.2 scores 0★, and 0.9+ scores 5★.

**Reason codes:** the result includes the `best` pillar (not counting the gate), the `worst` pillar (counting the gate), and a one-line `tip` for the worst pillar, such as "1.5 stops too dark."

## Decisions

- Units: meters in the world, millimeters for focal length and blur.
- `EV_scene` is a single exported float on the scene (`scene_ev`, default 13 ≈ hazy sun; full sun is 15).
- Scoring runs on shutter press only.
- All constants live in `ScoringConfig` so they can be tuned in the inspector.
- **Visuals match grading:** `PhotoCamera` drives `CameraAttributesPhysical` (focal length → FOV, focus distance + aperture → depth of field) from the same values the scorer reads. Physical light units are off, so brightness is driven by `exposure_multiplier = 2^(−EV error)`, which uses the same number as the exposure pillar.
- Framing originally used a Gaussian (σ = 0.1) with no flat top. It was much harder to max than focus or exposure: a ≥ 0.9 score needed the head within 0.046 of a point. It now uses the same "ok zone + smoothstep falloff" shape as the other pillars. A first pass (0.06 / 0.25) overshot, and a bug gave full framing to subjects that weren't in frame at all (their screen position defaulted to the center). Now off-screen scores 0, and the zone is 0.05 / 0.22, so the worst spot between targets scores about 0.65.
- Gear is **not** a score multiplier. Gear unlocks briefs (see the GDD).

- **v1:** motion and noise joined as weighted pillars, not gates. Per-brief weights reuse `ScoringConfig` (one `.tres` per brief) instead of a separate weights dictionary. The score already divides by `Σw`, so the weights don't need to sum to 1. The ISO dial now reaches 12800, and the shutter dial already reached 1/4000.
- **Motion blur visual (Phase 2.1 decision): a ghost trail.** `MotionTrail` draws see-through copies of the subject's meshes along `−velocity · shutter` in world space, the same `v·t` the pillar scores. Copies are faded with `GeometryInstance3D.transparency`, so materials stay untouched. It's drawn in 3D, so it works in both the viewfinder and the polaroid grab without a post-process pass, and it shows only while the camera is raised. The fallback, a `CompositorEffect` directional blur with a subject mask, would look smoother but needs a subject mask pass and its own shader. Revisit it if the ghosts read as "clones" in playtests.
- **Grain:** `GrainOverlay` is a full-screen shader on its own CanvasLayer (layer 0, under the HUD), with strength `1 − Noise`, so the frame grab keeps it. Above the noise pillar's floor (ISO 12800) it adds color blotches, so the top ISO still looks worse than 6400. Like motion blur, it shows only through the raised camera.
- Camera panning doesn't reduce the smear yet. `PhotoCamera.cross_frame_speed()` is where the camera's own motion would be subtracted.

## Briefs

A `Brief` (`scripts/briefs/brief.gd`, `.tres` files in `resources/briefs/`) holds the client's ask, a `ScoringConfig` with that client's weights, the goal (`target_stars` within `shot_limit`, or best of N with `win_mode = BEST_OF`), `BriefRequirement`s, the reward, and the scene (scene EV, sun, sky, `render_gain`, and subject behavior). A required requirement decides whether a shot counts at all. Optional ones earn the bonus. `RoundRunner` plays the briefs in order: brief card → shoot → result → next brief. A loss retries the same brief, and the last win shows a summary.

Every brief shows the live "fix your camera" coach on its first attempt (`coach = true`, with `ScoringSandbox.coach_rounds` deciding how many attempts), phrased with the brief's `subject_name`. When a flyer is out of sight the coach says to wait for it rather than look for it. Only R1 scrambles the settings. The polaroid is stamped with what the shot meant for the brief: `BRIEF COMPLETE` (plus `+BONUS`), or `DOESN'T COUNT` when a required requirement failed. The shot that moves on to the next brief leaves the last polaroid up, and shots fired while a brief-ending shot is still revealing are ignored, so the result can't be skipped by accident.

| Brief | Goal | Weights F/E/P/M/N | Requirement | Scene |
|---|---|---|---|---|
| R1 The Wanderer | 4★ in 5 | 0.5 / 0.3 / 0.2 / 0 / 0 | – | EV 13, sine wanderer (scrambled settings) |
| R2 Dusk Portrait | 4★ in 6 | 0.3 / 0.25 / 0.15 / 0.2 / 0.1 | Noise ≥ 0.5 (ISO ≤ 1600), required | EV 2, slow sway (0.4 m/s peak), "the model" |
| R3 Bird in Flight | best of 8 ≥ 3★ | 0.3 / 0.2 / 0.1 / 0.4 / 0 | Motion ≥ 0.8, bonus | EV 13, flyer: 8–12 m/s passes 4–8 m up, 2–5 s gaps, "the bird" |

Tuning checks in `tests/test_scoring.gd`:
- **Dusk:** sweeping every setting at 50/85/135 mm (subject at 4 m, swaying 0.4 m/s, focus 0.15 m off), ISO ≤ 400 tops out at 0.776 (3★). 5★ (0.926) needs about ISO 1600, so the player has to accept some grain.
- **Bird:** at 10 m/s, 15 m out, on 200 mm, 1/500 gives Motion 0.06 and 1/1000 gives 0.92. A clean freeze needs 1/1000 or faster.

## Not yet scored (next candidates)

- Subject size in frame and edge cropping.
- More brief requirements ("blurred background", "3 birds").
- Tagged composition helpers: leading lines, balance, repetition, and color harmony.
