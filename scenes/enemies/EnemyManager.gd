# EnemyManager.gd
extends Node
class_name EnemyManager

# Available enemy types
var enemy_types = {
	"firebug": "res://assets/Enemies/firebug/firebug.tres",
	# Add more enemy types here as you create them
	# "orc": "res://assets/Enemies/orc/orc.tres",
	# "dragon": "res://assets/Enemies/dragon/dragon.tres",
}

# Wave management
var current_wave = 1
var enemies_in_wave = 5
var enemies_spawned_this_wave = 0
var wave_delay = 3.0  # seconds between waves
var spawn_delay = 1.0  # seconds between individual enemy spawns

signal wave_started(wave_number)
signal wave_completed(wave_number)
signal all_enemies_defeated()

func get_enemy_data_path(enemy_type: String) -> String:
	"""Get the path to enemy data for a given enemy type"""
	if enemy_types.has(enemy_type):
		return enemy_types[enemy_type]
	else:
		print("Warning: Unknown enemy type '", enemy_type, "'. Using firebug as default.")
		return enemy_types["firebug"]

func get_available_enemy_types() -> Array:
	"""Get list of all available enemy types"""
	return enemy_types.keys()

func add_enemy_type(type_name: String, data_path: String):
	"""Add a new enemy type to the manager"""
	enemy_types[type_name] = data_path

func get_enemies_for_wave(wave_number: int) -> Array:
	"""Define which enemies spawn in each wave"""
	# This is a simple example - you can make this more complex
	if wave_number <= 3:
		return ["firebug"]  # Only firebugs for first 3 waves
	elif wave_number <= 6:
		return ["firebug", "firebug"]  # More firebugs
	else:
		return ["firebug", "firebug", "firebug"]  # Even more firebugs
	
	# Future example when you add more enemies:
	# elif wave_number <= 10:
	#     return ["firebug", "orc"]  # Mix of firebugs and orcs
	# else:
	#     return ["firebug", "orc", "dragon"]  # All enemy types
