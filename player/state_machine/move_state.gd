class_name MoveState extends PlayerState

@export var idle_state: PlayerState

var _initial_direction: Vector2i = Vector2i.ZERO
var _queued_direction: Vector2i = Vector2i.ZERO
var _is_moving: bool = false
var _started: bool = false

func setup(direction: Vector2i) -> void:
	_initial_direction = direction

func enter() -> void:
	super()
	_queued_direction = Vector2i.ZERO
	_started = _do_move(_initial_direction)
	_initial_direction = Vector2i.ZERO

func process_input(_event: InputEvent) -> PlayerState:
	var input_vector: Vector2i = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2i.ZERO:
		_queued_direction = input_vector
	return null

func process_frame(_delta: float) -> PlayerState:
	if not _started:
		return idle_state
	if _is_moving:
		return null
	var next_dir := _queued_direction
	_queued_direction = Vector2i.ZERO
	if next_dir == Vector2i.ZERO:
		next_dir = Vector2i(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if next_dir != Vector2i.ZERO and _do_move(next_dir):
		return null
	return idle_state

func _do_move(direction: Vector2i) -> bool:
	if not parent.try_move(direction):
		return false
	_is_moving = true
	var tween := parent.create_tween()
	tween.tween_property(parent, "global_position", parent.level_tile_map.tile_to_world(parent.current_tile), parent.move_duration)
	tween.tween_callback(func():
		_is_moving = false
	)
	return true
