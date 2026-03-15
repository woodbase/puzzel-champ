# Performance Optimizations – Low-End Mobile Devices

## Milestone: Performance Optimization

This document records the performance bottlenecks identified when testing Puzzle Champ on a low-end Android device (entry-level phone, ~2 GB RAM, Mali-G52 GPU, Android 12) and the code changes made to resolve them.

---

## Identified Bottlenecks

### 1. Slow puzzle build – image resize (Critical)

**Symptom:** Noticeable freeze (1–3 s) when loading a new puzzle on mobile.

**Root cause:** `Image.resize()` was called with `INTERPOLATE_LANCZOS`, a high-quality but expensive filter that runs entirely on the CPU. On the test device this took up to 2.5 s for a 2 MP photo downscaled to a small jigsaw grid.

**Fix (`scripts/puzzle_board.gd`):** Use `INTERPOLATE_BILINEAR` on mobile. Bilinear filtering is handled by a tight C++ loop (no windowed convolution) and produces visually indistinguishable results at the small piece sizes used on mobile.

---

### 2. Slow puzzle build – polygon mask fill (Critical)

**Symptom:** Additional 0.5–1 s stall during puzzle generation, proportional to piece count.

**Root cause:** `PuzzleGenerator._fill_polygon()` filled the mask image by calling `Image.set_pixel()` inside a nested GDScript loop (one call per pixel). For a piece texture that is 80 × 80 px the loop executed 6 400 GDScript iterations; for 48 pieces that is ~307 000 GDScript calls just for mask creation.

**Fix (`scripts/puzzle_generator.gd`):** Replaced the inner `for x` pixel loop with a single `image.fill_rect()` call per scanline span. `fill_rect` is a native C++ function; replacing O(width) GDScript calls per scanline with one call reduces GDScript overhead by roughly 95 % for typical piece sizes.

---

### 3. Excessive texture memory – oversample factor (Moderate)

**Symptom:** High texture memory usage reported in the Godot profiler; occasional out-of-memory kills on 2 GB devices with large (≥ 48-piece) puzzles.

**Root cause:** `SOURCE_OVERSAMPLE = 1.35` caused piece textures to be 35 % larger than their on-screen pixel size in each dimension, consuming ~82 % more GPU memory than strictly needed.

**Fix (`scripts/puzzle_board.gd`):** On mobile the oversample factor is lowered to `1.0`, so textures exactly match display size. Desktop retains the 1.35 × factor for crisper appearance when the player zooms in.

---

### 4. Jittery frame rate – snap particle effects (Moderate)

**Symptom:** Visible frame-rate drop (< 30 fps) when snapping multiple pieces in quick succession.

**Root cause:** Each snap spawned a `CPUParticles2D` node with 18 particles, a per-particle colour gradient, and a scale-amount `Curve`. Rapid snapping could leave 3–4 simultaneous particle systems alive, each evaluated every frame.

**Fix (`scripts/puzzle_piece.gd`):** On mobile the particle count is reduced from 18 to 8, and the per-particle scale curve is skipped (the gradient fade alone provides a clean visual result).

---

### 5. Completion screen jank – confetti effect (Moderate)

**Symptom:** Frame rate drops to ~20 fps for the first 3 seconds of the completion screen on mobile.

**Root cause:** The confetti effect spawned 70 particles per second for 4 seconds (up to ~280 simultaneous rotating quads), each requiring two `cos`/`sin` calls per frame.

**Fix (`scripts/confetti_effect.gd`):** On mobile the spawn rate is halved to 35 particles/second and the spawn window is shortened to 2.5 s, capping the live particle count at roughly 87. The effect is still visually festive but imposes far less CPU work per frame.

---

### 6. Long polygon generation – bezier step count (Minor)

**Symptom:** Marginal extra build time on Expert (48-piece) puzzles with jigsaw shape.

**Root cause:** Each non-flat jigsaw edge was approximated by three cubic Bézier curves, each sampled at `_BEZIER_STEPS = 5` points, producing up to 45 extra polygon vertices per piece edge. With 4 edges per piece and 48 pieces, that is up to 8 640 extra vertices feeding into the scanline fill loop.

**Fix (`scripts/puzzle_generator.gd`):** On mobile `_BEZIER_STEPS_MOBILE = 3` is used instead of 5. The tab shape is still clearly rounded; the simplification is imperceptible at mobile screen sizes.

---

### 7. Unnecessary drag-position updates – `_update_drag` (Minor)

**Symptom:** Touch screens on modern phones report drag events at 120 Hz or faster, producing many near-identical events per visual frame. Each event unconditionally overwrote `global_position`, triggering a redundant Area2D transform recalculation and Sprite2D redraw even when the finger had barely moved.

**Fix (`scripts/puzzle_piece.gd`):** A `MIN_DRAG_MOVE_SQ = 0.25` (≈ 0.5 px) squared-distance guard was added to `_update_drag`. If the new target position is within 0.5 px of the current position, the assignment is skipped entirely. The threshold is sub-pixel and completely imperceptible but eliminates most duplicate events on high-rate touch screens.

---

### 8. Per-frame sorting-box hit-test during drag (Minor)

**Symptom:** `_update_box_drop_highlight()` ran every process frame while a piece was being dragged, even when the piece had not moved since the previous frame (e.g. between two touch events). Each call iterated over all sorting boxes and called `get_global_rect().has_point()`.

**Fix (`scripts/puzzle_board.gd`):** The call is now gated on the same position-change check used for `queue_redraw()`. The hit-test loop only runs when `_dragged_piece.global_position` has changed from `_last_drag_pos`, matching the real rate at which the result could differ.

---

### 9. Completion glow – per-frame draw calls (Minor)

**Symptom:** After puzzle completion the victory glow effect called `queue_redraw()` every frame for 6 seconds, issuing 4 `draw_rect` calls per frame (one per concentric glow layer), plus two `sin()` evaluations for the dual-frequency pulse.

**Fix (`scripts/puzzle_glow_effect.gd`):** On mobile the layer count is reduced from 4 to 2 (`GLOW_LAYERS_MOBILE = 2`) and the pulse is simplified to a single `sin()` call. Per-frame rendering cost of the effect is roughly halved on mobile.

---

## Summary of Code Changes

| File | Change | Benefit |
|---|---|---|
| `scripts/puzzle_generator.gd` | `set_pixel` loop → `fill_rect` per scanline (all platforms) | ~95 % reduction in GDScript iterations during mask generation |
| `scripts/puzzle_generator.gd` | Bezier steps: 3 on mobile, 5 on desktop | Fewer polygon vertices to generate and fill |
| `scripts/puzzle_board.gd` | `INTERPOLATE_BILINEAR` on mobile, `INTERPOLATE_LANCZOS` on desktop | Puzzle build ~2–4× faster on mobile |
| `scripts/puzzle_board.gd` | Oversample factor: 1.0 on mobile, 1.35 on desktop | ~45 % reduction in per-piece GPU texture memory |
| `scripts/puzzle_board.gd` | `_update_box_drop_highlight()` gated on drag-position change | Eliminates per-frame sorting-box hit-test loop when piece is stationary |
| `scripts/puzzle_piece.gd` | Snap particles: 8 on mobile (down from 18), no scale curve | Lower per-snap CPU/GPU cost |
| `scripts/puzzle_piece.gd` | `MIN_DRAG_MOVE_SQ` threshold in `_update_drag` | Skips Area2D transform/AABB recalculation for sub-pixel touch events |
| `scripts/puzzle_glow_effect.gd` | Glow layers: 2 on mobile (down from 4); single-frequency pulse | ~50 % fewer draw calls per frame during victory glow |
| `scripts/confetti_effect.gd` | Spawn rate: 35/s on mobile (down from 70), duration: 2.5 s | Peak live particles cut by ~69 % |

All mobile-specific paths are gated on `GameState.is_mobile`, which is set once at startup via `OS.has_feature("mobile")` and is `false` on desktop, so desktop behaviour is completely unchanged.
