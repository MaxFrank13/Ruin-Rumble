extends Node

const MAX_ITEMS := 3

# Kept exported so the old autoload scene remains compatible, but these are now
# permanent player tools and no longer consume treasure inventory slots.
@export var starting_detector: ItemData
@export var starting_shovel: ItemData

var items: Array[ItemData] = []
var equipped_item: ItemData = null

signal item_added(item: ItemData)
signal item_removed(item: ItemData)
signal equipped_item_changed(item: ItemData)
signal item_durability_changed(item: ItemData)

func _ready() -> void:
	# The 3 visible slots are intentionally reserved for excavated finds.
	pass

func add_item(item: ItemData) -> bool:
	if item == null or is_full():
		return false
	var instance := _fresh_instance(item)
	items.append(instance)
	item_added.emit(instance)
	if equipped_item == null:
		equip_item(instance)
	return true

func add_existing_item(item: ItemData) -> bool:
	if item == null or is_full():
		return false
	items.append(item)
	item_added.emit(item)
	if equipped_item == null:
		equip_item(item)
	return true

func remove_item(item: ItemData) -> void:
	if not items.has(item):
		return
	var old_index := items.find(item)
	items.erase(item)
	item_removed.emit(item)
	if equipped_item == item:
		if items.is_empty():
			equipped_item = null
			equipped_item_changed.emit(null)
		else:
			equip_item(items[mini(old_index, items.size() - 1)])

func swap_equipped_for(new_item: ItemData) -> ItemData:
	if new_item == null:
		return null
	if not is_full():
		add_item(new_item)
		return null
	if equipped_item == null:
		return null
	var index := items.find(equipped_item)
	var dropped := equipped_item
	var instance := _fresh_instance(new_item)
	items[index] = instance
	item_removed.emit(dropped)
	item_added.emit(instance)
	equip_item(instance)
	return dropped

func has_item(item: ItemData) -> bool:
	return items.has(item)

func is_full() -> bool:
	return items.size() >= MAX_ITEMS

func get_items() -> Array[ItemData]:
	return items.duplicate()

func equip_item(item: ItemData) -> bool:
	if not items.has(item):
		return false
	equipped_item = item
	equipped_item_changed.emit(item)
	return true

func unequip_item() -> void:
	equipped_item = null
	equipped_item_changed.emit(null)

func get_equipped_item() -> ItemData:
	return equipped_item

func is_equipped(item: ItemData) -> bool:
	return equipped_item == item

func cycle_equipped_item() -> void:
	if items.is_empty():
		return
	var current_index := items.find(equipped_item)
	var next_index := 0 if current_index < 0 else (current_index + 1) % items.size()
	equip_item(items[next_index])

func apply_item_use(item: ItemData) -> void:
	if item == null or not items.has(item):
		return
	item.apply_use_durability()
	item_durability_changed.emit(item)
	if item.is_broken():
		remove_item(item)

func get_total_value() -> int:
	var total := 0
	for item in items:
		total += item.display_value()
	return total

func clear_inventory() -> void:
	items.clear()
	equipped_item = null
	equipped_item_changed.emit(null)

func _fresh_instance(item: ItemData) -> ItemData:
	var instance: ItemData = item.duplicate()
	instance.reset_durability()
	return instance
