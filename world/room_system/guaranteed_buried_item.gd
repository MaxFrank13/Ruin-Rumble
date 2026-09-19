class_name GuaranteedBuriedItem
extends Node

@export var item: ItemData
@export var candidate_tiles: Array[Vector2i] = []

func _ready() -> void:
	call_deferred("_place")

func _place() -> void:
	var level := get_tree().get_first_node_in_group("level_tile_map") as LevelTileMap
	if not level or not item or candidate_tiles.is_empty():
		return
	var valid: Array[Vector2i] = []
	for tile in candidate_tiles:
		# Use the base ground rather than is_walkable so a later room-layout setup
		# cannot accidentally remove every guaranteed candidate.
		if level.ground_layer.get_cell_source_id(tile) != -1:
			valid.append(tile)
	if valid.is_empty():
		return
	valid.shuffle()
	for tile in valid:
		if not level.has_buried_content(tile):
			level.place_item(tile, item)
			return
	# As a final anti-softlock fallback, overwrite the first candidate.
	level.place_item(valid[0], item)
