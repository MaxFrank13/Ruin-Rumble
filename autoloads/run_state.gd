extends Node

const MAX_HEALTH := 6

var current_health: int = MAX_HEALTH
var money: int = 0

signal health_changed(current: int, maximum: int)
signal money_changed(amount: int)

func damage(amount: int = 1) -> int:
	current_health = maxi(0, current_health - maxi(1, amount))
	health_changed.emit(current_health, MAX_HEALTH)
	return current_health

func refill_health() -> void:
	current_health = MAX_HEALTH
	health_changed.emit(current_health, MAX_HEALTH)

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)

func get_money() -> int:
	return money

func reset_run() -> void:
	money = 0
	money_changed.emit(money)
	refill_health()
