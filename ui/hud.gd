extends CanvasLayer

const SELECTED_ITEM_STYLE: StyleBox = preload("res://theme/selected_item_panel.tres")
const UNSELECTED_ITEM_STYLE: StyleBox = preload("res://theme/unselected_item_panel.tres")

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
@onready var value_label: Label = $PanelContainer/HBoxContainer/HBoxContainer2/PanelContainer/HBoxContainer/Label
@onready var heart_container: GridContainer = $PanelContainer/HBoxContainer/HBoxContainer2/PanelContainer2/HBoxContainer/GridContainer

var _message_panel: PanelContainer
var _message_label: Label
var _message_timer: Timer

var _detector_panel: PanelContainer
var _detector_title: Label
var _detector_arrow: Label
var _detector_info: Label
var _detector_timer: Timer

func _ready() -> void:
	InventoryManager.item_added.connect(_refresh_slots)
	InventoryManager.item_removed.connect(_refresh_slots)
	InventoryManager.equipped_item_changed.connect(_refresh_slots)
	InventoryManager.item_durability_changed.connect(_refresh_slots)
	if not RunState.money_changed.is_connected(_on_money_changed):
		RunState.money_changed.connect(_on_money_changed)
	_create_message_ui()
	_create_detector_ui()
	_refresh_slots()
	_refresh_hearts(RunState.current_health, RunState.MAX_HEALTH)
	call_deferred("_connect_player")

func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if not player:
		return
	if not player.status_message.is_connected(_show_message):
		player.status_message.connect(_show_message)
	if not player.detector_reading.is_connected(_show_detector_reading):
		player.detector_reading.connect(_show_detector_reading)
	if not player.health_changed.is_connected(_refresh_hearts):
		player.health_changed.connect(_refresh_hearts)

func _create_message_ui() -> void:
	_message_panel = PanelContainer.new()
	_message_panel.position = Vector2(4, 88)
	_message_panel.size = Vector2(152, 22)
	_message_panel.visible = false
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message_panel)

	_message_label = Label.new()
	_message_label.custom_minimum_size = Vector2(148, 18)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 8)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_panel.add_child(_message_label)

	_message_timer = Timer.new()
	_message_timer.wait_time = 2.2
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func() -> void: _message_panel.visible = false)
	add_child(_message_timer)

func _create_detector_ui() -> void:
	_detector_panel = PanelContainer.new()
	_detector_panel.position = Vector2(80, 4)
	_detector_panel.size = Vector2(76, 48)
	_detector_panel.visible = false
	_detector_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detector_panel)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 0)
	_detector_panel.add_child(root_box)

	_detector_title = Label.new()
	_detector_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detector_title.add_theme_font_size_override("font_size", 8)
	_detector_title.text = "SIGNAL"
	root_box.add_child(_detector_title)

	_detector_arrow = Label.new()
	_detector_arrow.visible = false
	root_box.add_child(_detector_arrow)

	_detector_info = Label.new()
	_detector_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detector_info.add_theme_font_size_override("font_size", 8)
	_detector_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	root_box.add_child(_detector_info)

	_detector_timer = Timer.new()
	_detector_timer.wait_time = 1.15
	_detector_timer.one_shot = true
	_detector_timer.timeout.connect(func() -> void: _detector_panel.visible = false)
	add_child(_detector_timer)

func _show_detector_reading(reading: Dictionary) -> void:
	if not _detector_panel:
		return
	if _message_panel:
		_message_panel.visible = false
	if not bool(reading.get("found", false)):
		_detector_title.text = "NO SIGNAL"
		_detector_info.text = "Nothing nearby"
	else:
		var here := bool(reading.get("here", false))
		var distance := int(reading.get("distance", 0))
		var arrow := str(reading.get("arrow", "?"))
		var level := int(reading.get("analysis_level", 1))
		_detector_title.text = "SIGNAL HERE" if here else "SIGNAL %s  %d" % [arrow, distance]
		var lines := "%s %d%%\nGOLD %d%%\nUSEFUL %d%%\n%s" % [
			str(reading.get("size_guess", "?")),
			int(reading.get("size_confidence", 0)),
			int(reading.get("gold", 0)),
			int(reading.get("utility", 0)),
			"B: DIG" if here else "SCAN %d/3" % level,
		]
		_detector_info.text = lines
	_detector_panel.visible = true
	_detector_timer.start()

func _show_message(text: String) -> void:
	if not _message_label:
		return
	if _detector_panel:
		_detector_panel.visible = false
	_message_label.text = text
	_message_panel.visible = true
	if text.begins_with("FOUND ") and text.contains("A:TAKE"):
		_message_timer.stop()
	else:
		_message_timer.start()

func _refresh_slots(_item: ItemData = null) -> void:
	var items := InventoryManager.get_items()
	var equipped := InventoryManager.get_equipped_item()
	for i in item_panels.size():
		var item: ItemData = items[i] if i < items.size() else null
		item_sprites[i].texture = item.icon if item else null
		item_sprites[i].visible = item != null
		var is_selected := item != null and item == equipped
		item_panels[i].add_theme_stylebox_override("panel", SELECTED_ITEM_STYLE if is_selected else UNSELECTED_ITEM_STYLE)
		_update_durability_bar(durability_bars[i], item)
	_refresh_value()

func _on_money_changed(_amount: int) -> void:
	_refresh_value()

func _refresh_value() -> void:
	# Show the value currently at stake: loose gold collected plus carried artifacts.
	value_label.text = "$%d" % (RunState.get_money() + InventoryManager.get_total_value())

func _refresh_hearts(current: int, maximum: int) -> void:
	var hearts := heart_container.get_children()
	for i in hearts.size():
		hearts[i].visible = i < mini(current, maximum)

func _update_durability_bar(bar: TextureProgressBar, item: ItemData) -> void:
	if item == null or item.max_durability <= 0:
		bar.visible = false
		return
	bar.visible = true
	bar.value = (float(item.current_durability) / float(item.max_durability)) * 100.0
