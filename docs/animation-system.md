# Puzzle Champ – Animation System

## Decision

After reviewing multiple animation prototypes explored during Milestone 7, the following animation
styles were selected as the best fit for the game's visual identity.  All chosen animations are
tween-based (using Godot's built-in `Tween` API) or lightweight procedural particle systems,
keeping performance predictable across desktop and mobile targets.

---

## Loading Animation

**Board entry – two-layer approach**

When a puzzle loads, two animations play simultaneously:

1. **Overlay fade-in** – A full-screen dark overlay is placed over the freshly-built board and
   fades to transparent over ~0.55 s (quad ease in-out).  This creates the impression of the
   scattered pieces being gradually revealed from darkness, masking the instant population of
   the board.

2. **Piece scale-in stagger** – Each piece starts at scale `Vector2.ZERO` and springs open to
   its normal size using an elastic ease (0.40 s per piece) with a 30 ms stagger between
   consecutive pieces.  The stagger makes the board feel like it's populating piece-by-piece
   rather than appearing all at once.

This combination was chosen because it is cheap to evaluate (one tween per piece, no GPU
particles), works identically on mobile and desktop, and gives the player a clear cue that a
new puzzle has started.

**Splash / logo animation**

The splash screen plays a branded intro before the main menu:
- Title fades in with a colour shimmer (accent-purple → near-white, 0.5 s)
- Subtitle fades in after the title (0.4 s)
- Hero image fades in over text (1.0 s fade)
- All elements fade out together before the scene transitions

---

## Victory Animation

When the last piece is placed, a layered celebration sequence plays:

1. **Piece celebration wave** – All locked pieces perform a scale-bounce + gold-flash animation
   staggered diagonally from the top-left corner (~55 ms per diagonal step).  The ripple effect
   travels from corner to corner, reinforcing the sense of the puzzle "coming alive".

2. **Puzzle glow** – A pulsing, multi-layered coloured border (soft purple/lavender) expands
   outward from the completed puzzle rectangle.  It fades over 5 seconds with a sinusoidal
   pulse, drawing the eye to the finished image.

3. **Confetti particles** – 55 festive rectangular confetti pieces per second rain down the
   screen for 3.5 seconds using a lightweight custom `Node2D` renderer (no GPU particles).
   A seven-colour palette (gold, red, green, blue, purple, orange, cyan) was chosen to feel
   celebratory without clashing with any particular puzzle image.

4. **Completion overlay card** – A "Puzzle Complete!" card fades in and scales up from 0.8× to
   1.0× over 0.35 s (ease-out back transition) with a simultaneous backdrop fade.  The card
   provides clear confirmation of completion and offers "Play Again" / "New Puzzle" / "Main Menu"
   actions so the player can continue playing easily after finishing.

This layered approach was selected because:
- Each layer targets a different part of the screen (board → overlay → full screen)
- The cumulative effect feels rewarding without being visually overwhelming
- Every layer respects the `GameState.feedback_visual` toggle so players can opt out

---

## Animation Constants (puzzle_board.gd)

| Constant | Value | Purpose |
|---|---|---|
| `ENTRY_OVERLAY_COLOR` | `Color(0.05, 0.05, 0.10, 1.0)` | Dark tint for the board-entry overlay |
| `PIECE_STAGGER_DELAY` | `0.03 s` | Time between each piece's scale-in animation |

---

## Files

| File | Role |
|---|---|
| `scripts/puzzle_board.gd` | Board entry animation, piece celebration wave, victory overlay |
| `scripts/puzzle_glow_effect.gd` | Pulsing glow border effect |
| `scripts/confetti_effect.gd` | Confetti particle rain |
| `scripts/puzzle_piece.gd` | Per-piece snap bounce + lock particles |
| `scripts/ui/splash.gd` | Splash / logo intro animation |
