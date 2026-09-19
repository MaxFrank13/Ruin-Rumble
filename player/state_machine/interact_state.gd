extends PlayerState

@export var idle_state: PlayerState

func enter() -> void:
	super()
	var acted = parent.try_interact()
	if not acted:
		acted = parent.try_use_selected_item()
	if not acted:
		parent.show_status("Nothing to interact with.")
	parent.complete_action()

func process_frame(_delta: float) -> PlayerState:
	return idle_state
