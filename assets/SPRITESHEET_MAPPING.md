# Sprite-sheet implementation

The runtime gameplay art for excavated items, enemies, and player combat now reads directly from the artist sprite sheets. No generated SVG item/enemy art is referenced by gameplay.

## `assets/items/useable_items/GB-items.png`
- Ancient Sword: `(8, 8, 16, 16)`
- Metal Plate / Shield: `(120, 8, 16, 16)`
- Rusted Spear: `(64, 56, 16, 32)`
- Old Gold Coin: `(128, 56, 16, 16)`
- Golden Idol: `(48, 96, 16, 16)`
- Iron Ball: `(112, 96, 16, 16)`
- Scrap Chunk: `(128, 96, 16, 16)`
- The Old Gold: `(96, 128, 16, 16)`

## `assets/misc/GB-enemies.png`
- Bat: first two flap frames along the top row.
- Moai: directional poses on the lower rows; extended-arm frames are used for pound wind-up/slam.

## `assets/misc/GB-darcy.png`
- Top row: normal movement/directional poses.
- Second row: shielded movement/directional poses.
- Bottom section: sword-attack compositions.

Thrown items use their atlas icon as the in-world projectile, so edits to the sheet automatically affect both HUD and gameplay visuals after Godot reimports the PNG.
