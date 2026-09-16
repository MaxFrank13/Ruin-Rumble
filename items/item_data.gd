class_name ItemData extends Resource

enum Action { SCAN, DIG }

@export var item_name: String = ""
@export var icon: Texture2D
@export var action: Action = Action.SCAN
@export var value: int = 0

@export_group("Durability")
@export var max_durability: int = -1
@export var durability_loss_per_use: int = 0

var current_durability: int = -1

func reset_durability() -> void:
	current_durability = max_durability

func is_broken() -> bool:
	return max_durability >= 0 and current_durability <= 0

func apply_use_durability() -> void:
	if max_durability < 0:
		return
	current_durability = maxi(0, current_durability - durability_loss_per_use)
