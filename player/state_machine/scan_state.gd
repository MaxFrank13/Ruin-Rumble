class_name ScanState extends PlayerState

@export var idle_state: PlayerState
@export var scan_radius: int = 4
@export var ring_stagger: float = 0.06
@export var display_duration: float = 0.55

var _finished: bool = false

func enter() -> void:
	super()
	_finished = false
	var hits: Array[Vector2i] = parent.level_tile_map.find_buried_in_radius(parent.current_tile, scan_radius)
	if hits.is_empty():
		parent.treasure_scanned.emit("NO SIGNAL")
		parent.show_detector_reading({"found": false})
	else:
		var nearest := hits[0]
		var reading: Dictionary = parent.level_tile_map.scan_signal_reading(nearest, parent.current_tile)
		parent.treasure_scanned.emit(parent.level_tile_map.get_signal_analysis(nearest, parent.current_tile))
		parent.show_detector_reading(reading)
		if bool(reading.get("here", false)):
			parent.show_treasure_alert()
	parent.level_tile_map.scan_overlay_finished.connect(_on_overlay_finished, CONNECT_ONE_SHOT)
	parent.level_tile_map.play_scan_overlay(parent.current_tile, scan_radius, ring_stagger, display_duration)

func exit() -> void:
	if parent.level_tile_map.scan_overlay_finished.is_connected(_on_overlay_finished):
		parent.level_tile_map.scan_overlay_finished.disconnect(_on_overlay_finished)

func process_frame(_delta: float) -> PlayerState:
	return idle_state if _finished else null

func _on_overlay_finished() -> void:
	_finished = true
	parent.complete_action()
