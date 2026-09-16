extends PlayerState

@export var idle_state: PlayerState

func enter() -> void:
	super()
	var tile_pos: Vector2i = parent.current_tile
	if not parent.level_tile_map.is_diggable(tile_pos):
		print("Nothing to dig here.")
		return

	var treasure: TreasureData = parent.level_tile_map.dig(tile_pos)
	if treasure:
		print("Dug up: %s" % treasure.treasure_name)

	var item: ItemData = parent.level_tile_map.get_item(tile_pos)
	if item:
		if InventoryManager.add_item(item):
			parent.level_tile_map.clear_item(tile_pos)
			print("Picked up: %s" % item.item_name)
		else:
			print("Inventory full — can't pick up %s." % item.item_name)

	if not treasure and not item:
		print("Nothing here.")

func process_frame(_delta: float) -> PlayerState:
	return idle_state
