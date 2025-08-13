# Test script for endless mode exponential scaling (Updated)
# This will help verify the new gradual scaling calculations

class_name EndlessScalingTest

static func test_exponential_scaling():
	print("=== Endless Mode Gradual Scaling Test ===")
	print()
	
	# Test base enemy values
	var base_health = 100
	var base_speed = 100.0
	
	print("Base Enemy Stats:")
	print("Health: %d" % base_health)
	print("Speed: %.1f" % base_speed)
	print()
	
	# Test scaling for different difficulty levels and enemy types
	var enemy_types = [
		["Easy (firebug)", "firebug"],
		["Medium (fireWasp)", "fireWasp"], 
		["Hard (magmaCrab)", "magmaCrab"]
	]
	
	for level in range(1, 16):
		print("=== Level %d (%.1f minutes) ===" % [level, level])
		
		for enemy_type_info in enemy_types:
			var type_name = enemy_type_info[0]
			var type_path = enemy_type_info[1]
			
			var health_mult = get_health_multiplier(level, type_path)
			var speed_mult = get_speed_multiplier(level, type_path)
			
			var scaled_health = int(base_health * health_mult)
			var scaled_speed = base_speed * speed_mult
			
			print("  %s: Health %d (%.2fx), Speed %.1f (%.2fx)" % [type_name, scaled_health, health_mult, scaled_speed, speed_mult])
		print()

static func get_health_multiplier(endless_difficulty_level: int, enemy_type: String) -> float:
	"""Same logic as in main.gd for health scaling"""
	var health_multiplier = 1.0
	
	if endless_difficulty_level <= 2:
		health_multiplier = 0.7 + (endless_difficulty_level - 1) * 0.15
	elif endless_difficulty_level <= 10:
		var progress = (endless_difficulty_level - 2) / 8.0
		health_multiplier = 0.85 + progress * 0.35
	else:
		var exponential_factor = 1.12
		health_multiplier = 1.2 * pow(exponential_factor, endless_difficulty_level - 10)
	
	# Apply enemy type multipliers for level 10+
	if endless_difficulty_level >= 10:
		if enemy_type.contains("firebug") or enemy_type.contains("leafbug"):
			health_multiplier *= 4.0
		elif enemy_type.contains("fireWasp") or enemy_type.contains("flyingLocust") or enemy_type.contains("clampBeetle"):
			health_multiplier *= 2.0
	
	return health_multiplier

static func get_speed_multiplier(endless_difficulty_level: int, enemy_type: String) -> float:
	"""Same logic as in main.gd for speed scaling"""
	var speed_multiplier = 1.0
	
	if endless_difficulty_level <= 2:
		speed_multiplier = 1.0 + (endless_difficulty_level - 1) * 0.05
	elif endless_difficulty_level <= 10:
		var progress = (endless_difficulty_level - 2) / 8.0
		speed_multiplier = 1.05 + progress * 0.25
	else:
		var exponential_factor = 1.08
		speed_multiplier = 1.3 + (pow(exponential_factor, endless_difficulty_level - 10) - 1) * 0.8
		speed_multiplier = min(speed_multiplier, 3.0)
	
	# Apply enemy type multipliers for level 10+
	if endless_difficulty_level >= 10:
		if enemy_type.contains("firebug") or enemy_type.contains("leafbug"):
			speed_multiplier = min(speed_multiplier * 4.0, 3.0)
		elif enemy_type.contains("fireWasp") or enemy_type.contains("flyingLocust") or enemy_type.contains("clampBeetle"):
			speed_multiplier = min(speed_multiplier * 2.0, 3.0)
	
	return speed_multiplier
