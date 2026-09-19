class_name LevelTileMap extends Node

@export var ground_layer: TileMapLayer
@export var blocking_layer: TileMapLayer
@export var scan_overlay_layer: TileMapLayer

@export_group("Treasure Seeding")
@export_range(0.0, 1.0, 0.01) var treasure_chance: float = 0.06
@export var default_treasure: TreasureData

@export_group("Item Seeding")
@export_range(0.0, 1.0, 0.01) var item_chance: float = 0.12
@export var default_item: ItemData

@export_group("Scan Overlay")
@export var scan_overlay_density_levels: int = 4

const DEFAULT_ITEM_POOL = [
	preload("res://items/loot/iron_ball.tres"),
	preload("res://items/loot/metal_plate.tres"),
	preload("res://items/loot/rusted_spear.tres"),
	preload("res://items/loot/ancient_sword.tres"),
	preload("res://items/loot/gold_coin.tres"),
	preload("res://items/loot/golden_idol.tres"),
	preload("res://items/loot/scrap_chunk.tres"),
]

# Vector2i tile_pos -> { is_diggable, treasure, item }
var tile_data: Dictionary = {}
var runtime_blocked_tiles: Dictionary = {}
# Each buried object gets one persistent detector profile. Scans reveal that
# profile with increasing confidence instead of rerolling the object.
var signal_profiles: Dictionary = {}
var signal_scan_counts: Dictionary = {}
var _scan_display_tween: Tween

signal treasure_dug(tile_pos: Vector2i, treasure: TreasureData)
signal scan_overlay_finished()

func _ready() -> void:
	add_to_group("level_tile_map")
	_seed_tile_contents()

func is_walkable(tile_pos: Vector2i) -> bool:
	if runtime_blocked_tiles.has(tile_pos):
		return false
	if blocking_layer and blocking_layer.get_cell_source_id(tile_pos) != -1:
		return false
	return ground_layer.get_cell_source_id(tile_pos) != -1

func add_runtime_blocker(tile_pos: Vector2i) -> void:
	runtime_blocked_tiles[tile_pos] = true

func remove_runtime_blocker(tile_pos: Vector2i) -> void:
	runtime_blocked_tiles.erase(tile_pos)

func is_diggable(tile_pos: Vector2i) -> bool:
	return tile_data.has(tile_pos) and tile_data[tile_pos]["is_diggable"]

func has_treasure(tile_pos: Vector2i) -> bool:
	return tile_data.has(tile_pos) and tile_data[tile_pos]["treasure"] != null

func get_treasure(tile_pos: Vector2i) -> TreasureData:
	if not tile_data.has(tile_pos):
		return null
	return tile_data[tile_pos]["treasure"]

func set_diggable(tile_pos: Vector2i, value: bool) -> void:
	_ensure_tile(tile_pos)
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
		_clear_signal_profile(tile_pos)

func clear_buried_content(tile_pos: Vector2i) -> void:
	if tile_data.has(tile_pos):
		tile_data[tile_pos]["item"] = null
		tile_data[tile_pos]["treasure"] = null
		_clear_signal_profile(tile_pos)

func place_item(tile_pos: Vector2i, item: ItemData) -> bool:
	if item == null or ground_layer.get_cell_source_id(tile_pos) == -1:
		return false
	_ensure_tile(tile_pos)
	var instance: ItemData = item.duplicate()
	instance.reset_durability()
	tile_data[tile_pos]["item"] = instance
	tile_data[tile_pos]["is_diggable"] = true
	_reset_signal_profile(tile_pos)
	return true

func place_existing_item(tile_pos: Vector2i, item: ItemData) -> bool:
	if item == null or ground_layer.get_cell_source_id(tile_pos) == -1:
		return false
	_ensure_tile(tile_pos)
	tile_data[tile_pos]["item"] = item
	tile_data[tile_pos]["is_diggable"] = true
	_reset_signal_profile(tile_pos)
	return true

func has_buried_content(tile_pos: Vector2i) -> bool:
	return has_treasure(tile_pos) or has_item(tile_pos)

func dig(tile_pos: Vector2i) -> TreasureData:
	if not is_diggable(tile_pos):
		return null
	var treasure: TreasureData = get_treasure(tile_pos)
	if treasure == null:
		return null
	tile_data[tile_pos]["treasure"] = null
	_clear_signal_profile(tile_pos)
	treasure_dug.emit(tile_pos, treasure)
	return treasure

func find_treasure_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	# Kept for compatibility with older code.
	return find_buried_in_radius(center, radius)

func find_buried_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var hits: Array[Vector2i] = []
	for pos: Vector2i in tile_data:
		if not has_buried_content(pos):
			continue
		var dist := absi(pos.x - center.x) + absi(pos.y - center.y)
		if dist <= radius:
			hits.append(pos)
	hits.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := absi(a.x - center.x) + absi(a.y - center.y)
		var db := absi(b.x - center.x) + absi(b.y - center.y)
		return da < db)
	return hits

func scan_signal_reading(tile_pos: Vector2i, from_tile: Vector2i) -> Dictionary:
	# A real scan improves analysis by one step, capped at three.
	if not has_buried_content(tile_pos):
		return {"found": false}
	_ensure_signal_profile(tile_pos)
	var scan_level: int = mini(int(signal_scan_counts.get(tile_pos, 0)) + 1, 3)
	signal_scan_counts[tile_pos] = scan_level
	return _build_signal_reading(tile_pos, from_tile, scan_level)

func get_signal_reading(tile_pos: Vector2i, from_tile: Vector2i) -> Dictionary:
	# Non-mutating lookup for UI/debug code. Actual scanning should call
	# scan_signal_reading() so repeated scans improve confidence.
	if not has_buried_content(tile_pos):
		return {"found": false}
	_ensure_signal_profile(tile_pos)
	var scan_level: int = maxi(1, int(signal_scan_counts.get(tile_pos, 0)))
	return _build_signal_reading(tile_pos, from_tile, scan_level)

func _build_signal_reading(tile_pos: Vector2i, from_tile: Vector2i, scan_level: int) -> Dictionary:
	var profile: Dictionary = signal_profiles[tile_pos]
	var delta := tile_pos - from_tile
	var dist := absi(delta.x) + absi(delta.y)
	var level := clampi(scan_level, 1, 3)

	# Gold/usefulness are probabilities reported by an imperfect detector.
	# Their bands overlap on early scans, then separate as analysis improves.
	var gold_pct := _trait_probability(bool(profile["is_gold"]), int(profile["gold_noise"]), level)
	var utility_pct := _trait_probability(bool(profile["is_useful"]), int(profile["utility_noise"]), level)

	# Size is a classification rather than a yes/no probability. Some objects
	# begin misclassified, but most are corrected by scans two or three.
	var size_guess: String = str(profile["true_size_name"])
	var reveal_scan: int = int(profile["size_reveal_scan"])
	if level < reveal_scan:
		size_guess = str(profile["wrong_size_name"])
	var size_confidence := _size_confidence(level, level >= reveal_scan, int(profile["size_noise"]))

	return {
		"found": true,
		"here": dist == 0,
		"distance": dist,
		"direction": _direction_name(delta),
		"arrow": _direction_arrow(delta),
		"size_guess": size_guess,
		"size_confidence": size_confidence,
		"gold": gold_pct,
		"utility": utility_pct,
		"analysis_level": level,
		"analysis_max": 3,
	}

func get_signal_analysis(tile_pos: Vector2i, from_tile: Vector2i) -> String:
	var reading := get_signal_reading(tile_pos, from_tile)
	if not bool(reading.get("found", false)):
		return "No buried signal."
	if bool(reading.get("here", false)):
		return "SIGNAL HERE - B: DIG"
	return "%d tiles %s" % [int(reading.get("distance", 0)), str(reading.get("direction", ""))]

func _ensure_signal_profile(tile_pos: Vector2i) -> void:
	if signal_profiles.has(tile_pos):
		return
	var item := get_item(tile_pos)
	var true_size := ItemData.ItemSize.SMALL
	var is_gold := false
	var is_useful := false
	if item:
		true_size = item.item_size
		is_gold = item.is_gold
		is_useful = item.use_type != ItemData.UseType.NONE or not item.capabilities.is_empty()
	else:
		# Loose buried treasure is compact, valuable, and not a utility tool.
		true_size = ItemData.ItemSize.SMALL
		is_gold = true
		is_useful = false

	var true_size_name := _size_name(true_size)
	var wrong_sizes := ["SMALL", "MEDIUM", "LARGE"]
	wrong_sizes.erase(true_size_name)
	var wrong_size_name: String = wrong_sizes.pick_random()

	# Roughly 55% read size correctly immediately, 27% correct on scan two,
	# 13% on scan three, and 5% remain imperfect even after three scans.
	var roll := randf()
	var reveal_scan := 1
	if roll >= 0.95:
		reveal_scan = 4
	elif roll >= 0.82:
		reveal_scan = 3
	elif roll >= 0.55:
		reveal_scan = 2

	signal_profiles[tile_pos] = {
		"true_size_name": true_size_name,
		"wrong_size_name": wrong_size_name,
		"size_reveal_scan": reveal_scan,
		"size_noise": randi_range(-6, 6),
		"is_gold": is_gold,
		"gold_noise": randi_range(-10, 10),
		"is_useful": is_useful,
		"utility_noise": randi_range(-10, 10),
	}
	signal_scan_counts[tile_pos] = 0

func _reset_signal_profile(tile_pos: Vector2i) -> void:
	_clear_signal_profile(tile_pos)
	if has_buried_content(tile_pos):
		_ensure_signal_profile(tile_pos)

func _clear_signal_profile(tile_pos: Vector2i) -> void:
	signal_profiles.erase(tile_pos)
	signal_scan_counts.erase(tile_pos)

func _trait_probability(actual_trait: bool, noise: int, scan_level: int) -> int:
	var base: int
	var noise_scale: float
	match scan_level:
		1:
			base = 60 if actual_trait else 40
			noise_scale = 1.0
		2:
			base = 74 if actual_trait else 26
			noise_scale = 0.65
		_:
			base = 87 if actual_trait else 13
			noise_scale = 0.35
	return clampi(base + int(round(noise * noise_scale)), 5, 95)

func _size_confidence(scan_level: int, guess_is_correct: bool, noise: int) -> int:
	var base := 48 + scan_level * 12
	if not guess_is_correct:
		base -= 8
	return clampi(base + noise, 35, 94)

func _size_name(size: ItemData.ItemSize) -> String:
	match size:
		ItemData.ItemSize.SMALL:
			return "SMALL"
		ItemData.ItemSize.MEDIUM:
			return "MEDIUM"
		ItemData.ItemSize.LARGE:
			return "LARGE"
	return "UNKNOWN"

func _direction_name(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return "HERE"
	var vertical := ""
	var horizontal := ""
	if delta.y < 0:
		vertical = "UP"
	elif delta.y > 0:
		vertical = "DOWN"
	if delta.x < 0:
		horizontal = "LEFT"
	elif delta.x > 0:
		horizontal = "RIGHT"
	if vertical != "" and horizontal != "":
		return vertical + "/" + horizontal
	return vertical if vertical != "" else horizontal

func _direction_arrow(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return "!"
	var arrow := ""
	if delta.y < 0:
		arrow += "^"
	elif delta.y > 0:
		arrow += "v"
	if delta.x < 0:
		arrow += "<"
	elif delta.x > 0:
		arrow += ">"
	return arrow

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

	var buried_hits: Array[Vector2i] = find_buried_in_radius(center, radius)
	var rings: Array = _group_tiles_into_rings(center, radius)
	var non_empty_rings: Array = rings.filter(func(ring: Array) -> bool: return not ring.is_empty())

	if non_empty_rings.is_empty():
		scan_overlay_finished.emit()
		return

	_scan_display_tween = create_tween()
	for i in range(non_empty_rings.size()):
		var ring: Array[Vector2i] = non_empty_rings[i]
		_scan_display_tween.tween_callback(_paint_ring.bind(ring, buried_hits))
		if i < non_empty_rings.size() - 1:
			_scan_display_tween.tween_interval(ring_stagger)
	_scan_display_tween.tween_interval(display_duration)
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
	var rings: Array = []
	rings.resize(radius + 1)
	for i in range(radius + 1):
		rings[i] = [] as Array[Vector2i]
	for pos: Vector2i in find_tiles_in_radius(center, radius):
		var dist := absi(pos.x - center.x) + absi(pos.y - center.y)
		rings[dist].append(pos)
	return rings

func _paint_ring(ring: Array[Vector2i], buried_hits: Array[Vector2i]) -> void:
	for pos: Vector2i in ring:
		var level := _scan_density_level(pos, buried_hits)
		scan_overlay_layer.set_cell(pos, 0, Vector2i(level - 1, 0))

func _clear_ring(ring: Array[Vector2i]) -> void:
	for pos: Vector2i in ring:
		scan_overlay_layer.erase_cell(pos)

func _scan_density_level(pos: Vector2i, buried_hits: Array[Vector2i]) -> int:
	if has_buried_content(pos):
		return scan_overlay_density_levels
	var nearest_dist := 9999
	for buried_pos: Vector2i in buried_hits:
		nearest_dist = mini(nearest_dist, absi(pos.x - buried_pos.x) + absi(pos.y - buried_pos.y))
	return clampi(scan_overlay_density_levels - nearest_dist, 1, scan_overlay_density_levels - 1)

func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return ground_layer.to_global(ground_layer.map_to_local(tile_pos))

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(world_pos))

func get_tile_size() -> Vector2i:
	return ground_layer.tile_set.tile_size

func _ensure_tile(tile_pos: Vector2i) -> void:
	if not tile_data.has(tile_pos):
		tile_data[tile_pos] = {"is_diggable": true, "treasure": null, "item": null}

func _seed_tile_contents() -> void:
	var treasure_count := 0
	var item_count := 0
	for cell: Vector2i in ground_layer.get_used_cells():
		if blocking_layer and blocking_layer.get_cell_source_id(cell) != -1:
			continue
		_ensure_tile(cell)
		# Items and loose treasure are exclusive so every signal has one clear reveal.
		if randf() < item_chance:
			var source: ItemData = DEFAULT_ITEM_POOL.pick_random()
			var item_instance: ItemData = source.duplicate()
			item_instance.reset_durability()
			tile_data[cell]["item"] = item_instance
			item_count += 1
		elif default_treasure and randf() < treasure_chance:
			tile_data[cell]["treasure"] = default_treasure.duplicate()
			treasure_count += 1
	# Generate one stable detector profile for every buried object after seeding.
	for pos: Vector2i in tile_data:
		if has_buried_content(pos):
			_ensure_signal_profile(pos)
	print("LevelTileMap: seeded %d treasure tile(s) and %d usable item tile(s)" % [treasure_count, item_count])
