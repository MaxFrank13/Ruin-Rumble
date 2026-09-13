class_name LevelTileMap extends Node

@export var ground_layer: TileMapLayer
@export var blocking_layer: TileMapLayer

@export_group("Treasure Seeding")
@export_range(0.0, 1.0, 0.01) var treasure_chance: float = 0.1
@export var default_treasure: TreasureData

# Vector2i tile_pos → { "is_diggable": bool, "treasure": TreasureData }
var tile_data: Dictionary = {}

signal treasure_dug(tile_pos: Vector2i, treasure: TreasureData)

func _ready() -> void:
	_seed_treasure()

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

func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return ground_layer.to_global(ground_layer.map_to_local(tile_pos))

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(world_pos))

func get_tile_size() -> Vector2i:
	return ground_layer.tile_set.tile_size

func _seed_treasure() -> void:
	var treasure_count := 0
	for cell: Vector2i in ground_layer.get_used_cells():
		if not is_walkable(cell):
			continue
		tile_data[cell] = {"is_diggable": true, "treasure": null}
		if default_treasure and randf() < treasure_chance:
			tile_data[cell]["treasure"] = default_treasure.duplicate()
			treasure_count += 1
	print("LevelTileMap: seeded %d treasure tile(s) across %d walkable tiles" % [treasure_count, tile_data.size()])
