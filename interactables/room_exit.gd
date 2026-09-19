class_name RoomExit
extends Node2D

@export var tile_position: Vector2i = Vector2i(15, 6)
@export_file("*.tscn") var target_scene: String = ""
@export var requires_enemy_clear: bool = false
@export var interaction_distance: int = 1
@export var auto_enter_on_tile: bool = true

var _level_tile_map: LevelTileMap
var _transitioning := false
@onready var _prompt: Label = get_node_or_null("Prompt")

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("room_exits")
	if _prompt:
		_prompt.visible = false
	call_deferred("_place_on_grid")

func _place_on_grid() -> void:
	_level_tile_map = get_tree().get_first_node_in_group("level_tile_map") as LevelTileMap
	if not _level_tile_map:
		return
	global_position = _level_tile_map.tile_to_world(tile_position)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or _transitioning:
		if _prompt:
			_prompt.visible = false
		return

	var distance := _tile_distance(player.current_tile, tile_position)
	if _prompt:
		_prompt.visible = distance <= interaction_distance
		if distance == 0 and auto_enter_on_tile:
			_prompt.text = "WALK IN"
		else:
			_prompt.text = "A: ENTER"

	# A room exit should behave like a doorway, not a precision interaction.
	# Once the player actually steps onto it, enter automatically.
	if auto_enter_on_tile and player.current_tile == tile_position:
		_try_enter(player)

func can_interact(player: Player) -> bool:
	if _transitioning or not player:
		return false
	# No facing-direction requirement. If you're next to the doorway, A works.
	return _tile_distance(player.current_tile, tile_position) <= interaction_distance

func interact(player: Player) -> bool:
	return _try_enter(player)

func _try_enter(player: Player) -> bool:
	if _transitioning or player == null:
		return false
	if requires_enemy_clear and not get_tree().get_nodes_in_group("enemies").is_empty():
		player.show_status("The exit is sealed while guardians remain.")
		return true
	if target_scene.is_empty():
		player.show_status("This exit has nowhere to go yet.")
		return true
	_transitioning = true
	get_tree().change_scene_to_file(target_scene)
	return true

func _tile_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
