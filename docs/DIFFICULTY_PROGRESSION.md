# Difficulty Progression System

## Overview

Puzzle Champ features a carefully designed difficulty progression system that provides an appropriate challenge for players ranging from absolute beginners to puzzle experts. The progression follows an exponential growth pattern that ensures each difficulty level presents a meaningful increase in challenge.

## Difficulty Levels

The game offers four distinct difficulty levels, ordered from easiest to most challenging:

### 1. Easy (6 pieces)
- **Grid Size**: 3 × 2
- **Description**: "Perfect for beginners"
- **Target Audience**: New players, young children, or anyone wanting a quick puzzle
- **Estimated Time**: 5-10 minutes
- **Features**: Large pieces are easy to identify and manipulate, especially on mobile devices

### 2. Medium (12 pieces)
- **Grid Size**: 4 × 3
- **Description**: "A balanced challenge"
- **Target Audience**: Players with basic puzzle experience
- **Estimated Time**: 10-20 minutes
- **Features**: Doubles the piece count from Easy, providing a noticeable but manageable increase in difficulty
- **Default**: Automatically selected for desktop users on first launch

### 3. Hard (24 pieces)
- **Grid Size**: 6 × 4
- **Description**: "For experienced players"
- **Target Audience**: Experienced puzzle solvers
- **Estimated Time**: 20-40 minutes
- **Features**: Doubles the piece count from Medium, requiring more strategy and patience

### 4. Expert (48 pieces)
- **Grid Size**: 8 × 6
- **Description**: "The ultimate test"
- **Target Audience**: Puzzle enthusiasts seeking a serious challenge
- **Estimated Time**: 40+ minutes
- **Features**: Doubles the piece count from Hard, providing the ultimate puzzle challenge

## Progression Design Principles

### Exponential Growth
Each difficulty level approximately doubles the number of pieces from the previous level:
- Easy → Medium: 2× (6 → 12 pieces)
- Medium → Hard: 2× (12 → 24 pieces)
- Hard → Expert: 2× (24 → 48 pieces)

This exponential scaling ensures that:
1. The difficulty increase is consistent and predictable
2. Players feel a clear progression as they advance
3. No level feels too similar to adjacent levels

### Aspect Ratio Variety
The grid dimensions vary in aspect ratio:
- Easy: 3:2 (1.5 ratio)
- Medium: 4:3 (1.33 ratio)
- Hard: 6:4 = 3:2 (1.5 ratio)
- Expert: 8:6 = 4:3 (1.33 ratio)

This variation:
- Maintains visual interest across different difficulty levels
- Works well with various image aspect ratios
- Prevents monotony in puzzle layout

### Adaptive Defaults
The system intelligently selects an appropriate default difficulty based on the player's device:

- **Mobile Devices**: Easy (6 pieces)
  - Rationale: Larger pieces are easier to manipulate with touch controls
  - Ensures a positive first experience on smaller screens

- **Desktop/Tablet**: Medium (12 pieces)
  - Rationale: More screen space and precise mouse/trackpad control enable handling smaller pieces
  - Provides a balanced introduction without being too trivial

### Player Control
While the system provides smart defaults, players always have full control:
- All four difficulty levels are accessible from the main menu
- Selected difficulty persists across sessions (via `GameState.difficulty_explicitly_set`)
- No unlocking or progression barriers - players can jump to any difficulty
- **Desktop players** can also choose a fully custom piece count (2–1000) using the "Custom" button

## Implementation Details

### Code Location
The difficulty system is defined in `/scripts/ui/main_menu.gd`:

```gdscript
const DIFFICULTIES: Array[Dictionary] = [
    {"label": "Easy",   "cols": 3, "rows": 2, "desc": "Perfect for beginners"},
    {"label": "Medium", "cols": 4, "rows": 3, "desc": "A balanced challenge"},
    {"label": "Hard",   "cols": 6, "rows": 4, "desc": "For experienced players"},
    {"label": "Expert", "cols": 8, "rows": 6, "desc": "The ultimate test"},
]
```

### State Management
Difficulty settings are stored in the `GameState` autoload singleton:
- `GameState.cols`: Number of columns in the puzzle grid
- `GameState.rows`: Number of rows in the puzzle grid
- `GameState.difficulty_explicitly_set`: Tracks whether the player has manually selected a difficulty

### Default Selection Logic
```gdscript
func _default_difficulty_for_screen() -> int:
    return 0 if UIScale.is_mobile() else 1  # Easy for mobile, Medium for desktop
```

## User Experience

### Visual Feedback
When a difficulty is selected:
1. The button highlights with an accent color and border
2. The piece count is displayed (e.g., "12 pieces (4 × 3 grid)")
3. A descriptive label appears below (e.g., "A balanced challenge")

### Persistence
Once a player has explicitly selected a difficulty:
- That choice is remembered across game sessions
- The adaptive default is no longer applied
- Players can always change their selection at any time

## Acceptance Criteria Met

✅ **Difficulties are ordered from easy to hard**: The system progresses from 6 pieces (Easy) through 12 (Medium) and 24 (Hard) to 48 pieces (Expert), with each level providing approximately 2× the challenge of the previous level.

✅ **Each difficulty level provides an appropriate challenge**: The exponential progression ensures that beginners have a gentle introduction while experts have a substantial challenge. The variety in grid dimensions and the descriptive labels help players understand what to expect at each level.

## Custom Piece Count (Desktop Only)

Desktop players can bypass the preset difficulty levels and enter any piece count from
2 to 1000 via the **Custom** button in the difficulty row.

### How It Works
1. Click **Custom** in the difficulty row — the button highlights and a "Number of pieces" spinner appears.
2. Set any value between **2** and **1000**.
3. The game computes the best-fit grid targeting a 4:3 (landscape) aspect ratio:
   ```gdscript
   cols = round(sqrt(n * 4/3))
   rows = round(n / cols)
   ```
   Because `cols` and `rows` are integers, the actual piece count (`cols × rows`) may
   differ slightly from the requested value. The piece-count label shows both numbers
   when they differ, e.g. **"105 requested → 108 pieces (12 × 9 grid)"**.
4. Click **Start Puzzle** — the computed grid dimensions are passed to `GameState.cols` / `GameState.rows`.

The custom selection persists across sessions just like preset difficulties.

### Why Desktop Only
On mobile devices, large piece counts produce pieces too small to tap reliably.
The custom option is therefore hidden when `UIScale.is_mobile()` returns true.

## Future Enhancement Ideas

While the current system meets all requirements, potential future improvements could include:

1. **Very Easy (Beginner)**: A 2×2 grid (4 pieces) for absolute novices
2. **Master**: A 10×8 grid (80 pieces) for extreme challenges
3. **Time Tracking**: Display average completion times for each difficulty
4. **Achievements**: Unlock badges for completing puzzles at each difficulty
5. **Recommended Difficulty**: AI-based suggestion after completing a puzzle

## Testing

To verify the difficulty progression:
1. Launch the game on both mobile and desktop
2. Verify adaptive defaults are applied correctly
3. Select each difficulty level and start a puzzle
4. Confirm piece counts match specifications
5. Verify descriptions display correctly
6. Test that difficulty selection persists across sessions
7. On desktop, click "Custom", enter a value (e.g. 500), and verify the correct grid is shown
8. Confirm the Custom button is absent on mobile
