class_name RoomSetup
extends Node2D

@export_range(1, 3, 1) var room_id: int = 1

const IRON_BALL: ItemData = preload("res://items/loot/iron_ball.tres")
const METAL_PLATE: ItemData = preload("res://items/loot/metal_plate.tres")
const RUSTED_SPEAR: ItemData = preload("res://items/loot/rusted_spear.tres")
const ANCIENT_SWORD: ItemData = preload("res://items/loot/ancient_sword.tres")
const GOLD_COIN: ItemData = preload("res://items/loot/gold_coin.tres")
const GOLDEN_IDOL: ItemData = preload("res://items/loot/golden_idol.tres")
const SCRAP_CHUNK: ItemData = preload("res://items/loot/scrap_chunk.tres")
const OLD_GOLD: ItemData = preload("res://items/loot/old_gold_relic.tres")

var _level: LevelTileMap
var _blocked: Array[Vector2i] = []
var _used_signal_tiles: Dictionary = {}

func _ready() -> void:
	z_index = 4
	call_deferred("_setup")

func _setup() -> void:
	_level = get_tree().get_first_node_in_group("level_tile_map") as LevelTileMap
	if not _level:
		return

	# Rooms use hand-authored, controlled randomness rather than blanketing the map
	# with random loot. Five meaningful signals is enough to create inventory pressure.
	_clear_all_buried_content()

	match room_id:
		1:
			_setup_room_one()
		2:
			_setup_room_two()
		3:
			_setup_room_three()

	for tile in _blocked:
		_level.clear_buried_content(tile)
		_level.add_runtime_blocker(tile)
	queue_redraw()

func _setup_room_one() -> void:
	# Open introductory chamber. The guardian sits between the player and the seal.
	# The solution exists, but the player has to decide which signals are worth the
	# time/risk to investigate rather than being handed the exact item.
	for y in range(0, 13):
		if y != 6:
			_blocked.append(Vector2i(15, y))

	_place_random_from_pool(
		[IRON_BALL, ANCIENT_SWORD, GOLDEN_IDOL],
		[Vector2i(3, 3), Vector2i(5, 9), Vector2i(7, 5)]
	)
	_place_random_from_pool(
		[METAL_PLATE, RUSTED_SPEAR, SCRAP_CHUNK],
		[Vector2i(4, 10), Vector2i(8, 3), Vector2i(10, 9)]
	)
	_place_random_from_pool(
		[GOLD_COIN, GOLD_COIN, GOLDEN_IDOL],
		[Vector2i(6, 2), Vector2i(11, 3), Vector2i(12, 10)]
	)
	_place_random_from_pool(
		[IRON_BALL, METAL_PLATE, RUSTED_SPEAR, ANCIENT_SWORD, GOLD_COIN, SCRAP_CHUNK],
		[Vector2i(9, 11), Vector2i(12, 4), Vector2i(13, 8)]
	)
	_place_random_from_pool(
		[SCRAP_CHUNK, SCRAP_CHUNK, GOLD_COIN],
		[Vector2i(3, 11), Vector2i(8, 10), Vector2i(13, 2)]
	)

func _setup_room_two() -> void:
	# Room 2 is about sacrifice. A heavy object must be left on the pressure plate
	# to open the passage, so a valuable idol or useful shield may have to be given up.
	for y in range(0, 13):
		if y != 4:
			_blocked.append(Vector2i(10, y))
	for x in range(2, 8):
		if x != 5:
			_blocked.append(Vector2i(x, 8))

	_place_random_from_pool(
		[IRON_BALL, METAL_PLATE, GOLDEN_IDOL, SCRAP_CHUNK],
		[Vector2i(2, 2), Vector2i(6, 5), Vector2i(8, 10)]
	)
	_place_random_from_pool(
		[RUSTED_SPEAR, ANCIENT_SWORD, METAL_PLATE],
		[Vector2i(3, 6), Vector2i(7, 2), Vector2i(8, 6)]
	)
	_place_random_from_pool(
		[GOLD_COIN, GOLD_COIN, GOLDEN_IDOL],
		[Vector2i(3, 10), Vector2i(7, 10), Vector2i(9, 2)]
	)
	_place_random_from_pool(
		[IRON_BALL, RUSTED_SPEAR, ANCIENT_SWORD, GOLD_COIN, SCRAP_CHUNK],
		[Vector2i(4, 4), Vector2i(6, 10), Vector2i(9, 7)]
	)
	# A tempting signal sits close to the guardian's route.
	_place_random_from_pool(
		[GOLD_COIN, GOLDEN_IDOL, ANCIENT_SWORD],
		[Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5)]
	)

func _setup_room_three() -> void:
	# Final room: zig-zag sight lines, two guardians, and the guaranteed Old Gold
	# signal near the deepest point. It is valuable, but not required to escape.
	for y in range(2, 13):
		if y != 9:
			_blocked.append(Vector2i(5, y))
	for y in range(0, 10):
		if y != 3:
			_blocked.append(Vector2i(10, y))
	for y in range(0, 13):
		if y != 1:
			_blocked.append(Vector2i(14, y))

	_place_random_from_pool(
		[ANCIENT_SWORD, IRON_BALL, RUSTED_SPEAR],
		[Vector2i(2, 10), Vector2i(4, 6), Vector2i(7, 8)]
	)
	_place_random_from_pool(
		[METAL_PLATE, RUSTED_SPEAR, SCRAP_CHUNK],
		[Vector2i(6, 10), Vector2i(8, 4), Vector2i(9, 8)]
	)
	_place_random_from_pool(
		[GOLD_COIN, GOLDEN_IDOL],
		[Vector2i(7, 2), Vector2i(11, 8), Vector2i(12, 4)]
	)
	_place_random_from_pool(
		[IRON_BALL, ANCIENT_SWORD, GOLD_COIN, GOLDEN_IDOL, SCRAP_CHUNK],
		[Vector2i(11, 3), Vector2i(12, 8), Vector2i(13, 10)]
	)
	_place_specific(OLD_GOLD, Vector2i(13, 2))

func _place_random_from_pool(pool: Array, candidates: Array) -> void:
	if pool.is_empty():
		return
	var shuffled := candidates.duplicate()
	shuffled.shuffle()
	for tile_variant in shuffled:
		var tile: Vector2i = tile_variant
		if _used_signal_tiles.has(tile):
			continue
		if not _level.is_walkable(tile):
			continue
		var selected: ItemData = pool.pick_random()
		_level.clear_buried_content(tile)
		_level.place_item(tile, selected)
		_used_signal_tiles[tile] = true
		return

func _place_specific(item: ItemData, tile: Vector2i) -> void:
	if not _level.is_walkable(tile):
		return
	_level.clear_buried_content(tile)
	_level.place_item(tile, item)
	_used_signal_tiles[tile] = true

func _clear_all_buried_content() -> void:
	for tile_variant in _level.tile_data.keys():
		_level.clear_buried_content(tile_variant)

func _draw() -> void:
	if not _level:
		return
	for tile in _blocked:
		var p := to_local(_level.tile_to_world(tile))
		draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color("523a3a"), true)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color("8b5e5e"), false, 1.0)
