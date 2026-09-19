extends PlayerState

@export var idle_state: PlayerState

func enter() -> void:
	super()
	var tile_pos: Vector2i = parent.current_tile
	if not parent.level_tile_map.is_diggable(tile_pos):
		parent.show_status("Nothing to dig here.")
		parent.complete_action(2)
		return

	var treasure: TreasureData = parent.level_tile_map.dig(tile_pos)
	if treasure:
		# Legacy loose treasure remains supported, although controlled rooms now
		# primarily use inventory-based valuables so death can put value at risk.
		RunState.add_money(treasure.value)
		parent.show_status("Found %s! +$%d" % [treasure.treasure_name, treasure.value])
		parent.show_treasure_alert()

	var item: ItemData = parent.level_tile_map.get_item(tile_pos)
	if item:
		if not InventoryManager.is_full():
			InventoryManager.add_item(item)
			parent.level_tile_map.clear_item(tile_pos)
			parent.show_status("%s  $%d\n%s" % [item.item_name, item.display_value(), item.use_summary()])
		else:
			# Reveal the item but leave it in the ground until the player decides.
			# The highlighted HUD slot is the item A will replace.
			parent.begin_loot_choice(tile_pos, item)
		parent.show_treasure_alert()

	if not treasure and not item:
		parent.show_status("Nothing here.")

	# Excavating costs two action beats. With enemies acting every two beats,
	# digging near a guardian is a deliberate risk instead of a free pickup.
	parent.complete_action(2)

func process_frame(_delta: float) -> PlayerState:
	return idle_state
