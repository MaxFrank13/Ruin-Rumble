class_name RoomLayout
extends Node2D

@export var blocked_tiles: Array[Vector2i] = []

var _level_tile_map: LevelTileMap

func _ready() -> void:
	z_index = 4
	call_deferred("_apply_layout")

func _apply_layout() -> void:
	_level_tile_map = get_tree().get_first_node_in_group("level_tile_map") as LevelTileMap
	if not _level_tile_map:
		return
	for tile in blocked_tiles:
		_level_tile_map.add_runtime_blocker(tile)
	queue_redraw()

func _draw() -> void:
	if not _level_tile_map:
		return
	for tile in blocked_tiles:
		var local_pos := to_local(_level_tile_map.tile_to_world(tile))
		draw_rect(Rect2(local_pos - Vector2(4, 4), Vector2(8, 8)), Color("523a3a"), true)
		draw_rect(Rect2(local_pos - Vector2(3, 3), Vector2(6, 6)), Color("8b5e5e"), false, 1.0)
