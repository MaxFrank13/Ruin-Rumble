class_name BatEnemy
extends Node2D

@export var starting_tile: Vector2i = Vector2i(9, 9)
@export_range(1, 16, 1) var chase_range: int = 10

# How many player actions happen before the bat moves.
# 1 = every action
# 2 = every other action
# 3 = every third action
@export_range(1, 4, 1) var player_actions_per_move: int = 2

# How quickly the bat visually travels between tiles.
@export var move_duration: float = 0.15

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_tile: Vector2i

var _player: Player
var _level_tile_map: LevelTileMap

var _is_moving := false
var _dead := false
var _last_step := Vector2i.ZERO
var _action_counter: int = 0


func _ready() -> void:
	add_to_group("enemies")

	current_tile = starting_tile

	if sprite:
		sprite.play("flap")

	call_deferred("_connect_to_room")


func _connect_to_room() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_level_tile_map = (
		get_tree().get_first_node_in_group("level_tile_map")
		as LevelTileMap
	)

	if _level_tile_map:
		current_tile = _nearest_walkable_tile(starting_tile)
		global_position = _level_tile_map.tile_to_world(current_tile)

	if (
		_player
		and not _player.action_finished.is_connected(
			_on_player_action_finished
		)
	):
		_player.action_finished.connect(_on_player_action_finished)

	_check_player_contact()


func _on_player_action_finished() -> void:
	if (
		_dead
		or _is_moving
		or not _player
		or not _level_tile_map
	):
		return

	var distance := _manhattan(
		current_tile,
		_player.current_tile
	)

	# Already touching the player.
	if distance <= 0:
		_hit_player()
		return

	# Outside detection range.
	# Reset the counter so the bat doesn't "store" turns
	# while the player is far away.
	if distance > chase_range:
		_action_counter = 0
		return

	# Bat only moves after the required number
	# of player actions.
	_action_counter += 1

	if _action_counter < player_actions_per_move:
		return

	_action_counter = 0

	var step := _choose_step_toward(
		_player.current_tile
	)

	if step == Vector2i.ZERO:
		return

	var target := current_tile + step

	if not _can_enter(target):
		return

	if sprite and step.x != 0:
		sprite.flip_h = step.x < 0

	_last_step = step
	current_tile = target
	_is_moving = true

	var tween := create_tween()

	tween.tween_property(
		self,
		"global_position",
		_level_tile_map.tile_to_world(current_tile),
		move_duration
	)

	tween.tween_callback(
		func() -> void:
			_is_moving = false
			_check_player_contact()
	)


func on_player_bumped(player: Player) -> void:
	if player == _player:
		_hit_player()


func take_hit(_damage: int = 1) -> void:
	if _dead:
		return

	_dead = true
	remove_from_group("enemies")
	queue_free()


func reset_to_start() -> void:
	if not _level_tile_map:
		return

	current_tile = _nearest_walkable_tile(starting_tile)

	global_position = (
		_level_tile_map.tile_to_world(current_tile)
	)

	_is_moving = false
	_last_step = Vector2i.ZERO
	_action_counter = 0


func _check_player_contact() -> void:
	if (
		_player
		and current_tile == _player.current_tile
	):
		_hit_player()


func _hit_player() -> void:
	if not _player:
		return

	var player_died := (
		_player.on_enemy_contact(self)
	)

	if player_died:
		return

	_back_off_from_player()


func _back_off_from_player() -> void:
	var away := (
		current_tile
		- _player.current_tile
	)

	var candidates: Array[Vector2i] = []

	if (
		away == Vector2i.ZERO
		and _last_step != Vector2i.ZERO
	):
		candidates.append(-_last_step)

	if away.x != 0:
		candidates.append(
			Vector2i(
				1 if away.x > 0 else -1,
				0
			)
		)

	if away.y != 0:
		candidates.append(
			Vector2i(
				0,
				1 if away.y > 0 else -1
			)
		)

	for direction in candidates:
		var target := current_tile + direction

		if _can_enter(target):
			current_tile = target
			global_position = (
				_level_tile_map.tile_to_world(
					current_tile
				)
			)
			return


func _choose_step_toward(
	target: Vector2i
) -> Vector2i:
	var delta := target - current_tile

	var candidates: Array[Vector2i] = []

	if absi(delta.x) >= absi(delta.y):
		if delta.x != 0:
			candidates.append(
				Vector2i(
					1 if delta.x > 0 else -1,
					0
				)
			)

		if delta.y != 0:
			candidates.append(
				Vector2i(
					0,
					1 if delta.y > 0 else -1
				)
			)
	else:
		if delta.y != 0:
			candidates.append(
				Vector2i(
					0,
					1 if delta.y > 0 else -1
				)
			)

		if delta.x != 0:
			candidates.append(
				Vector2i(
					1 if delta.x > 0 else -1,
					0
				)
			)

	for direction in candidates:
		if _can_enter(
			current_tile + direction
		):
			return direction

	return Vector2i.ZERO


func _can_enter(tile: Vector2i) -> bool:
	if not _level_tile_map.is_walkable(tile):
		return false

	for enemy in get_tree().get_nodes_in_group(
		"enemies"
	):
		if (
			enemy == self
			or enemy.is_queued_for_deletion()
		):
			continue

		if enemy.get("current_tile") == tile:
			return false

	return true


func _nearest_walkable_tile(
	preferred: Vector2i
) -> Vector2i:
	if _level_tile_map.is_walkable(preferred):
		return preferred

	for radius in range(1, 18):
		for y in range(
			-radius,
			radius + 1
		):
			for x in range(
				-radius,
				radius + 1
			):
				var candidate := (
					preferred
					+ Vector2i(x, y)
				)

				if (
					_manhattan(
						preferred,
						candidate
					)
					!= radius
				):
					continue

				if (
					_level_tile_map
					.is_walkable(candidate)
				):
					return candidate

	return preferred


static func _manhattan(
	a: Vector2i,
	b: Vector2i
) -> int:
	return (
		absi(a.x - b.x)
		+ absi(a.y - b.y)
	)
