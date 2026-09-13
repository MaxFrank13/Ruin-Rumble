extends PlayerState

@export var idle_state: PlayerState

func enter() -> void:
	super()
	var treasure: TreasureData = parent.level_tile_map.dig(parent.current_tile)
	if treasure:
		print("Dug up: %s" % treasure.treasure_name)
	else:
		print("Nothing to dig here.")

func process_frame(_delta: float) -> PlayerState:
	return idle_state
