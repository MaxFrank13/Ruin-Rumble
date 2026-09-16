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
		return null
	if event.is_action_pressed("B"):
		return _use_equipped_item()

	var input_vector: Vector2i = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2i.ZERO:
		move_state.setup(input_vector)
		return move_state
	return null

func _use_equipped_item() -> PlayerState:
	var item: ItemData = InventoryManager.get_equipped_item()
	if item == null:
		return null
	var next_state: PlayerState = null
	match item.action:
		ItemData.Action.SCAN:
			next_state = scan_state
		ItemData.Action.DIG:
			next_state = dig_state
	if next_state:
		InventoryManager.apply_item_use(item)
	return next_state
