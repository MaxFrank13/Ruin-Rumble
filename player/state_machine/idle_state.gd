extends PlayerState

@export var move_state: MoveState
@export var scan_state: PlayerState
@export var dig_state: PlayerState

func process_input(event: InputEvent) -> PlayerState:
	if event.is_action_pressed("scan"):
		return scan_state
	if event.is_action_pressed("action"):
		return dig_state

	var input_vector: Vector2i = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2i.ZERO:
		move_state.setup(input_vector)
		return move_state
	return null
