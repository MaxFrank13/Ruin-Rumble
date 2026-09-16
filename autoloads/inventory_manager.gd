extends Node

const MAX_ITEMS := 3

@export var starting_detector: ItemData
@export var starting_shovel: ItemData

var items: Array[ItemData] = []
var equipped_item: ItemData = null

signal item_added(item: ItemData)
signal item_removed(item: ItemData)
signal equipped_item_changed(item: ItemData)
signal item_durability_changed(item: ItemData)

func _ready() -> void:
	_setup_starting_items()

func add_item(item: ItemData) -> bool:
	if item == null or is_full():
		return false
	items.append(item)
	item_added.emit(item)
	return true

func remove_item(item: ItemData) -> void:
	if not items.has(item):
		return
	items.erase(item)
	if equipped_item == item:
		unequip_item()
	item_removed.emit(item)

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
	var next_index := (current_index + 1) % items.size()
	equip_item(items[next_index])

func apply_item_use(item: ItemData) -> void:
	item.apply_use_durability()
	item_durability_changed.emit(item)
	if item.is_broken():
		remove_item(item)

func _setup_starting_items() -> void:
	if starting_detector:
		add_item(_fresh_instance(starting_detector))
	if starting_shovel:
		add_item(_fresh_instance(starting_shovel))
	if not items.is_empty():
		equip_item(items[0])

func _fresh_instance(item: ItemData) -> ItemData:
	var instance: ItemData = item.duplicate()
	instance.reset_durability()
	return instance
