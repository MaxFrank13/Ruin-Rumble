class_name Player extends CharacterBody2D

@onready var state_machine: Node = $StateMachine
@onready var animations: AnimatedSprite2D = $AnimatedSprite2D
@onready var action_sprite: AnimatedSprite2D = get_node_or_null("ActionSprite")
@onready var treasure_alert: Sprite2D = get_node_or_null("TreasureAlert")
@onready var treasure_alert_timer: Timer = get_node_or_null("TreasureAlertTimer")

@export var level_tile_map: LevelTileMap
@export var starting_tile: Vector2i = Vector2i.ZERO

var current_tile: Vector2i = Vector2i.ZERO
var move_duration: float = 0.15
var facing_direction: Vector2i = Vector2i(0, 1)
var shield_charges: int = 0
var _damage_grace_actions: int = 0
var _pending_loot_tile: Vector2i = Vector2i(-9999, -9999)
var _pending_loot_item: ItemData = null
var _attack_visual_token: int = 0

signal treasure_scanned(hint_text: String)
signal detector_reading(reading: Dictionary)
signal status_message(text: String)
signal health_changed(current: int, maximum: int)
signal action_finished()

func _ready() -> void:
	add_to_group("player")
	current_tile = starting_tile
	state_machine.init(self)
	if level_tile_map:
		global_position = level_tile_map.tile_to_world(current_tile)
	if treasure_alert:
		treasure_alert.visible = false
	if treasure_alert_timer and not treasure_alert_timer.timeout.is_connected(_hide_treasure_alert):
		treasure_alert_timer.timeout.connect(_hide_treasure_alert)
	call_deferred("_emit_initial_ui")

func _emit_initial_ui() -> void:
	health_changed.emit(RunState.current_health, RunState.MAX_HEALTH)
	show_status("B: SCAN/DIG  A: USE\nSELECT: ITEM")

func _unhandled_input(event: InputEvent) -> void:
	if _pending_loot_item != null:
		_process_loot_choice_input(event)
		return
	state_machine.process_input(event)


func begin_loot_choice(tile_pos: Vector2i, item: ItemData) -> void:
	_pending_loot_tile = tile_pos
	_pending_loot_item = item
	_show_loot_choice_prompt()

func _process_loot_choice_input(event: InputEvent) -> void:
	if event.is_action_pressed("SELECT"):
		InventoryManager.cycle_equipped_item()
		_show_loot_choice_prompt()
		return
	if event.is_action_pressed("A"):
		var replacing := InventoryManager.get_equipped_item()
		if replacing == null:
			show_status("Select an item to replace, or B to leave this find.")
			return
		var new_item := _pending_loot_item
		var dropped := InventoryManager.swap_equipped_for(new_item)
		level_tile_map.clear_item(_pending_loot_tile)
		if dropped:
			level_tile_map.place_existing_item(_pending_loot_tile, dropped)
		show_status("Took %s; left %s." % [new_item.item_name, replacing.item_name])
		_clear_loot_choice()
		return
	if event.is_action_pressed("B"):
		show_status("Left %s buried here." % _pending_loot_item.item_name)
		_clear_loot_choice()

func _show_loot_choice_prompt() -> void:
	show_status("FOUND %s $%d\nA:TAKE  B:LEAVE  SELECT:SLOT" % [_pending_loot_item.item_name, _pending_loot_item.display_value()])

func _clear_loot_choice() -> void:
	_pending_loot_item = null
	_pending_loot_tile = Vector2i(-9999, -9999)

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)

func _process(delta: float) -> void:
	state_machine.process_frame(delta)

func try_move(direction: Vector2i) -> bool:
	var target_tile := current_tile + direction
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("get") and enemy.get("current_tile") == target_tile:
			if enemy.has_method("on_player_bumped"):
				enemy.on_player_bumped(self)
			else:
				on_enemy_contact(enemy)
			return false
	if level_tile_map and level_tile_map.is_walkable(target_tile):
		current_tile = target_tile
		return true
	return false

func complete_action(cost: int = 1) -> void:
	for _i in range(maxi(1, cost)):
		if _damage_grace_actions > 0:
			_damage_grace_actions -= 1
		action_finished.emit()

func try_interact() -> bool:
	for node in get_tree().get_nodes_in_group("interactables"):
		if not node.has_method("can_interact") or not node.has_method("interact"):
			continue
		if node.can_interact(self):
			return bool(node.interact(self))
	return false

func try_use_selected_item() -> bool:
	var item: ItemData = InventoryManager.get_equipped_item()
	if item == null:
		show_status("No excavated item selected.")
		return false
	match item.use_type:
		ItemData.UseType.THROW:
			_use_throw_item(item)
			return true
		ItemData.UseType.MELEE:
			return _use_melee_item(item)
		ItemData.UseType.SHIELD:
			shield_charges += 1
			InventoryManager.apply_item_use(item)
			_play_current_idle_animation()
			show_status("%s readied as a shield." % item.item_name)
			return true
		_:
			show_status("%s is valuable, but not useful here." % item.item_name)
			return false

func _use_throw_item(item: ItemData) -> void:
	var hit_enemy: Node = null
	var tile := current_tile
	var final_tile := current_tile
	for _i in range(item.use_range):
		var next_tile := tile + facing_direction
		if level_tile_map and not level_tile_map.is_walkable(next_tile):
			break
		tile = next_tile
		final_tile = tile
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.get("current_tile") == tile:
				hit_enemy = enemy
				break
		if hit_enemy:
			break

	_play_thrown_item_visual(item, final_tile)
	if hit_enemy and hit_enemy.has_method("take_hit"):
		hit_enemy.take_hit(maxi(1, item.damage))
		show_status("%s hit the enemy." % item.item_name)
	else:
		show_status("Threw %s." % item.item_name)
	InventoryManager.apply_item_use(item)

func _use_melee_item(item: ItemData) -> bool:
	var target := current_tile + facing_direction
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get("current_tile") == target:
			_play_sword_attack_visual()
			enemy.take_hit(maxi(1, item.damage))
			InventoryManager.apply_item_use(item)
			show_status("Used %s." % item.item_name)
			return true
	_play_sword_attack_visual()
	show_status("Nothing in reach for %s." % item.item_name)
	return false

func _play_thrown_item_visual(item: ItemData, target_tile: Vector2i) -> void:
	if item.icon == null or level_tile_map == null:
		return
	var projectile := Sprite2D.new()
	projectile.texture = item.icon
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.z_index = 18
	if item.item_name.contains("Spear"):
		match facing_direction:
			Vector2i(0, 1): projectile.rotation = PI
			Vector2i(1, 0): projectile.rotation = PI * 0.5
			Vector2i(-1, 0): projectile.rotation = -PI * 0.5
			_: projectile.rotation = 0.0
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	var distance := maxi(1, absi(target_tile.x - current_tile.x) + absi(target_tile.y - current_tile.y))
	var tween := projectile.create_tween()
	tween.tween_property(projectile, "global_position", level_tile_map.tile_to_world(target_tile), 0.07 * distance)
	tween.tween_callback(func() -> void: projectile.queue_free())

func _play_sword_attack_visual() -> void:
	if action_sprite == null:
		return
	_attack_visual_token += 1
	var token := _attack_visual_token
	var suffix := "down"
	match facing_direction:
		Vector2i(0, -1):
			suffix = "up"
			action_sprite.offset = Vector2(9, -12)
		Vector2i(-1, 0):
			suffix = "left"
			action_sprite.offset = Vector2(-12, -7)
		Vector2i(1, 0):
			suffix = "right"
			action_sprite.offset = Vector2(10, -7)
		_:
			action_sprite.offset = Vector2(-8, -12)
	action_sprite.animation = "sword_" + suffix
	action_sprite.frame = 0
	action_sprite.visible = true
	animations.visible = false
	get_tree().create_timer(0.16).timeout.connect(func() -> void:
		if token != _attack_visual_token:
			return
		action_sprite.visible = false
		animations.visible = true
		_play_current_idle_animation()
	)

func _play_current_idle_animation() -> void:
	if animations == null or animations.sprite_frames == null:
		return
	var base := "shield_idle" if shield_charges > 0 else "idle"
	var suffix := "down"
	match facing_direction:
		Vector2i(0, -1): suffix = "up"
		Vector2i(-1, 0): suffix = "left"
		Vector2i(1, 0): suffix = "right"
	var animation_name := "%s_%s" % [base, suffix]
	if animations.sprite_frames.has_animation(animation_name):
		animations.play(animation_name)

func on_enemy_contact(_enemy: Node) -> bool:
	if shield_charges > 0:
		shield_charges -= 1
		_play_current_idle_animation()
		show_status("Your shield blocked the hit!")
		return false
	if _damage_grace_actions > 0:
		return false
	var health_left := RunState.damage(1)
	health_changed.emit(health_left, RunState.MAX_HEALTH)
	if health_left <= 0:
		_clear_loot_choice()
		InventoryManager.clear_inventory()
		show_status("You collapsed and dropped your finds. Back to the entrance.")
		_restart_room_position()
		return true
	else:
		_damage_grace_actions = 1
		show_status("Ouch! %d heart%s left." % [health_left, "" if health_left == 1 else "s"])
	return false

func _restart_room_position() -> void:
	RunState.refill_health()
	health_changed.emit(RunState.current_health, RunState.MAX_HEALTH)
	current_tile = starting_tile
	if level_tile_map:
		global_position = level_tile_map.tile_to_world(current_tile)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("reset_to_start"):
			enemy.reset_to_start()
	_damage_grace_actions = 1


func show_detector_reading(reading: Dictionary) -> void:
	detector_reading.emit(reading)

func show_status(text: String) -> void:
	status_message.emit(text)
	print(text)

func show_treasure_alert() -> void:
	if not treasure_alert:
		return
	treasure_alert.visible = true
	treasure_alert.scale = Vector2.ONE
	if treasure_alert_timer:
		treasure_alert_timer.start()

func _hide_treasure_alert() -> void:
	if treasure_alert:
		treasure_alert.visible = false
