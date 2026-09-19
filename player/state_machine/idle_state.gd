extends PlayerState

@export var move_state: MoveState
@export var scan_state: ScanState
@export var dig_state: PlayerState
@export var interact_state: PlayerState

func process_input(event: InputEvent) -> PlayerState:
	if event.is_action_pressed("A"):
		return interact_state
	if event.is_action_pressed("SELECT"):
		InventoryManager.cycle_equipped_item()
		var selected := InventoryManager.get_equipped_item()
		if selected:
			parent.show_status("Selected: %s ($%d)" % [selected.item_name, selected.display_value()])
		return null
	if event.is_action_pressed("B"):
		# B is always the treasure-hunting button: dig if standing on a signal,
		# otherwise scan the surrounding area.
		if parent.level_tile_map and parent.level_tile_map.has_buried_content(parent.current_tile):
			return dig_state
		return scan_state

	var input_vector: Vector2i = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2i.ZERO:
		move_state.setup(input_vector)
		return move_state
	return null
