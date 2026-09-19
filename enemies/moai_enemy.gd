class_name MoaiEnemy
extends Node2D

@export var starting_tile: Vector2i = Vector2i(7, 5)
@export_range(1, 16, 1) var chase_range: int = 8
@export_range(1, 8, 1) var health: int = 3
@export_range(1, 6, 1) var player_actions_per_move: int = 3
@export var move_duration: float = 0.32

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_tile: Vector2i
var _player: Player
var _level_tile_map: LevelTileMap
var _is_moving := false
var _dead := false
var _action_counter := 0
var _pound_armed := false
var _facing := Vector2i(0, 1)

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
	_play_facing_idle()

func _on_player_action_finished() -> void:
	if _dead or _is_moving or not _player or not _level_tile_map:
		return
	var distance := _manhattan(current_tile, _player.current_tile)
	if distance > chase_range:
		_cancel_pound()
		return

	if _pound_armed:
		if distance == 1:
			_perform_pound()
		else:
			_cancel_pound()
		return

	if distance == 1:
		_begin_pound()
		return

	_action_counter += 1
	if _action_counter < player_actions_per_move:
		return
	_action_counter = 0
	var step := _choose_step_toward(_player.current_tile)
	if step == Vector2i.ZERO:
		return
	var target := current_tile + step
	if not _can_enter(target) or target == _player.current_tile:
		return
	_facing = step
	_play_facing_idle()
	current_tile = target
	_is_moving = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", _level_tile_map.tile_to_world(current_tile), move_duration)
	tween.tween_callback(func() -> void:
		_is_moving = false
	)

func on_player_bumped(player: Player) -> void:
	if player != _player:
		return
	if _manhattan(current_tile, _player.current_tile) == 1 and not _pound_armed:
		_begin_pound()

func _begin_pound() -> void:
	_pound_armed = true
	_action_counter = 0
	var delta := _player.current_tile - current_tile
	if delta != Vector2i.ZERO:
		_facing = delta
	if sprite:
		sprite.flip_h = _facing.x < 0
		sprite.play("pound_windup")

func _perform_pound() -> void:
	_pound_armed = false
	_action_counter = 0
	if sprite:
		sprite.flip_h = _facing.x < 0
		sprite.play("pound_slam")
	if _player and _manhattan(current_tile, _player.current_tile) == 1:
		_player.on_enemy_contact(self)
	get_tree().create_timer(0.18).timeout.connect(func() -> void:
		if not _dead:
			_play_facing_idle()
	)

func _cancel_pound() -> void:
	if not _pound_armed:
		return
	_pound_armed = false
	_play_facing_idle()

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
	_pound_armed = false
	_play_facing_idle()

func _play_facing_idle() -> void:
	if not sprite:
		return
	var animation_name := "idle_down"
	if absi(_facing.x) > absi(_facing.y):
		animation_name = "idle_left" if _facing.x < 0 else "idle_right"
	elif _facing.y < 0:
		animation_name = "idle_up"
	sprite.flip_h = false
	sprite.play(animation_name)

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
		if enemy.get("current_tile") == tile:
			return false
	return true

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
