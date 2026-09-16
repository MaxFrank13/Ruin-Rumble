extends CanvasLayer

const SELECTED_ITEM_STYLE: StyleBox = preload("res://theme/selected_item_panel.tres")

## TODO: parallel arrays are never great. shouldn't build on top of this but is okay for now
@onready var item_panels: Array[PanelContainer] = [
	$PanelContainer/HBoxContainer/HBoxContainer/ItemSlot,
	$PanelContainer/HBoxContainer/HBoxContainer/ItemSlot2,
	$PanelContainer/HBoxContainer/HBoxContainer/ItemSlot3,
]
@onready var item_sprites: Array[TextureRect] = [
	$PanelContainer/HBoxContainer/HBoxContainer/ItemSlot/VBoxContainer/PanelContainer/CurrentItemSprite,
	$PanelContainer/HBoxContainer/HBoxContainer/ItemSlot2/VBoxContainer/PanelContainer/CurrentItemSprite,
	$PanelContainer/HBoxContainer/HBoxContainer/ItemSlot3/VBoxContainer/PanelContainer/CurrentItemSprite,
]
@onready var durability_bars: Array[TextureProgressBar] = [
	$PanelContainer/HBoxContainer/HBoxContainer/ItemSlot/VBoxContainer/Durability,
	$PanelContainer/HBoxContainer/HBoxContainer/ItemSlot2/VBoxContainer/Durability,
	$PanelContainer/HBoxContainer/HBoxContainer/ItemSlot3/VBoxContainer/Durability,
]

var _unselected_item_style := StyleBoxEmpty.new()

func _ready() -> void:
	_unselected_item_style.content_margin_left = 2.0
	_unselected_item_style.content_margin_top = 2.0
	_unselected_item_style.content_margin_right = 2.0
	_unselected_item_style.content_margin_bottom = 2.0

	InventoryManager.item_added.connect(_refresh_slots)
	InventoryManager.item_removed.connect(_refresh_slots)
	InventoryManager.equipped_item_changed.connect(_refresh_slots)
	InventoryManager.item_durability_changed.connect(_refresh_slots)
	_refresh_slots()

func _refresh_slots(_item: ItemData = null) -> void:
	var items := InventoryManager.get_items()
	var equipped := InventoryManager.get_equipped_item()
	for i in item_panels.size():
		var item: ItemData = items[i] if i < items.size() else null
		item_sprites[i].texture = item.icon if item else null
		var is_selected := item != null and item == equipped
		item_panels[i].add_theme_stylebox_override("panel", SELECTED_ITEM_STYLE if is_selected else _unselected_item_style)
		_update_durability_bar(durability_bars[i], item)

func _update_durability_bar(bar: TextureProgressBar, item: ItemData) -> void:
	if item == null or item.max_durability <= 0:
		bar.visible = false
		return
	bar.visible = true
	bar.value = (float(item.current_durability) / float(item.max_durability)) * 100.0
