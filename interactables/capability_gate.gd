class_name CapabilityGate
extends Node2D

@export var tile_position: Vector2i = Vector2i.ZERO
@export var required_capabilities: PackedStringArray = PackedStringArray(["heavy"])
@export var gate_name: String = "Blocked Passage"
@export var interaction_distance: int = 1
@export var consume_item_use: bool = true
@export var emergency_fallback_item: ItemData
@export var emergency_fallback_tile: Vector2i = Vector2i(-1, -1)

var _level_tile_map: LevelTileMap
var _opened := false

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("gates")
	call_deferred("_setup_gate")

func _setup_gate() -> void:
	_level_tile_map = get_tree().get_first_node_in_group("level_tile_map") as LevelTileMap
	if not _level_tile_map:
		return
	global_position = _level_tile_map.tile_to_world(tile_position)
	_level_tile_map.clear_buried_content(tile_position)
	_level_tile_map.add_runtime_blocker(tile_position)
	queue_redraw()

func can_interact(player: Player) -> bool:
	if _opened or not player:
		return false
	var delta := tile_position - player.current_tile
	var distance := absi(delta.x) + absi(delta.y)
	return distance <= interaction_distance and (distance == 0 or delta == player.facing_direction)

func interact(player: Player) -> bool:
	if _opened:
		return false
	var item: ItemData = InventoryManager.get_equipped_item()
	if item == null:
		_ensure_emergency_fallback()
		player.show_status("%s: need %s. Scan nearby." % [gate_name, _requirement_text()])
		return true
	var valid := false
	for capability in required_capabilities:
		if item.has_capability(capability):
			valid = true
			break
	if not valid:
		_ensure_emergency_fallback()
		player.show_status("%s won't work. Need %s. Scan nearby." % [item.item_name, _requirement_text()])
		return true
	if consume_item_use:
		InventoryManager.apply_item_use(item)
	_opened = true
	if _level_tile_map:
		_level_tile_map.remove_runtime_blocker(tile_position)
	player.show_status("%s opened. Path clear." % gate_name)
	queue_redraw()
	return true

func _ensure_emergency_fallback() -> void:
	if not _level_tile_map or emergency_fallback_item == null or emergency_fallback_tile.x < 0:
		return
	# Do not hand the player the answer merely for checking the gate. The fallback
	# exists only as true softlock protection after every valid solution has been
	# spent, destroyed, or lost.
	if _valid_solution_still_exists():
		return
	_level_tile_map.place_item(emergency_fallback_tile, emergency_fallback_item)

func _valid_solution_still_exists() -> bool:
	for carried in InventoryManager.get_items():
		for capability in required_capabilities:
			if carried.has_capability(capability):
				return true
	for tile_variant in _level_tile_map.tile_data.keys():
		var tile: Vector2i = tile_variant
		var buried := _level_tile_map.get_item(tile)
		if buried == null:
			continue
		for capability in required_capabilities:
			if buried.has_capability(capability):
				return true
	return false

func _requirement_text() -> String:
	var words := PackedStringArray()
	for capability in required_capabilities:
		words.append(capability.to_upper())
	return " or ".join(words)

func _draw() -> void:
	if _opened:
		return
	# Placeholder gate art using the existing Game Boy-like palette.
	draw_rect(Rect2(-4, -4, 8, 8), Color("523a3a"), true)
	draw_rect(Rect2(-2, -3, 4, 6), Color("8b5e5e"), true)
