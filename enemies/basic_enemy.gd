class_name BasicEnemy
extends Node2D

@export var starting_tile: Vector2i = Vector2i(10, 6)
@export_range(1, 10, 1) var chase_range: int = 7
@export_range(1, 5, 1) var health: int = 1
@export var move_duration: float = 0.28
@export_range(1, 4, 1) var player_actions_per_move: int = 2

var current_tile: Vector2i
var _player: Player
var _level_tile_map: LevelTileMap
var _is_moving := false
var _dead := false
var _action_counter := 0

func _ready() -> void:
	add_to_group("enemies")
	current_tile = starting_tile
	call_deferred("_connect_to_room")

func _connect_to_room() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_level_tile_map = get_tree().get_first_node_in_group("level_tile_map") as LevelTileMap
	if _level_tile_map:
		current_tile = _nearest_walkable_tile(starting_tile)
		global_position = _level_tile_map.tile_to_world(current_tile)
	if _player and not _player.action_finished.is_connected(_on_player_action_finished):
		_player.action_finished.connect(_on_player_action_finished)
	_check_player_contact()

func _on_player_action_finished() -> void:
	if _dead or _is_moving or not _player or not _level_tile_map:
		return
	_action_counter += 1
	if _action_counter < player_actions_per_move:
		return
	_action_counter = 0

	var distance := _manhattan(current_tile, _player.current_tile)
	if distance <= 0:
		_catch_player()
		return
	if distance > chase_range:
		return

	var step := _choose_step_toward(_player.current_tile)
	if step == Vector2i.ZERO:
		return
	var target := current_tile + step
	if not _can_enter(target):
		return

	current_tile = target
	_is_moving = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", _level_tile_map.tile_to_world(current_tile), move_duration)
	tween.tween_callback(func() -> void:
		_is_moving = false
		_check_player_contact())

func _choose_step_toward(target: Vector2i) -> Vector2i:
	var delta := target - current_tile
	var candidates: Array[Vector2i] = []
	if absi(delta.x) >= absi(delta.y):
		if delta.x != 0:
			candidates.append(Vector2i(1 if delta.x > 0 else -1, 0))
		if delta.y != 0:
			candidates.append(Vector2i(0, 1 if delta.y > 0 else -1))
	else:
		if delta.y != 0:
			candidates.append(Vector2i(0, 1 if delta.y > 0 else -1))
		if delta.x != 0:
			candidates.append(Vector2i(1 if delta.x > 0 else -1, 0))
	for direction in candidates:
		if _can_enter(current_tile + direction):
			return direction
	return Vector2i.ZERO

func _can_enter(tile: Vector2i) -> bool:
	if not _level_tile_map.is_walkable(tile):
		return false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or enemy.is_queued_for_deletion():
			continue
		if enemy is BasicEnemy and enemy.current_tile == tile:
			return false
	return true

func take_hit(damage: int = 1) -> void:
	if _dead:
		return
	health -= maxi(1, damage)
	if health <= 0:
		_dead = true
		remove_from_group("enemies")
		queue_free()

func reset_to_start() -> void:
	if not _level_tile_map:
		return
	current_tile = _nearest_walkable_tile(starting_tile)
	global_position = _level_tile_map.tile_to_world(current_tile)
	_is_moving = false
	_action_counter = 0

func _check_player_contact() -> void:
	if _player and current_tile == _player.current_tile:
		_catch_player()

func _catch_player() -> void:
	if not _player:
		return
	var player_died := _player.on_enemy_contact(self)
	if player_died:
		return
	# A hit should create pressure, not teleport the threat out of the room.
	# Back off one tile if possible so the player gets one decision to recover.
	_back_off_from_player()

func _back_off_from_player() -> void:
	if not _player or not _level_tile_map:
		return
	var away := current_tile - _player.current_tile
	var candidates: Array[Vector2i] = []
	if away.x != 0:
		candidates.append(Vector2i(1 if away.x > 0 else -1, 0))
	if away.y != 0:
		candidates.append(Vector2i(0, 1 if away.y > 0 else -1))
	for direction in candidates:
		var target := current_tile + direction
		if _can_enter(target):
			current_tile = target
			global_position = _level_tile_map.tile_to_world(current_tile)
			break
	_action_counter = 0

func _nearest_walkable_tile(preferred: Vector2i) -> Vector2i:
	if _level_tile_map.is_walkable(preferred):
		return preferred
	for radius in range(1, 18):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := preferred + Vector2i(x, y)
				if _manhattan(preferred, candidate) != radius:
					continue
				if _level_tile_map.is_walkable(candidate):
					return candidate
	return preferred

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
