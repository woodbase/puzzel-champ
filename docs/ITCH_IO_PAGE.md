# Puzzle Champ – itch.io Page Kit

Target page (update if different): `https://woodbase.itch.io/puzzle-champ`

This file packages the assets and copy needed to publish the itch.io page quickly.

## Assets (repository paths)
- `docs/itchio/cover.png` – hero / cover image.
- `docs/itchio/screenshot-1.png` – main in-game shot.
- `docs/itchio/screenshot-2.png` – alternate shot.
- `docs/itchio/gameplay.gif` – short motion preview.
- `gfx/icon_itch_512.png` – itch.io project icon.

## Short description
Relaxing jigsaw puzzles with your own photos. Upload an image, pick your piece shape and difficulty, then sort, zoom, and snap pieces together.

## Full page copy
Puzzle Champ lets you turn any picture into a satisfying jigsaw. Upload your own photos or pick from the built-in gallery, choose your piece shape, and play comfortably on desktop or mobile with smooth drag-and-drop, zoom, and pan controls. Keep improving by chasing the leaderboard for each difficulty.

### Feature bullets
- Upload your own images or play bundled photos.
- Difficulty ladder: Easy (3×2), Medium (4×3), Hard (6×4), Expert (8×6).
- Piece shapes: classic jigsaw or clean square cuts.
- Drag, snap, and lock pieces with visual, audio, and optional haptic feedback.
- Sorting boxes to park edge pieces or custom categories.
- Zoom, pan, and reference preview panel for close-up solving.
- Save/resume plus per-difficulty leaderboards for best times.
- Responsive UI for desktop and mobile (touch-friendly controls).

### How to play
**Desktop / Laptop**
- Click and drag pieces to move them; they snap when near the correct spot.
- Mouse wheel to zoom toward the cursor; middle-click drag to pan.
- Preview button toggles the small reference image; click it to open full zoom.
- Use the in-game menu to change difficulty, piece shape, audio, and haptics.
- Sorting boxes (left panel) let you stash pieces by category.

**Mobile / Touch**
- Tap and drag pieces to move them; snap feedback is visual, audio, and optional haptic.
- Pinch to zoom, two-finger drag to pan the workspace.
- Tap the preview thumbnail to open the large reference overlay.

### Suggested download text
- Windows & Linux builds include embedded resources; install is not required—extract and run.
- Android APK is signed for direct sideloading; saves and settings are stored locally.

### System requirements (guide)
- Windows 10/11 or Linux x86_64; OpenGL 3.3+.
- Android 8.0+ (arm64) with ~200 MB free space.
- 4 GB RAM recommended for larger puzzles.

## Page setup checklist
1) Create or open the itch.io project page and set Title: “Puzzle Champ”.  
2) Upload assets in this order: `cover.png` (cover), `gameplay.gif`, `screenshot-1.png`, `screenshot-2.png`, and set `icon_itch_512.png` as the project icon.  
3) Paste the **Short description** and **Full page copy** above into the page body (use the feature bullets list).  
4) Pricing: mark as Free (or update if you choose to charge).  
5) Kind of project: Game; Release status: In development (or Release when builds are ready).  
6) Visibility: set to Public when ready; keep “Show this page in listings” enabled.  
7) Add the Downloads section with builds/channels below.  
8) Save, then “View page” to confirm assets load correctly.

## Builds & uploads

### Export builds from Godot 4.3
Run from the repository root (Godot 4.3 export templates required):
```
godot4 --headless --export-release "Windows Desktop" builds/windows/puzzle-champ.exe
godot4 --headless --export-release "Linux/X11" builds/linux/puzzle-champ.x86_64
godot4 --headless --export-release "Android" builds/android/puzzle-champ.apk
```

### Push builds with butler (replace account if different)
```
butler push builds/windows/puzzle-champ.exe woodbase/puzzle-champ:windows
butler push builds/linux/puzzle-champ.x86_64 woodbase/puzzle-champ:linux
butler push builds/android/puzzle-champ.apk woodbase/puzzle-champ:android
```
Recommend setting Windows/Linux channels to “Install by extracting” and Android to “Download and install APK”.

### If uploading via the itch.io web UI
- Create a separate upload entry for each platform with matching labels (Windows, Linux, Android).
- Tick “This file is a build” and choose the correct OS for each upload.
- If you want an HTML5 build later, add another upload/channel.

## Support blurb (optional)
Need help? File an issue on the GitHub repo or reach out via the itch.io page comments.
