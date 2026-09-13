class_name PlayerState
extends Node

@export var state_name: String

var parent: CharacterBody2D

func enter() -> void:
	if state_name and parent.animations.sprite_frames and parent.animations.sprite_frames.has_animation(state_name):
		parent.animations.play(state_name)

func exit() -> void:
	pass

func process_input(_event: InputEvent) -> PlayerState:
	return null

func process_frame(_delta: float) -> PlayerState:
	return null

func process_physics(_delta: float) -> PlayerState:
	return null
