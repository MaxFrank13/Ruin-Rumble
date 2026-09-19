class_name ItemData extends Resource

# Legacy actions are kept so the existing detector/shovel resources still load.
enum Action { SCAN, DIG }
enum UseType { NONE, THROW, MELEE, SHIELD }
enum ItemSize { SMALL, MEDIUM, LARGE }

@export var item_name: String = ""
@export var icon: Texture2D
@export var action: Action = Action.SCAN
@export var value: int = 0

@export_group("Gameplay")
@export var use_type: UseType = UseType.NONE
@export var capabilities: PackedStringArray = PackedStringArray()
@export_range(0, 5, 1) var damage: int = 0
@export_range(1, 6, 1) var use_range: int = 1
@export var item_size: ItemSize = ItemSize.SMALL
@export var is_gold: bool = false
@export var value_loss_per_use: int = 0

@export_group("Durability")
@export var max_durability: int = -1
@export var durability_loss_per_use: int = 0

var current_durability: int = -1
var current_value: int = 0

func reset_durability() -> void:
	current_durability = max_durability
	current_value = value

func is_broken() -> bool:
	return max_durability >= 0 and current_durability <= 0

func apply_use_durability() -> void:
	if max_durability >= 0:
		current_durability = maxi(0, current_durability - maxi(1, durability_loss_per_use))
	if value_loss_per_use > 0:
		current_value = maxi(0, current_value - value_loss_per_use)

func has_capability(capability: String) -> bool:
	return capabilities.has(capability)

func display_value() -> int:
	return current_value if current_value > 0 or value > 0 else value

func use_summary() -> String:
	var parts := PackedStringArray()
	match use_type:
		UseType.THROW:
			parts.append("THROW")
		UseType.MELEE:
			parts.append("MELEE")
		UseType.SHIELD:
			parts.append("SHIELD")
		_:
			pass
	for capability in capabilities:
		var upper := capability.to_upper()
		if upper in ["HEAVY", "BREAKER", "SHARP"] and not parts.has(upper):
			parts.append(upper)
	if parts.is_empty():
		return "TREASURE"
	return " / ".join(parts)
