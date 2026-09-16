class_name ScanState extends PlayerState

@export var idle_state: PlayerState
@export var scan_radius: int = 3
@export var ring_stagger: float = 0.08
@export var display_duration: float = 0.6

var _finished: bool = false

func enter() -> void:
	super()
	_finished = false
	var hits : Array[Vector2i] = parent.level_tile_map.find_treasure_in_radius(parent.current_tile, scan_radius)
	parent.treasure_scanned.emit(_format_hint(hits, parent.current_tile))
	parent.level_tile_map.scan_overlay_finished.connect(_on_overlay_finished, CONNECT_ONE_SHOT)
	parent.level_tile_map.play_scan_overlay(parent.current_tile, scan_radius, ring_stagger, display_duration)

func exit() -> void:
	if parent.level_tile_map.scan_overlay_finished.is_connected(_on_overlay_finished):
		parent.level_tile_map.scan_overlay_finished.disconnect(_on_overlay_finished)

func process_frame(_delta: float) -> PlayerState:
	return idle_state if _finished else null

func _on_overlay_finished() -> void:
	_finished = true

func _format_hint(hits: Array[Vector2i], from: Vector2i) -> String:
	if hits.is_empty():
		return "No treasure detected nearby."
	var nearest: Vector2i = hits[0]
	if nearest == from:
		return "Treasure detected right here."
	var dist := absi(nearest.x - from.x) + absi(nearest.y - from.y)
	return "Treasure detected %d tile(s) away, to the %s." % [dist, _direction_hint(nearest - from)]

## TODO: janky bit of code that formats the cardinal direction. just being used for print now
## can remove later or refine for UI
func _direction_hint(delta: Vector2i) -> String:
	var parts: PackedStringArray = []
	if delta.y < 0:
		parts.append("north")
	elif delta.y > 0:
		parts.append("south")
	if delta.x > 0:
		parts.append("east")
	elif delta.x < 0:
		parts.append("west")
	return "".join(parts)
