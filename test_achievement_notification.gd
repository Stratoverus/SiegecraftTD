extends Node

# Simple test script to verify achievement notifications work

func _ready():
	# Wait a bit to ensure everything is loaded
	await get_tree().create_timer(2.0).timeout
	
	# Test achievement notification
	var achievement_manager = get_node("/root/AchievementManager")
	if achievement_manager:
		print("Testing achievement notification...")
		# Trigger a test achievement (this will only trigger if not already unlocked)
		achievement_manager.unlock_achievement("first_victory")
		
		# Wait and trigger another one
		await get_tree().create_timer(6.0).timeout
		achievement_manager.unlock_achievement("tower_enthusiast")
