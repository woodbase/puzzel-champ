extends Node

## Path to the selected image file.
## For built-in gallery images this is the res:// resource path.
## For user-uploaded images this is the user:// path where the copy was saved.
## Empty string means no path is stored.
var image_path: String = ""

## Pre-loaded texture for the puzzle.
## Non-null when an image has been selected from the gallery or uploaded.
var image_texture: Texture2D = null

## Index of the selected gallery item (-1 = selection outside the current gallery).
## Indices 0..N-1 map to the bundled default images; higher indices are
## user-uploaded images loaded from user://gallery/.
var gallery_index: int = 0

## Number of puzzle columns.
var cols: int = 4

## Number of puzzle rows.
var rows: int = 3

## Selected piece shape. Possible values: "square", "jigsaw".
var piece_shape: String = "jigsaw"

## Whether visual snap feedback (scale bounce + colour flash) is enabled.
var feedback_visual: bool = true

## Whether audio snap feedback (sound effect) is enabled.
var feedback_audio: bool = true

## Whether haptic snap feedback (device vibration) is enabled.
var feedback_haptic: bool = true

## Whether background music is enabled during gameplay.
var music_enabled: bool = true

## Master volume for all game audio (linear scale: 0.0 = silent, 1.0 = full).
var volume: float = 1.0

## True once the player has explicitly started a game (difficulty has been
## committed at least once). Used by the main menu to decide whether to
## auto-select a screen-size-appropriate difficulty on first load.
var difficulty_explicitly_set: bool = false
