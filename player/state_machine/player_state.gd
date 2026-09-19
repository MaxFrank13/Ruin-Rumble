class_name PlayerState
extends Node

@export var state_name: String

var parent: CharacterBody2D

func enter() -> void:
	play_directional_animation(state_name, parent.facing_direction)

func exit() -> void:
	pass

func process_input(_event: InputEvent) -> PlayerState:
	return null

func process_frame(_delta: float) -> PlayerState:
	return null

func process_physics(_delta: float) -> PlayerState:
	return null

func play_directional_animation(base_name: String, direction: Vector2i) -> void:
	if not base_name or not parent.animations.sprite_frames:
		return
	var effective_base := base_name
	if parent is Player and (parent as Player).shield_charges > 0 and base_name in ["idle", "walk"]:
		effective_base = "shield_" + base_name
	var directional_name := "%s_%s" % [effective_base, _direction_suffix(direction)]
	if parent.animations.sprite_frames.has_animation(directional_name):
		parent.animations.play(directional_name)

static func _direction_suffix(direction: Vector2i) -> String:
	match direction:
		Vector2i(0, -1): return "up"
		Vector2i(-1, 0): return "left"
		Vector2i(1, 0): return "right"
		_: return "down"
