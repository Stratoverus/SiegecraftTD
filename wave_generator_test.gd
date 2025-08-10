extends Node

func _ready():
	# Load the improved wave system
	var improved_system = load("res://improved_wave_system.gd")
	
	# Generate 30 waves with improved system
	print("=== IMPROVED WAVE SYSTEM (30 WAVES) ===")
	print("Copy this into your .tres file:")
	print("")
	print(improved_system.generate_improved_waves(30))
	print("")
	print("=== WAVE DEFINITIONS ARRAY ===")
	print(improved_system.generate_wave_definitions_array(30))
	
	# Exit after generating
	get_tree().quit()
