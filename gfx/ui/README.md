# UI Assets

This directory contains all graphical UI assets for Puzzle Champ.

## Directory Structure

- **backgrounds/** - Background textures and patterns
- **buttons/** - Button state graphics (normal, hover, pressed)
- **icons/** - Icon graphics for buttons and UI elements (64x64)
- **panels/** - Panel and container backgrounds

## Using These Assets

### In GDScript

Icons are preloaded as constants in the relevant scripts:

```gdscript
const ICON_PLAY := preload("res://gfx/ui/icons/icon_play.png")

# Then assigned to buttons:
var btn := Button.new()
btn.icon = ICON_PLAY
btn.text = "Resume"
```

### Color Scheme

All assets follow the game's color palette defined in `scripts/main_menu.gd`:

- Background: `#1a1e2b`
- Panel: `#262d38`
- Accent: `#8d5be6` (purple)
- Button: `#471a85` (primary purple)
- Text: `#e0d0fa` (light)

## Asset Specifications

### Icons
- Size: 64x64 pixels
- Format: PNG with transparency
- Style: Simple, geometric, high contrast

### Buttons
- Size: 128x48 pixels
- States: normal, hover, pressed
- Corner radius: 6px

### Panels
- Sizes: 256x256 (small), 512x256 (medium), 512x512 (large)
- Border: 2-3px accent color
- Corner radius: 8-10px

## Regenerating Assets

Assets were generated programmatically using Python/PIL. To regenerate:

1. Ensure Pillow is installed: `pip install Pillow`
2. Run the generation script (currently in `/tmp/generate_ui_assets.py`)
3. Assets will be created in their respective directories

## Theme Resource

The `puzzle_champ_theme.tres` file contains a Godot Theme resource with:
- StyleBoxFlat definitions for all UI elements
- Color overrides for buttons, labels, panels
- Font size defaults

See `docs/UI_ASSETS.md` for complete documentation.
