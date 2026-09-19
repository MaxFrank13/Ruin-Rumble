extends Node

func _ready() -> void:
	$CanvasLayer/CenterContainer/VBoxContainer/Title.text = "RUIN CLEARED  $%d" % (RunState.get_money() + InventoryManager.get_total_value())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("A"):
		InventoryManager.clear_inventory()
		RunState.reset_run()
		get_tree().change_scene_to_file("res://main.tscn")
