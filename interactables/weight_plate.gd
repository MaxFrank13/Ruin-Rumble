class_name WeightPlate
extends Node2D

@export var tile_position: Vector2i = Vector2i.ZERO
@export var gate_tile_position: Vector2i = Vector2i.ZERO
@export var interaction_distance: int = 1
@export var required_capability: String = "heavy"
@export var emergency_fallback_item: ItemData
@export var emergency_fallback_tile: Vector2i = Vector2i(-1, -1)

var _level_tile_map: LevelTileMap
var _activated := false
var _held_item_name := ""

func _ready() -> void:
	add_to_group("interactables")
	call_deferred("_setup")

func _setup() -> void:
	_level_tile_map = get_tree().get_first_node_in_group("level_tile_map") as LevelTileMap
	if not _level_tile_map:
		return
	global_position = _level_tile_map.tile_to_world(tile_position)
	_level_tile_map.clear_buried_content(gate_tile_position)
	_level_tile_map.add_runtime_blocker(gate_tile_position)
	queue_redraw()

func can_interact(player: Player) -> bool:
	if _activated or not player:
		return false
	return _tile_distance(player.current_tile, tile_position) <= interaction_distance

func interact(player: Player) -> bool:
	if _activated:
		return false
	var item := InventoryManager.get_equipped_item()
	if item == null:
		_ensure_emergency_fallback()
		player.show_status("PRESSURE PLATE: needs something HEAVY.")
		return true
	if not item.has_capability(required_capability):
		_ensure_emergency_fallback()
		player.show_status("%s is not heavy enough." % item.item_name)
		return true

	_held_item_name = item.item_name
	InventoryManager.remove_item(item)
	_activated = true
	if _level_tile_map:
		_level_tile_map.remove_runtime_blocker(gate_tile_position)
	player.show_status("Left %s on the plate. Passage opened." % _held_item_name)
	queue_redraw()
	return true

func _ensure_emergency_fallback() -> void:
	if not _level_tile_map or emergency_fallback_item == null or emergency_fallback_tile.x < 0:
		return
	if _heavy_solution_still_exists():
		return
	_level_tile_map.place_item(emergency_fallback_tile, emergency_fallback_item)

func _heavy_solution_still_exists() -> bool:
	for carried in InventoryManager.get_items():
		if carried.has_capability(required_capability):
			return true
	for tile_variant in _level_tile_map.tile_data.keys():
		var tile: Vector2i = tile_variant
		var buried := _level_tile_map.get_item(tile)
		if buried and buried.has_capability(required_capability):
			return true
	return false

func _tile_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _draw() -> void:
	# Plate.
	draw_rect(Rect2(-4, -2, 8, 4), Color("75694e"), true)
	draw_rect(Rect2(-3, -1, 6, 2), Color("b49a67") if not _activated else Color("8a744d"), true)
	if not _level_tile_map:
		return
	# Gate controlled by the plate.
	if not _activated:
		var gate_local := to_local(_level_tile_map.tile_to_world(gate_tile_position))
		draw_rect(Rect2(gate_local - Vector2(4, 4), Vector2(8, 8)), Color("523a3a"), true)
		draw_rect(Rect2(gate_local - Vector2(2, 3), Vector2(4, 6)), Color("8b5e5e"), true)
