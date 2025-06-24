extends Node

class_name PlayerProgression

# Handles player XP, level, and currency
signal xp_changed(xp, xp_to_next, level)
signal coin_collected(total_currency)
signal level_up(level)

var xp := 0
var level := 1
var xp_to_next := 100
var currency := 0

func initialize(controller):
	self.controller = controller

func add_xp(amount: int):
	xp += amount
	if xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.2)
		level_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)

func add_currency(amount: int):
	currency += amount
	coin_collected.emit(currency)

func get_xp():
	return xp

func get_level():
	return level

func get_xp_to_next():
	return xp_to_next

func get_currency():
	return currency
