extends PlayerState

@export var idle_state: PlayerState

func enter() -> void:
	super()
	print("Nothing to interact with.")

func process_frame(_delta: float) -> PlayerState:
	return idle_state
