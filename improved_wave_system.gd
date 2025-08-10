# Improved Wave System Generator
# Creates a comprehensive 30+ wave system with dynamic spawn rate scaling

class_name ImprovedWaveSystem

# Calculate dynamic spawn interval based on enemy count
static func calculate_spawn_interval(enemy_count: int, base_interval: float = 1.0) -> float:
	# For large enemy counts, significantly reduce spawn interval
	# This creates the "horde" feeling you want
	if enemy_count <= 10:
		return base_interval
	elif enemy_count <= 25:
		return base_interval * 0.7  # 30% faster
	elif enemy_count <= 50:
		return base_interval * 0.5  # 50% faster  
	elif enemy_count <= 100:
		return base_interval * 0.3  # 70% faster
	else:
		return base_interval * 0.2  # 80% faster for massive hordes

# Generate comprehensive wave data with proper scaling
static func generate_improved_waves(num_waves: int = 30) -> String:
	var output = ""
	var enemy_types = ["firebug", "leafbug", "fireWasp", "flyingLocust", "clampBeetle", "voidButterfly", "scorpion", "magmaCrab"]
	
	# Define enemy tiers for progressive difficulty
	var easy_enemies = ["firebug", "leafbug"]
	var medium_enemies = ["fireWasp", "flyingLocust", "clampBeetle"] 
	var hard_enemies = ["voidButterfly", "scorpion"]
	var boss_enemies = ["magmaCrab"]
	
	for i in range(num_waves):
		var wave_num = i + 1
		var is_boss = (wave_num % 10 == 0)  # Every 10th wave is boss
		var is_challenge = (wave_num % 5 == 0 and wave_num % 10 != 0)  # Every 5th wave (non-boss) is challenge
		
		# Progressive enemy counts - start much higher for horde feeling
		var base_count: int
		if wave_num <= 5:
			base_count = 15 + (wave_num * 5)  # 20, 25, 30, 35, 40
		elif wave_num <= 10:
			base_count = 30 + (wave_num * 8)  # 38, 46, 54, 62, 70, 78
		elif wave_num <= 20:
			base_count = 50 + (wave_num * 10)  # 60, 70, 80... up to 250
		else:
			base_count = 100 + (wave_num * 15)  # Massive hordes for late game
		
		# Determine enemy types based on wave number
		var available_enemies = []
		if wave_num <= 3:
			available_enemies = easy_enemies
		elif wave_num <= 8:
			available_enemies = easy_enemies + medium_enemies.slice(0, 1)  # Add fireWasp
		elif wave_num <= 15:
			available_enemies = easy_enemies + medium_enemies
		elif wave_num <= 25:
			available_enemies = easy_enemies + medium_enemies + hard_enemies
		else:
			available_enemies = enemy_types
		
		# Calculate groups and distribution
		var groups_needed: int
		if is_boss:
			groups_needed = 3 + (wave_num / 10)  # More complex boss waves
		elif is_challenge:
			groups_needed = 2 + (wave_num / 8)
		else:
			groups_needed = max(1, 1 + (wave_num / 12))
		
		groups_needed = min(groups_needed, 4)  # Cap at 4 groups
		
		output += "; ===== WAVE " + str(wave_num) + " ===== " + ("(BOSS)" if is_boss else ("(CHALLENGE)" if is_challenge else "")) + "\n"
		
		# Generate enemy groups
		var total_enemies_in_wave = 0
		for group_idx in range(groups_needed):
			var group_num = group_idx + 1
			var enemies_in_group: int
			
			if is_boss and group_idx == groups_needed - 1:
				# Last group in boss wave gets boss enemy
				enemies_in_group = max(1, base_count / 8)  # Fewer boss enemies
				var enemy_type = boss_enemies[0]  # magmaCrab
				
				output += '[sub_resource type="Resource" id="EnemyGroup_' + str(wave_num) + '_' + str(group_num) + '"]\n'
				output += 'script = ExtResource("3_0")\n'
				output += 'enemy_type = "' + enemy_type + '"\n'
				output += 'count = ' + str(enemies_in_group) + '\n'
				output += 'spawn_delay = ' + str(group_idx * 8.0) + '\n'
				output += '\n'
			else:
				# Regular group
				enemies_in_group = base_count / groups_needed
				if group_idx == 0:
					enemies_in_group += base_count % groups_needed  # Give remainder to first group
				
				# Select enemy type
				var enemy_type: String
				if is_challenge and group_idx < available_enemies.size():
					# For challenge waves, use harder enemies
					enemy_type = available_enemies[min(group_idx + available_enemies.size()/2, available_enemies.size()-1)]
				else:
					enemy_type = available_enemies[group_idx % available_enemies.size()]
				
				output += '[sub_resource type="Resource" id="EnemyGroup_' + str(wave_num) + '_' + str(group_num) + '"]\n'
				output += 'script = ExtResource("3_0")\n'
				output += 'enemy_type = "' + enemy_type + '"\n'
				output += 'count = ' + str(enemies_in_group) + '\n'
				output += 'spawn_delay = ' + str(group_idx * 6.0) + '\n'
				output += '\n'
			
			total_enemies_in_wave += enemies_in_group
		
		# Generate wave definition with dynamic spawn interval
		var base_spawn_interval = 1.2 if is_boss else 1.0
		var dynamic_spawn_interval = calculate_spawn_interval(total_enemies_in_wave, base_spawn_interval)
		
		var prep_time = 20.0 if is_boss else (18.0 if is_challenge else max(8.0, 15.0 - (wave_num * 0.2)))
		
		output += '[sub_resource type="Resource" id="Wave_' + str(wave_num) + '"]\n'
		output += 'script = ExtResource("2_0")\n'
		output += 'wave_number = ' + str(wave_num) + '\n'
		output += 'is_boss_wave = ' + str(is_boss) + '\n'
		output += 'preparation_time = ' + str(prep_time) + '\n'
		output += 'spawn_interval = ' + str(dynamic_spawn_interval) + '  ; Dynamic scaling for ' + str(total_enemies_in_wave) + ' enemies\n'
		
		# Build groups array
		output += 'enemy_groups = Array[ExtResource("3_0")](['
		for group_idx in range(groups_needed):
			if group_idx > 0:
				output += ", "
			output += 'SubResource("EnemyGroup_' + str(wave_num) + '_' + str(group_idx + 1) + '")'
		output += "])\n\n"
	
	return output

# Generate the wave definitions array for the resource file
static func generate_wave_definitions_array(num_waves: int = 30) -> String:
	var output = "wave_definitions = Array[ExtResource(\"2_0\")]([" 
	for i in range(num_waves):
		if i > 0:
			output += ", "
		output += 'SubResource("Wave_' + str(i + 1) + '")'
	output += "])\n"
	return output
