class_name Player extends CharacterBody2D

@onready var state_machine: Node = $StateMachine
@onready var animations: AnimatedSprite2D = $AnimatedSprite2D

@export var level_tile_map: LevelTileMap

var current_tile: Vector2i = Vector2i.ZERO
var move_duration: float = 0.15

signal treasure_scanned(hint_text: String)

func _ready() -> void:
	state_machine.init(self)
	if level_tile_map:
		global_position = level_tile_map.tile_to_world(current_tile)
	# TODO: replace with a HUD listener once UI exists
	treasure_scanned.connect(func(hint: String) -> void: print(hint))

func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)

func _process(delta: float) -> void:
	state_machine.process_frame(delta)

func try_move(direction: Vector2i) -> bool:
	var target_tile := current_tile + direction
	if level_tile_map and level_tile_map.is_walkable(target_tile):
		current_tile = target_tile
		return true
	return false
