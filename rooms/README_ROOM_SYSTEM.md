# Room / Enemy Prototype

This pass is additive. Existing movement, scanning, digging, inventory and HUD remain in place.

## Basic Enemy
- Moves on the same tile grid as the player.
- Takes one chase step after a completed player move, scan, dig or interaction.
- Does not move until the player is inside `chase_range`.
- Contact returns the player to that room's starting tile for now.
- `take_hit(damage)` is already available for future thrown-item / weapon combat.

## Room Exit
- Press A while standing on the exit tile or facing it from an adjacent tile.
- `target_scene` chooses the next room.
- Set `requires_enemy_clear = true` later if a room should lock until enemies are defeated.

## Current Prototype Flow
main.tscn -> room_02.tscn -> room_03.tscn -> run_complete.tscn

The room art/layout is intentionally still the existing prototype map so this does not replace existing work. Build unique TileMap layouts later.
