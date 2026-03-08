extends Node

## Path to the user-selected image file on disk.
## Empty string means a built-in gallery texture was chosen.
var image_path: String = ""

## Pre-loaded texture for the puzzle.
## Non-null when an image has been selected from the gallery or uploaded.
var image_texture: Texture2D = null

## Index of the selected built-in gallery item (-1 = custom upload).
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
