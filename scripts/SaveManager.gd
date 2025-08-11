extends Node

# Singleton for managing game saves
# Available as SaveManager autoload

signal save_completed(slot_number: int)
signal load_completed(slot_number: int)
signal save_failed(slot_number: int, error: String)
signal load_failed(slot_number: int, error: String)

# Save/load file paths
const SAVE_SLOTS = 3
const SAVE_FILE_FORMAT = "user://profiles/%s/game_save_slot_%d.save"
const CHECKPOINT_FILE_FORMAT = "user://profiles/%s/checkpoint.save"

# Save data structure
const SAVE_VERSION = 2  # Updated for path loading fixes and map handling improvements

# Current save slot being used
var current_save_slot: int = 1

func get_save_file_path(slot: int) -> String:
	"""Get save file path for given slot"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.has_profile():
		var clean_name = profile_manager.clean_profile_name(profile_manager.profile_name)
		# Ensure profile save directory exists
		var profile_save_dir = "user://profiles/" + clean_name
		if not DirAccess.dir_exists_absolute(profile_save_dir):
			DirAccess.open("user://profiles/").make_dir_recursive(clean_name)
		return SAVE_FILE_FORMAT % [clean_name, slot]
	else:
		# Fallback to default profile if no profile
		var clean_name = ProfileManager.clean_profile_name("default")
		var profile_save_dir = "user://profiles/" + clean_name
		if not DirAccess.open(profile_save_dir):
			DirAccess.open("user://profiles/").make_dir_recursive(clean_name)
		return SAVE_FILE_FORMAT % [clean_name, slot]

func get_checkpoint_file_path() -> String:
	"""Get checkpoint file path for current profile"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.has_profile():
		var clean_name = profile_manager.clean_profile_name(profile_manager.profile_name)
		# Ensure profile save directory exists
		var profile_save_dir = "user://profiles/" + clean_name
		if not DirAccess.dir_exists_absolute(profile_save_dir):
			DirAccess.open("user://profiles/").make_dir_recursive(clean_name)
		return CHECKPOINT_FILE_FORMAT % clean_name
	else:
		# Fallback to default profile if no profile
		var clean_name = ProfileManager.clean_profile_name("default")
		var profile_save_dir = "user://profiles/" + clean_name
		if not DirAccess.open(profile_save_dir):
			DirAccess.open("user://profiles/").make_dir_recursive(clean_name)
		return CHECKPOINT_FILE_FORMAT % clean_name

func save_file_exists(slot: int) -> bool:
	"""Check if save file exists for given slot"""
	return FileAccess.file_exists(get_save_file_path(slot))

func get_save_file_info(slot: int) -> Dictionary:
	"""Get information about a save file without fully loading it"""
	var file_path = get_save_file_path(slot)
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		return {}
	
	var save_data = json.data
	
	# Extract summary information
	var info = {
		"exists": true,
		"timestamp": save_data.get("timestamp", ""),
		"game_mode": save_data.get("game_mode_name", "Unknown"),
		"wave_number": save_data.get("current_wave_number", 1),
		"gold": save_data.get("gold", 0),
		"health": save_data.get("health", 100),
		"play_time": save_data.get("total_play_time", 0.0),
		"formatted_time": format_timestamp(save_data.get("timestamp", ""))
	}
	
	return info

func get_checkpoint_file_info() -> Dictionary:
	"""Get information about the checkpoint file without fully loading it"""
	var file_path = get_checkpoint_file_path()
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		return {}
	
	var save_data = json.data
	
	# Extract summary information
	var info = {
		"exists": true,
		"timestamp": save_data.get("timestamp", ""),
		"game_mode": save_data.get("game_mode_name", "Unknown"),
		"wave_number": save_data.get("current_wave_number", 1),
		"gold": save_data.get("gold", 0),
		"health": save_data.get("health", 100),
		"play_time": save_data.get("total_play_time", 0.0),
		"formatted_time": format_timestamp(save_data.get("timestamp", ""))
	}
	
	return info

func save_game(slot: int, main_scene: Node) -> bool:
	"""Save current game state to specified slot"""
	current_save_slot = slot
	
	# Show saving indicator
	if main_scene.has_method("show_notification"):
		main_scene.show_notification("Saving...", 1.0)
	
	var save_data = collect_game_state(main_scene)
	var file_path = get_save_file_path(slot)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		save_failed.emit(slot, "Failed to create save file")
		return false
	
	file.store_string(JSON.stringify(save_data))
	file.close()
	
	print("Game saved to slot ", slot)
	save_completed.emit(slot)
	return true

func load_game(slot: int, main_scene: Node) -> bool:
	"""Load game state from specified slot"""
	current_save_slot = slot
	
	var file_path = get_save_file_path(slot)
	if not FileAccess.file_exists(file_path):
		load_failed.emit(slot, "Save file does not exist")
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		load_failed.emit(slot, "Failed to open save file")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		load_failed.emit(slot, "Save file is corrupted")
		return false
	
	var save_data = json.data
	
	# Validate save version
	var save_version = save_data.get("save_version", 0)
	if save_version != SAVE_VERSION:
		load_failed.emit(slot, "Save file version incompatible")
		return false
	
	apply_game_state(save_data, main_scene)
	
	# Ensure achievements and house skins are properly loaded after loading game
	ensure_systems_loaded()
	
	print("Game loaded from slot ", slot)
	load_completed.emit(slot)
	return true

func collect_game_state(main_scene: Node) -> Dictionary:
	"""Collect all game state data for saving"""
	var save_data = {
		"save_version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		
		# Basic game state
		"gold": main_scene.gold,
		"health": main_scene.health,
		"current_wave_number": main_scene.current_wave_number,
		"is_wave_active": main_scene.is_wave_active,
		"is_preparation_phase": main_scene.is_preparation_phase,
		"wave_timer": main_scene.wave_timer,
		"enemies_remaining_in_wave": main_scene.enemies_remaining_in_wave,
		
		# Game mode information
		"game_mode_path": "",
		"game_mode_name": "",
		"game_mode_type": "",
		
		# Endless mode specific
		"endless_survival_time": main_scene.endless_survival_time,
		"endless_enemies_killed": main_scene.endless_enemies_killed,
		"endless_difficulty_level": main_scene.endless_difficulty_level,
		"endless_next_difficulty_time": main_scene.endless_next_difficulty_time,
		
		# Wave spawning state
		"current_spawn_group_index": main_scene.current_spawn_group_index,
		"enemies_spawned_in_group": main_scene.enemies_spawned_in_group,
		"spawn_timer": main_scene.spawn_timer,
		
		# Towers data
		"towers": [],
		
		# Path and map information
		"map_path": "",
		"path_points": main_scene.path_points,
		
		# Play time tracking
		"total_play_time": 0.0  # Could add play time tracking later
	}
	
	# Save game mode information
	if main_scene.current_game_mode:
		# Try to find the resource path for the game mode
		var game_mode_path = find_game_mode_path(main_scene.current_game_mode)
		save_data["game_mode_path"] = game_mode_path
		save_data["game_mode_name"] = main_scene.current_game_mode.mode_name
		save_data["game_mode_type"] = main_scene.current_game_mode.mode_type
	
	# Save towers information
	if main_scene.has_node("TowerContainer"):
		for tower in main_scene.get_node("TowerContainer").get_children():
			if tower.has_method("attack_target") and not tower.is_being_destroyed:
				var tower_data = {
					"position": {"x": tower.position.x, "y": tower.position.y},
					"level": tower.level,
					"tower_data_path": get_tower_data_path(tower),
					"attack_cooldown": tower.attack_cooldown if "attack_cooldown" in tower else 0.0
				}
				save_data["towers"].append(tower_data)
			elif tower.has_method("_process") and "elapsed" in tower and "build_time" in tower:
				# Save tower construction progress
				var construction_data = {
					"position": {"x": tower.position.x, "y": tower.position.y},
					"tower_scene_path": tower.tower_scene.resource_path if tower.tower_scene else "",
					"elapsed_time": tower.elapsed,
					"build_time": tower.build_time,
					"stage": tower.stage if "stage" in tower else 0,
					"mode": tower.mode if "mode" in tower else "build",
					"is_construction": true
				}
				# Save metadata if it exists
				if tower.has_meta("initial_tower_data"):
					var tower_data_resource = tower.get_meta("initial_tower_data")
					if tower_data_resource and tower_data_resource.resource_path:
						construction_data["initial_tower_data_path"] = tower_data_resource.resource_path
				# Also save upgrade metadata
				if tower.has_meta("upgrade_tower_data"):
					var upgrade_data_resource = tower.get_meta("upgrade_tower_data")
					if upgrade_data_resource and upgrade_data_resource.resource_path:
						construction_data["upgrade_tower_data_path"] = upgrade_data_resource.resource_path
				if tower.has_meta("upgrade_level"):
					construction_data["upgrade_level"] = tower.get_meta("upgrade_level")
				save_data["towers"].append(construction_data)
	
	# Try to determine current map path
	save_data["map_path"] = "res://scenes/map.tscn"  # Default map path
	if main_scene.has_node("LevelContainer"):
		var level_container = main_scene.get_node("LevelContainer")
		if level_container.get_child_count() > 0:
			var map_node = level_container.get_child(0)
			if map_node.scene_file_path:
				save_data["map_path"] = map_node.scene_file_path
	
	return save_data

func apply_game_state(save_data: Dictionary, main_scene: Node):
	"""Apply loaded save data to the game scene"""
	
	# Apply basic game state
	main_scene.gold = save_data.get("gold", 1000)
	main_scene.health = save_data.get("health", 100)
	main_scene.current_wave_number = save_data.get("current_wave_number", 1)
	main_scene.is_wave_active = save_data.get("is_wave_active", false)
	main_scene.is_preparation_phase = save_data.get("is_preparation_phase", true)
	main_scene.wave_timer = save_data.get("wave_timer", 0.0)
	main_scene.enemies_remaining_in_wave = save_data.get("enemies_remaining_in_wave", 0)
	
	# Apply endless mode state
	main_scene.endless_survival_time = save_data.get("endless_survival_time", 0.0)
	main_scene.endless_enemies_killed = save_data.get("endless_enemies_killed", 0)
	main_scene.endless_difficulty_level = save_data.get("endless_difficulty_level", 1)
	main_scene.endless_next_difficulty_time = save_data.get("endless_next_difficulty_time", 60.0)
	
	# Apply wave spawning state
	main_scene.current_spawn_group_index = save_data.get("current_spawn_group_index", 0)
	main_scene.enemies_spawned_in_group = save_data.get("enemies_spawned_in_group", 0)
	main_scene.spawn_timer = save_data.get("spawn_timer", 0.0)
	
	# Load game mode
	var game_mode_path = save_data.get("game_mode_path", "")
	if game_mode_path != "":
		main_scene.current_game_mode = load(game_mode_path)
	else:
		# Fallback: try to load by type
		var game_mode_type = save_data.get("game_mode_type", "normal")
		main_scene.current_game_mode = load_game_mode_by_type(game_mode_type)
	
	# Load map if specified (only if different from current)
	var map_path = save_data.get("map_path", "res://scenes/map.tscn")
	print("Save data map_path: ", map_path)
	
	# Check if we need to load a different map
	var need_map_load = true
	if main_scene.has_node("LevelContainer") and main_scene.get_node("LevelContainer").get_child_count() > 0:
		var existing_map = main_scene.get_node("LevelContainer").get_child(0)
		if existing_map.scene_file_path == map_path:
			print("Map already loaded, skipping map load")
			need_map_load = false
		else:
			print("Different map needed, current: ", existing_map.scene_file_path)
	
	if need_map_load and map_path != "" and main_scene.has_method("load_map"):
		print("Loading map from path: ", map_path)
		print("Calling load_map...")
		main_scene.load_map(map_path)
		print("Map load called, checking if LevelContainer exists...")
		
		# Check if map loaded immediately
		if main_scene.has_node("LevelContainer"):
			print("LevelContainer exists after load_map")
			if main_scene.get_node("LevelContainer").get_child_count() > 0:
				print("LevelContainer has children: ", main_scene.get_node("LevelContainer").get_child_count())
			else:
				print("LevelContainer has no children yet")
		else:
			print("LevelContainer does not exist after load_map")
		
		# Use call_deferred to check path after the frame
		print("Scheduling deferred path check...")
		main_scene.call_deferred("_ensure_path_after_load")
	else:
		print("Skipping map load - not needed or no path/method")
	
	# Load path points (but prefer saved path_points if they exist and map path matches)
	var path_points_data = save_data.get("path_points", [])
	print("Loading path_points from save data, count: ", path_points_data.size())
	if path_points_data.size() > 0:
		# Use saved path points
		main_scene.path_points.clear()
		for point_data in path_points_data:
			if typeof(point_data) == TYPE_VECTOR2:
				main_scene.path_points.append(point_data)
			elif typeof(point_data) == TYPE_DICTIONARY:
				main_scene.path_points.append(Vector2(point_data.get("x", 0), point_data.get("y", 0)))
		print("Loaded path_points from save data, final size: ", main_scene.path_points.size())
	else:
		print("No saved path_points, relying on map-generated path")
	
	# Load towers
	clear_existing_towers(main_scene)
	var towers_data = save_data.get("towers", [])
	for tower_data in towers_data:
		restore_tower(tower_data, main_scene)
	
	# Load current wave data based on game mode and wave number
	if main_scene.current_game_mode and main_scene.current_game_mode.mode_type != "endless":
		if main_scene.current_wave_number <= main_scene.current_game_mode.wave_definitions.size():
			main_scene.current_wave_data = main_scene.current_game_mode.wave_definitions[main_scene.current_wave_number - 1]
			
			# If we're in preparation phase but wave_timer is 0 or negative, reset it
			if main_scene.is_preparation_phase and main_scene.wave_timer <= 0:
				main_scene.wave_timer = main_scene.current_wave_data.preparation_time
				print("Reset preparation timer for wave ", main_scene.current_wave_number)
	
	# Update UI to reflect loaded state
	main_scene.update_ui()
	
	# Show notification with loaded game info
	var game_mode_name = save_data.get("game_mode_name", "Unknown")
	var wave_number = save_data.get("current_wave_number", 1)
	var gold = save_data.get("gold", 0)
	
	var notification_text = "Game Loaded!\n%s - Wave %d\nGold: %d" % [game_mode_name, wave_number, gold]
	main_scene.show_notification(notification_text)

func find_game_mode_path(game_mode: Resource) -> String:
	"""Try to find the resource path for a game mode"""
	# Check common game mode paths
	var common_paths = [
		"res://assets/gameMode/normalMode.tres",
		"res://assets/gameMode/extraHardMode.tres",
		"res://assets/gameMode/endlessMode.tres"
	]
	
	for path in common_paths:
		var resource = load(path)
		if resource == game_mode:
			return path
	
	# If not found, try to match by name/type
	if game_mode.mode_type == "endless":
		return "res://assets/gameMode/endlessMode.tres"
	elif game_mode.mode_type == "extra_hard":
		return "res://assets/gameMode/extraHardMode.tres"
	else:
		return "res://assets/gameMode/normalMode.tres"

func load_game_mode_by_type(mode_type: String) -> Resource:
	"""Load a game mode by its type"""
	match mode_type:
		"endless":
			return load("res://assets/gameMode/endlessMode.tres")
		"extra_hard":
			return load("res://assets/gameMode/extraHardMode.tres")
		"normal":
			return load("res://assets/gameMode/normalMode.tres")
		_:
			return load("res://assets/gameMode/normalMode.tres")

func get_tower_data_path(tower: Node) -> String:
	"""Get the resource path for a tower's data"""
	if not tower.tower_data:
		return ""
	
	# Check common tower data paths
	var common_paths = [
		"res://assets/towers/tower1/tower1.tres",
		"res://assets/towers/tower2/tower2.tres",
		"res://assets/towers/tower3/tower3.tres",
		"res://assets/towers/tower4/tower4.tres",
		"res://assets/towers/tower5/tower5.tres",
		"res://assets/towers/tower6/tower6.tres",
		"res://assets/towers/tower7/tower7.tres",
		"res://assets/towers/tower8/tower8.tres"
	]
	
	for path in common_paths:
		var resource = load(path)
		if resource == tower.tower_data:
			return path
	
	# Fallback: try to extract from scene path
	if tower.tower_data.scene_path:
		var scene_path = tower.tower_data.scene_path
		return scene_path.replace(".tscn", ".tres").replace("/towers/", "/towers/")
	
	return ""

func clear_existing_towers(main_scene: Node):
	"""Clear all existing towers before loading"""
	if main_scene.has_node("TowerContainer"):
		for tower in main_scene.get_node("TowerContainer").get_children():
			tower.queue_free()

func restore_tower(tower_data: Dictionary, main_scene: Node):
	"""Restore a tower from save data"""
	
	# Check if this is construction data
	if tower_data.get("is_construction", false):
		restore_tower_construction(tower_data, main_scene)
		return
	
	var tower_data_path = tower_data.get("tower_data_path", "")
	if tower_data_path == "":
		return
	
	var tower_resource = load(tower_data_path)
	if not tower_resource:
		return
	
	var tower_scene = load(tower_resource.scene_path)
	if not tower_scene:
		return
	
	var tower = tower_scene.instantiate()
	if not tower:
		return
	
	# Set position
	var pos_data = tower_data.get("position", {"x": 0, "y": 0})
	tower.position = Vector2(pos_data.x, pos_data.y)
	
	# Set level and apply stats
	tower.level = tower_data.get("level", 1)
	tower.tower_data = tower_resource
	
	# Apply level-specific stats
	if tower.has_method("apply_level_stats"):
		tower.apply_level_stats()
	
	# Set attack cooldown
	tower.attack_cooldown = tower_data.get("attack_cooldown", 0.0)
	
	# Add to tower container
	if main_scene.has_node("TowerContainer"):
		main_scene.get_node("TowerContainer").add_child(tower)
	
	# Set z_index based on position for proper depth sorting (like normal tower placement)
	# Lower Y positions (higher on screen) should be behind higher Y positions (lower on screen)
	tower.z_index = int(tower.position.y)

func restore_tower_construction(construction_data: Dictionary, main_scene: Node):
	"""Restore a tower construction from save data"""
	var tower_scene_path = construction_data.get("tower_scene_path", "")
	if tower_scene_path == "":
		return
	
	var tower_scene = load(tower_scene_path)
	if not tower_scene:
		return
	
	# Create the construction node
	var construction_scene = preload("res://scenes/towers/towerConstruction/TowerBuild.tscn")
	var construction = construction_scene.instantiate()
	
	# Set position
	var pos_data = construction_data.get("position", {"x": 0, "y": 0})
	construction.position = Vector2(pos_data.x, pos_data.y)
	
	# Restore construction state
	construction.tower_scene = tower_scene
	construction.tower_position = construction.position
	construction.elapsed = construction_data.get("elapsed_time", 0.0)
	construction.build_time = construction_data.get("build_time", 3.0)
	construction.stage = construction_data.get("stage", 0)
	construction.mode = construction_data.get("mode", "build")
	
	# Set the tower parent reference
	if main_scene.has_node("TowerContainer"):
		construction.tower_parent = main_scene.get_node("TowerContainer")
		main_scene.get_node("TowerContainer").add_child(construction)
	
	# Restore metadata if it was saved
	if construction_data.has("initial_tower_data_path"):
		var tower_data_path = construction_data["initial_tower_data_path"]
		if tower_data_path != "":
			var tower_data_resource = load(tower_data_path)
			if tower_data_resource:
				construction.set_meta("initial_tower_data", tower_data_resource)
	
	# Restore upgrade metadata
	if construction_data.has("upgrade_tower_data_path"):
		var upgrade_data_path = construction_data["upgrade_tower_data_path"]
		if upgrade_data_path != "":
			var upgrade_data_resource = load(upgrade_data_path)
			if upgrade_data_resource:
				construction.set_meta("upgrade_tower_data", upgrade_data_resource)
	
	if construction_data.has("upgrade_level"):
		construction.set_meta("upgrade_level", construction_data["upgrade_level"])
	
	# Set z_index based on position
	construction.z_index = int(construction.position.y)

func delete_save(slot: int) -> bool:
	"""Delete a save file"""
	var file_path = get_save_file_path(slot)
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		return true
	return false

func get_all_save_info() -> Array:
	"""Get information about all save slots"""
	var saves_info = []
	for i in range(1, SAVE_SLOTS + 1):
		saves_info.append(get_save_file_info(i))
	return saves_info

func create_checkpoint_save(main_scene: Node):
	"""Create an automatic checkpoint save"""
	var save_data = collect_game_state(main_scene)
	var file_path = get_checkpoint_file_path()
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("Warning: Failed to create checkpoint save")
		return
	
	file.store_string(JSON.stringify(save_data))
	file.close()
	
	print("Checkpoint saved")

func has_checkpoint_save() -> bool:
	"""Check if there's an automatic checkpoint save"""
	return FileAccess.file_exists(get_checkpoint_file_path())

func load_checkpoint_save(main_scene: Node) -> bool:
	"""Load the automatic checkpoint save"""
	var checkpoint_path = get_checkpoint_file_path()
	if not FileAccess.file_exists(checkpoint_path):
		print("No checkpoint save found")
		return false
	
	var file = FileAccess.open(checkpoint_path, FileAccess.READ)
	if not file:
		print("Failed to open checkpoint save")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("Failed to parse checkpoint save JSON")
		return false
	
	var save_data = json.data
	
	# Validate save version
	var save_version = save_data.get("save_version", 0)
	if save_version != SAVE_VERSION:
		print("Checkpoint save version incompatible")
		return false
	
	apply_game_state(save_data, main_scene)
	
	# Ensure achievements and house skins are properly loaded after loading game
	ensure_systems_loaded()
	
	print("Checkpoint loaded successfully")
	return true

func ensure_systems_loaded():
	"""Ensure all singletons are properly loaded after loading a save"""
	# Reload achievements
	var achievement_manager = get_node("/root/AchievementManager")
	if achievement_manager:
		achievement_manager.load_achievements()
	
	# Reload house skin selection
	var house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		house_skin_manager.load_selected_skin()

func format_timestamp(timestamp_str: String) -> String:
	"""Format timestamp into a readable format"""
	if timestamp_str == "":
		return "Unknown"
	
	# Parse the ISO timestamp format from Godot: "2025-01-09T12:34:56"
	var parts = timestamp_str.split("T")
	if parts.size() != 2:
		return "Unknown"
	
	var date_part = parts[0]
	var time_part = parts[1]
	
	# Format date from YYYY-MM-DD to MM/DD/YYYY
	var date_components = date_part.split("-")
	if date_components.size() == 3:
		var year = date_components[0]
		var month = date_components[1]
		var day = date_components[2]
		
		# Format time from HH:MM:SS to HH:MM
		var time_components = time_part.split(":")
		if time_components.size() >= 2:
			var hour = int(time_components[0])
			var minute = time_components[1]
			
			# Convert to 12-hour format
			var period = "AM"
			if hour == 0:
				hour = 12
			elif hour == 12:
				period = "PM"
			elif hour > 12:
				hour -= 12
				period = "PM"
			
			return "%s/%s/%s %d:%s %s" % [month, day, year, hour, minute, period]
	
	return timestamp_str
