class_name LevelTileMap extends Node

@export var ground_layer: TileMapLayer
@export var blocking_layer: TileMapLayer
@export var scan_overlay_layer: TileMapLayer

@export_group("Treasure Seeding")
@export_range(0.0, 1.0, 0.01) var treasure_chance: float = 0.1
@export var default_treasure: TreasureData

@export_group("Item Seeding")
@export_range(0.0, 1.0, 0.01) var item_chance: float = 0.0
@export var default_item: ItemData

@export_group("Scan Overlay")
@export var scan_overlay_density_levels: int = 4

# Vector2i tile_pos → { "is_diggable": bool, "treasure": TreasureData, "item": ItemData }
var tile_data: Dictionary = {}

var _scan_display_tween: Tween

signal treasure_dug(tile_pos: Vector2i, treasure: TreasureData)
signal scan_overlay_finished()

func _ready() -> void:
	_seed_tile_contents()

func is_walkable(tile_pos: Vector2i) -> bool:
	if blocking_layer and blocking_layer.get_cell_source_id(tile_pos) != -1:
		return false
	return ground_layer.get_cell_source_id(tile_pos) != -1

## TODO: meant to be used to check if something is impeding the player from digging on the tile
func is_diggable(tile_pos: Vector2i) -> bool:
	return tile_data.has(tile_pos) and tile_data[tile_pos]["is_diggable"]

func has_treasure(tile_pos: Vector2i) -> bool:
	return tile_data.has(tile_pos) and tile_data[tile_pos]["treasure"] != null

func get_treasure(tile_pos: Vector2i) -> TreasureData:
	if not tile_data.has(tile_pos):
		return null
	return tile_data[tile_pos]["treasure"]

func set_diggable(tile_pos: Vector2i, value: bool) -> void:
	if tile_data.has(tile_pos):
		tile_data[tile_pos]["is_diggable"] = value

func has_item(tile_pos: Vector2i) -> bool:
	return tile_data.has(tile_pos) and tile_data[tile_pos]["item"] != null

func get_item(tile_pos: Vector2i) -> ItemData:
	if not tile_data.has(tile_pos):
		return null
	return tile_data[tile_pos]["item"]

func clear_item(tile_pos: Vector2i) -> void:
	if tile_data.has(tile_pos):
		tile_data[tile_pos]["item"] = null

func dig(tile_pos: Vector2i) -> TreasureData:
	if not is_diggable(tile_pos):
		return null
	var treasure: TreasureData = get_treasure(tile_pos)
	if treasure == null:
		return null
	tile_data[tile_pos]["treasure"] = null
	treasure_dug.emit(tile_pos, treasure)
	return treasure

func find_treasure_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var hits: Array[Vector2i] = []
	for pos: Vector2i in tile_data:
		if not has_treasure(pos):
			continue
		var dist := absi(pos.x - center.x) + absi(pos.y - center.y)
		if dist <= radius:
			hits.append(pos)
	hits.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var distance_to_a := absi(a.x - center.x) + absi(a.y - center.y)
		var distance_to_b := absi(b.x - center.x) + absi(b.y - center.y)
		return distance_to_a < distance_to_b)
	return hits

func find_tiles_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var hits: Array[Vector2i] = []
	for pos: Vector2i in tile_data:
		if absi(pos.x - center.x) + absi(pos.y - center.y) <= radius:
			hits.append(pos)
	return hits

func play_scan_overlay(center: Vector2i, radius: int, ring_stagger: float, display_duration: float) -> void:
	if not scan_overlay_layer:
		scan_overlay_finished.emit()
		return
	_cancel_scan_overlay()

	var treasure_hits: Array[Vector2i] = find_treasure_in_radius(center, radius)
	var rings: Array = _group_tiles_into_rings(center, radius)
	var non_empty_rings: Array = rings.filter(func(ring: Array) -> bool: return not ring.is_empty())

	if non_empty_rings.is_empty():
		scan_overlay_finished.emit()
		return

	_scan_display_tween = create_tween()

	# reveal the closest ring to the player, outward to the farthest non-empty ring
	for i in range(non_empty_rings.size()):
		var ring: Array[Vector2i] = non_empty_rings[i]
		_scan_display_tween.tween_callback(_paint_ring.bind(ring, treasure_hits))
		if i < non_empty_rings.size() - 1:
			_scan_display_tween.tween_interval(ring_stagger)

	# hold the full pattern visible using tween
	_scan_display_tween.tween_interval(display_duration)

	# retract the farthest ring from the player inward
	for i in range(non_empty_rings.size() - 1, -1, -1):
		var ring: Array[Vector2i] = non_empty_rings[i]
		_scan_display_tween.tween_callback(_clear_ring.bind(ring))
		if i > 0:
			_scan_display_tween.tween_interval(ring_stagger)

	_scan_display_tween.tween_callback(func():
		clear_scan_overlay()
		scan_overlay_finished.emit())

func clear_scan_overlay() -> void:
	if scan_overlay_layer:
		scan_overlay_layer.clear()

func _cancel_scan_overlay() -> void:
	if _scan_display_tween and _scan_display_tween.is_valid():
		_scan_display_tween.kill()
	clear_scan_overlay()

func _group_tiles_into_rings(center: Vector2i, radius: int) -> Array:
	# index i holds an Array[Vector2i] of tiles at Manhattan distance i from center
	var rings: Array = []
	rings.resize(radius + 1)
	for i in range(radius + 1):
		rings[i] = [] as Array[Vector2i]
	for pos: Vector2i in find_tiles_in_radius(center, radius):
		var dist := absi(pos.x - center.x) + absi(pos.y - center.y)
		rings[dist].append(pos)
	return rings

func _paint_ring(ring: Array[Vector2i], treasure_hits: Array[Vector2i]) -> void:
	for pos: Vector2i in ring:
		var level := _scan_density_level(pos, treasure_hits)
		scan_overlay_layer.set_cell(pos, 0, Vector2i(level - 1, 0))

func _clear_ring(ring: Array[Vector2i]) -> void:
	for pos: Vector2i in ring:
		scan_overlay_layer.erase_cell(pos)

func _scan_density_level(pos: Vector2i, treasure_hits: Array[Vector2i]) -> int:
	if has_treasure(pos):
		return scan_overlay_density_levels
	var nearest_dist := 9999
	for treasure_pos: Vector2i in treasure_hits:
		nearest_dist = mini(nearest_dist, absi(pos.x - treasure_pos.x) + absi(pos.y - treasure_pos.y))
	# the solid level (scan_overlay_density_levels) is reserved for has_treasure(pos) above; every
	# other level steps down exactly one per tile of distance, so each is reachable at some distance
	return clampi(scan_overlay_density_levels - nearest_dist, 1, scan_overlay_density_levels - 1)

func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return ground_layer.to_global(ground_layer.map_to_local(tile_pos))

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(world_pos))

func get_tile_size() -> Vector2i:
	return ground_layer.tile_set.tile_size

func _seed_tile_contents() -> void:
	var treasure_count := 0
	var item_count := 0
	for cell: Vector2i in ground_layer.get_used_cells():
		if not is_walkable(cell):
			continue
		tile_data[cell] = {"is_diggable": true, "treasure": null, "item": null}
		if default_treasure and randf() < treasure_chance:
			tile_data[cell]["treasure"] = default_treasure.duplicate()
			treasure_count += 1
		if default_item and randf() < item_chance:
			var item_instance: ItemData = default_item.duplicate()
			item_instance.reset_durability()
			tile_data[cell]["item"] = item_instance
			item_count += 1
	print("LevelTileMap: seeded %d treasure tile(s) and %d item tile(s) across %d walkable tiles" % [treasure_count, item_count, tile_data.size()])
