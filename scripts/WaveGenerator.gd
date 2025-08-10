# Wave Generator Tool
# This script helps generate wave data for the game mode system

# Example usage:
# var wave_gen = WaveGenerator.new()
# wave_gen.generate_progressive_waves(50)

class_name WaveGenerator

# Generate a series of progressive waves
static func generate_progressive_waves(num_waves: int) -> Array:
	var waves = []
	var enemy_types = ["firebug", "fireWasp", "flyingLocust", "clampBeetle", "leafbug", "voidButterfly", "scorpion", "magmaCrab"]
	
	for i in range(num_waves):
		var wave_num = i + 1
		var is_boss = (wave_num % 5 == 0)  # Every 5th wave is a boss wave
		
		# Calculate difficulty scaling
		var enemy_count = 3 + (wave_num * 2)  # Start with 3, add 2 per wave
		var enemy_variety = min(3 + (wave_num / 5), enemy_types.size())  # Increase variety over time
		
		print("; Wave ", wave_num, " - ", ("Boss Wave" if is_boss else "Regular"))
		
		# Generate enemy groups for this wave
		var groups_needed = 1 + (wave_num / 10)  # More groups in later waves
		for group_idx in range(groups_needed):
			var group_num = group_idx + 1
			var enemy_type = enemy_types[randi() % enemy_variety]
			var count = max(1, enemy_count / groups_needed + randi() % 3)
			var delay = group_idx * 5.0  # 5 second delay between groups
			
			print('[sub_resource type="Resource" id="EnemyGroup_', wave_num, '_', group_num, '"]')
			print('script = ExtResource("3_0")')
			print('enemy_type = "', enemy_type, '"')
			print('count = ', count)
			print('spawn_delay = ', delay)
			print("")
		
		# Generate wave definition
		print('[sub_resource type="Resource" id="Wave_', wave_num, '"]')
		print('script = ExtResource("2_0")')
		print('wave_number = ', wave_num)
		print('is_boss_wave = ', is_boss)
		print('preparation_time = ', (20.0 if is_boss else 15.0 - (wave_num * 0.1)))
		print('spawn_interval = ', max(0.5, 2.0 - (wave_num * 0.02)))
		
		# Build groups array
		var groups_array = "Array[Resource](["
		for group_idx in range(groups_needed):
			if group_idx > 0:
				groups_array += ", "
			groups_array += 'SubResource("EnemyGroup_' + str(wave_num) + '_' + str(group_idx + 1) + '")'
		groups_array += "])"
		
		print('enemy_groups = ', groups_array)
		print("")
	
	return waves

# Simple function to print a basic wave structure
static func print_wave_template(wave_number: int, enemy_type: String, count: int):
	print("; Wave ", wave_number)
	print('[sub_resource type="Resource" id="EnemyGroup_', wave_number, '_1"]')
	print('script = ExtResource("3_0")')
	print('enemy_type = "', enemy_type, '"')
	print('count = ', count)
	print('spawn_delay = 0.0')
	print("")
	print('[sub_resource type="Resource" id="Wave_', wave_number, '"]')
	print('script = ExtResource("2_0")')
	print('wave_number = ', wave_number)
	print('is_boss_wave = false')
	print('preparation_time = 15.0')
	print('spawn_interval = 1.5')
	print('enemy_groups = Array[Resource]([SubResource("EnemyGroup_', wave_number, '_1")])')
	print("")
